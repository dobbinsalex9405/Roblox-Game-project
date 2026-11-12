--!strict
-- What the client does when a species' meshes arrive in
-- ReplicatedStorage.CreatureMeshes, in order (client/CreatureView passes
-- the Roblox calls; pure, so the Lune tests drive it):
--
-- 1. Wait, up to `arriveSeconds`, until every mesh the server sent has
--    replicated. The model's ChildAdded fires before all its MeshParts are
--    here, and redrawing then drew boxes again with nothing to redraw once
--    they came (Studio gate, Nov 8: a Llama drawn early stayed boxes all
--    session; one drawn later meshed at once).
-- 2. Load the meshes and texture (PreloadAsync), each try given at most
--    `preloadSeconds`. A failed load is tried again after each of
--    `retrySeconds`: a fresh upload can fail for a few minutes while Roblox
--    still generates its texture (Studio gate, #137: Squid stayed boxes
--    until the client restarted). It stops if the meshes are taken away
--    meanwhile.
--    A load that neither succeeds nor fails in time (hung behind hundreds
--    of other species' loads) is not a failure: with every mesh here the
--    creatures are redrawn anyway and Roblox finishes loading as it draws
--    (#178: two Quails stayed boxes for 20 minutes with all their meshes
--    present). With meshes still missing it is tried again like a failure.
-- 3. Redraw the species' creatures that are still boxes.
--
-- Returns whether the meshes loaded.

local MeshArrival = {}

export type Hooks = {
	complete: () -> boolean, -- every mesh the server sent is here
	settle: () -> (), -- yields a moment (or until a mesh arrives)
	-- Loads the meshes and texture, waiting at most the given seconds: true
	-- if all loaded, false if any failed, nil if it had not finished in time.
	preload: (number) -> boolean?,
	wait: (number) -> (), -- yields that many seconds
	alive: () -> boolean, -- the meshes are still in ReplicatedStorage
	redraw: () -> (),
	now: () -> number, -- seconds
}

function MeshArrival.run(
	hooks: Hooks,
	arriveSeconds: number,
	retrySeconds: { number },
	preloadSeconds: number
): boolean
	local start = hooks.now()
	while not hooks.complete() and hooks.alive() and hooks.now() - start < arriveSeconds do
		hooks.settle()
	end
	-- Whether the meshes are ready to draw: loaded, or here but slow to load.
	local function attempt(): boolean
		if not hooks.alive() then
			return false
		end
		local loaded = hooks.preload(preloadSeconds)
		if loaded == nil then
			return hooks.complete()
		end
		return loaded
	end
	local ok = attempt()
	for _, seconds in retrySeconds do
		if ok or not hooks.alive() then
			break
		end
		hooks.wait(seconds)
		ok = attempt()
	end
	if ok then
		hooks.redraw()
	end
	return ok
end

return MeshArrival
