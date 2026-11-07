--!strict
-- Whole sessions through the real core services and Actions: the M2 bar is
-- "10 minutes of play survive a rejoin".
local Book = require("../src/shared/Book")
local Creatures = require("../src/shared/Creatures")
local Fakes = require("../../../packages/core/tests/Fakes")
local Harness = require("./Harness")
local Hatchery = require("../src/shared/Hatchery")
local Tower = require("../src/shared/Tower")
local Util = require("@core/Util")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local config = Harness.config
local economy = config.economy
local NO_PERKS = { doubleCoins = false, extraIncubators = false, autoCollect = false }

-- A simple player: keeps incubators full of the best egg it can afford
-- while its tower has room, hatches what is ready, collects every 30
-- seconds, buys slots and floors when it can and rides its first creature.
local function play(h: any, player: any, seconds: number)
	local elapsed = 0
	local sinceCollect = 0
	while elapsed < seconds do
		local d = h.get(player)
		local now = h.clock.now()
		for _, incubator in table.clone(d.incubators) do
			if incubator.readyAt <= now then
				h.actions:hatch(player, incubator.slot)
			end
		end
		d = h.get(player)
		if #d.creatures > 0 and d.mountUid == "" then
			h.actions:ride(player, d.creatures[1].uid)
		end
		if sinceCollect >= 30 then
			h.actions:collect(player)
			sinceCollect = 0
		end
		d = h.get(player)
		local cost = Hatchery.nextSlotCost(d, economy)
		if cost and d.coins >= cost + 2500 then
			h.actions:buySlot(player)
		end
		d = h.get(player)
		local floorPrice = Tower.nextFloorPrice(d, economy)
		if floorPrice and d.coins >= floorPrice then
			h.actions:buyFloor(player)
		end
		d = h.get(player)
		if Hatchery.freeSlot(d, d.slots) and not Hatchery.padsFull(d, config.creatures, economy) then
			local eggId = if d.coins >= 2500 then "MeadowEgg" else "BasicEgg"
			if d.coins >= 50 then
				local index = h.findOnBelt(eggId)
				if index and h.actions:buyEgg(player, index) then
					h.taken[index] = true
				end
			end
		end
		h.wait(player, 1)
		elapsed += 1
		sinceCollect += 1
	end
end

-- The parts of the save a rejoin must keep exactly.
local function kept(d: { [string]: any }): { [string]: any }
	return Util.deepCopy({
		coins = d.coins,
		rebirths = d.rebirths,
		slots = d.slots,
		incubators = d.incubators,
		eggsBought = d.eggsBought,
		creatures = d.creatures,
		nextUid = d.nextUid,
		mountUid = d.mountUid,
		firsts = d.firsts,
	})
end

