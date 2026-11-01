--!strict
-- The pure rules: pack, gear, oil and the shaft's geometry.
local Economy = require("@core/Economy")
local DataService = require("@core/DataService")
local Gear = require("../src/shared/Gear")
local Lamp = require("../src/shared/Lamp")
local Layout = require("../src/shared/Layout")
local Pack = require("../src/shared/Pack")
local DataTemplate = require("../src/shared/DataTemplate")
local Fakes = require("../../../packages/core/tests/Fakes")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local mine = require("../config/mine")
local blocks = require("../config/blocks")
local gear = require("../config/gear")
local dive = require("../config/dive")

local NO_PERKS = { biggerPack = false, betterLamp = false, autoSell = false }

describe("Pack", function()
	it("counts, values and fills up", function()
		local pack = {}
		for _ = 1, 3 do
			expect(Pack.add(pack, "Copper", 4)).toBe(true)
		end
		expect(Pack.add(pack, "Quartz", 4)).toBe(true)
		expect(Pack.add(pack, "Coal", 4)).toBe(false)
		expect(Pack.count(pack)).toBe(4)
		expect(Pack.value(pack, blocks)).toBe(3 * blocks.Copper.value + blocks.Quartz.value)
	end)

	it("a lamp-out keeps exactly floor(total x keep), spread in proportion", function()
		local pack = { Coal = 8, Copper = 4, Quartz = 1 } -- 13 pieces
		local kept, dropped = Pack.split(pack, 0.25, blocks)
		expect(Pack.count(kept)).toBe(3)
		expect(Pack.count(kept) + Pack.count(dropped)).toBe(13)
		expect(kept.Coal).toBe(2)
		expect(kept.Copper).toBe(1)
		expect(kept.Quartz).toBeNil()
		expect(dropped.Quartz).toBe(1)
		-- The input is untouched.
		expect(pack.Coal).toBe(8)
	end)

	it("leftover keep goes to the largest remainder, ties to the more valuable ore", function()
		local kept = Pack.split({ Coal = 2, Quartz = 2 }, 0.25, blocks)
		expect(Pack.count(kept)).toBe(1)
		expect(kept.Quartz).toBe(1)
		local all = Pack.split({ Coal = 5, Iron = 2 }, 1, blocks)
		expect(all.Coal).toBe(5)
		expect(all.Iron).toBe(2)
		local none, lost = Pack.split({ Coal = 5 }, 0, blocks)
		expect(Pack.count(none)).toBe(0)
		expect(lost.Coal).toBe(5)
	end)
end)

describe("Gear", function()
	local function playerData()
		local service = DataService.new({
			store = Fakes.store(),
			template = DataTemplate.template,
			migrations = DataTemplate.migrations,
		})
		local p = Fakes.player(1)
		service:load(p, 1)
		local economy =
			Economy.new({ data = service, currencies = { coins = { field = "coins", max = 1e15 } } })
		return service, economy, p
	end

	it("upgrades cost the next tier's price and refuse when short", function()
		local service, economy, p = playerData()
		local refusal: string? = nil
		service:update(p, function(d)
			d.coins = gear.pick[2].cost + 5
			local ledger = economy:ledger(p, d)
			expect((Gear.upgrade(d, ledger, gear, "Pick"))).toBe(true)
			local ok, why = Gear.upgrade(d, ledger, gear, "Pick")
			expect(ok).toBe(false)
			refusal = why
		end)
		local d = service:get(p) :: any
		expect(d.gear.pick).toBe(2)
		expect(d.coins).toBe(5)
		expect(refusal).toContain(`{gear.pick[3].cost - 5} more coins`)
	end)

	it("refuses past the top tier", function()
		local service, economy, p = playerData()
		service:update(p, function(d)
			d.gear.lamp = #gear.lamp
			d.coins = 1e9
			local ok, why = Gear.upgrade(d, economy:ledger(p, d), gear, "Lamp")
			expect(ok).toBe(false)
			expect(why).toContain("best")
		end)
	end)

	it("passes add pack room and lamp oil", function()
		local d = { gear = { pick = 1, pack = 2, lamp = 3 } }
		expect(Gear.packCapacity(d, gear, NO_PERKS)).toBe(gear.pack[2].capacity)
		expect(Gear.packCapacity(d, gear, { biggerPack = true, betterLamp = false, autoSell = false })).toBe(
			gear.pack[2].capacity + gear.passes.biggerPackSlots
		)
		expect(Gear.oilCapacity(d, gear, { biggerPack = false, betterLamp = true, autoSell = false })).toBe(
			gear.lamp[3].oilSeconds * gear.passes.betterLampMultiplier
		)
	end)
end)

describe("Lamp", function()
	it("burns at the meter's rate and never below zero", function()
		local m = { oil = 60, rate = 1.5, at = 100 }
		expect(Lamp.oilAt(m, 110)).toBe(45)
		expect(Lamp.oilAt(m, 1000)).toBe(0)
		expect(Lamp.emptyAt(m)).toBe(140)
		local settled = Lamp.settle(m, 110, 2)
		expect(settled.oil).toBe(45)
		expect(Lamp.emptyAt(settled)).toBe(132.5)
	end)

	it("deeper layers burn faster; the top face burns like layer 1", function()
		expect(Lamp.rateAt(mine, 0)).toBe(mine.layers[1].oilPerSecond)
		expect(Lamp.rateAt(mine, Layout.layerTop(mine, 2))).toBe(mine.layers[2].oilPerSecond)
		expect(Lamp.rateAt(mine, Layout.totalRows(mine))).toBe(mine.layers[3].oilPerSecond)
	end)

	it("climbing out takes longer the deeper you are", function()
		expect(Lamp.climbSeconds(dive, 0)).toBe(dive.climb.baseSeconds)
		expect(Lamp.climbSeconds(dive, 20)).toBe(dive.climb.baseSeconds + 20 * dive.climb.secondsPerRow)
	end)
end)

describe("Shaft geometry", function()
	it("a root standing in cell (x, y, z) reads as row y", function()
		for _, y in { 1, 5, 12, 13, 36 } do
			local c = Layout.blockCenter(mine, 3, y, 3)
			expect(Layout.rowAt(mine, -y * mine.blockSize + 3)).toBe(y)
			expect(Layout.rowAt(mine, c.y)).toBe(y)
		end
		expect(Layout.rowAt(mine, 3)).toBe(0)
	end)

	it("the footprint covers exactly the grid", function()
		local corner = Layout.blockCenter(mine, 1, 1, 1)
		expect(Layout.inFootprint(mine, corner)).toBe(true)
		local spawn = Layout.campSpawn(mine)
		expect(Layout.inFootprint(mine, spawn)).toBe(false)
		for _, name in { "SellPad", "Pick", "Pack", "Lamp", "Guide" } do
			expect(Layout.inFootprint(mine, Layout.station(mine, name))).toBe(false)
		end
	end)

	it("layers stack in order", function()
		expect(Layout.layerOf(mine, 1)).toBe(1)
		expect(Layout.layerOf(mine, mine.layers[1].rows)).toBe(1)
		expect(Layout.layerOf(mine, mine.layers[1].rows + 1)).toBe(2)
		expect(Layout.layerTop(mine, 3)).toBe(mine.layers[1].rows + mine.layers[2].rows + 1)
	end)
end)
