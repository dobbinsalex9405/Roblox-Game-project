--!strict
-- The Robux list's first part (approved by Alex, Nov 12): the VIP pass,
-- Instant Hatch, Double Offline Earnings and the Streak Saver. Each gives
-- exactly what its listing says, only when it applies, and never twice.
local Daily = require("../src/shared/Daily")
local Hatchery = require("../src/shared/Hatchery")
local Products = require("../src/shared/Products")
local ShopPlan = require("../src/shared/ShopPlan")
local Harness = require("./Harness")
local Fakes = require("../../../packages/core/tests/Fakes")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local economy = require("../config/economy")
local monetization = require("../config/monetization")
local raids = require("../config/raids")

local DAY = 86400
local DAYS = #economy.daily.rewards
local NO = { doubleCoins = false, extraIncubators = false }

local function ledger()
	local l = { coins = 0 }
	function l.add(self: any, _currency: string, amount: number, _reason: string): number
		self.coins += amount
		return amount
	end
	return l
end

describe("Streak Saver", function()
	-- Claimed Day 4 on day 100, so day 101 continues and day 102 has missed one.
	local function onDay4(): { [string]: any }
		return { daily = { lastDay = 100, streak = 4 }, streakSavers = 0 }
	end

	it("is offered only on the day a streak breaks by one missed day", function()
		local d = onDay4()
		expect(Daily.status(d, 101 * DAY, DAYS).broken).toBe(false)
		expect(Daily.saverRefusal(d, 101 * DAY, DAYS)).toBeTruthy()
		local missed = Daily.status(d, 102 * DAY, DAYS)
		expect(missed.broken).toBe(true)
		expect(missed.day).toBe(1)
		expect(missed.lost).toBe(4)
		expect(Daily.saverRefusal(d, 102 * DAY, DAYS)).toBeNil()
		-- Two days missed: too late to save.
		expect(Daily.status(d, 103 * DAY, DAYS).broken).toBe(false)
		expect(Daily.saverRefusal(d, 103 * DAY, DAYS)).toBeTruthy()
		-- A new player has no streak to save.
		local fresh = { daily = { lastDay = 0, streak = 0 }, streakSavers = 0 }
		expect(Daily.status(fresh, 102 * DAY, DAYS).broken).toBe(false)
	end)

	it("keeps the streak going when claimed, and is used up", function()
		local d = onDay4()
		Daily.addSaver(d)
		local status = Daily.status(d, 102 * DAY + 60, DAYS)
		expect(status.broken).toBe(false)
		expect(status.saving).toBe(true)
		expect(status.day).toBe(5)
		-- Only one held at a time.
		expect(Daily.saverRefusal(d, 102 * DAY + 60, DAYS)).toBeTruthy()
		local coins, day = Daily.claim(d, ledger(), 102 * DAY + 60, 0, economy.daily)
		expect(coins).toBe(economy.daily.rewards[5].minCoins)
		expect(day).toBe(5)
		expect(d.streakSavers).toBe(0)
		-- The next day carries on normally.
		local _, next = Daily.claim(d, ledger(), 103 * DAY, 0, economy.daily)
		expect(next).toBe(6)
	end)

	it("is kept, not lost, when the streak was not broken at claim time", function()
		local d = onDay4()
		Daily.addSaver(d)
		local _, day = Daily.claim(d, ledger(), 101 * DAY, 0, economy.daily)
		expect(day).toBe(5)
		expect(d.streakSavers).toBe(1)
		-- Saved for the next time exactly one day is missed.
		local _, later = Daily.claim(d, ledger(), 103 * DAY, 0, economy.daily)
		expect(later).toBe(6)
		expect(d.streakSavers).toBe(0)
	end)
end)

