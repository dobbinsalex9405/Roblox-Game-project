--!strict
-- The Robux shop: what is listed, the per-experience ids, and every grant run
-- through the core's real receipt path (exactly once per purchase id), as
-- the Studio test panel's Buy and Replay buttons do.
local Config = require("@core/Config")
local Fakes = require("../../../packages/core/tests/Fakes")
local Harness = require("./Harness")
local Lamp = require("../src/shared/Lamp")
local Monetization = require("@core/Monetization")
local Odds = require("@core/Odds")
local Pack = require("../src/shared/Pack")
local Products = require("../src/shared/Products")
local Receipts = require("@core/Receipts")
local Schema = require("@core/Schema")
local Schemas = require("../src/shared/Schemas")(Schema, Odds)
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local config = Harness.config
local gear, monetization = config.gear, config.monetization
local oreBoost = monetization.boosts.OreBoost

local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = copy(v)
	end
	return out
end

local function rawConfig(): { [string]: any }
	return {
		economy = require("../config/economy"),
		blocks = require("../config/blocks"),
		mine = require("../config/mine"),
		gear = require("../config/gear"),
		dive = require("../config/dive"),
		monetization = require("../config/monetization"),
	}
end

-- A harness with the shop's grants registered on a real Receipts, saving
-- always succeeding. `after` work runs when `flush` is called, as task.defer
-- would run it right after the purchase.
local function shop()
	local h = Harness.new()
	local queued: { () -> () } = {}
	local receipts = Receipts.new({
		data = h.data,
		economy = h.economy,
		findPlayer = function()
			return nil
		end,
		persist = function()
			return true
		end,
	})
	local grants = Products.grants({
		monetization = monetization,
		actions = h.actions,
		now = h.clock.now,
		after = function(fn: () -> ())
			table.insert(queued, fn)
		end,
	})
	local ids = Monetization.resolve(monetization, "dev")
	for _, key in Products.SOLD do
		receipts:register(key, ids.products[key], grants[key])
	end
	local s: any = { h = h, receipts = receipts }
	local purchases = 0
	-- The test panel's Buy: a new purchase id each time. Returns the id.
	function s.buy(p: any, key: string): string
		purchases += 1
		local id = `test-{purchases}`
		local decision, granted = receipts:grant(p, key, id, 0)
		assert(decision == "PurchaseGranted" and granted, `{key} was not granted`)
		s.flush()
		return id
	end
	function s.flush()
		local run = queued
		queued = {}
		for _, fn in run do
			fn()
		end
	end
	return s
end

-- Starts a dive on the top face and burns the lamp down to `fraction` full.
local function diveTo(h: any, p: any, fraction: number)
	h.standOn(p, 8, 8)
	h.wait(p, 0.2)
	local s = h.session(p)
	local burn = (h.oil(p) - s.capacity * fraction) / s.meter.rate
	h.wait(p, burn)
end

