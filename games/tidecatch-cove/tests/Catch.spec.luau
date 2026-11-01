--!strict
local Catch = require("../src/shared/Catch")
local Odds = require("@core/Odds")
local fishing = require("../config/fishing")
local species = require("../config/species")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local function weightsByRarity(outcomes: { Catch.Outcome }): { [string]: number }
	local out = {}
	for _, o in outcomes do
		local rarity = species.species[o.id].rarity
		out[rarity] = (out[rarity] or 0) + o.weight
	end
	return out
end

describe("Catch", function()
	local tables = Catch.oddsTables(fishing, species.species, Odds.normalize, false)
	local byId: { [string]: Catch.OddsTable } = {}
	for _, def in tables do
		byId[def.id] = def
	end

	it("the no-bait table is the spot exactly as configured", function()
		local spot = Catch.spot(fishing, "Shallows")
		expect(byId.Shallows_None.outcomes).toEqual(spot.outcomes)
	end)

	it("bait shifts odds towards the rarities it names", function()
		local plain = weightsByRarity(byId.Shallows_None.outcomes)
		local lure = weightsByRarity(byId.Shallows_GoldenLure.outcomes)
		expect(lure.Legendary > plain.Legendary).toBe(true)
		expect(lure.Epic > plain.Epic).toBe(true)
		expect(lure.Common < plain.Common).toBe(true)
	end)

	it("every bait table keeps every species of its spot possible", function()
		for _, def in tables do
			for _, o in def.outcomes do
				expect(o.weight).toBeAtLeast(1)
			end
		end
	end)

	it("a cast is paid only with Robux bait, or when coins are sold", function()
		expect(Catch.isPaid(nil, true)).toBe(false) -- no bait: always free
		expect(Catch.isPaid({ robux = false }, false)).toBe(false)
		expect(Catch.isPaid({ robux = true }, false)).toBe(true)
		expect(Catch.isPaid({ robux = false }, true)).toBe(true)
		local paidTables = Catch.oddsTables(fishing, species.species, Odds.normalize, true)
		for _, def in paidTables do
			expect(def.paid).toBe(not string.match(def.id, "_None$"))
		end
	end)

	it("the starting rod changes nothing; better rods boost rare catches", function()
		local outcomes = byId.Reef_None.outcomes
		expect(Catch.rodBoost(fishing.rods[1], outcomes, species.species)).toBeNil()
		local boost = Catch.rodBoost(fishing.rods[3], outcomes, species.species)
		expect(boost and boost.id).toBe("StormRod")
		expect(boost and boost.multipliers.PearlWhale).toBe(fishing.rods[3].luck.Legendary)
		expect(boost and boost.multipliers.BubbleGoby).toBeNil() -- Common: unchanged
	end)

	it("rolls sizes inside the species' range", function()
		local whale = species.species.PearlWhale
		expect(Catch.rollKg(whale, 0)).toBe(whale.minKg)
		expect(Catch.rollKg(whale, 0.999999)).toBeAtMost(whale.maxKg)
		expect(Catch.rollKg(whale, 0.5)).toBe((whale.minKg + whale.maxKg) / 2)
	end)
end)
