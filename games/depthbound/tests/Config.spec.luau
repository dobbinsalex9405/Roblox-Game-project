--!strict
-- A bad config fails CI, not the live game: these are the same checks the
-- server runs at start-up.
local Config = require("@core/Config")
local Odds = require("@core/Odds")
local Schema = require("@core/Schema")
local Schemas = require("../src/shared/Schemas")(Schema, Odds)
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local function load()
	return {
		economy = require("../config/economy"),
		blocks = require("../config/blocks"),
		mine = require("../config/mine"),
		gear = require("../config/gear"),
		dive = require("../config/dive"),
		monetization = require("../config/monetization"),
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

describe("Depthbound config", function()
	it("every file matches its schema", function()
		local problems = Config.validate(Schemas.sections(load()))
		expect(table.concat(problems, "\n")).toBe("")
	end)

	it("passes the cross-file checks", function()
		expect(table.concat(Schemas.crossCheck(load()), "\n")).toBe("")
	end)

	it("every layer is a valid, free odds table that totals exactly 100%", function()
		local odds = Odds.new()
		for _, def in Schemas.oddsTables(load().mine) do
			odds:define(def)
			expect(def.paid).toBe(false)
			local total = 0
			for _, row in odds:display(def.id, {}).rows do
				total += row.weight
			end
			expect(total).toBe(10000)
		end
	end)

	it("the plan's launch scope: one shaft with 3 layers, pick, pack and lamp tiers", function()
		local config = load()
		expect(#config.mine.layers).toBe(3)
		for _, kind in { "pick", "pack", "lamp" } do
			expect(#config.gear[kind] >= 2).toBe(true)
		end
	end)

	it("deeper is richer and burns more oil", function()
		local config = load()
		local best = 0
		for index, layer in config.mine.layers do
			local top = 0
			for _, entry in layer.blocks do
				top = math.max(top, config.blocks[entry.id].value)
			end
			expect(top > best).toBe(true)
			best = top
			if index > 1 then
				expect(layer.oilPerSecond > config.mine.layers[index - 1].oilPerSecond).toBe(true)
			end
		end
	end)

	it("sells no coin packs and no paid random items before M5", function()
		local config = load()
		for key, product in config.monetization.products do
			expect(string.match(key, "^CoinPack")).toBeNil()
			expect(product.id).toBe(0)
		end
	end)

	it("catches broken configs", function()
		local bad = copy(load())
		bad.mine.layers[1].blocks[1].weight += 1
		bad.mine.layers[2].blocks[2].id = "Mithril"
		bad.mine.layers[3].minPickTier = 9
		bad.gear.pick[3].cost = 1
		bad.gear.lamp[1].oilSeconds = 5
		bad.monetization.products.OreBoost.id = 77
		bad.monetization.products.GeodeCrate.id = 77
		local text = table.concat(Schemas.crossCheck(bad), "\n")
		expect(text).toContain("must total exactly 10000")
		expect(text).toContain("unknown block Mithril")
		expect(text).toContain("no pick tier reaches minPickTier 9")
		expect(text).toContain("cannot climb out from the bottom of layer 1")
		expect(text).toContain("id 77")
		local schemaProblems = table.concat(Config.validate(Schemas.sections(bad)), "\n")
		expect(schemaProblems).toContain("costs must not decrease")
	end)
end)
