--!strict
-- A species' meshes reach the client (ReplicatedStorage.CreatureMeshes) as
-- one Model per species. The client loads them, then redraws that species'
-- creatures from voxel boxes to meshes (client/CreatureView).
--
-- Studio gate, Nov 8: a Llama or Meerkat drawn before its meshes loaded
-- stayed boxes all session, while one drawn later meshed at once. The model
-- arrives (ChildAdded) before all of its MeshParts have replicated, so the
-- old order (load, then redraw at once) redrew while meshes were still
-- missing: the redraw drew boxes again, and nothing redrew once they came.
local MeshArrival = require("../src/shared/MeshArrival")
local atmosphere = require("../config/atmosphere")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

-- A species model on the client: `have` meshes now, `coming` replicate one
-- per settle(); the clock moves with every wait.
-- `preloads` gives each preload's result in turn: true, false (failed) or
-- "hang" (never resolved within its time limit); missing ones succeed.
local function fake(have: number, coming: number, preloads: { any }?)
	local state = {
		have = have,
		coming = coming,
		total = have + coming,
		clock = 0,
		preloads = 0,
		limits = {} :: { number },
		waited = {} :: { number },
		redraws = {} :: { boolean }, -- complete? at each redraw
		alive = true,
	}
	local hooks: MeshArrival.Hooks = {
		complete = function()
			return state.have >= state.total
		end,
		settle = function()
			state.clock += 0.25
			if state.coming > 0 then
				state.coming -= 1
				state.have += 1
			end
		end,
		preload = function(limit: number): boolean?
			state.preloads += 1
			table.insert(state.limits, limit)
			local results = preloads or {}
			local ok = results[state.preloads]
			if ok == "hang" then
				state.clock += limit
				return nil
			end
			return if ok == nil then true else ok
		end,
		wait = function(seconds: number)
			table.insert(state.waited, seconds)
			state.clock += seconds
		end,
		alive = function()
			return state.alive
		end,
		redraw = function()
			table.insert(state.redraws, state.have >= state.total)
		end,
		now = function()
			return state.clock
		end,
	}
	return state, hooks
end

local RETRY = { 5, 15, 45 }
local LIMIT = 20

describe("MeshArrival.run", function()
	it("redraws only once every mesh of the species has replicated", function()
		local state, hooks = fake(0, 9)
		expect(MeshArrival.run(hooks, 30, RETRY, LIMIT)).toBe(true)
		expect(#state.redraws).toBe(1)
		expect(state.redraws[1]).toBe(true)
	end)

	it("redraws at once when the model came whole", function()
		local state, hooks = fake(7, 0)
		expect(MeshArrival.run(hooks, 30, RETRY, LIMIT)).toBe(true)
		expect(state.redraws).toEqual({ true })
		expect(state.clock).toBe(0)
	end)

	it("stops waiting for meshes after arriveSeconds and draws what it has", function()
		-- Never completes: the creature's own check still draws boxes for a
		-- species missing a mesh, so a half model is never drawn.
		local state, hooks = fake(2, 1000)
		expect(MeshArrival.run(hooks, 30, RETRY, LIMIT)).toBe(true)
		expect(state.clock >= 30 and state.clock < 31).toBe(true)
		expect(#state.redraws).toBe(1)
	end)

	it("tries a failed load again after each wait until it succeeds", function()
		-- Studio gate (#137): right after an upload Squid's texture was still
		-- "being generated", the one preload failed, and Squid stayed voxel
		-- boxes until the client restarted.
		local state, hooks = fake(4, 0, { false, false, true })
		expect(MeshArrival.run(hooks, 30, RETRY, LIMIT)).toBe(true)
		expect(state.preloads).toBe(3)
		expect(state.waited).toEqual({ 5, 15 })
		expect(state.redraws).toEqual({ true })
	end)

	it("gives up after the last wait, and stops once the meshes are gone", function()
		local state, hooks = fake(4, 0, { false, false, false, false })
		expect(MeshArrival.run(hooks, 30, RETRY, LIMIT)).toBe(false)
		expect(state.preloads).toBe(4) -- once, then once after each wait
		expect(#state.redraws).toBe(0)

		local gone, goneHooks = fake(4, 0, { false, false })
		local preload = goneHooks.preload
		goneHooks.preload = function(limit: number): boolean?
			gone.alive = false
			return preload(limit)
		end
		expect(MeshArrival.run(goneHooks, 30, RETRY, LIMIT)).toBe(false)
		expect(gone.preloads).toBe(1)
	end)

	-- Issue #178 (verifier's Studio play-solo of #175): 13 to 20 minutes in,
	-- both placed Quails stayed voxel boxes with all 9 of their meshes
	-- present. A manual PreloadAsync of the Quail model succeeded and both
	-- swapped within a second: the client's own preload had neither
	-- succeeded nor failed, so nothing retried and nothing redrew.
	it("draws the meshes when a load hangs but every mesh is here", function()
		local state, hooks = fake(9, 0, { "hang" })
		expect(MeshArrival.run(hooks, 30, RETRY, LIMIT)).toBe(true)
		expect(state.limits).toEqual({ LIMIT }) -- the load was given a time limit
		expect(state.redraws).toEqual({ true })
	end)

	it("tries a hung load again while meshes are still missing", function()
		local state, hooks = fake(2, 1000, { "hang", true })
		expect(MeshArrival.run(hooks, 30, RETRY, LIMIT)).toBe(true)
		expect(state.preloads).toBe(2)
		expect(state.waited).toEqual({ 5 })
		expect(#state.redraws).toBe(1)
	end)

	it("gives every load a time limit in the client", function()
		local source = (require("@lune/fs") :: any).readFile(
			"games/hatchery-heist/src/client/CreatureView.luau"
		)
		expect(string.find(source, "meshTiming.preloadSeconds", 1, true) ~= nil).toBe(true)
		local m = atmosphere.creatureMeshes :: any
		expect(type(m.preloadSeconds)).toBe("number")
		expect(m.preloadSeconds >= 5 and m.preloadSeconds <= 60).toBe(true)
	end)

	it("the game's settings wait long enough", function()
		local m = atmosphere.creatureMeshes
		expect(m.arriveSeconds >= 10).toBe(true)
		local total = 0
		for _, s in m.retrySeconds do
			total += s
		end
		expect(#m.retrySeconds >= 3).toBe(true)
		expect(total >= 300).toBe(true)
	end)
end)
