--!strict
-- The first-session goal line walks a new player through dig, climb out and
-- sell, then the first upgrade, and then gets out of the way.
local DataTemplate = require("../src/shared/DataTemplate")
local Guide = require("../src/shared/Guide")
local Util = require("@core/Util")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local gear = require("../config/gear")

local function fresh(): { [string]: any }
	return Util.deepCopy(DataTemplate.template)
end

describe("Depthbound goal line", function()
	it("leads a new player through the loop, one step at a time", function()
		local d = fresh()
		expect(Guide.objective(d, gear, "Camp")).toContain("step onto the mine")
		expect(Guide.objective(d, gear, "Diving")).toContain("tap a block")
		d.firsts.FirstBlockMined = 1
		expect(Guide.objective(d, gear, "Diving")).toContain("climb out")
		expect(Guide.objective(d, gear, "Camp")).toContain("dive again")
		d.pack.Coal = 3
		expect(Guide.objective(d, gear, "Camp")).toContain("sell")
		d.pack = {}
		d.firsts.FirstSale = 2
		d.coins = 10
		local cheapest, kind = Guide.cheapestUpgrade(d, gear)
		expect(kind).toBe("Pack")
		expect(cheapest.name).toBe(gear.pack[2].name)
		expect(Guide.objective(d, gear, "Camp")).toContain(`10/{cheapest.cost} coins`)
		d.coins = cheapest.cost
		expect(Guide.objective(d, gear, "Camp")).toBe(
			`Goal: buy the {cheapest.name} at the Upgrade pack stand`
		)
		expect(Guide.objective(d, gear, "Diving")).toContain("climb out and buy")
		d.firsts.FirstUpgrade = 3
		expect(Guide.objective(d, gear, "Camp")).toBeNil()
	end)

	it("says nothing about upgrades once everything is maxed", function()
		local d = fresh()
		d.firsts.FirstBlockMined, d.firsts.FirstSale = 1, 2
		d.gear = { pick = #gear.pick, pack = #gear.pack, lamp = #gear.lamp }
		expect(Guide.cheapestUpgrade(d, gear)).toBeNil()
		expect(Guide.objective(d, gear, "Camp")).toBeNil()
	end)
end)
