--!strict
-- The Hatchery Heist progression simulator (tools/economy) runs on today's
-- config, gives the same answer for the same seed, and still describes a
-- game that starts gently and ends in a grind: these are the pacing
-- promises in ops/ECONOMY.md, checked on a short run so CI stays fast.
local Sim = require("../economy/sim")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local config = Sim.loadConfig()
local regular = Sim.PROFILES[2]

describe("Economy simulator", function()
	it("plays the same game for the same seed", function()
		local a = Sim.run(config, regular, 1, 42)
		local b = Sim.run(config, regular, 1, 42)
		expect(a.days[1].income).toBe(b.days[1].income)
		expect(a.days[1].floors).toBe(b.days[1].floors)
	end)

	it("keeps the first session gentle and the tower a long goal", function()
		local results = Sim.batch(config, regular, 2, 8)
		local firstRare, tenthFloor = {}, 0
		for _, r in results do
			local m = r.milestones["first Rare"]
			table.insert(firstRare, if m then m.minutes else math.huge)
			if r.milestones["floor 10"] then
				tenthFloor += 1
			end
		end
		-- A Rare inside the first session (40 minutes) for most players...
		expect(Sim.quantile(firstRare, 0.5)).toBeAtMost(40)
		-- ...and nobody owns the whole tower after two days.
		expect(tenthFloor).toBe(0)
	end)

	it("lets a patch change the config without touching the game's own tables", function()
		local patched = Sim.loadConfig(function(raw)
			raw.economy.startingCoins = 12345
		end)
		expect(patched.economy.startingCoins).toBe(12345)
		expect(Sim.loadConfig().economy.startingCoins).toBe(config.economy.startingCoins)
	end)
end)
