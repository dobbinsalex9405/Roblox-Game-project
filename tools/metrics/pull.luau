--!strict
-- Reads every live game's daily counters through Open Cloud and writes the
-- studio scoreboard.
--
--   lune run tools/metrics/pull [--env production|staging] [--through 20261101]
--                               [--out metrics-out] [--environments ops/environments.json]
--
-- `--through` is the last UTC day to report (default yesterday). Reads the
-- experience ids from ops/environments.json and the read-only Open Cloud key
-- from ROBLOX_READ_API_KEY (DataStore "list entry keys" + "read entry", the
-- same key the feedback pull uses; see ops/SETUP.md). The key is never printed.
--
-- Writes <out>/scoreboard.md (the issue body, with the hidden JSON block) and
-- <out>/scoreboard.json. Writes `configured` and `problems` to $GITHUB_OUTPUT
-- when running in GitHub Actions.

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")
local Metrics = require("@core/Metrics")
local lib = require("./lib")

local args: { [string]: string } = {}
do
	local i = 1
	while i <= #process.args do
		local flag = process.args[i]
		local value = process.args[i + 1]
		if string.sub(flag, 1, 2) ~= "--" or value == nil then
			print("usage: lune run tools/metrics/pull [--env production|staging] [--through YYYYMMDD]")
			print("                                   [--out dir] [--environments file]")
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

local environment = args.env or "production"
local through = args.through or Metrics.dayKey(os.time() - 86400)
local outDir = args.out or "metrics-out"
lib.dayNumber(through) -- checks the format

local environments = serde.decode("json", fs.readFile(args.environments or "ops/environments.json"))
local targets = lib.targets(environments, environment)
local key = process.env.ROBLOX_READ_API_KEY
local base = process.env.OPEN_CLOUD_BASE_URL

if #targets == 0 or key == nil or key == "" then
	output("configured", "false")
	print(
		if #targets == 0
			then `No game has {environment} experience ids in ops/environments.json yet; nothing to read.`
			else "ROBLOX_READ_API_KEY is not set; nothing to read (see ops/SETUP.md)."
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

-- Read from the day before the challenge start (for its D1) or, at most, 62 days back.
local earliest = lib.addDays(lib.CHALLENGE_START, -1)
local floor = lib.addDays(through, -62)
local from = if earliest > floor then earliest else floor

local problems: { string } = {}
local reports: { lib.GameReport } = {}
local readOk = 0
local configured: { [string]: lib.Target } = {}
for _, target in targets do
	configured[target.game] = target
end

for _, game in lib.allGames(environments) do
	local target = configured[game]
	local days: lib.GameDays = {}
	if target then
		local label = `{game} {environment}`
		local keys: { string } = {}
		local failed = false
		local cursor: string? = nil
		repeat
			local ok, body, status = get(lib.listUrl(target.universeId, cursor, base))
			if not ok then
				-- A 404 here usually means nothing has been written yet (a new game).
				if status ~= 404 then
					table.insert(
						problems,
						`{label}: listing keys failed with HTTP {status}: {string.sub(body, 1, 200)}`
					)
					failed = true
				end
				break
			end
			local page = serde.decode("json", body)
			for _, entry in page.keys or {} do
				if type(entry.key) == "string" then
					table.insert(keys, entry.key)
				end
			end
			cursor = page.nextPageCursor
		until cursor == nil or cursor == ""

		if not failed then
			for _, entryKey in lib.keysToRead(keys, from, through) do
				local ok, body, status = get(lib.entryUrl(target.universeId, entryKey, base))
				if ok then
					local decodedOk, value = pcall(serde.decode, "json" :: "json", body)
					local problem = lib.addShard(days, entryKey, if decodedOk then value else nil)
					if problem then
						table.insert(problems, `{label}: skipped {entryKey}: {problem}`)
					end
				else
					table.insert(problems, `{label}: reading {entryKey} failed with HTTP {status}`)
				end
			end
			readOk += 1
		end
		print(`{label}: {#keys} keys`)
	end
	table.insert(reports, lib.report(game, target ~= nil, days, through))
end

local markdown, json =
	lib.scoreboard(reports, through, environment, os.date("!%Y-%m-%d %H:%M UTC") :: string, problems)
local encoded = serde.encode("json", json)
fs.writeDir(outDir)
fs.writeFile(`{outDir}/scoreboard.md`, markdown .. "\n" .. lib.hiddenBlock(encoded))
fs.writeFile(`{outDir}/scoreboard.json`, serde.encode("json", json, true))

output("problems", tostring(#problems))
print(
	`scoreboard through {through}: {json.robuxTotal} Robux since {lib.CHALLENGE_START}; {#problems} problems`
)
for _, problem in problems do
	print(`problem: {problem}`)
end

-- Fail only when no game could be read at all (a bad key or an outage).
if readOk == 0 then
	process.exit(1)
end
