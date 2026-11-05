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
		eggs = require("../config/eggs"),
		raids = require("../config/raids"),
		monetization = require("../config/monetization"),
		atmosphere = require("../config/atmosphere"),
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
				expect(total).toBe(10000)
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

	it("never sells raid immunity", function()
		for key in load().monetization.products do
			expect(string.find(string.lower(key), "immun", 1, true)).toBeNil()
		end
	end)
end)