local function lastDive(h: any): any
	return h.dives[#h.dives]
end

describe("Depthbound shop", function()
	it("lists only what the game can deliver, and nothing random", function()
		local catalog = Products.catalog(monetization, gear)
		local seen: { [string]: boolean } = {}
		for _, item in catalog do
			expect(seen[item.key]).toBeNil()
			seen[item.key] = true
			expect(item.oddsTable).toBeNil()
			expect(item.paidRandom).toBeNil()
			expect(#item.name > 0 and #item.description > 0).toBe(true)
			if item.kind == "product" then
				expect(table.find(Products.SOLD, item.key) ~= nil).toBe(true)
			else
				expect(monetization.passes[item.key]).toBe(0)
			end
		end
		-- Every product sold is listed and configured; every pass is listed.
		for _, key in Products.SOLD do
			expect(seen[key]).toBe(true)
			expect(monetization.products[key] ~= nil).toBe(true)
		end
		for key in monetization.passes do
			expect(seen[key]).toBe(true)
		end
		-- The Geode Crate is a paid random item: it waits for M5 and its odds screen.
		expect(seen.GeodeCrate).toBeNil()
		-- Every grant the shop registers exists.
		local grants = Products.grants({
			monetization = monetization,
			actions = {},
			now = os.clock,
			after = function() end,
		})
		for _, key in Products.SOLD do
			expect(type(grants[key])).toBe("function")
		end
	end)

	it("picks each experience's ids, and the config checks catch slips", function()
		local raw = copy(rawConfig())
		raw.monetization.environments.staging = {
			passes = { BiggerPack = 101 },
			products = { OilRefill = 201, OreBoost = 202 },
		}
		raw.monetization.environments.production = { products = { OilRefill = 301 } }
		expect(table.concat(Config.validate(Schemas.sections(raw)), "\n")).toBe("")
		expect(table.concat(Schemas.crossCheck(raw), "\n")).toBe("")
		local staging = Monetization.resolve(raw.monetization, "staging")
		expect(staging.passes.BiggerPack).toBe(101)
		expect(staging.passes.BetterLamp).toBe(0)
		expect(staging.products.OreBoost).toBe(202)
		local production = Monetization.resolve(raw.monetization, "production")
		expect(production.products.OilRefill).toBe(301)
		expect(production.products.OreBoost).toBe(0)
		expect(Monetization.resolve(raw.monetization, "dev").products.OilRefill).toBe(0)

		local bad = copy(rawConfig())
		bad.monetization.environments.staging = {
			passes = { HugePack = 5 },
			products = { OilRefill = 9, OreBoost = 9 },
		}
		bad.monetization.environments.production.products = { OilRefill = 9 } -- fine on its own
		bad.monetization.boosts.LuckBoost = { durationSeconds = 60, sellMultiplier = 2 }
		local text = table.concat(Schemas.crossCheck(bad), "\n")
		expect(text).toContain("environments.staging.passes.HugePack is not a pass")
		expect(text).toContain("monetization (staging): id 9 used by")
		expect(string.find(text, "(production)", 1, true)).toBeNil()
		expect(text).toContain("monetization.boosts.LuckBoost has no matching product")
		local schemaText = table.concat(Config.validate(Schemas.sections(bad)), "\n")
		expect(schemaText).toContain("LuckBoost")
	end)

	it("an oil refill bought mid-dive pours right away, and only once per purchase", function()
		local s = shop()
		local h = s.h
		local p = Fakes.player(1)
		h.join(p)
		diveTo(h, p, 0.3)
		local id = s.buy(p, "OilRefill")
		expect(h.oil(p)).toBeCloseTo(h.session(p).capacity, 1e-6)
		expect(h.get(p).oilRefills).toBe(0)
		expect(lastDive(h).refilled).toBe(true)
		expect(h.notices[#h.notices]).toContain("Lamp refilled")
		-- Roblox retrying the same receipt (the test panel's Replay) gives nothing.
		local decision, granted = s.receipts:grant(p, "OilRefill", id, 0)
		expect(decision).toBe("PurchaseGranted")
		expect(granted).toBe(false)
		s.flush()
		expect(h.get(p).oilRefills).toBe(0)
		local refills = 0
		for _, args in h.eventsOf("custom") do
			if args[1] == "Dive:Refill" then
				refills += 1
			end
		end
		expect(refills).toBe(1)
	end)

	it("one refill per dive: a second purchase is kept for the next dive", function()
		local s = shop()
		local h = s.h
		local p = Fakes.player(1)
		h.join(p)
		diveTo(h, p, 0.3)
		s.buy(p, "OilRefill")
		h.wait(p, (h.oil(p) - h.session(p).capacity * 0.3) / h.session(p).meter.rate)
		local before = h.oil(p)
		s.buy(p, "OilRefill")
		expect(h.oil(p)).toBeCloseTo(before, 1e-6)
		expect(h.get(p).oilRefills).toBe(1)
		expect(h.notices[#h.notices]).toContain("One refill per dive")
		-- Pouring by hand is refused too.
		expect(select(2, h.actions:refill(p))).toBe("one per dive")
		-- Next dive, it pours.
		h.toCamp(p)
		h.wait(p, 0.2)
		expect(h.session(p).phase).toBe("Camp")
		diveTo(h, p, 0.4)
		expect(lastDive(h).refilled).toBe(false)
		expect(h.actions:refill(p)).toBe(true)
		expect(h.oil(p)).toBeCloseTo(h.session(p).capacity, 1e-6)
		expect(h.get(p).oilRefills).toBe(0)
	end)

	it("a refill bought at camp or with a nearly full lamp waits, and survives a rejoin", function()
		local s = shop()
		local h = s.h
		local p = Fakes.player(1)
		h.join(p)
		s.buy(p, "OilRefill")
		expect(h.get(p).oilRefills).toBe(1)
		expect(h.notices[#h.notices]).toContain("saved for a later dive")
		-- Just onto the mine, the lamp is full: the purchase is not wasted.
		diveTo(h, p, 0.95)
		s.buy(p, "OilRefill")
		expect(h.get(p).oilRefills).toBe(2)
		expect(select(2, h.actions:refill(p))).toBe("lamp nearly full")
		expect(h.get(p).oilRefills).toBe(2)
		-- Saved data: the refills come back on the next server.
		h.toCamp(p)
		h.wait(p, 0.2)
		h.leave(p)
		local h2 = Harness.new({ store = h.store })
		h2.join(p)
		expect(h2.get(p).oilRefills).toBe(2)
		-- With none left, pouring is refused.
		h2.data:update(p, function(d)
			d.oilRefills = 0
		end)
		diveTo(h2, p, 0.3)
		expect(select(2, h2.actions:refill(p))).toBe("You have no oil refills.")
	end)

	it("a refill on the rope saves a climb that would have run dry", function()
		local s = shop()
		local h = s.h
		local p = Fakes.player(1)
		h.join(p)
		h.standOn(p, 2, 2)
		h.wait(p, 0.2)
		for y = 1, 10 do
			expect((h.mine(p, 2, y, 2))).toBe(true)
			h.stand(p, 2, y, 2)
		end
		h.data:update(p, function(d)
			d.pack.Coal = 4
		end)
		-- Too little oil to make it up: 3 seconds of climbing short.
		local need = Lamp.climbOil(config.dive, 10)
		h.clock.advance((h.oil(p) - need + 3) / config.mine.layers[1].oilPerSecond)
		expect(h.actions:climb(p)).toBe(true)
		h.wait(p, 1)
		s.buy(p, "OilRefill")
		h.wait(p, Lamp.climbSeconds(config.dive, 10))
		expect(#h.lampOuts).toBe(0)
		expect(h.session(p).phase).toBe("Camp")
		expect(Pack.count(h.get(p).pack)).toBe(4)
	end)

	it("too late is too late: a dry lamp is a lamp-out and the refill stays in stock", function()
		local s = shop()
		local h = s.h
		local p = Fakes.player(1)
		h.join(p)
		h.standOn(p, 8, 8)
		h.wait(p, 0.2)
		h.clock.advance(gear.lamp[1].oilSeconds + 1) -- dry before the next step
		s.buy(p, "OilRefill")
		h.wait(p, 0.2)
		expect(#h.lampOuts).toBe(1)
		expect(h.get(p).oilRefills).toBe(1)
	end)

	it("an Ore Boost multiplies sales until it runs out, and more adds time", function()
		local s = shop()
		local h = s.h
		local p = Fakes.player(1)
		h.join(p)
		local function sellNow(items: { [string]: number }): number
			h.data:update(p, function(d)
				for id, n in items do
					d.pack[id] = n
				end
			end)
			local coins = h.get(p).coins
			expect(h.actions:sell(p)).toBe(true)
			return h.get(p).coins - coins
		end
		local items = { Coal = 5, Copper = 2 }
		local base = Pack.value(items, config.blocks)
		local start = h.clock.now()
		s.buy(p, "OreBoost")
		expect(h.get(p).boosts.OreBoost).toBe(start + oreBoost.durationSeconds)
		expect(h.notices[#h.notices]).toContain("Ore Boost")
		expect(sellNow(items)).toBe(math.floor(base * oreBoost.sellMultiplier))
		-- A second boost stacks its time on what is left.
		h.clock.advance(100)
		s.buy(p, "OreBoost")
		expect(h.get(p).boosts.OreBoost).toBe(start + 2 * oreBoost.durationSeconds)
		-- It runs across a rejoin (saved as an end time).
		h.leave(p)
		local h2 = Harness.new({ store = h.store, start = h.clock.now() + 60 })
		h2.join(p)
		h = h2
		expect(sellNow(items)).toBe(math.floor(base * oreBoost.sellMultiplier))
		-- After it ends, prices are back to normal.
		h.clock.advance(2 * oreBoost.durationSeconds)
		expect(sellNow(items)).toBe(base)
	end)

	it("Auto-Sell on the way out gets the boosted price too", function()
		local s = shop()
		local h = s.h
		h.perks.autoSell = true
		local p = Fakes.player(1)
		h.join(p)
		s.buy(p, "OreBoost")
		h.standOn(p, 8, 8)
		h.wait(p, 0.2)
		h.data:update(p, function(d)
			d.pack.Coal = 3
		end)
		local base = Pack.value({ Coal = 3 }, config.blocks)
		h.toCamp(p)
		h.wait(p, 0.2)
		expect(h.get(p).coins).toBe(math.floor(base * oreBoost.sellMultiplier))
	end)
end)
