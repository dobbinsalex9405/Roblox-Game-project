--!strict
local Config = require("@core/Config")
local Schema = require("@core/Schema")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

describe("Config", function()
	local schema = Schema.record({ startingCoins = Schema.integer({ min = 0 }) })

	it("loads valid sections and freezes them", function()
		Config.reset()
		Config.load({ economy = { schema = schema, value = { startingCoins = 50 } } })
		local economy = Config.get("economy")
		expect(economy.startingCoins).toBe(50)
		expect(function()
			economy.startingCoins = 1
		end).toThrow()
	end)

	it("fails with every problem listed", function()
		Config.reset()
		expect(function()
			Config.load({
				economy = { schema = schema, value = { startingCoins = -1 } },
				other = { schema = schema, value = { nope = true } },
			})
		end).toThrow("economy.startingCoins")
		local problems = Config.validate({
			economy = { schema = schema, value = { startingCoins = -1 } },
			other = { schema = schema, value = { nope = true } },
		})
		expect(#problems).toBe(2)
	end)

	it("throws on unknown section names", function()
		Config.reset()
		expect(function()
			Config.get("missing")
		end).toThrow("never loaded")
	end)
end)
