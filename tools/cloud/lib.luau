--!strict
-- Pure helpers for tools/cloud/run.luau (Open Cloud Luau Execution), kept
-- separate so they are unit-tested without a key or a network.

local lib = {}

local DEFAULT_BASE = "https://apis.roblox.com"

-- The API base may only be Roblox or this machine (the tool's own tests),
-- so a key is never sent anywhere else.
function lib.base(base: string?): string
	local root = base or DEFAULT_BASE
	assert(
		root == DEFAULT_BASE or string.match(root, "^http://127%.0%.0%.1:%d+$"),
		"the API base URL can only be Roblox or a local test server"
	)
	return root
end

-- Saves (does not publish) a place version: players never see it.
function lib.saveUrl(universeId: number, placeId: number, base: string?): string
	return `{lib.base(base)}/universes/v1/{universeId}/places/{placeId}/versions?versionType=Saved`
end

function lib.taskUrl(universeId: number, placeId: number, version: number, base: string?): string
	return `{lib.base(base)}/cloud/v2/universes/{universeId}/places/{placeId}/versions/{version}/luau-execution-session-tasks`
end

-- A task's own URL from the `path` the create call returns.
function lib.pathUrl(path: string, base: string?): string
	assert(
		string.match(
			path,
			"^universes/%d+/places/%d+/versions/%d+/luau%-execution%-sessions/[%w%-]+/tasks/[%w%-]+$"
		),
		`unexpected task path {path}`
	)
	return `{lib.base(base)}/cloud/v2/{path}`
end

export type Outcome = { done: boolean, ok: boolean, results: { any }?, error: string? }

-- Reads a task resource: still running, finished with results, or failed.
function lib.outcome(task: { [string]: any }): Outcome
	local state = task.state
	if state == "COMPLETE" then
		local output = task.output
		return { done = true, ok = true, results = if type(output) == "table" then output.results else nil }
	elseif state == "FAILED" or state == "CANCELLED" then
		local err = task.error
		local message = if type(err) == "table"
			then `{err.code or "ERROR"}: {err.message or ""}`
			else tostring(state)
		return { done = true, ok = false, error = message }
	end
	return { done = false, ok = false }
end

-- The probe script sent to Roblox: the shared World checks (run with
-- loadstring, so the module's types stay top-level), the HUD texts the
-- headless audit measured, then probe.luau.
function lib.script(
	worldSource: string,
	probeSource: string,
	texts: { any },
	encodeJson: (any) -> string
): string
	local function longString(s: string): string
		local eq = "="
		while string.find(s, "]" .. eq .. "]", 1, true) do
			eq ..= "="
		end
		return `[{eq}[{s}]{eq}]`
	end
	return table.concat({
		"-- Written by tools/cloud/run.luau. Runs once in a fresh Roblox server for this place version.",
		`local WORLD_SOURCE = {longString(worldSource)}`,
		`local TEXTS_JSON = {longString(encodeJson(texts))}`,
		probeSource,
	}, "\n")
end

-- The probe returns one JSON string; anything else is a harness error.
function lib.report(results: { any }?, decodeJson: (string) -> any): { [string]: any }
	assert(type(results) == "table" and type(results[1]) == "string", "the probe returned no JSON report")
	local report = decodeJson(results[1])
	assert(type(report) == "table" and type(report.findings) == "table", "the probe's report has no findings")
	return report
end

return lib
