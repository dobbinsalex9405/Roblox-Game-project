--!strict
-- Pulls player feedback from every configured game through Open Cloud and
-- writes a triage digest.
--
--   lune run tools/feedback/pull [--from 2026-11-01] [--to 2026-11-01]
--                                [--env production|staging|all] [--out feedback-out]
--                                [--environments ops/environments.json]
--
-- Dates are UTC days, inclusive; both default to yesterday, so a daily run
-- reads each report exactly once. Reads the experience ids from
-- ops/environments.json and a read-only Open Cloud key from ROBLOX_READ_API_KEY
-- (DataStore "list entry keys" + "read entry"; see ops/SETUP.md). The key is
-- never printed.
--
-- Writes <out>/digest.md (Markdown, also the GitHub issue body),
-- <out>/reports.jsonl (one report per line, with user ids, for the artifact
-- only) and <out>/summary.json. Writes `configured`, `total`, `bugs`,
-- `problems` and `title` to $GITHUB_OUTPUT when running in GitHub Actions.

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")
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

local yesterday = lib.dateOf(os.time() - 86400)
local from = args.from or yesterday
local to = args.to or from
local envFilter = args.env or "all"
local outDir = args.out or "feedback-out"
assert(
	envFilter == "all" or table.find(lib.ENVIRONMENTS, envFilter),
	"--env must be production, staging or all"
)

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

local reports: { lib.Report } = {}
local problems: { string } = {}
local readOk = 0

for _, target in targets do
	local label = `{target.game} {target.environment}`
	local failed = false
	for _, prefix in prefixes do
		local cursor: string? = nil
		repeat
			local ok, body, status = get(lib.listUrl(target.universeId, prefix, cursor, base))
			if not ok then
				-- Roblox's error text never contains the key.
				table.insert(
					problems,
					`{label}: listing {prefix} failed with HTTP {status}: {string.sub(body, 1, 200)}`
				)
				failed = true
				break
			end
			local page = serde.decode("json", body)
			for _, entry in page.keys or {} do
				local entryOk, entryBody, entryStatus = get(lib.entryUrl(target.universeId, entry.key, base))
				if entryOk then
					local decodedOk, batch = pcall(serde.decode, "json" :: "json", entryBody)
					local found, reason = lib.reportsFrom(if decodedOk then batch else nil)
					if reason then
						table.insert(problems, `{label}: skipped {entry.key}: {reason}`)
					end
					for _, report in found do
						report.environment = target.environment
						table.insert(reports, report)
					end
				else
					table.insert(problems, `{label}: reading {entry.key} failed with HTTP {entryStatus}`)
				end
			end
			cursor = page.nextPageCursor
		until cursor == nil or cursor == ""
		if failed then
			break
		end
	end
	if not failed then
		readOk += 1
	end
	print(`{label}: done`)
end

table.sort(reports, function(a, b)
	if a.game ~= b.game then
		return a.game < b.game
	end
	return a.at < b.at
end)

local title = if from == to then `Player feedback {from}` else `Player feedback {from} to {to}`
local digest = lib.digest(reports, title)
local markdown = digest.markdown
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
fs.writeFile(
	`{outDir}/summary.json`,
	serde.encode("json", {
		from = from,
		to = to,
		total = digest.total,
		bugs = digest.bugs,
		ideas = digest.ideas,
		other = digest.other,
		problems = problems,
	}, true)
)

output("total", tostring(digest.total))
output("bugs", tostring(digest.bugs))
output("problems", tostring(#problems))
output("title", title)
print(`{digest.total} reports ({digest.bugs} bugs) from {from} to {to}; digest in {outDir}/digest.md`)
for _, problem in problems do
	print(`problem: {problem}`)
end

-- Fail the run only when nothing could be read at all (a bad key or outage),
-- so one misconfigured experience never hides the others' feedback.
if readOk == 0 then
	process.exit(1)
end
