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
-- 2. Load the meshes and texture (PreloadAsync). A failed load is tried
--    again after each of `retrySeconds`: a fresh upload can fail for a few
--    minutes while Roblox still generates its texture (Studio gate, #137:
--    Squid stayed boxes until the client restarted). It stops if the
--    meshes are taken away meanwhile.
-- 3. Redraw the species' creatures that are still boxes.
--
-- Returns whether the meshes loaded.

local MeshArrival = {}

export type Hooks = {
	complete: () -> boolean, -- every mesh the server sent is here
	settle: () -> (), -- yields a moment (or until a mesh arrives)
	preload: () -> boolean, -- loads the meshes and texture; false if any failed
	wait: (number) -> (), -- yields that many seconds
	alive: () -> boolean, -- the meshes are still in ReplicatedStorage
	redraw: () -> (),
	now: () -> number, -- seconds
}

function MeshArrival.run(hooks: Hooks, arriveSeconds: number, retrySeconds: { number }): boolean
	local start = hooks.now()
	while not hooks.complete() and hooks.alive() and hooks.now() - start < arriveSeconds do
		hooks.settle()
	end
	local ok = hooks.alive() and hooks.preload()
	for _, seconds in retrySeconds do
		if ok or not hooks.alive() then
			break
		end
		hooks.wait(seconds)
		ok = hooks.alive() and hooks.preload()
	end
	if ok then
		hooks.redraw()
	end
	return ok
end

return MeshArrival
