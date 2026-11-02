--!strict
-- Writes the update plan (ops/UPDATE_LOOP.md) from the scoreboard, the release
-- tags and the open bugs.
--
--   lune run tools/loop/run --metrics <file> [--releases <file>] [--bugs <file>]
--                           [--today YYYYMMDD] [--out loop-out]
--                           [--environments ops/environments.json]
--
-- --metrics   the scoreboard issue body (with its hidden loop-lab-metrics block)
--             or scoreboard.json; a missing or empty file means "no numbers yet"
-- --releases  lines "<game>/production/v<n>|YYYYMMDD" (git for-each-ref, see the workflow)
-- --bugs      gh issue list --label bug --state open --json number,labels
--
-- Writes <out>/plan.md (the issue body with the hidden loop-lab-plan block) and
-- <out>/plan.json. Reads no secrets and calls no network.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local metricsLib = require("../metrics/lib")
local lib = require("./lib")

local args: { [string]: string } = {}
do
	local i = 1
	while i <= #process.args do
		local flag = process.args[i]
		local value = process.args[i + 1]
		if string.sub(flag, 1, 2) ~= "--" or value == nil then
			print("usage: lune run tools/loop/run --metrics file [--releases file] [--bugs file]")
			print("                               [--today YYYYMMDD] [--out dir] [--environments file]")
			process.exit(2)
		end
		args[string.sub(flag, 3)] = value
		i += 2
	end
end

local function readOptional(path: string?): string
	if path and fs.isFile(path) then
		return fs.readFile(path)
	end
	return ""
end

local today = args.today or (os.date("!%Y%m%d") :: string)
metricsLib.dayNumber(today) -- checks the format
local outDir = args.out or "loop-out"

local environments = serde.decode("json", fs.readFile(args.environments or "ops/environments.json"))
local games = metricsLib.allGames(environments)

local metricsText = readOptional(args.metrics)
local metrics, problem = nil, nil
if string.match(metricsText, "%S") then
	metrics, problem = lib.extractMetrics(metricsText, function(text)
		return serde.decode("json", text)
	end)
end

local releases = lib.parseReleases(readOptional(args.releases))

local bugsText = readOptional(args.bugs)
local issues: any = {}
if string.match(bugsText, "%S") then
	local ok, decoded = pcall(serde.decode, "json" :: "json", bugsText)
	issues = if ok then decoded else {}
end

local plan = lib.plan(metrics, games, releases, issues, today)
if problem then
	table.insert(plan.problems, 1, problem)
end

local markdown = lib.markdown(plan, os.date("!%Y-%m-%d %H:%M UTC") :: string)
fs.writeDir(outDir)
fs.writeFile(`{outDir}/plan.md`, markdown .. "\n" .. lib.hiddenBlock(serde.encode("json", plan)))
fs.writeFile(`{outDir}/plan.json`, serde.encode("json", plan, true))

for _, name in plan.order do
	local g = plan.games[name]
	print(`{name}: {g.stage}, focus {g.focus}: {g.focusWhy}`)
end
for _, p in plan.problems do
	print(`problem: {p}`)
end
