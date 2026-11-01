--!strict
local DataService = require("@core/DataService")
local DataTemplate = require("../src/shared/DataTemplate")
local Fakes = require("../../../packages/core/tests/Fakes")
local economy = require("../config/economy")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

describe("Depthbound save data", function()
	it("the template is accepted by DataService at the latest version", function()
		local service = DataService.new({
			store = Fakes.store(),
			template = DataTemplate.template,
			migrations = DataTemplate.migrations,
		})
		expect(service.version).toBe(DataTemplate.template.version)
		local p = Fakes.player(1)
		expect((service:load(p, 1))).toBe("loaded")
		expect((service:get(p) :: any).coins).toBe(economy.startingCoins)
	end)

	it("starting values match config", function()
		expect(DataTemplate.template.coins).toBe(economy.startingCoins)
		expect(DataTemplate.template.gear.pick).toBe(1)
		expect(DataTemplate.template.gear.pack).toBe(1)
		expect(DataTemplate.template.gear.lamp).toBe(1)
	end)

	it("has every field the plan lists for version 1", function()
		for _, field in
			{ "coins", "gear", "deepestRow", "layersReached", "geodes", "receipts", "stats", "meta" }
		do
			expect(DataTemplate.template[field] ~= nil).toBe(true)
		end
	end)

	it("never saves the mine", function()
		for key in DataTemplate.template do
			expect(string.find(string.lower(key), "mine", 1, true)).toBeNil()
		end
	end)
end)
