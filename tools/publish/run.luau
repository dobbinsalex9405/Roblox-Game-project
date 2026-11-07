--!strict
-- Publishes build/<game>.rbxl to one environment through Open Cloud.
--
--   lune run tools/publish/run <game> <staging|production>          publish
--   lune run tools/publish/run <game> <staging|production> --check  only report whether it is configured
--
-- Reads the experience ids from ops/environments.json and the API key from the
-- ROBLOX_API_KEY environment variable (set from a GitHub environment secret).
-- The key is never printed. Writes `configured`, `version` and `place_id` to
-- $GITHUB_OUTPUT when running in GitHub Actions.

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")
local lib = require("./lib")

local game, environment, flag = process.args[1], process.args[2], process.args[3]
if game == nil or environment == nil then
	print("usage: lune run tools/publish/run <game> <staging|production> [--check]")
	process.exit(2)
end

local function output(name: string, value: string)
	local path = process.env.GITHUB_OUTPUT
	if path then
		local existing = if fs.isFile(path) then fs.readFile(path) else ""
		fs.writeFile(path, existing .. `{name}={value}\n`)
	end
end

local environments = serde.decode("json", fs.readFile("ops/environments.json"))
local target, reason = lib.target(environments, game, environment)
local key = process.env.ROBLOX_API_KEY
local hasKey = key ~= nil and key ~= ""

if flag == "--check" then
	local configured = target ~= nil and hasKey
	output("configured", tostring(configured))
	if not configured then
		print(
			`{game} {environment} is not set up yet: {reason or `the {lib.secretName(game)} secret is missing`}`
		)
	end
	process.exit(0)
end

if target == nil then
	print(`Cannot publish: {reason}`)
	process.exit(1)
end
if not hasKey then
	print(`Cannot publish: the {lib.secretName(game)} secret is not set for the {environment} environment`)
	process.exit(1)
end

local placeFile = `build/{game}.rbxl`
if not fs.isFile(placeFile) then
	print(`Cannot publish: {placeFile} does not exist; run tools/build.sh {game} first`)
	process.exit(1)
end

local body = fs.readFile(placeFile)
local response
for attempt = 1, lib.MAX_ATTEMPTS do
	response = net.request({
		url = lib.url(target, process.env.OPEN_CLOUD_BASE_URL),
		method = "POST",
		headers = {
			["x-api-key"] = key :: string,
			["content-type"] = "application/octet-stream",
		},
		body = body,
	})
	if response.ok then
		break
	end
	-- Roblox answers 409 "Server is busy" while an earlier save to the same
	-- place settles (a real-engine check, or the previous publish); 429 and
	-- 5xx are its rate limit and outages. Wait and try again.
	local delay = lib.retryDelay(response.statusCode, attempt)
	if not delay then
		break
	end
	print(`HTTP {response.statusCode} from Roblox; trying again in {delay} s ({attempt}/{lib.MAX_ATTEMPTS})`)
	task.wait(delay)
end

if not response.ok then
	-- The body is Roblox's error message; it never contains the key.
	print(`Publish failed: HTTP {response.statusCode} {response.statusMessage}\n{response.body}`)
	process.exit(1)
end

local version = lib.versionFrom(serde.decode("json", response.body))
print(`Published {game} to {environment}: place {target.placeId}, version {version}`)
output("version", tostring(version))
output("place_id", tostring(target.placeId))
