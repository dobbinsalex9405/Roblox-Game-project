--!strict
local Monetization = require("@core/Monetization")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local config = {
	passes = { DoubleCoins = 0, AutoCollect = 0 },
	products = {
		CoinPack = { id = 0, coins = 5000 },
		Shield = { id = 0 },
	},
	environments = {
		staging = { passes = { DoubleCoins = 11 }, products = { CoinPack = 21, Shield = 22 } },
		production = { passes = { DoubleCoins = 31, AutoCollect = 32 }, products = { CoinPack = 41 } },
	},
}

describe("Monetization", function()
	it("uses the defaults in dev and each environment's own ids elsewhere", function()
		local dev = Monetization.resolve(config, "dev")
		expect(dev.passes).toEqual({ DoubleCoins = 0, AutoCollect = 0 })
		expect(dev.products).toEqual({ CoinPack = 0, Shield = 0 })
		local staging = Monetization.resolve(config, "staging")
		expect(staging.passes).toEqual({ DoubleCoins = 11, AutoCollect = 0 })
		expect(staging.products).toEqual({ CoinPack = 21, Shield = 22 })
		local production = Monetization.resolve(config, "production")
		expect(production.environment).toBe("production")
		expect(production.products).toEqual({ CoinPack = 41, Shield = 0 })
	end)

	it("works for configs without an environments table", function()
		local plain = Monetization.resolve({ passes = { A = 5 }, products = { B = { id = 6 } } }, "staging")
		expect(plain.passes).toEqual({ A = 5 })
		expect(plain.products).toEqual({ B = 6 })
	end)

	it("refuses unknown keys, bad ids, duplicates and unknown environments", function()
		expect(function()
			Monetization.resolve(config, "live")
		end).toThrow("unknown environment")
		expect(function()
			Monetization.resolve(
				{ passes = {}, products = {}, environments = { staging = { passes = { X = 1 } } } },
				"staging"
			)
		end).toThrow("is not a pass")
		expect(function()
			Monetization.resolve({ passes = {}, products = { P = { id = 1.5 } } }, "dev")
		end).toThrow("whole number")
		expect(function()
			Monetization.resolve({ passes = { A = 7, B = 7 }, products = {} }, "dev")
		end).toThrow("used by both")
	end)
end)
