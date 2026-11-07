--!strict
-- Pure helpers for tools/publish/run.luau, kept separate so they are unit-tested.

export type Target = { universeId: number, placeId: number }

local lib = {}

lib.ENVIRONMENTS = { "staging", "production" }

local GAME_PATTERN = "^[a-z][a-z0-9%-]*$"

-- Returns the target, or nil and a reason it is not configured yet.
function lib.target(environments: { [string]: any }, game: string, environment: string): (Target?, string?)
	assert(string.match(game, GAME_PATTERN), `invalid game name {game}`)
	assert(
		table.find(lib.ENVIRONMENTS, environment),
		`environment must be staging or production, got {environment}`
	)
	local entry = environments[game]
	if type(entry) ~= "table" then
		return nil, `ops/environments.json has no entry for {game}`
	end
	local env = entry[environment]
	if type(env) ~= "table" then
		return nil, `ops/environments.json has no {environment} entry for {game}`
	end
	local universeId, placeId = env.universeId, env.placeId
	for name, value in { universeId = universeId, placeId = placeId } do
		if type(value) ~= "number" or value // 1 ~= value or value < 0 then
			error(`{game}.{environment}.{name} must be a whole number, got {tostring(value)}`)
		end
	end
	if universeId == 0 or placeId == 0 then
		return nil, `{game} has no {environment} experience ids yet`
	end
	return { universeId = universeId, placeId = placeId }, nil
end

local DEFAULT_BASE = "https://apis.roblox.com"

-- Open Cloud Place Publishing API. `base` may only point at this machine
-- (for the tool's own smoke test), so a key can never be sent anywhere else.
function lib.url(target: Target, base: string?): string
	local root = base or DEFAULT_BASE
	assert(
		root == DEFAULT_BASE or string.match(root, "^http://127%.0%.0%.1:%d+$"),
		"the API base URL can only be Roblox or a local test server"
	)
	return `{root}/universes/v1/{target.universeId}/places/{target.placeId}/versions?versionType=Published`
end

-- The GitHub secret that holds a game's key in each environment, e.g. ROBLOX_API_KEY_HATCHERY_HEIST.
function lib.secretName(game: string): string
	return "ROBLOX_API_KEY_" .. string.upper((string.gsub(game, "%-", "_")))
end

-- Reads the version number from a successful response body.
function lib.versionFrom(body: { [string]: any }): number
	local version = body.versionNumber
	assert(type(version) == "number" and version >= 1, "response has no versionNumber")
	return version
end

-- How long to wait before trying an Open Cloud place save again, or nil to
-- give up. Roblox answers 429 while a place has too many tasks and 5xx when it
-- is down; it also answers 409 "Save failed. Server is busy" for a minute or
-- two after any save to the same place, even one by another workflow, so a
-- 409 earns a long wait instead of a failed publish.
lib.MAX_ATTEMPTS = 4
function lib.retryDelay(statusCode: number, attempt: number): number?
	if attempt >= lib.MAX_ATTEMPTS then
		return nil
	end
	if statusCode == 409 then
		return 45 * attempt
	end
	if statusCode == 429 or statusCode >= 500 then
		return 2 ^ attempt * 2
	end
	return nil
end

return lib
