--!strict
-- Real-engine check: runs tools/cloud/probe.luau inside a real Roblox server
-- for one game's built place, through Open Cloud Luau Execution.
--
--   lune run tools/cloud/run <game> [--place build/<game>.rbxl]
--
-- 1. Copies build/<game>.rbxl with ServerScriptService.LoadStringEnabled on
--    (the probe starts the server scripts itself) to build/cloud-<game>.rbxl.
-- 2. Saves it as a new version of the game's Staging place WITHOUT
--    publishing it (versionType=Saved): players and live servers never see
--    it; the next Staging publish replaces it as the latest version.
-- 3. Starts a Luau Execution task on that version, waits for it (5 min max),
--    prints its log and writes build/cloud/<game>.json and .md.
--
-- Needs ROBLOX_API_KEY: the game's Staging key with Luau Execution access
-- (ops/SETUP.md). The key is never printed. The HUD texts the headless
-- audit measured (build/audit/<game>/report.json) are measured again with
-- Roblox's own fonts when present. Exit code 1 when any check fails.

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local task = require("@lune/task")
local lib = require("./lib")
local publishLib = require("../publish/lib")

local game = process.args[1]
if game == nil then
	print("usage: lune run tools/cloud/run <game>")
	process.exit(2)
end

local environments = serde.decode("json", fs.readFile("ops/environments.json"))
local target, reason = publishLib.target(environments, game :: string, "staging")
if target == nil then
	print(`Cannot run the cloud check: {reason}`)
	process.exit(1)
end
local key = process.env.ROBLOX_API_KEY
if key == nil or key == "" then
	print(
		`Cannot run the cloud check: ROBLOX_API_KEY is not set (the {publishLib.secretName(game :: string)} Staging secret)`
	)
	process.exit(1)
end
local base = process.env.OPEN_CLOUD_BASE_URL
local place = target :: publishLib.Target

local built = `build/{game}.rbxl`
if process.args[2] == "--place" and process.args[3] then
	built = process.args[3]
end
if not fs.isFile(built) then
	print(
		`Cannot run the cloud check: {built} does not exist; run BUILD_ENVIRONMENT=staging tools/build.sh {game} first`
	)
	process.exit(1)
end

-- 1. The probe's copy of the place.
local datamodel = roblox.deserializePlace(fs.readFile(built))
datamodel:GetService("ServerScriptService").LoadStringEnabled = true
fs.writeDir("build/cloud")
local copy = `build/cloud-{game}.rbxl`
fs.writeFile(copy, roblox.serializePlace(datamodel))

local function request(method: string, url: string, body: string?, contentType: string?): { [string]: any }
	local headers: { [string]: string } = { ["x-api-key"] = key :: string }
	if contentType then
		headers["content-type"] = contentType
	end
	for attempt = 1, publishLib.MAX_ATTEMPTS do
		local response = net.request({ url = url, method = method :: any, headers = headers, body = body })
		if response.ok then
			return if response.body == "" then {} else serde.decode("json", response.body)
		end
		-- 409 (another save to this place is still settling), 429 (ten tasks
		-- per place at once, five creates a minute) and 5xx: wait and retry.
		local delay = publishLib.retryDelay(response.statusCode, attempt)
		if delay then
			print(
				`HTTP {response.statusCode} from Roblox; trying again in {delay} s ({attempt}/{publishLib.MAX_ATTEMPTS})`
			)
			task.wait(delay)
		else
			-- Roblox's own error message; it never contains the key.
			print(
				`{method} {string.gsub(url, "%?.*$", "")} failed: HTTP {response.statusCode} {response.statusMessage}\n{response.body}`
			)
			process.exit(1)
		end
	end
	error("unreachable")
end

-- 2. Save, don't publish.
local saved = request(
	"POST",
	lib.saveUrl(place.universeId, place.placeId, base),
	fs.readFile(copy),
	"application/octet-stream"
)
local version = publishLib.versionFrom(saved)
print(`Saved {game} as Staging place version {version} (not published)`)

-- 3. Run the probe on that version.
local texts = {}
local auditReport = `build/audit/{game}/report.json`
if fs.isFile(auditReport) then
	texts = serde.decode("json", fs.readFile(auditReport)).texts or {}
end
local script = lib.script(
	fs.readFile("tools/audit/World.luau"),
	fs.readFile("tools/cloud/probe.luau"),
	texts,
	function(v)
		return serde.encode("json", v)
	end
)
local created = request(
	"POST",
	lib.taskUrl(place.universeId, place.placeId, version, base),
	serde.encode("json", { script = script, timeout = "300s" }),
	"application/json"
)
local path = created.path
assert(type(path) == "string", "the create call returned no task path")
print(`Started {path}`)

local outcome = lib.outcome(created)
local deadline = os.clock() + 330
while not outcome.done do
	if os.clock() > deadline then
		print("The task did not finish in time")
		process.exit(1)
	end
	task.wait(3)
	outcome = lib.outcome(request("GET", lib.pathUrl(path, base)))
end

local logs = request("GET", lib.pathUrl(path, base) .. "/logs")
for _, page in logs.luauExecutionSessionTaskLogs or {} do
	for _, line in page.messages or {} do
		print(`[log] {line}`)
	end
end

if not outcome.ok then
	print(`The probe failed: {outcome.error}`)
	process.exit(1)
end

local report = lib.report(outcome.results, function(s)
	return serde.decode("json", s)
end)
for _, f in lib.coverage(report) do
	table.insert(report.findings, f)
end
fs.writeFile(`build/cloud/{game}.json`, serde.encode("json", report, true))
local covered =
	`Started {report.started} server script(s); {report.parts} parts, {report.labels} labels and prompts, {report.spawns} spawn(s); {report.texts} HUD texts measured with Roblox's fonts.`
print(covered)
local lines = {
	`# Real-engine check: {game}, Staging place version {version}`,
	"",
	covered,
	"",
}
local failed = false
for _, f in report.findings do
	table.insert(lines, `- **{f.severity}** \`{f.rule}\`: {f.message}`)
	print(`[{f.severity}] {f.rule}: {f.message}`)
	if f.severity == "FAIL" then
		failed = true
	end
end
fs.writeFile(`build/cloud/{game}.md`, table.concat(lines, "\n") .. "\n")
if failed then
	print(`\nREAL-ENGINE CHECK FAILED for {game}`)
	process.exit(1)
end
print(`\nREAL-ENGINE CHECK PASSED for {game}`)
