--!strict
-- Whole sessions through the real core services and Actions: the M2 bar is
-- "10 minutes of play survive a rejoin".
local Bot = require("./Bot")
local Fakes = require("../../../packages/core/tests/Fakes")
local Harness = require("./Harness")
local Restaurant = require("../src/shared/Restaurant")
local Util = require("@core/Util")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local config = Harness.config
local economy = config.economy
local NO_PERKS = { doubleCash = false }

-- The parts of the save a rejoin must keep exactly.
local function kept(d: { [string]: any }): { [string]: any }
	return Util.deepCopy({
		cash = d.cash,
		rebirths = d.rebirths,
		districts = d.districts,
		stations = d.stations,
		cooks = d.cooks,
		nextUid = d.nextUid,
		boosts = d.boosts,
		firsts = d.firsts,
		customersServed = d.stats.customersServed,
	})
end

describe("Street Food Empire sessions", function()
	it("10 minutes of play survive leaving and rejoining", function()
		local h = Harness.new()
		local player = Fakes.player(1)
		h.join(player)
		Bot.play(h, player, 600)

		local before = h.get(player)
		expect(#before.stations).toBeAtLeast(4)
		expect(#before.cooks).toBeAtLeast(2)
		expect(before.stats.customersServed).toBeAtLeast(60)
		expect(before.stats.playSeconds).toBeAtLeast(590)
		local snapshot = kept(before)
		local pending, queue = before.pendingCash, before.queue
		h.leave(player)

		-- Rejoin on a different server a moment later: same store, new services.
		local h2 = Harness.new({ store = h.store, start = h.clock.now() + 5 })
		h2.join(player)
		local after = h2.get(player)
		expect(kept(after)).toEqual(snapshot)
		expect(after.pendingCash).toBeAtLeast(pending) -- plus 5 seconds at the offline rate
		expect(after.queue).toBeAtLeast(queue)
		expect(h2.actions:collect(player)).toBe(true)
	end)

	it("pays the cooks at the offline rate, capped, and a full line is waiting", function()
		local h = Harness.new()
		local player = Fakes.player(2)
		h.join(player)
		Bot.play(h, player, 300)
		h.actions:collect(player)
		local d = h.get(player)
		-- Nothing building, so the rate holds for the whole absence.
		local now = h.clock.now()
		for _, s in d.stations do
			if Restaurant.isBuilding(s, now) then
				h.wait(player, s.readyAt - now)
				now = h.clock.now()
			end
		end
		h.actions:collect(player)
		d = h.get(player)
		local perSecond = Restaurant.rates(d, config, NO_PERKS, h.clock.now()).registerPerSecond
		expect(perSecond > 0).toBe(true)
		local pendingBefore = d.pendingCash
		h.leave(player)

		-- Away for 10 hours: pay is capped at offline.maxSeconds.
		local h2 = Harness.new({ store = h.store, start = h.clock.now() + 10 * 3600 })
		h2.join(player)
		local after = h2.get(player)
		local expected = perSecond * economy.offline.maxSeconds * economy.offline.rate
		expect(after.pendingCash).toBeCloseTo(pendingBefore + expected, 1e-6)
		expect(h2.welcomes[1].cash).toBe(math.floor(expected))
		expect(h2.welcomes[1].waiting).toBe(economy.customers.queueMax)
		for _ = 1, economy.customers.queueMax do
			expect(h2.actions:serve(player)).toBe(true)
		end
		expect(h2.actions:serve(player)).toBe(false)
	end)

	it("reports the onboarding steps once ever, in order", function()
		local h = Harness.new()
		local player = Fakes.player(3)
		h.join(player)
		h.wait(player, 10)
		expect(h.actions:serve(player)).toBe(true)
		h.give(player, 100_000)
		assert(h.actions:build(player, "LemonadeStand", 2))
		assert(h.actions:hireCook(player, "Trainee", 1))
		assert(h.actions:unlockDistrict(player))
		h.leave(player)
		local h2 = Harness.new({ store = h.store, start = h.clock.now() + 60 })
		h2.join(player)
		Bot.play(h2, player, 60)

		local steps = {}
		for _, args in h.eventsOf("onboarding") do
			table.insert(steps, args[2])
		end
		expect(steps).toEqual(Restaurant.ONBOARDING)
		expect(#h2.eventsOf("onboarding")).toBe(0)
	end)

	it("reports every onboarding step even when played out of order", function()
		-- The common opening: build before serving anyone, then hire.
		local h = Harness.new()
		local player = Fakes.player(30)
		h.join(player)
		h.give(player, 1000)
		assert(h.actions:build(player, "LemonadeStand", 2))
		assert(h.actions:hireCook(player, "Trainee", 1))
		h.wait(player, 10)
		assert(h.actions:serve(player))
		local steps = {}
		for _, args in h.eventsOf("onboarding") do
			table.insert(steps, args[2])
		end
		expect(steps).toEqual({ "Joined", "FirstCustomerServed", "FirstStationBought", "FirstCookHired" })
	end)

	it("refuses what the player cannot do and leaves cash alone", function()
		local h = Harness.new()
		local player = Fakes.player(4)
		h.join(player)
		expect(h.actions:serve(player)).toBe(false) -- nobody waiting yet
		expect(h.actions:build(player, "FryStation", 2)).toBe(false)
		expect(h.notices[#h.notices]).toBe("Not enough cash.")
		expect(h.actions:build(player, "TacoTruck", 2)).toBe(false)
		expect(h.actions:upgrade(player, 7)).toBe(false)
		expect(h.actions:hireCook(player, "Chef", 1)).toBe(false)
		expect(h.actions:hireCook(player, "Nobody", 1)).toBe(false)
		expect(h.actions:unlockDistrict(player)).toBe(false)
		expect(h.actions:rebirth(player)).toBe(false)
		expect(h.actions:move(player, 1, 9)).toBe(false)
		local d = h.get(player)
		expect(d.cash).toBe(economy.startingCash)
		expect(d.stations).toEqual(Restaurant.starterStations(config))
		expect(#h.eventsOf("economy")).toBe(0)
	end)

	it("auto-collects the register with the pass", function()
		local h = Harness.new({ perks = { doubleCash = false, autoCollect = true } })
		local player = Fakes.player(5)
		h.join(player)
		h.give(player, 1000)
		assert(h.actions:hireCook(player, "Trainee", 1))
		local cash = h.get(player).cash
		h.wait(player, 120)
		local d = h.get(player)
		expect(d.cash > cash).toBe(true)
		-- At most one auto-collect period (plus one tick) is waiting.
		local perSecond = Restaurant.rates(d, config, NO_PERKS, h.clock.now()).registerPerSecond
		expect(d.pendingCash).toBeAtMost(perSecond * (economy.autoCollectSeconds + 10))
	end)

	it("doubles hand serves and cook sales with the 2x Cash pass", function()
		local h = Harness.new({ perks = { doubleCash = true, autoCollect = false } })
		local player = Fakes.player(6)
		h.join(player)
		h.wait(player, 10)
		assert(h.actions:serve(player))
		local meal = Restaurant.rates(h.get(player), config, NO_PERKS, h.clock.now()).meal
		expect(h.served[1]).toBe(
			math.floor(meal * (1 + economy.customers.handServeBonus) * economy.doubleCashMultiplier)
		)
	end)

	it("grows through every district to a rebirth, then starts over with more cash per sale", function()
		local h = Harness.new()
		local player = Fakes.player(7)
		h.join(player)
		h.give(player, 1e9)
		for _ = 2, #config.districts do
			assert(h.actions:unlockDistrict(player))
		end
		expect(h.actions:build(player, "DessertCafe", 12)).toBe(true)
		expect(h.actions:rebirth(player)).toBe(true)
		local d = h.get(player)
		expect(d.rebirths).toBe(1)
		expect(d.cash).toBe(economy.startingCash)
		expect(d.districts).toBe(1)
		expect(#d.rebirthArchive[1].stations).toBe(2)
		expect(Restaurant.rates(d, config, NO_PERKS, h.clock.now()).multiplier).toBe(
			1 + economy.rebirth.incomeBonusPerRebirth
		)
		local progression = h.eventsOf("progression")
		expect(progression[#progression][1]).toBe("Rebirth")
		h.give(player, 1e9)
		for _ = 2, #config.districts do
			assert(h.actions:unlockDistrict(player))
		end
		expect(h.actions:rebirth(player)).toBe(false) -- one rebirth tier at launch
	end)
end)
