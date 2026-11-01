--!strict
-- A bad config fails CI, not the live game: these are the same checks the
-- server runs at start-up.
local Config = require("@core/Config")
local Schema = require("@core/Schema")
local DataTemplate = require("../src/shared/DataTemplate")
local Restaurant = require("../src/shared/Restaurant")
local Schemas = require("../src/shared/Schemas")(Schema)
local fs = require("@lune/fs")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local GAME = "games/street-food-empire"

local function load()
	return {
		economy = require("../config/economy"),
		districts = require("../config/districts"),
		stations = require("../config/stations"),
		cooks = require("../config/cooks"),
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

-- Every .luau file under a folder, as { path = source }.
local function sources(dir: string, out: { [string]: string })
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			sources(path, out)
		elseif string.match(name, "%.luau$") then
			out[path] = fs.readFile(path)
		end
	end
	return out
end

describe("Street Food Empire config", function()
	it("every file matches its schema", function()
		local problems = Config.validate(Schemas.sections(load()))
		expect(table.concat(problems, "\n")).toBe("")
	end)

	it("passes the cross-file checks", function()
		expect(table.concat(Schemas.crossCheck(load()), "\n")).toBe("")
	end)

	it("has the launch scope: 3 districts, about 12 stations with 3 levels, 3 cook tiers", function()
		local config = load()
		expect(#config.districts).toBe(3)
		expect(#config.stations).toBe(12)
		for _, station in config.stations do
			expect(#station.levels).toBe(3)
		end
		expect(#config.cooks.tiers).toBe(3)
		expect(config.economy.rebirth.maxRebirths).toBe(1)
	end)

	it("the save template starts with the starter station built on spot 1", function()
		local config = load()
		expect(DataTemplate.template.stations).toEqual(Restaurant.starterStations(config))
	end)

	it("catches broken configs", function()
		local bad = copy(load())
		bad.stations[2].district = 9
		bad.stations[3].id = bad.stations[4].id
		bad.economy.starterStation = "TacoTruck"
		bad.monetization.products.CashPackSmall.id = 77
		bad.monetization.products.CashPackLarge.id = 77
		bad.monetization.products.CashPackMedium.cash = nil
		local text = table.concat(Schemas.crossCheck(bad), "\n")
		expect(text).toContain("unknown district 9")
		expect(text).toContain("is listed twice")
		expect(text).toContain("first-district station")
		expect(text).toContain("product id 77")
		expect(text).toContain("cash packs need cash")

		local schemaBad = copy(load())
		schemaBad.districts[1].cost = 5
		schemaBad.stations[1].levels[2].price = 1
		schemaBad.cooks.tiers[2].servesPerMinute = 1
		local schemaProblems = table.concat(Config.validate(Schemas.sections(schemaBad)), "\n")
		expect(schemaProblems).toContain("its cost must be 0")
		expect(schemaProblems).toContain("price must be higher")
		expect(schemaProblems).toContain("serve more customers")
	end)

	it("every station fits on a spot", function()
		local bad = copy(load())
		bad.districts[1].spots = 2
		expect(table.concat(Schemas.crossCheck(bad), "\n")).toContain("need a spot")
	end)

	-- The brief requires exact odds on any paid random item. This game sells
	-- none and rolls no dice at all; if that changes, it needs an odds screen
	-- and a PolicyService check first (see Hatchery Heist).
	it("has no randomness anywhere in game code, so no odds screen is needed", function()
		local files = sources(`{GAME}/src`, {})
		sources(`{GAME}/config`, files)
		local checked = 0
		for path, source in files do
			checked += 1
			for _, word in { "math.random", "Random.new", "NextInteger", "NextNumber", "rollPaid", ":roll(" } do
				if string.find(source, word, 1, true) then
					error(`{path} uses {word}: paid randomness needs an odds screen`)
				end
			end
		end
		expect(checked > 10).toBe(true)
	end)
end)
