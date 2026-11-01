--!strict
-- Pulls player feedback from every configured game through Open Cloud and
-- writes a triage digest.
--
--   lune run tools/feedback/pull [--from 2026-11-01] [--to 2026-11-01]
--                                [--env production|staging|all] [--out feedback-out]
--                                [--environments ops/environments.json]
--   lune run tools/feedback/pull --hours 1 [--build <commit>]   (post-publish error sweep)
--
-- Reads two DataStores per experience: "Feedback" (player reports) and
-- "ErrorQueue" (server and client errors, see errors.luau). With --hours it
-- covers the last N hours instead of whole days, and --build keeps only
-- errors from builds starting with that commit.
--
-- Dates are UTC days, inclusive; both default to yesterday, so a daily run
-- reads each report exactly once. Reads the experience ids from
-- ops/environments.json and a read-only Open Cloud key from ROBLOX_READ_API_KEY
-- (DataStore "list entry keys" + "read entry"; see ops/SETUP.md). The key is
-- never printed.
--
-- Runs the plain-code prefilter (prefilter.luau) and puts its ranked "Needs
-- triage" list at the top of the digest.
--
-- Writes <out>/digest.md (Markdown, also the GitHub issue body),
-- <out>/triage.json (the prefilter's groups),
-- <out>/reports.jsonl (one report per line, with user ids, for the artifact
-- only) and <out>/summary.json. Writes `configured`, `total`, `bugs`,
-- `problems` and `title` to $GITHUB_OUTPUT when running in GitHub Actions.

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")
local Errors = require("./errors")
local Prefilter = require("./prefilter")
local lib = require("./lib")

local args: { [string]: string } = {}
do
	local i = 1
	while i <= #process.args do
		local flag = process.args[i]
		local value = process.args[i + 1]
		if string.sub(flag, 1, 2) ~= "--" or value == nil then
			print("usage: lune run tools/feedback/pull [--from YYYY-MM-DD] [--to YYYY-MM-DD]")
			print("                                    [--env production|staging|all] [--out dir]")
			process.exit(2)
		end
		args[string.sub(flag, 3)] = value
		i += 2
	end
end

local function output(name: string, value: string)
	local path = process.env.GITHUB_OUTPUT
	if path then
		local existing = if fs.isFile(path) then fs.readFile(path) else ""
		fs.writeFile(path, existing .. `{name}={value}\n`)
	end
end

local now = tonumber(process.env.FEEDBACK_NOW) or os.time() -- FEEDBACK_NOW: the tool's own tests only
local hours = if args.hours then tonumber(args.hours) else nil
assert(args.hours == nil or (hours and hours > 0 and hours <= 24 * 62), "--hours must be a number of hours")
local since: number? = if hours then now - hours * 3600 else nil
local yesterday = lib.dateOf(now - 86400)
local from = if since then lib.dateOf(since) else (args.from or yesterday)
local to = if since then lib.dateOf(now) else (args.to or from)
local buildFilter = args.build
local envFilter = args.env or "all"
local outDir = args.out or "feedback-out"
assert(
	envFilter == "all" or table.find(lib.ENVIRONMENTS, envFilter),
	"--env must be production, staging or all"
)
assert(buildFilter == nil or string.match(buildFilter, "^%x+$"), "--build is a commit hash (or its start)")

local prefixes = lib.dayPrefixes(from, to)
local environments = serde.decode("json", fs.readFile(args.environments or "ops/environments.json"))
local targets = lib.targets(environments, envFilter)
local key = process.env.ROBLOX_READ_API_KEY
local base = process.env.OPEN_CLOUD_BASE_URL

if #targets == 0 or key == nil or key == "" then
	output("configured", "false")
	print(
		if #targets == 0
			then "No game has experience ids in ops/environments.json yet; nothing to pull."
			else "ROBLOX_READ_API_KEY is not set; nothing to pull (see ops/SETUP.md)."
	)
	process.exit(0)
end
output("configured", "true")

-- GET with retries on rate limits and server errors.
local function get(url: string): (boolean, string, number)
	local wait = 2
	for attempt = 1, 5 do
		local response = net.request({
			url = url,
			method = "GET",
			headers = { ["x-api-key"] = key :: string },
		})
		if response.ok then
			return true, response.body, response.statusCode
		end
		local retry = response.statusCode == 429 or response.statusCode >= 500
		if not retry or attempt == 5 then
			return false, response.body, response.statusCode
		end
		task.wait(wait)
		wait *= 2
	end
	return false, "", 0
end

local problems: { string } = {}

-- Reads every batch in one store for the chosen days. Returns false when the
-- store could not be listed at all.
local function readStore(target: lib.Target, store: string, onBatch: (key: string, batch: any) -> ()): boolean
	local label = `{target.game} {target.environment} {store}`
	for _, prefix in prefixes do
		local cursor: string? = nil
		repeat
			local ok, body, status = get(lib.listUrl(target.universeId, prefix, cursor, base, store))
			if not ok then
				-- Roblox's error text never contains the key.
				table.insert(
					problems,
					`{label}: listing {prefix} failed with HTTP {status}: {string.sub(body, 1, 200)}`
				)
				return false
			end
			local page = serde.decode("json", body)
			for _, entry in page.keys or {} do
				local entryOk, entryBody, entryStatus =
					get(lib.entryUrl(target.universeId, entry.key, base, store))
				if entryOk then
					local decodedOk, batch = pcall(serde.decode, "json" :: "json", entryBody)
					onBatch(entry.key, if decodedOk then batch else nil)
				else
					table.insert(problems, `{label}: reading {entry.key} failed with HTTP {entryStatus}`)
				end
			end
			cursor = page.nextPageCursor
		until cursor == nil or cursor == ""
	end
	return true
end

local reports: { lib.Report } = {}
local errorRecords: { Errors.Record } = {}
local droppedErrors = 0
local readOk = 0

for _, target in targets do
	local feedbackOk = readStore(target, lib.STORE, function(entryKey, batch)
		local found, reason = lib.reportsFrom(batch)
		if reason then
			table.insert(problems, `{target.game} {target.environment}: skipped {entryKey}: {reason}`)
		end
		for _, report in found do
			if since == nil or report.at >= since then
				report.environment = target.environment
				table.insert(reports, report)
			end
		end
	end)
	local errorsOk = readStore(target, Errors.STORE, function(entryKey, batch)
		local found, reason = Errors.from(batch, target.environment, Errors.serverFromKey(entryKey))
		if reason then
			table.insert(
				problems,
				`{target.game} {target.environment}: skipped error batch {entryKey}: {reason}`
			)
			return
		end
		if since == nil or (tonumber(batch.at) or 0) >= since then
			droppedErrors += tonumber(batch.droppedSignatures) or 0
			for _, record in found do
				table.insert(errorRecords, record)
			end
		end
	end)
	if feedbackOk or errorsOk then
		readOk += 1
	end
	print(`{target.game} {target.environment}: done`)
end

table.sort(reports, function(a, b)
	if a.game ~= b.game then
		return a.game < b.game
	end
	return a.at < b.at
end)

local title = if hours
	then `Error sweep: last {hours} h` .. (if buildFilter
		then ` (build {string.sub(buildFilter, 1, 7)})`
		else "")
	elseif from == to then `Player feedback {from}`
	else `Player feedback {from} to {to}`

local sweep = Errors.sweep(errorRecords, buildFilter, droppedErrors)
local errorSection = Errors.markdown(sweep, lib.escape)

-- The prefilter must never stop the issue: if it fails, the issue says so
-- and every bug is triaged by hand.
local function emptyTriage(): Prefilter.Result
	return { items = {}, quiet = 0, cappedReporters = 0, cappedGroups = {}, overflow = {} }
end
local triage = emptyTriage()
local preface = ""
local blockExtra = { errors = Errors.blockEntries(sweep), stop = sweep.stop }
local prefilterOk, prefilterErr = pcall(function()
	if process.env.FEEDBACK_TEST_BREAK_PREFILTER == "1" then
		error("forced failure for the tool's own test")
	end
	triage = Prefilter.run(reports :: any)
	preface = Prefilter.markdown(triage, lib.escape)
		.. "\n"
		.. Prefilter.block(triage, function(value)
			return serde.encode("json", value)
		end, blockExtra)
end)
if not prefilterOk then
	print(`problem: prefilter failed: {prefilterErr}`)
	triage = emptyTriage()
	local failed =
		{ version = 1, failed = true, items = {}, errors = blockExtra.errors, stop = blockExtra.stop }
	preface = "## Needs triage\n\n**Prefilter failed: triage every bug by hand.**\n\n"
		.. `<!-- loop-lab-triage v1\n{(string.gsub(serde.encode("json", failed), "%-%-", "- -"))}\n-->`
	table.insert(problems, "prefilter failed; see the run log")
end

local digest = lib.digest(reports, title, nil, preface)
-- Errors go right after the triage list, before the per-game feedback.
local markdown = digest.markdown
local firstGame = string.find(markdown, "\n## ", 1, true)
local afterTriage = if #reports > 0 then string.find(markdown, "\n## ", (firstGame or 0) + 1, true) else nil
if afterTriage then
	markdown = string.sub(markdown, 1, afterTriage) .. errorSection .. string.sub(markdown, afterTriage)
else
	markdown ..= "\n" .. errorSection
end
if #problems > 0 then
	local lines = { "", "## Problems reading feedback", "" }
	for _, problem in problems do
		table.insert(lines, `- {lib.escape(problem)}`)
	end
	markdown ..= table.concat(lines, "\n") .. "\n"
end

fs.writeDir(outDir)
fs.writeFile(`{outDir}/digest.md`, markdown)
local jsonl = {}
for _, report in reports do
	table.insert(jsonl, serde.encode("json", report))
end
fs.writeFile(`{outDir}/reports.jsonl`, table.concat(jsonl, "\n") .. (if #jsonl > 0 then "\n" else ""))
fs.writeFile(`{outDir}/triage.json`, serde.encode("json", triage, true))
fs.writeFile(`{outDir}/errors.json`, serde.encode("json", sweep, true))
fs.writeFile(
	`{outDir}/summary.json`,
	serde.encode("json", {
		from = from,
		to = to,
		hours = hours,
		build = buildFilter,
		total = digest.total,
		bugs = digest.bugs,
		ideas = digest.ideas,
		other = digest.other,
		escalated = #triage.items + #triage.overflow,
		errorGroups = #sweep.groups,
		stop = sweep.stop,
		problems = problems,
	}, true)
)

output("total", tostring(digest.total))
output("bugs", tostring(digest.bugs))
output("problems", tostring(#problems))
output("escalated", tostring(#triage.items + #triage.overflow))
output("errors", tostring(#sweep.groups))
output("stop", tostring(sweep.stop))
output("title", title)
print(
	`{digest.total} reports ({digest.bugs} bugs) and {#sweep.groups} error groups`
		.. ` from {from} to {to}; digest in {outDir}/digest.md`
)
if sweep.stop then
	print("STOP: a server error, or a client error seen 10+ times (ops/PUBLISH_CHECKS.md step 3)")
end
for _, problem in problems do
	print(`problem: {problem}`)
end

-- Fail the run only when nothing could be read at all (a bad key or outage),
-- so one misconfigured experience never hides the others' feedback.
if readOk == 0 then
	process.exit(1)
end
