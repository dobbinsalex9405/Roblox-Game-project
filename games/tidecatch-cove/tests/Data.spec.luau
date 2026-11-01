--!strict
local DataService = require("@core/DataService")
local DataTemplate = require("../src/shared/DataTemplate")
local Fakes = require("../../../packages/core/tests/Fakes")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

describe("Tidecatch Cove save data", function()
	it("the template is accepted by DataService at the latest version", function()
		local service = DataService.new({
			store = Fakes.store(),
			template = DataTemplate.template,
			migrations = DataTemplate.migrations,
		})
		expect(service.version).toBe(DataTemplate.template.version)
		local p = Fakes.player(1)
		expect((service:load(p, 1))).toBe("loaded")
		expect((service:get(p) :: any).rodTier).toBe(1)
	end)

	it("has the fields the build plan lists for version 1", function()
		local d = DataTemplate.template :: any
		for _, field in { "coins", "rodTier", "bait", "bucket", "pools", "journal", "receipts", "stats" } do
			expect(d[field] ~= nil).toBe(true)
		end
		expect(type(d.meta)).toBe("table")
	end)

	it("a used-up bait stays used up after a reload", function()
		local store = Fakes.store()
		local service = DataService.new({
			store = store,
			template = DataTemplate.template,
			migrations = DataTemplate.migrations,
		})
		local p = Fakes.player(2)
		service:load(p, 2)
		service:update(p, function(d)
			d.bait.Worm = 0
		end)
		service:release(p)
		service:load(p, 2)
		expect((service:get(p) :: any).bait.Worm).toBe(0)
	end)
end)