describe("Instant Hatch", function()
	local function incubators(): { [string]: any }
		return {
			incubators = {
				{ slot = 1, eggId = "BasicEgg", startedAt = 0, readyAt = 50, outcome = "Chick" },
				{ slot = 2, eggId = "MoonlitEgg", startedAt = 0, readyAt = 900, outcome = "Chick" },
				{ slot = 3, eggId = "MeadowEgg", startedAt = 0, readyAt = 300, outcome = "Chick" },
			},
		}
	end

	it("finishes the egg the player chose", function()
		local d = incubators()
		local done = Hatchery.finishEgg(d, 3, 100)
		expect(done and done.slot).toBe(3)
		expect(d.incubators[3].readyAt).toBe(100)
		expect(d.incubators[2].readyAt).toBe(900)
	end)

	it("finishes the longest wait when the chosen egg already hatched", function()
		local d = incubators()
		local done = Hatchery.finishEgg(d, 1, 100) -- slot 1 was ready at 50
		expect(done and done.slot).toBe(2)
		expect(d.incubators[2].readyAt).toBe(100)
		expect(d.incubators[1].readyAt).toBe(50)
	end)

	it("finishes nothing when no egg is hatching", function()
		local d = incubators()
		expect(Hatchery.finishEgg(d, nil, 1000)).toBeNil()
		for _, incubator in d.incubators do
			expect(incubator.readyAt <= 1000).toBe(true)
		end
	end)

	it("uses one paid for earlier on the next egg, once", function()
		local h = Harness.new()
		local player = Fakes.player(31)
		h.join(player)
		-- Nothing hatching yet: nothing is used.
		h.get(player).instantHatches = 1
		expect(h.actions:useInstantHatch(player, 1)).toBe(false)
		expect(h.get(player).instantHatches).toBe(1)
		expect(h.buy(player, "BasicEgg")).toBe(true)
		local slot = h.get(player).incubators[1].slot
		expect(h.actions:useInstantHatch(player, slot)).toBe(true)
		local d = h.get(player)
		expect(d.instantHatches).toBe(0)
		expect(d.incubators[1].readyAt <= h.clock.now()).toBe(true)
		-- None left: the server opens the purchase prompt instead.
		expect(h.buy(player, "BasicEgg")).toBe(true)
		expect(h.actions:useInstantHatch(player, slot)).toBe(false)
	end)
end)