describe("Hatchery Heist sessions", function()
	it("10 minutes of play survive leaving and rejoining", function()
		local h = Harness.new()
		local player = Fakes.player(1)
		h.join(player)
		play(h, player, 600)

		local before = h.get(player)
		expect(#before.creatures).toBeAtLeast(8) -- floor 1 full, saving for floor 2
		expect(before.slots).toBeAtLeast(4) -- bought at least one slot
		expect(before.mountUid ~= "").toBe(true)
		expect(before.stats.playSeconds).toBeAtLeast(590)
		local snapshot = kept(before)
		local pending = before.pendingCoins
		h.leave(player)

		-- Rejoin on a different server a moment later: same store, new services.
		local h2 = Harness.new({ store = h.store, start = h.clock.now() + 5 })
		h2.join(player)
		local after = h2.get(player)
		expect(kept(after)).toEqual(snapshot)
		expect(after.pendingCoins).toBeAtLeast(pending) -- plus 5 seconds at the offline rate
		expect(h2.mounts[1]).toBeTruthy() -- back on the mount
	end)

	it("pays offline earnings at the offline rate, capped, and eggs keep hatching", function()
		local h = Harness.new()
		local player = Fakes.player(2)
		h.join(player)
		play(h, player, 120)
		h.actions:buyEgg(player, h.findOnBelt("BasicEgg") or -1) -- fill an incubator if one is free
		h.actions:collect(player)
		local d = h.get(player)
		local perSecond = Hatchery.incomePerSecond(d, config, NO_PERKS)
		expect(perSecond > 0).toBe(true)
		local pendingBefore = d.pendingCoins
		local busy = #d.incubators
		h.leave(player)

		-- Away for 10 hours: pay is capped at offline.maxSeconds.
		local h2 = Harness.new({ store = h.store, start = h.clock.now() + 10 * 3600 })
		h2.join(player)
		local after = h2.get(player)
		local expected = Creatures.offlineEarnings(perSecond, 10 * 3600, economy)
		expect(after.pendingCoins).toBeCloseTo(pendingBefore + expected, 0.001)
		expect(h2.welcomes[1].coins).toBe(expected)
		expect(h2.welcomes[1].ready).toBe(busy)
		for _, incubator in after.incubators do
			expect(h2.actions:hatch(player, incubator.slot)).toBe(true)
		end
	end)

	it("reports storage auto-sales at most every 20 seconds, summed", function()
		local h = Harness.new()
		local player = Fakes.player(9)
		h.join(player)
		h.data:update(player, function(d: Hatchery.Data)
			d.creatures = {}
			for i = 1, Tower.SPOTS + economy.storage.slots do
				table.insert(d.creatures, {
					uid = tostring(i),
					speciesId = "Chick",
					mutation = "None",
					slot = if i <= Tower.SPOTS then i else nil,
					eggId = "BasicEgg",
					hatchedAt = 0,
				})
			end
			d.nextUid = 100
			d.incubators = {}
			for slot = 1, 3 do
				table.insert(
					d.incubators,
					{ slot = slot, eggId = "BasicEgg", readyAt = 0, outcome = "Chick" }
				)
			end
		end)
		local function soldNotices(): { string }
			local out = {}
			for _, n in h.noticesFor do
				if n.player == player and string.find(n.text, "Inventory is full", 1, true) then
					table.insert(out, n.text)
				end
			end
			return out
		end
		for slot = 1, 3 do
			assert(h.actions:hatch(player, slot))
		end
		local value =
			Hatchery.sellValue({ speciesId = "Chick", mutation = "None" }, config.creatures, economy)
		expect(soldNotices()).toEqual({ `Inventory is full: sold Chick for {value} coins.` })
		h.wait(player, 25)
		expect(soldNotices()[2]).toBe(`Inventory is full: sold 2 creatures for {value * 2} coins.`)
		expect(#soldNotices()).toBe(2)
	end)

	it("reports the onboarding steps once ever, in order", function()
		local h = Harness.new()
		local player = Fakes.player(3)
		h.join(player)
		play(h, player, 90)
		h.leave(player)
		local h2 = Harness.new({ store = h.store, start = h.clock.now() + 60 })
		h2.join(player)
		play(h2, player, 60)

		local steps = {}
		for _, args in h.eventsOf("onboarding") do
			table.insert(steps, args[2])
		end
		-- Floor 1 holds 8 creatures, so it fills in the first minute and a half.
		expect(steps).toEqual({
			"Joined",
			"FirstEggBought",
			"FirstHatch",
			"FirstRide",
			"FirstCollect",
			"PadsFull",
		})
		-- The second session may reach new steps, but never repeats one.
		for _, args in h2.eventsOf("onboarding") do
			expect(table.find(steps, args[2])).toBeNil()
		end
	end)

	it("gives restricted players the shown fixed order instead of a roll", function()
		local h = Harness.new({ restricted = true })
		local player = Fakes.player(4)
		h.join(player)
		h.economy:add(player, "coins", 1000, "Admin:Test")
		local basic = Hatchery.eggById(config.eggs, "BasicEgg")
		for _ = 1, 3 do
			expect(h.buy(player, "BasicEgg")).toBe(true)
		end
		local outcomes = {}
		for _, incubator in h.get(player).incubators do
			table.insert(outcomes, incubator.outcome)
		end
		local expected = {}
		for i = 0, 2 do
			table.insert(expected, Hatchery.fixedOrderOutcome(basic, i))
		end
		expect(outcomes).toEqual(expected)
		expect(outcomes).toEqual({ "BeaglePup", "Bunny", "Canary" })
	end)

	it("rolls from the odds table for players who may receive paid random items", function()
		local h = Harness.new({ seed = 12345 })
		local player = Fakes.player(5)
		h.join(player)
		local seen: { [string]: boolean } = {}
		for _ = 1, 30 do
			h.actions:collect(player)
			h.economy:add(player, "coins", 50, "Admin:Test")
			assert(h.buy(player, "BasicEgg"))
			local incubator = h.get(player).incubators[1]
			seen[incubator.outcome] = true
			h.wait(player, 15)
			assert(h.actions:hatch(player, incubator.slot))
		end
		-- 30 rolls among 16 Commons: many different creatures, not a fixed list.
		local kinds = 0
		for _ in seen do
			kinds += 1
		end
		expect(kinds).toBeAtLeast(8)
	end)

	it("refuses what the player cannot do and leaves coins alone", function()
		local h = Harness.new()
		local player = Fakes.player(6)
		h.join(player)
		expect(h.buy(player, "MeadowEgg")).toBeFalsy() -- 50 coins, egg costs 2500
		expect(h.get(player).coins).toBe(economy.startingCoins)
		-- Says which egg it was and which egg the player can afford.
		expect(h.notices[#h.notices]).toBe("Not enough coins: a Meadow Egg costs 2.5K. Basic Eggs cost 50.")

		local index = h.findOnBelt("BasicEgg") :: number
		expect(h.actions:buyEgg(player, index)).toBe(true)
		expect(h.actions:buyEgg(player, index)).toBeFalsy() -- same belt egg twice
		expect(h.actions:buyEgg(player, index - 1000)).toBeFalsy() -- long gone
		expect(h.actions:hatch(player, 1)).toBeFalsy() -- not ready
		expect(h.actions:hatch(player, 9)).toBeFalsy() -- empty
		expect(h.actions:ride(player, "999")).toBeFalsy()
		expect(h.actions:rebirth(player)).toBeFalsy()
		expect(h.get(player).rebirths).toBe(0)
	end)

	it("auto-collects with the pass", function()
		local h =
			Harness.new({ perks = { doubleCoins = false, extraIncubators = false, autoCollect = true } })
		local player = Fakes.player(7)
		h.join(player)
		assert(h.buy(player, "BasicEgg"))
		h.wait(player, 20)
		assert(h.actions:hatch(player, 1))
		local coins = h.get(player).coins
		h.wait(player, 60)
		local d = h.get(player)
		expect(d.coins > coins).toBe(true)
		-- At most one auto-collect period (plus one tick) is waiting.
		local perSecond = Hatchery.incomePerSecond(d, config, NO_PERKS)
		expect(d.pendingCoins).toBeAtMost(perSecond * (economy.autoCollectSeconds + 10))
		expect(#h.eventsOf("economy") > 0).toBe(true)
	end)

	it("rebirth resets coins and creatures, keeps eggs and slots, raises income", function()
		local h = Harness.new()
		local player = Fakes.player(8)
		h.join(player)
		play(h, player, 120)
		h.actions:collect(player)
		local d = h.get(player)
		local creatures = #d.creatures
		local incubators = #d.incubators
		local slots = d.slots
		h.economy:add(player, "coins", economy.rebirth.baseCost, "Admin:Test")
		expect(h.actions:rebirth(player)).toBe(true)
		d = h.get(player)
		expect(d.rebirths).toBe(1)
		expect(d.coins).toBe(economy.startingCoins)
		expect(#d.creatures).toBe(0)
		expect(#d.rebirthArchive[1].creatures).toBe(creatures)
		expect(#d.incubators).toBe(incubators)
		expect(d.slots).toBe(slots)
		expect(d.mountUid).toBe("")
		expect(h.mounts[#h.mounts]).toBe(false)
		expect(Creatures.multiplier(d.rebirths, false, economy)).toBe(
			1 + economy.rebirth.incomeBonusPerRebirth
		)
		local progression = h.eventsOf("progression")
		expect(progression[#progression][1]).toBe("Rebirth")
	end)

	it("claims the daily reward once a day through the server", function()
		local h = Harness.new()
		local player = Fakes.player(9)
		h.join(player)
		local before = h.get(player).coins
		expect((h.actions:claimDaily(player))).toBe(true)
		local reward = economy.daily.rewards[1].minCoins
		expect(h.get(player).coins).toBe(before + reward)
		expect(h.lastNotice(player)).toBe(`Day 1 reward: +{reward} coins!`)
		expect((h.actions:claimDaily(player))).toBe(false)
		expect(h.get(player).coins).toBe(before + reward)
		h.wait(player, 86400)
		expect((h.actions:claimDaily(player))).toBe(true)
		expect(h.get(player).daily.streak).toBe(2)
	end)

	it("moves a pre-tower save onto the tower best-first, once", function()
		local h = Harness.new()
		local player = Fakes.player(11)
		h.join(player)
		h.leave(player)
		-- An older save: 20 creatures on the old pads, no tower yet.
		do
			local d = h.store.saved["Player_11"]
			d.creatures = {}
			for i = 1, 20 do
				table.insert(d.creatures, {
					uid = tostring(i),
					speciesId = if i == 20 then "Penguin" else "Chick",
					mutation = "None",
					slot = i,
					eggId = "BasicEgg",
					hatchedAt = 0,
				})
			end
			d.towerVersion = 0
			d.mountUid = "3"
		end
		local h2 = Harness.new({ store = h.store, start = h.clock.now() + 10 })
		h2.join(player)
		local d = h2.get(player)
		local placed = 0
		for _, c in d.creatures do
			if c.slot then
				placed += 1
			end
		end
		expect(#d.creatures).toBe(20) -- nothing lost
		expect(placed).toBe(8)
		expect(d.creatures[20].slot ~= nil).toBe(true) -- the Penguin earns
		expect(d.mountUid).toBe("")
		expect(d.towerVersion).toBe(1)
	end)

	it("opening the Hatchery Book clears its NEW cards", function()
		local h = Harness.new()
		local player = Fakes.player(10)
		h.join(player)
		h.actions:change(player, function(d)
			d.found.Chick = h.clock.now()
			return nil
		end)
		local d = h.get(player)
		expect(Book.newCount(d.found, config.creatures.species, d.bookSeenAt)).toBe(1)
		h.wait(player, 5)
		h.actions:seeBook(player)
		d = h.get(player)
		expect(Book.newCount(d.found, config.creatures.species, d.bookSeenAt)).toBe(0)
	end)
end)

-- The Studio test panel's "Give a creature": guard walks and rides can be
-- checked in Studio without hatching the right egg first.
describe("Studio grant", function()
	it("puts any species on a pad, ready to ride and guard", function()
		local h = Harness.new()
		local player = Fakes.player(1)
		h.join(player)
		-- A species only the second egg holds, so the recorded egg is checked.
		local first: { [string]: boolean } = {}
		for _, outcome in config.eggs[1].outcomes do
			first[outcome.id] = true
		end
		local speciesId: string? = nil
		for _, outcome in config.eggs[2].outcomes do
			if speciesId == nil and not first[outcome.id] then
				speciesId = outcome.id
			end
		end
		local id = speciesId :: string
		local ok, text = h.actions:grantCreature(player, id)
		expect(ok).toBe(true)
		expect(text).toBe(`{id} added on floor 1, ready to ride or guard.`)
		local d = h.get(player)
		expect(#d.creatures).toBe(1)
		local c = d.creatures[1]
		expect(c.speciesId).toBe(id)
		expect(c.slot).toBe(1)
		expect(c.eggId).toBe(config.eggs[2].id) -- the egg that holds it
		assert(h.actions:ride(player, c.uid))
		assert(h.actions:dismount(player))
		assert(h.raids:toggleGuard(player, c.uid))
		expect(h.get(player).guardUid).toBe(c.uid)
	end)

	it("refuses an unknown species and changes nothing", function()
		local h = Harness.new()
		local player = Fakes.player(1)
		h.join(player)
		local ok, text = h.actions:grantCreature(player, "NoSuchCreature")
		expect(ok).toBe(false)
		expect(text).toBe("No creature called NoSuchCreature.")
		expect(#h.get(player).creatures).toBe(0)
	end)
end)
