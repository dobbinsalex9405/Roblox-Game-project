--!strict
-- The shop's products, run through the core's real receipt path (the same
-- path the Studio test panel's Buy and Replay buttons use).
local Fakes = require("../../../packages/core/tests/Fakes")
local Harness = require("./Harness")
local Monetization = require("@core/Monetization")
local Products = require("../src/shared/Products")
local Receipts = require("@core/Receipts")
local Restaurant = require("../src/shared/Restaurant")
local Schemas = require("../src/shared/Schemas")(require("@core/Schema"))
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local function setup()
	local h = Harness.new()
	local player = Fakes.player(1)
	h.join(player)
	local receipts = Receipts.new({
		data = h.data,
		economy = h.economy,
		findPlayer = function()
			return player
		end,
		persist = function()
			return true
		end,
	})
	local monetization = h.config.monetization
	local ids = Monetization.resolve(monetization, "dev")
	local catalog = Products.register(receipts, ids.products, monetization, h.config.economy, h.actions)
	return h, player, receipts, catalog
end

describe("Street Food Empire products", function()
	it("lists every product it registers and every pass it honours, once", function()
		local _, _, receipts, catalog = setup()
		local listed: { [string]: boolean } = {}
		for _, item in catalog do
			local tag = `{item.kind}:{item.key}`
			expect(listed[tag]).toBe(nil)
			listed[tag] = true
			expect(#item.name > 0 and #item.description > 0).toBe(true)
		end
		for _, key in Products.SOLD do
			expect(listed[`product:{key}`]).toBe(true)
		end
		for _, key in Products.PASSES do
			expect(listed[`pass:{key}`]).toBe(true)
		end
		local keys = receipts:keys()
		table.sort(keys)
		local sold = table.clone(Products.SOLD)
		table.sort(sold)
		expect(keys).toEqual(sold)
	end)

	it("only sells products and passes that exist in config", function()
		local h = Harness.new()
		for _, key in Products.SOLD do
			expect(h.config.monetization.products[key] ~= nil).toBe(true)
		end
		for _, key in Products.PASSES do
			expect(h.config.monetization.passes[key] ~= nil).toBe(true)
		end
	end)

	it("cash packs add their cash exactly once, even when Roblox retries", function()
		local h, player, receipts = setup()
		for _, key in { "CashPackSmall", "CashPackMedium", "CashPackLarge" } do
			local before = h.get(player).cash
			local decision, granted = receipts:grant(player, key, `test-{key}`)
			expect(decision).toBe("PurchaseGranted")
			expect(granted).toBe(true)
			local cash = h.config.monetization.products[key].cash
			expect(h.get(player).cash).toBe(before + cash)
			-- Replay: the same purchase id again.
			decision, granted = receipts:grant(player, key, `test-{key}`)
			expect(decision).toBe("PurchaseGranted")
			expect(granted).toBe(false)
			expect(h.get(player).cash).toBe(before + cash)
		end
	end)

	it("a Speed Boost doubles customers from the moment it is bought, never before", function()
		local h, player, receipts = setup()
		local boost = h.config.monetization.boosts.SpeedBoost
		-- Customers pile up for a while at the normal rate, with no tick yet.
		h.clock.advance(8)
		local now = h.clock.now()
		local normal =
			Restaurant.rates(h.get(player), h.config, { doubleCash = false }, now).customersPerSecond
		local _, expected = Restaurant.preview(h.get(player), h.config, { doubleCash = false }, now)
		expect((receipts:grant(player, "SpeedBoost", "test-speed"))).toBe("PurchaseGranted")
		local d = h.get(player)
		expect(d.queue).toBe(expected)
		expect(d.boosts.SpeedBoost).toBe(now + boost.durationSeconds)
		local boosted = Restaurant.rates(d, h.config, { doubleCash = false }, now).customersPerSecond
		expect(boosted).toBe(normal * boost.customerMultiplier)
		-- A replay grants nothing; a second purchase extends it.
		expect(select(2, receipts:grant(player, "SpeedBoost", "test-speed"))).toBe(false)
		expect(h.get(player).boosts.SpeedBoost).toBe(now + boost.durationSeconds)
		expect((receipts:grant(player, "SpeedBoost", "test-speed-2"))).toBe("PurchaseGranted")
		expect(h.get(player).boosts.SpeedBoost).toBe(now + 2 * boost.durationSeconds)
	end)

	it("accepts per-experience ids and rejects unknown keys", function()
		local h = Harness.new()
		local monetization = table.clone(h.config.monetization)
		monetization.environments = {
			staging = { passes = { DoubleCash = 11 }, products = { CashPackSmall = 22 } },
		}
		local ok = Schemas.monetization(monetization, "monetization")
		expect(ok).toBe(true)
		local ids = Monetization.resolve(monetization, "staging")
		expect(ids.passes.DoubleCash).toBe(11)
		expect(ids.products.CashPackSmall).toBe(22)
		expect(Monetization.resolve(monetization, "production").products.CashPackSmall).toBe(0)
		monetization.environments = { staging = { gems = {} } }
		expect((Schemas.monetization(monetization, "monetization"))).toBe(false)
	end)
end)