describe("VIP", function()
	it("adds 10% to every creature's coins", function()
		local h = Harness.new()
		local player = Fakes.player(41)
		h.join(player)
		h.buy(player, "BasicEgg")
		h.wait(player, 400)
		h.actions:hatch(player, h.get(player).incubators[1].slot)
		local d = h.get(player)
		local plain = Hatchery.incomePerSecond(d, Harness.config, NO)
		local vip = Hatchery.incomePerSecond(
			d,
			Harness.config,
			{ doubleCoins = false, extraIncubators = false, vip = true }
		)
		expect(plain > 0).toBe(true)
		expect(vip).toBeCloseTo(plain * 1.1, 1e-9)
	end)

	it("gives one free Moonlit Egg each UTC day, into a free incubator", function()
		local h = Harness.new({
			perks = { doubleCoins = false, extraIncubators = false, autoCollect = false, vip = true },
		})
		local player = Fakes.player(42)
		h.join(player)
		h.wait(player, 10)
		local d = h.get(player)
		expect(#d.incubators).toBe(1)
		expect(d.incubators[1].eggId).toBe(monetization.perks.vip.dailyEgg)
		expect(d.coins).toBe(economy.startingCoins) -- free
		expect(d.eggsBought.MoonlitEgg).toBe(1) -- counts towards the fixed order
		expect(string.find(h.lastNotice(player) or "", "VIP gift", 1, true) ~= nil).toBe(true)
		-- Not again the same day, even once it hatches.
		h.wait(player, 600)
		local slot = d.incubators[1].slot
		h.wait(player, economy.offline.maxSeconds)
		h.actions:hatch(player, slot)
		local today = h.get(player).vipEggDay
		h.wait(player, 60)
		expect(#h.get(player).incubators).toBe(0)
		-- The next UTC day: another.
		local untilTomorrow = (today + 1) * DAY - h.clock.now()
		h.wait(player, untilTomorrow + 10)
		expect(#h.get(player).incubators).toBe(1)
		expect(h.get(player).vipEggDay).toBe(today + 1)
	end)

	it("waits for a free incubator", function()
		local h = Harness.new({
			perks = { doubleCoins = false, extraIncubators = false, autoCollect = false, vip = true },
		})
		local player = Fakes.player(43)
		h.join(player)
		local d = h.get(player)
		-- Every incubator busy before the first tick.
		for slot = 1, d.slots do
			table.insert(d.incubators, {
				slot = slot,
				eggId = "BasicEgg",
				startedAt = 0,
				readyAt = h.clock.now() + 5000,
				outcome = "Chick",
			})
		end
		h.wait(player, 30)
		expect(#h.get(player).incubators).toBe(d.slots)
		expect(h.get(player).vipEggDay).toBe(0)
		-- One frees up: the gift arrives on the next tick.
		table.remove(h.get(player).incubators, 1)
		h.wait(player, 10)
		expect(h.get(player).vipEggDay > 0).toBe(true)
	end)

	it("gives nothing without the pass", function()
		local h = Harness.new()
		local player = Fakes.player(44)
		h.join(player)
		h.wait(player, 60)
		expect(#h.get(player).incubators).toBe(0)
		expect(h.get(player).vipEggDay).toBe(0)
	end)

	it("restricted players get the egg's fixed order, never a roll", function()
		local perks = { doubleCoins = false, extraIncubators = false, autoCollect = false, vip = true }
		local h = Harness.new({ perks = perks, restricted = true })
		local player = Fakes.player(45)
		h.join(player)
		h.wait(player, 10)
		local d = h.get(player)
		local egg = Hatchery.eggById(Harness.config.eggs, monetization.perks.vip.dailyEgg)
		expect(d.incubators[1].outcome).toBe(Hatchery.fixedOrderOutcome(egg, 0))
	end)

	it("is sold as a paid random item, with the free egg's odds shown first", function()
		local catalog = Products.catalog(monetization, raids)
		local vip: any = nil
		for _, item in catalog do
			if item.key == "VIP" then
				vip = item
			end
		end
		expect(vip).toBeTruthy()
		expect(vip.kind).toBe("pass")
		expect(vip.paidRandom).toBe(true)
		expect(vip.oddsTable).toBe(monetization.perks.vip.dailyEgg)
	end)
end)

describe("Double Offline Earnings", function()
	it("offers exactly the coins the welcome back added, for a while", function()
		local h = Harness.new()
		local player = Fakes.player(51)
		h.join(player)
		h.buy(player, "BasicEgg")
		h.wait(player, 400)
		h.actions:hatch(player, h.get(player).incubators[1].slot)
		h.wait(player, 30)
		h.leave(player)

		local h2 = Harness.new({ store = h.store, start = h.clock.now() + 3600 })
		h2.join(player)
		local d = h2.get(player)
		expect(h2.welcomes[1].coins > 0).toBe(true)
		expect(d.offlineBonus.coins).toBe(h2.welcomes[1].coins)
		expect(d.offlineBonus.untilAt).toBe(h2.clock.now() + monetization.perks.doubleOfflineSeconds)
	end)
end)

describe("Items sold from their own buttons", function()
	it("stay out of the Shop window and off the shop's displays", function()
		local catalog = Products.catalog(monetization, raids)
		local hidden: { [string]: boolean } = {}
		for _, item in catalog do
			if item.hidden then
				hidden[item.key] = true
			end
		end
		expect(hidden.InstantHatch).toBe(true)
		expect(hidden.DoubleOffline).toBe(true)
		expect(hidden.StreakSaver).toBe(true)
		local _, problems = ShopPlan.displays({}, catalog :: any)
		for _, problem in problems do
			expect(string.find(problem, "Instant Hatch", 1, true)).toBeNil()
			expect(string.find(problem, "Streak Saver", 1, true)).toBeNil()
			expect(string.find(problem, "Double Offline", 1, true)).toBeNil()
		end
	end)

	it("are listed on Roblox at the approved prices", function()
		local products = monetization.listings.products
		expect(products.InstantHatch.robux).toBe(25)
		expect(products.DoubleOffline.robux).toBe(25)
		expect(products.StreakSaver.robux).toBe(25)
		expect(products.ShieldRefill.robux).toBe(25)
		expect(monetization.listings.passes.VIP.robux).toBe(399)
	end)
end)
