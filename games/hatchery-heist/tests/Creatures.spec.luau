--!strict
local Creatures = require("../src/shared/Creatures")
local creatures = require("../config/creatures")
local economy = require("../config/economy")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

describe("Creatures", function()
	local placed = {
		{ uid = "a", speciesId = "Chick", mutation = "None", slot = 1 },
		{ uid = "b", speciesId = "Penguin", mutation = "Golden", slot = 2 },
		{ uid = "c", speciesId = "Phoenix", mutation = "None", slot = nil }, -- in storage: earns nothing
	}

	it("sums income from placed creatures with mutations", function()
		expect(Creatures.baseIncome(placed, creatures)).toBe(1 + 20 * 2)
	end)

	it("applies rebirth and Double Coins multipliers", function()
		expect(Creatures.multiplier(0, false, economy)).toBe(1)
		expect(Creatures.multiplier(2, false, economy)).toBe(1.5)
		expect(Creatures.multiplier(2, true, economy)).toBe(3)
	end)

	it("pays whole coins and caps offline earnings", function()
		expect(Creatures.earned(2.5, 3)).toBe(7)
		local perSecond = 10
		local capped = Creatures.offlineEarnings(perSecond, 10 * 24 * 3600, economy)
		expect(capped).toBe(math.floor(perSecond * economy.offline.maxSeconds * economy.offline.rate))
		expect(Creatures.offlineEarnings(perSecond, -50, economy)).toBe(0)
	end)

	it("rebirth cost grows each time", function()
		expect(Creatures.rebirthCost(0, economy)).toBe(economy.rebirth.baseCost)
		expect(Creatures.rebirthCost(1, economy) > Creatures.rebirthCost(0, economy)).toBe(true)
	end)
end)
