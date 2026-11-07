--!strict
-- Coin packs keep their value as income grows (Alex's plan, Nov 5): each
-- gives its fixed coins or minutes of the buyer's income, whichever is more.
local Products = require("../src/shared/Products")
local monetization = require("../config/monetization")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local products = monetization.products :: any
local listings = monetization.listings.products :: any

describe("Coin packs", function()
	it("are always worth at least 5 minutes of the buyer's income", function()
		for _, income in { 0, 1, 37, 950, 4875, 12000, 250000 } do
			for _, key in Products.COIN_PACKS do
				local coins = Products.packCoins(products[key], income)
				expect(coins >= products[key].coins).toBe(true)
				-- Rounding to three digits loses under 1%.
				expect(coins >= income * 60 * 5 * 0.99).toBe(true)
			end
		end
	end)

	it("give the fixed coins until income passes them, then scale", function()
		local big = products.CoinPackBig
		expect(Products.packCoins(big, 0)).toBe(big.coins)
		expect(Products.packCoins(big, 10)).toBe(big.coins)
		-- 4,875 coins a second (a Star 3 Moon Unicorn on floor 10) for 45 minutes.
		expect(Products.packCoins(big, 4875)).toBe(13100000)
	end)

	it("give more per Robux the bigger the pack, at any income", function()
		for _, income in { 0, 100, 4875 } do
			local last = 0
			for _, key in Products.COIN_PACKS do
				local perRobux = Products.packCoins(products[key], income) / listings[key].robux
				expect(perRobux >= last * 0.98).toBe(true)
				last = perRobux
			end
		end
	end)

	it("name amounts the short way", function()
		expect(Products.short(5000)).toBe("5K")
		expect(Products.short(13100000)).toBe("13.1M")
		expect(Products.short(2470000000)).toBe("2.47B")
		expect(Products.short(950)).toBe("950")
	end)
end)
