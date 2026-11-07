--!strict
-- A bad config fails CI, not the live game: these are the same checks the
-- server runs at start-up.
local Config = require("@core/Config")
local Odds = require("@core/Odds")
local Schema = require("@core/Schema")
local Eggs = require("../src/shared/Eggs")
local Schemas = require("../src/shared/Schemas")(Schema, Odds)
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local function load()
	return {
		economy = require("../config/economy"),
		creatures = require("../config/creatures"),
		eggs = Eggs.expand(require("../config/eggs"), require("../config/creatures").species),
		raids = require("../config/raids"),
		monetization = require("../config/monetization"),
		atmosphere = require("../config/atmosphere"),
		shophouse = require("../config/shophouse"),
		charms = require("../config/charms"),
	}
end

local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = copy(v)
	end
	return out
end

describe("Hatchery Heist config", function()
	it("every file matches its schema", function()
		local problems = Config.validate(Schemas.sections(load()))
		expect(table.concat(problems, "\n")).toBe("")
	end)

	it("passes the cross-file checks", function()
		expect(table.concat(Schemas.crossCheck(load()), "\n")).toBe("")
	end)

	it("every egg is a valid odds table, marked paid because coins are sold for Robux", function()
		local odds = Odds.new()
		for _, def in Eggs.oddsTables(load().eggs, true) do
			odds:define(def)
			expect(def.paid).toBe(true)
		end
	end)

	it("the luck boost keeps every boosted egg at exactly 100%", function()
		local config = load()
		local odds = Odds.new()
		for _, def in Eggs.oddsTables(config.eggs, true) do
			odds:define(def)
		end
		local boost = config.monetization.boosts.LuckBoost
		local player = {}
		for _, egg in config.eggs do
			if table.find(boost.eggs, egg.id) then
				local multipliers = Eggs.boostMultipliers(egg, boost, config.creatures.species)
				odds:setBoosts(player, egg.id, { { id = "LuckBoost", multipliers = multipliers } })
				local total = 0
				for _, row in odds:display(egg.id, player).rows do
					total += row.weight
				end
				expect(total).toBe(egg.total or 10000)
			end
		end
	end)

	it("catches broken configs", function()
		local bad = load()
		bad = copy(bad)
		bad.eggs[1].outcomes[1].weight += 1
		bad.eggs[2].outcomes[1].id = "Unicorn"
		bad.economy.incubators.slotCosts[3] = 1
		bad.monetization.products.CoinPackSmall.id = 77
		bad.monetization.products.CoinPackLarge.id = 77
		local problems = Schemas.crossCheck(bad)
		local text = table.concat(problems, "\n")
		expect(text).toContain("must total exactly 10000")
		expect(text).toContain("unknown species Unicorn")
		expect(text).toContain("product id 77")
		local schemaProblems = table.concat(Config.validate(Schemas.sections(bad)), "\n")
		expect(schemaProblems).toContain("slotCosts must not decrease")
	end)

	it("keeps coin packs worth buying across the whole roster", function()
		-- Income may grow with rarity but not run away from what coins buy:
		-- the best creature earns at most 1,000 times the worst, each tier
		-- earns more than the one below, and the 80K pack is at least five
		-- minutes of any Epic's income (Nov 5 balance review).
		local config = load()
		local tiers = { "Common", "Uncommon", "Rare", "Ultra Rare", "Epic", "Legendary", "Godly" }
		local low, high = {}, {}
		local worst, best = math.huge, 0
		for _, s in config.creatures.species do
			local r = table.find(tiers, s.rarity) :: number
			low[r] = math.min(low[r] or math.huge, s.coinsPerSecond)
			high[r] = math.max(high[r] or 0, s.coinsPerSecond)
			worst = math.min(worst, s.coinsPerSecond)
			best = math.max(best, s.coinsPerSecond)
		end
		expect(best / worst).toBeAtMost(1000)
		for r = 2, #tiers do
			expect(low[r]).toBeAtLeast(high[r - 1] + 1)
		end
		expect(config.monetization.products.CoinPackBig.coins / high[5]).toBeAtLeast(5 * 60)
	end)

	it("keeps every daily reward at most a quarter of the 80K Coins pack", function()
		local config = load()
		local pack = config.monetization.products.CoinPackBig.coins
		for day, reward in config.economy.daily.rewards do
			expect(reward.maxCoins).toBeAtMost(pack * 0.25)
			-- The floor sits below the cap, so income still counts in between.
			expect(reward.minCoins).toBeAtMost(reward.maxCoins - 1)
			if day > 1 then
				expect(reward.maxCoins).toBeAtLeast(config.economy.daily.rewards[day - 1].maxCoins)
			end
		end
	end)

	-- A per-species book bonus grew with the roster (+1% each would be +150%
	-- at 150 Commons); the capped bonus splits a fixed total between tiers.
	it("caps the Hatchery Book bonus with a share for every tier that has creatures", function()
		local config = load()
		local book = config.economy.book
		expect(book.maxBonus).toBeAtMost(0.25)
		local sum = 0
		for rarity, share in book.tierShare do
			sum += share
			local members = 0
			for _, s in config.creatures.species do
				if s.rarity == rarity then
					members += 1
				end
			end
			expect(members > 0 and rarity or `no {rarity} creatures for its book share`).toBe(rarity)
		end
		expect(sum).toBeCloseTo(1, 1e-9)
		for id, s in config.creatures.species do
			expect(book.tierShare[s.rarity] ~= nil and id or `{id}: no book share for {s.rarity}`).toBe(id)
		end
	end)

	it("never sells raid immunity", function()
		for key in load().monetization.products do
			expect(string.find(string.lower(key), "immun", 1, true)).toBeNil()
		end
	end)
end)
