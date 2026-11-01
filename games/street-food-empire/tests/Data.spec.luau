--!strict
local DataService = require("@core/DataService")
local DataTemplate = require("../src/shared/DataTemplate")
local Fakes = require("../../../packages/core/tests/Fakes")
local economy = require("../config/economy")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

describe("Street Food Empire save data", function()
	it("the template is accepted by DataService at the latest version", function()
		local service = DataService.new({
			store = Fakes.store(),
			template = DataTemplate.template,
			migrations = DataTemplate.migrations,
		})
		expect(service.version).toBe(DataTemplate.template.version)
		local p = Fakes.player(1)
		expect((service:load(p, 1))).toBe("loaded")
		expect((service:get(p) :: any).cash).toBe(economy.startingCash)
	end)

	it("starting values match config", function()
		expect(DataTemplate.template.cash).toBe(economy.startingCash)
		expect(DataTemplate.template.stations[1].stationId).toBe(economy.starterStation)
		expect(DataTemplate.template.districts).toBe(1)
	end)

	it("has the fields the core relies on", function()
		expect(type(DataTemplate.template.receipts)).toBe("table")
		expect(type(DataTemplate.template.meta)).toBe("table")
	end)

	it("has every field the Wave 1 plan lists for save data v1", function()
		for _, field in
			{
				"cash",
				"rebirths",
				"districts",
				"stations",
				"cooks",
				"orderBoard",
				"festival",
				"receipts",
				"stats",
			}
		do
			expect(DataTemplate.template[field] ~= nil).toBe(true)
		end
	end)
end)
