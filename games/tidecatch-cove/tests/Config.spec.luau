--!strict
-- A bad config fails CI, not the live game: these are the same checks the
-- server runs at start-up.
local Config = require("@core/Config")
local Odds = require("@core/Odds")
local Schema = require("@core/Schema")
local Util = require("@core/Util")
local Catch = require("../src/shared/Catch")
local Schemas = require("../src/shared/Schemas")(Schema, Odds)
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local function load()
	return {
		species = require("../config/species"),
		fishing = require("../config/fishing"),
		pools = require("../config/pools"),
		economy = require("../config/economy"),
		monetization = require("../config/monetization"),
	}
end

describe("Tidecatch Cove config", function()
	it("every file matches its schema", function()
		local problems = Config.validate(Schemas.sections(load()))
		expect(table.concat(problems, "\n")).toBe("")
	end)

	it("passes the cross-file checks", function()
		expect(table.concat(Schemas.crossCheck(load()), "\n")).toBe("")
	end)

	it("has about 25 species in 5 rarities, 3 rods, 4 coin baits and 4 spots (build plan)", function()
		local config = load()
		local count = 0
		local rarities: { [string]: boolean } = {}
		for _, def in config.species.species do
			count += 1
			rarities[def.rarity] = true
		end
		expect(count).toBe(25)
		expect(#Util.keys(rarities)).toBe(5)
		expect(#config.fishing.rods).toBe(3)
		local coinBait = 0
		for _, bait in config.fishing.bait do
			if not bait.robux then
				coinBait += 1
			end
		end
		expect(coinBait).toBe(4)
		expect(#config.fishing.spots).toBe(4)
		local lowTide = 0
		for _, spot in config.fishing.spots do
			if spot.lowTideOnly then
				lowTide += 1
			end
		end
		expect(lowTide).toBe(1)
	end)

	it("every spot and bait is a valid odds table totalling exactly 100%", function()
		local config = load()
		local odds = Odds.new()
		local tables = Catch.oddsTables(config.fishing, config.species.species, Odds.normalize, false)
		expect(#tables).toBe(#config.fishing.spots * (#config.fishing.bait + 1))
		local robux: { [string]: boolean } = {}
		for _, bait in config.fishing.bait do
			robux[bait.id] = bait.robux
		end
		for _, def in tables do
			odds:define(def)
			-- Paid exactly when the bait only comes from Robux (coins are never sold).
			local baitId = string.match(def.id, "_(%w+)$") :: string
			expect(def.paid).toBe(robux[baitId] == true)
			local total = 0
			for _, row in odds:display(def.id, {}).rows do
				total += row.weight
			end
			expect(total).toBe(10000)
		end
	end)

	it("bait always pays: it only shifts catches rarer, and pays back on its spot", function()
		local config = load()
		local species = config.species.species
		local tables = Catch.oddsTables(config.fishing, species, Odds.normalize, false)
		local byId = {}
		for _, def in tables do
			byId[def.id] = def
		end
		-- Average Tiny sale value of one cast.
		local function value(spotId: string, baitId: string): number
			local total, sum = 0, 0
			for _, o in byId[Catch.tableId(spotId, baitId)].outcomes do
				total += o.weight
				sum += o.weight * species[o.id].value
			end
			return sum / total
		end
		local order = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
		for _, bait in config.fishing.bait do
			local last = 1
			for _, rarity in order do
				local m = bait.rarityMultipliers[rarity] or 1
				expect(m >= last).toBe(true)
				last = m
			end
			for _, spot in config.fishing.spots do
				expect(value(spot.id, bait.id) > value(spot.id, Catch.NO_BAIT)).toBe(true)
			end
		end
		-- Payback at Tiny prices on the spot each bait suits.
		local function payback(spotId: string, baitId: string): number
			local bait = Catch.bait(config.fishing, baitId) :: any
			return (value(spotId, baitId) - value(spotId, Catch.NO_BAIT)) / bait.priceCoins
		end
		expect(payback("Shallows", "Worm")).toBeAtLeast(1.5)
		expect(payback("Reef", "Krill")).toBeAtLeast(1.5)
		expect(payback("KelpForest", "GlowBait")).toBeAtLeast(1.5)
		expect(payback("KelpForest", "GoldenLure")).toBeAtLeast(0.9)
	end)

	it("every rod keeps every table at exactly 100%", function()
		local config = load()
		local odds = Odds.new()
		local tables = Catch.oddsTables(config.fishing, config.species.species, Odds.normalize, false)
		for _, def in tables do
			odds:define(def)
		end
		for tier, rod in config.fishing.rods do
			local player = { tier = tier }
			for _, def in tables do
				local boost = Catch.rodBoost(rod, def.outcomes, config.species.species)
				odds:setBoosts(player, def.id, if boost then { boost } else {})
				local total = 0
				for _, row in odds:display(def.id, player).rows do
					total += row.weight
				end
				expect(total).toBe(10000)
			end
		end
	end)

	it("save data starts where config says", function()
		local DataTemplate = require("../src/shared/DataTemplate")
		local config = load()
		expect(DataTemplate.template.coins).toBe(config.economy.startingCoins)
		expect(DataTemplate.template.poolSlots).toBe(config.pools.startingSlots)
		expect(next(DataTemplate.template.bait)).toBeNil() -- see the note in DataTemplate
	end)

	it("sells nothing until the M5 shop exists and Alex approves prices", function()
		local monetization = load().monetization
		for key, product in monetization.products do
			expect(key .. "=" .. product.id).toBe(key .. "=0")
		end
		for key, id in monetization.passes do
			expect(key .. "=" .. id).toBe(key .. "=0")
		end
	end)

	it("Robux products give only Robux-only bait, and Mystery Bait is a valid paid table", function()
		local config = load()
		local mystery = Catch.mysteryTable(config.monetization)
		expect(mystery.paid).toBe(true)
		Odds.validate(mystery)
		local bad = Util.deepCopy(config)
		bad.monetization.products.BaitPack.bait = "Worm"
		bad.monetization.mysteryBait[1].bait = "Dynamite"
		bad.monetization.mysteryBait[2].weight += 1
		bad.fishing.bait[5].priceCoins = 50
		local text = table.concat(Schemas.crossCheck(bad), "\n")
		expect(text).toContain("BaitPack: Worm is coin bait")
		expect(text).toContain("unknown bait Dynamite")
		expect(text).toContain("monetization.mysteryBait")
		expect(text).toContain("Robux bait needs priceCoins 0")
	end)

	it("catches broken configs", function()
		local bad = Util.deepCopy(load())
		bad.fishing.spots[1].outcomes[1].weight += 1
		bad.fishing.spots[2].outcomes[1].id = "Kraken"
		bad.fishing.spots[3].minRod = 9
		bad.fishing.rods[1].priceCoins = 5
		bad.economy.startingBait = { Dynamite = 3 }
		bad.monetization.products.GrowthBoost.id = 77
		bad.monetization.products.BaitPack.id = 77
		local text = table.concat(Schemas.crossCheck(bad), "\n")
		expect(text).toContain("must total exactly 10000")
		expect(text).toContain("unknown species Kraken")
		expect(text).toContain("minRod 9 is not a rod tier")
		expect(text).toContain("must be free")
		expect(text).toContain("unknown bait Dynamite")
		expect(text).toContain("product id 77")

		bad.pools.slotCosts[2] = 1
		bad.species.species.SandShrimp.maxKg = 0.05
		local schemaProblems = table.concat(Config.validate(Schemas.sections(bad)), "\n")
		expect(schemaProblems).toContain("slotCosts must not decrease")
		expect(schemaProblems).toContain("maxKg is below minKg")
	end)

	it("flags a species no spot can catch", function()
		local bad = Util.deepCopy(load())
		bad.species.species.Unicornfish = { rarity = "Epic", value = 10, minKg = 1, maxKg = 2 }
		expect(table.concat(Schemas.crossCheck(bad), "\n")).toContain("Unicornfish cannot be caught")
	end)
end)
