--!strict
-- The first-minute guide, walked through a real session: each goal appears
-- in order and the guide ends once the first creature has grown.
local Catch = require("../src/shared/Catch")
local Guide = require("../src/shared/Guide")
local Reel = require("../src/shared/Reel")
local Fakes = require("../../../packages/core/tests/Fakes")
local Harness = require("./Harness")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local fishing = Harness.config.fishing

describe("Tidecatch Cove first-minute guide", function()
	it("leads a new player from cast to catch to pool to growth, then gets out of the way", function()
		local h = Harness.new()
		local player = Fakes.player(50)
		h.join(player)
		local d = h.get(player)
		local step = Guide.step(d) :: Guide.Step
		expect(step.id).toBe("Cast")
		expect(step.arrowToDock).toBe(true)
		expect(Guide.dockFor(d, fishing)).toBe("Shallows")
		-- A new player starts with their Worms picked.
		local bait = Guide.startingBait(d, fishing)
		expect(bait).toBe("Worm")

		local attempts = 0
		local landed = false
		while not landed do
			local bite = h.castAndWait(player, "Shallows", bait) :: any
			expect((Guide.step(h.get(player)) :: Guide.Step).id).toBe("Reel")
			h.wait(Reel.minSeconds(bite.rarity, fishing) + 0.5)
			landed = (h.actions:reel(player, bite.id, true))
			attempts += 1
			assert(attempts < 20, "never landed a fish")
			h.wait(fishing.castCooldownSeconds)
		end
		step = Guide.step(h.get(player)) :: Guide.Step
		expect(step.id).toBe("Place")
		expect(step.arrowToDock).toBe(false)

		local uid = h.get(player).bucket[1].uid
		h.actions:place(player, uid)
		step = Guide.step(h.get(player)) :: Guide.Step
		expect(step.id).toBe("Grow")
		h.wait(Harness.config.pools.stageSeconds.Legendary + Harness.TICK)
		expect(Guide.step(h.get(player))).toBeNil()
	end)

	it("after selling the first catch, asks for another to keep", function()
		local d = { firsts = { FirstCast = 1, FirstCatch = 2 }, bucket = {} }
		local step = Guide.step(d) :: Guide.Step
		expect(step.id).toBe("Place")
		expect(step.arrowToDock).toBe(true)
	end)

	it("retires for a player who keeps selling and never pools, and stays retired", function()
		local d = { firsts = { FirstCast = 1, FirstCatch = 2 }, bucket = {}, stats = { catches = 1 } }
		expect((Guide.step(d) :: Guide.Step).id).toBe("Place")
		d.stats.catches = Guide.RETIRE_AFTER_CATCHES - 1
		expect((Guide.step(d) :: Guide.Step).id).toBe("Place")
		d.stats.catches = Guide.RETIRE_AFTER_CATCHES
		expect(Guide.step(d)).toBeNil()
		-- A catch kept in the bucket later does not bring it back.
		d.bucket = { { uid = "c1" } }
		expect(Guide.step(d)).toBeNil()
	end)

	it("points at the best open dock the rod allows and never a low-tide one", function()
		local d = { rodTier = 1, bait = {} }
		expect(Guide.dockFor(d, fishing)).toBe("Shallows")
		expect(Guide.startingBait(d, fishing)).toBe(Catch.NO_BAIT)
		for _, spot in fishing.spots do
			if spot.lowTideOnly then
				expect(Guide.dockFor({ rodTier = 99, bait = {} }, fishing) ~= spot.id).toBe(true)
			end
		end
	end)
end)
