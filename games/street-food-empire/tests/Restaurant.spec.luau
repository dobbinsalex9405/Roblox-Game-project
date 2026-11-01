--!strict
local DataTemplate = require("../src/shared/DataTemplate")
local Restaurant = require("../src/shared/Restaurant")
local Util = require("@core/Util")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local config: Restaurant.Config = {
	economy = require("../config/economy"),
	districts = require("../config/districts"),
	stations = require("../config/stations"),
	cooks = require("../config/cooks"),
	monetization = require("../config/monetization"),
}
local economy = config.economy
local NO_PERKS = { doubleCash = false }
local T0 = 1_800_000_000

-- A minimal ledger over a data table, like Economy's.
local function ledger(d: { [string]: any })
	local l = {}
	function l.balance(_self: any, _currency: string): number
		return d.cash
	end
	function l.add(_self: any, _currency: string, amount: number, _reason: string): number
		assert(amount > 0 and amount // 1 == amount, "amounts are whole")
		d.cash += amount
		return amount
	end
	function l.spend(_self: any, _currency: string, amount: number, _reason: string): boolean
		if d.cash < amount then
			return false
		end
		d.cash -= amount
		return true
	end
	return l
end

local function fresh(): { [string]: any }
	local d = Util.deepCopy(DataTemplate.template)
	d.lastIncomeAt = T0
	return d
end

local function station(id: string): any
	return Restaurant.stationConfig(config, id)
end

local function price(id: string, level: number): number
	return station(id).levels[level].price
end

local function tier(id: string): any
	return Restaurant.tierConfig(config, id)
end

local TRAFFIC_1 = config.districts[1].customersPerMinute / 60

describe("Restaurant rates", function()
	it("a new restaurant has the starter's meal, district 1 traffic and no cooks", function()
		local d = fresh()
		local rates = Restaurant.rates(d, config, NO_PERKS, T0)
		expect(rates.meal).toBe(price(economy.starterStation, 1))
		expect(rates.customersPerSecond).toBeCloseTo(TRAFFIC_1, 1e-12)
		expect(rates.registerPerSecond).toBe(0)
		expect(rates.multiplier).toBe(1)
	end)

	it("an empty lot gets no customers", function()
		local d = fresh()
		d.stations = {}
		expect(Restaurant.rates(d, config, NO_PERKS, T0).customersPerSecond).toBe(0)
	end)

	it("the meal is every finished station's dish; a new station counts once it is built", function()
		local d = fresh()
		d.cash = 1000
		local built = Restaurant.build(d, ledger(d), config, "LemonadeStand", 2, T0)
		assert(built, "build refused")
		expect(Restaurant.workingLevel(built, T0)).toBe(0)
		expect(Restaurant.rates(d, config, NO_PERKS, T0).meal).toBe(price("HotDogCart", 1))
		local done = built.readyAt
		expect(Restaurant.rates(d, config, NO_PERKS, done).meal).toBe(
			price("HotDogCart", 1) + price("LemonadeStand", 1)
		)
	end)

	it("an upgrading station keeps selling at its old level", function()
		local d = fresh()
		d.cash = 1000
		local upgraded = Restaurant.upgrade(d, ledger(d), config, 1, T0)
		assert(upgraded, "upgrade refused")
		expect(upgraded.level).toBe(2)
		expect(Restaurant.rates(d, config, NO_PERKS, T0 + 1).meal).toBe(price("HotDogCart", 1))
		expect(Restaurant.rates(d, config, NO_PERKS, upgraded.readyAt).meal).toBe(price("HotDogCart", 2))
	end)

	it("a cook sells their own station's dish at their pace", function()
		local d = fresh()
		d.cooks = { { uid = "1", tier = "Trainee", stationId = "HotDogCart" } }
		local rates = Restaurant.rates(d, config, NO_PERKS, T0)
		local perSecond = tier("Trainee").servesPerMinute / 60
		expect(rates.cookSalesPerSecond).toBeCloseTo(perSecond, 1e-12)
		expect(rates.registerPerSecond).toBeCloseTo(perSecond * price("HotDogCart", 1), 1e-9)
	end)

	it("a cook at a station still being built waits", function()
		local d = fresh()
		d.cash = 1000
		assert(Restaurant.build(d, ledger(d), config, "PretzelOven", 2, T0))
		d.cooks = { { uid = "1", tier = "Chef", stationId = "PretzelOven" } }
		expect(Restaurant.rates(d, config, NO_PERKS, T0).registerPerSecond).toBe(0)
	end)

	it("rebirths and the 2x Cash pass multiply every sale", function()
		local d = fresh()
		d.rebirths = 1
		d.cooks = { { uid = "1", tier = "Trainee", stationId = "HotDogCart" } }
		local base = Restaurant.rates(fresh(), config, NO_PERKS, T0)
		local rates = Restaurant.rates(d, config, { doubleCash = true }, T0)
		local m = (1 + economy.rebirth.incomeBonusPerRebirth) * economy.doubleCashMultiplier
		expect(rates.multiplier).toBe(m)
		expect(Restaurant.handServeValue(d, config, { doubleCash = true }, T0)).toBe(
			math.floor(base.meal * (1 + economy.customers.handServeBonus) * m)
		)
	end)

	it("a Speed Boost brings customers faster to the counter and to the cooks", function()
		local d = fresh()
		d.cooks = { { uid = "1", tier = "Trainee", stationId = "HotDogCart" } }
		local before = Restaurant.rates(d, config, NO_PERKS, T0)
		local boost = config.monetization.boosts.SpeedBoost
		Restaurant.startBoost(d, "SpeedBoost", T0, boost.durationSeconds)
		local during = Restaurant.rates(d, config, NO_PERKS, T0)
		expect(during.customersPerSecond).toBeCloseTo(
			before.customersPerSecond * boost.customerMultiplier,
			1e-12
		)
		expect(during.registerPerSecond).toBeCloseTo(
			before.registerPerSecond * boost.customerMultiplier,
			1e-9
		)
		local after = Restaurant.rates(d, config, NO_PERKS, T0 + boost.durationSeconds)
		expect(after.customersPerSecond).toBeCloseTo(before.customersPerSecond, 1e-12)
	end)

	it("buying a boost again extends it", function()
		local d = fresh()
		Restaurant.startBoost(d, "SpeedBoost", T0, 100)
		Restaurant.startBoost(d, "SpeedBoost", T0 + 50, 100)
		expect(d.boosts.SpeedBoost).toBe(T0 + 200)
		Restaurant.startBoost(d, "SpeedBoost", T0 + 500, 100)
		expect(d.boosts.SpeedBoost).toBe(T0 + 600)
	end)
end)

describe("Restaurant over time", function()
	local function busy(): { [string]: any }
		local d = fresh()
		d.cash = 10_000
		local l = ledger(d)
		assert(Restaurant.build(d, l, config, "LemonadeStand", 2, T0))
		assert(Restaurant.build(d, l, config, "PretzelOven", 3, T0 + 3))
		assert(Restaurant.upgrade(d, l, config, 1, T0 + 1))
		assert(Restaurant.hireCook(d, l, config, "Trainee", 1))
		assert(Restaurant.hireCook(d, l, config, "LineCook", 3))
		Restaurant.startBoost(d, "SpeedBoost", T0, 25)
		return d
	end

	it("is exact: one long step earns what many small steps earn, across every change", function()
		local a, b = busy(), busy()
		Restaurant.advance(a, config, NO_PERKS, T0, T0 + 600, 1)
		local tSmall = T0
		while tSmall < T0 + 600 do
			Restaurant.advance(b, config, NO_PERKS, tSmall, tSmall + 7, 1)
			tSmall += 7
		end
		-- b overshoots to the next multiple of 7; bring a level.
		Restaurant.advance(a, config, NO_PERKS, T0 + 600, tSmall, 1)
		expect(a.pendingCash).toBeCloseTo(b.pendingCash, 1e-6)
		expect(a.queue).toBeCloseTo(b.queue, 1e-9)
	end)

	it("matches a hand count across a station finishing", function()
		local d = fresh()
		d.cash = 1000
		local built = Restaurant.build(d, ledger(d), config, "LemonadeStand", 2, T0) :: any
		d.cooks = { { uid = "1", tier = "Trainee", stationId = "LemonadeStand" } }
		local seconds = built.readyAt - T0 + 60
		local earned = Restaurant.advance(d, config, NO_PERKS, T0, T0 + seconds, 1)
		-- Only the 60 seconds after the build finished earn.
		expect(earned).toBeCloseTo(
			60 * tier("Trainee").servesPerMinute / 60 * price("LemonadeStand", 1),
			1e-9
		)
	end)

	it("the counter queue fills with foot traffic and stops at queueMax", function()
		local d = fresh()
		Restaurant.advance(d, config, NO_PERKS, T0, T0 + 10, 1)
		expect(d.queue).toBeCloseTo(10 * TRAFFIC_1, 1e-9)
		Restaurant.advance(d, config, NO_PERKS, T0 + 10, T0 + 100000, 1)
		expect(d.queue).toBe(economy.customers.queueMax)
	end)

	it("accrue brings the restaurant up to now and ignores a clock that went back", function()
		local d = fresh()
		d.cooks = { { uid = "1", tier = "Trainee", stationId = "HotDogCart" } }
		Restaurant.accrue(d, config, NO_PERKS, T0 + 60)
		expect(d.lastIncomeAt).toBe(T0 + 60)
		expect(d.pendingCash).toBeCloseTo(
			60 * tier("Trainee").servesPerMinute / 60 * price("HotDogCart", 1),
			1e-9
		)
		local pending = d.pendingCash
		Restaurant.accrue(d, config, NO_PERKS, T0)
		expect(d.pendingCash).toBe(pending)
		expect(d.lastIncomeAt).toBe(T0)
	end)

	it("preview shows the register and queue at any moment without changing data", function()
		local d = busy()
		local before = Util.deepCopy(d)
		local pending, queue = Restaurant.preview(d, config, NO_PERKS, T0 + 300)
		expect(d).toEqual(before)
		Restaurant.advance(d, config, NO_PERKS, T0, T0 + 300, 1)
		expect(pending).toBeCloseTo(d.pendingCash, 1e-9)
		expect(queue).toBeCloseTo(d.queue, 1e-9)
	end)

	it("welcome back pays cooks at the offline rate for at most maxSeconds; the queue fills", function()
		local d = fresh()
		d.cooks = { { uid = "1", tier = "Trainee", stationId = "HotDogCart" } }
		local away = economy.offline.maxSeconds * 3
		local earned = Restaurant.welcomeBack(d, config, NO_PERKS, T0 + away)
		local perSecond = tier("Trainee").servesPerMinute / 60 * price("HotDogCart", 1)
		expect(earned).toBeCloseTo(perSecond * economy.offline.maxSeconds * economy.offline.rate, 1e-6)
		expect(d.pendingCash).toBeCloseTo(earned, 1e-9)
		expect(d.queue).toBe(economy.customers.queueMax)
		expect(d.lastIncomeAt).toBe(T0 + away)
	end)

	it("a first join pays nothing", function()
		local d = Util.deepCopy(DataTemplate.template)
		expect(Restaurant.welcomeBack(d, config, NO_PERKS, T0)).toBe(0)
		expect(d.lastIncomeAt).toBe(T0)
		expect(d.queue).toBe(0)
	end)
end)

describe("Restaurant actions", function()
	it("serves the front customer by hand for the meal plus the bonus", function()
		local d = fresh()
		local cash = d.cash
		local value, refusal = Restaurant.serve(d, ledger(d), config, NO_PERKS, T0)
		expect(value).toBeNil()
		expect(refusal).toContain("Nobody is waiting")
		d.queue = 2.5
		value = Restaurant.serve(d, ledger(d), config, NO_PERKS, T0)
		local expected = math.floor(price("HotDogCart", 1) * (1 + economy.customers.handServeBonus))
		expect(value).toBe(expected)
		expect(d.cash).toBe(cash + expected)
		expect(d.queue).toBe(1.5)
		expect(d.stats.customersServed).toBe(1)
	end)

	it("collects whole cash from the register and keeps the fraction", function()
		local d = fresh()
		d.pendingCash = 12.75
		expect(Restaurant.collect(d, ledger(d))).toBe(12)
		expect(d.cash).toBe(economy.startingCash + 12)
		expect(d.pendingCash).toBe(0.75)
		expect(Restaurant.collect(d, ledger(d))).toBe(0)
	end)

	it("builds a station on a free, open spot and charges for it", function()
		local d = fresh()
		local l = ledger(d)
		local lemonade = station("LemonadeStand").levels[1]
		local built = Restaurant.build(d, l, config, "LemonadeStand", 4, T0)
		expect(built and built.readyAt).toBe(T0 + lemonade.buildSeconds)
		expect(d.cash).toBe(economy.startingCash - lemonade.cost)
	end)

	it("refuses builds it should not make, and charges nothing", function()
		local d = fresh()
		d.cash = 1e9
		local l = ledger(d)
		local function refusal(id: string, spot: number): string
			local built, why = Restaurant.build(d, l, config, id, spot, T0)
			expect(built).toBeNil()
			return why :: string
		end
		expect(refusal("HotDogCart", 2)).toContain("already have")
		expect(refusal("TacoTruck", 2)).toBe("Open Market Row first.")
		expect(refusal("LemonadeStand", 5)).toContain("not open")
		expect(refusal("LemonadeStand", 1)).toContain("taken")
		expect(refusal("Spaceship", 2)).toBe("unknown station")
		expect(d.cash).toBe(1e9)
		d.cash = 0
		expect(refusal("LemonadeStand", 2)).toBe("Not enough cash.")
	end)

	it("upgrades one level at a time, not while building, and stops at the top", function()
		local d = fresh()
		d.cash = 1e9
		local l = ledger(d)
		local first = Restaurant.upgrade(d, l, config, 1, T0) :: any
		expect(first.level).toBe(2)
		local _, busy = Restaurant.upgrade(d, l, config, 1, T0 + 1)
		expect(busy).toContain("still being upgraded")
		local second = Restaurant.upgrade(d, l, config, 1, first.readyAt) :: any
		expect(second.level).toBe(3)
		local _, top = Restaurant.upgrade(d, l, config, 1, second.readyAt)
		expect(top).toContain("fully upgraded")
		local _, empty = Restaurant.upgrade(d, l, config, 2, T0)
		expect(empty).toContain("no station")
		local hotDog = station("HotDogCart")
		expect(d.cash).toBe(1e9 - hotDog.levels[2].cost - hotDog.levels[3].cost)
	end)

	it("moves a station to an open spot, swapping, and its cook goes with it", function()
		local d = fresh()
		d.cash = 1000
		assert(Restaurant.build(d, ledger(d), config, "LemonadeStand", 2, T0))
		assert(Restaurant.hireCook(d, ledger(d), config, "Trainee", 1))
		expect(Restaurant.move(d, config, 1, 2)).toBe(true)
		expect((Restaurant.stationAt(d, 2) :: any).stationId).toBe("HotDogCart")
		expect((Restaurant.stationAt(d, 1) :: any).stationId).toBe("LemonadeStand")
		expect((Restaurant.cookAt(d, "HotDogCart") :: any).tier).toBe("Trainee")
		expect(Restaurant.move(d, config, 2, 4)).toBe(true)
		expect(Restaurant.stationAt(d, 2)).toBeNil()
		expect((Restaurant.move(d, config, 4, 5))).toBe(false) -- district 2 is locked
		expect((Restaurant.move(d, config, 3, 1))).toBe(false) -- nothing on spot 3
		expect((Restaurant.move(d, config, 1, 1))).toBe(false)
	end)

	it("hires cooks at a growing price, one per station; a better tier replaces", function()
		local d = fresh()
		d.cash = 1e9
		local l = ledger(d)
		assert(Restaurant.build(d, l, config, "LemonadeStand", 2, T0))
		local trainee = tier("Trainee")
		expect(Restaurant.hireCost(d, config, "Trainee")).toBe(trainee.cost)
		assert(Restaurant.hireCook(d, l, config, "Trainee", 1))
		expect(Restaurant.hireCost(d, config, "Trainee")).toBe(math.floor(trainee.cost * trainee.costGrowth))
		local cook, refusal = Restaurant.hireCook(d, l, config, "Trainee", 1)
		expect(cook).toBeNil()
		expect(refusal).toContain("already has a cook")
		local better, _, replaced = Restaurant.hireCook(d, l, config, "LineCook", 1)
		expect(better and better.tier).toBe("LineCook")
		expect(replaced).toBe("Trainee")
		expect(#d.cooks).toBe(1)
		local _, worse = Restaurant.hireCook(d, l, config, "Trainee", 1)
		expect(worse).toContain("already has a cook")
		local _, nowhere = Restaurant.hireCook(d, l, config, "Trainee", 3)
		expect(nowhere).toContain("Build a station")
		assert(Restaurant.hireCook(d, l, config, "Trainee", 2))
		expect(#d.cooks).toBe(2)
		expect(d.nextUid).toBe(4)
	end)

	it("unlocks districts in order, opening their spots", function()
		local d = fresh()
		d.cash = 1e9
		local l = ledger(d)
		expect(Restaurant.spotCount(d.districts, config)).toBe(config.districts[1].spots)
		expect(Restaurant.nextDistrictCost(d, config)).toBe(config.districts[2].cost)
		for _ = 2, #config.districts do
			expect(Restaurant.unlockDistrict(d, l, config)).toBe(true)
		end
		expect(Restaurant.nextDistrictCost(d, config)).toBeNil()
		local done, refusal = Restaurant.unlockDistrict(d, l, config)
		expect(done).toBe(false)
		expect(refusal).toContain("Every district")
		expect(Restaurant.spotCount(d.districts, config)).toBe(12)
		expect(Restaurant.districtOfSpot(5, config)).toBe(2)
		expect(Restaurant.districtOfSpot(13, config)).toBeNil()
	end)

	it("rebirth needs every district and the cost, and is capped at maxRebirths", function()
		local d = fresh()
		local l = ledger(d)
		d.cash = economy.rebirth.cost
		expect(Restaurant.rebirthBlocker(d, l, config)).toContain("every district")
		d.districts = #config.districts
		d.cash = economy.rebirth.cost - 1
		expect(Restaurant.rebirthBlocker(d, l, config)).toContain("Not enough cash")
		d.cash = economy.rebirth.cost + 500
		d.cooks = { { uid = "1", tier = "Chef", stationId = "HotDogCart" } }
		d.stations[1].level = 3
		d.queue = 4
		d.pendingCash = 99
		expect(Restaurant.rebirth(d, l, config)).toBe(true)
		expect(d.rebirths).toBe(1)
		expect(d.cash).toBe(economy.startingCash)
		expect(d.districts).toBe(1)
		expect(d.stations).toEqual(Restaurant.starterStations(config))
		expect(#d.cooks).toBe(0)
		expect(d.queue).toBe(0)
		expect(d.pendingCash).toBe(0)
		expect(d.rebirthArchive[1].stations[1].level).toBe(3)
		expect(d.rebirthArchive[1].cooks[1].tier).toBe("Chef")
		d.districts = #config.districts
		d.cash = economy.rebirth.cost
		expect(Restaurant.rebirthBlocker(d, l, config)).toContain("every rebirth")
	end)

	it("Instant Build finishes every build and upgrade in progress", function()
		local d = fresh()
		d.cash = 1000
		local l = ledger(d)
		assert(Restaurant.build(d, l, config, "LemonadeStand", 2, T0))
		assert(Restaurant.upgrade(d, l, config, 1, T0))
		expect(Restaurant.finishBuilds(d, T0 + 1)).toBe(2)
		for _, s in d.stations do
			expect(Restaurant.isBuilding(s, T0 + 1)).toBe(false)
		end
		expect(Restaurant.finishBuilds(d, T0 + 1)).toBe(0)
	end)

	it("records each first-time moment once and reports steps only in order", function()
		local d = fresh()
		expect(Restaurant.markFirst(d, "Joined", T0)).toEqual({ 1 })
		expect(Restaurant.markFirst(d, "Joined", T0 + 5)).toEqual({})
		-- Early moments wait for the steps before them.
		expect(Restaurant.markFirst(d, "FirstCookHired", T0)).toEqual({})
		expect(Restaurant.markFirst(d, "FirstStationBought", T0)).toEqual({})
		expect(d.firsts.FirstCookHired).toBe(T0)
		expect(Restaurant.markFirst(d, "FirstCustomerServed", T0)).toEqual({ 2, 3 })
		expect(Restaurant.markFirst(d, "FirstCookHired", T0)).toEqual({})
		expect(Restaurant.markFirst(d, "FirstUpgrade", T0)).toEqual({ 4, 5 })
		expect(function()
			Restaurant.markFirst(d, "Nope", T0)
		end).toThrow("unknown onboarding moment")
	end)
end)
