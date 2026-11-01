--!strict
local DataService = require("@core/DataService")
local DataTemplate = require("../src/shared/DataTemplate")
local Fakes = require("../../../packages/core/tests/Fakes")
local economy = require("../config/economy")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

describe("Hatchery Heist save data", function()
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
		expect(DataTemplate.template.slots).toBe(economy.incubators.startingSlots)
	end)

	it("has the fields the core relies on", function()
		expect(type(DataTemplate.template.receipts)).toBe("table")
		expect(type(DataTemplate.template.meta)).toBe("table")
	end)
end)
