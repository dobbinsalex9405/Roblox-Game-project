--!strict
local Eggs = require("../src/shared/Eggs")
local Hatchery = require("../src/shared/Hatchery")
local DataTemplate = require("../src/shared/DataTemplate")
local Util = require("@core/Util")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local config = {
	economy = require("../config/economy"),
	creatures = require("../config/creatures"),
	eggs = Eggs.expand(require("../config/eggs"), require("../config/creatures").species),
}
local economy = config.economy
local NO_PERKS = { doubleCoins = false, extraIncubators = false }

-- A minimal ledger over a data table, like Economy's.
local function ledger(d: { [string]: any })
	local l = {}
	function l.balance(_self: any, _currency: string): number
		return d.coins
	end
	function l.add(_self: any, _currency: string, amount: number, _reason: string): number
		d.coins += amount
		return amount
	end
	function l.spend(_self: any, _currency: string, amount: number, _reason: string): boolean
		if d.coins < amount then
			return false
		end
		d.coins -= amount
		return true
	end
	return l
end

local function fresh(): { [string]: any }
	return Util.deepCopy(DataTemplate.template)
end

local function creature(uid: string, speciesId: string, slot: number?)
	return { uid = uid, speciesId = speciesId, mutation = "None", slot = slot }
end

local function always(id: string)
	return function()
		return id
	end
end

describe("Hatchery", function()
	it("lists every belt egg, cheapest first, so the odds list can open any of them", function()
		-- Studio gate (#131): a Moonlit Egg rides past its Buy prompt in about
		-- 1 s, too short to reach its card's "See every creature"; the odds
		-- list switches between the belt's eggs instead.
		local ids = Hatchery.marketEggs(config.eggs, economy.conveyor.weights)
		local count = 0
		for eggId in economy.conveyor.weights do
			count += 1
			expect(table.find(ids, eggId) ~= nil).toBe(true)
		end
		expect(#ids).toBe(count)
		for i = 2, #ids do
			local a = Hatchery.eggById(config.eggs, ids[i - 1])
			local b = Hatchery.eggById(config.eggs, ids[i])
			expect((a.priceCoins or 0) <= (b.priceCoins or 0)).toBe(true)
		end
		expect(ids[1]).toBe("BasicEgg")
		expect(table.find(ids, "MoonlitEgg") ~= nil).toBe(true)
	end)

	it("buys an egg into the first free incubator and pays its price", function()
		local d = fresh()
		local basic = Hatchery.eggById(config.eggs, "BasicEgg")
		local incubator = Hatchery.buyEgg(d, ledger(d), basic, 3, 100, always("Chick"))
		expect(incubator and incubator.slot).toBe(1)
		expect(incubator and incubator.readyAt).toBe(100 + basic.hatchSeconds)
		expect(d.coins).toBe(economy.startingCoins - basic.priceCoins)
		expect(d.eggsBought.BasicEgg).toBe(1)
	end)

	it("refuses when incubators are full, coins are short, or the egg is Robux-only", function()
		local d = fresh()
		d.coins = 10_000
		local basic = Hatchery.eggById(config.eggs, "BasicEgg")
		for _ = 1, 3 do
			assert(Hatchery.buyEgg(d, ledger(d), basic, 3, 0, always("Chick")))
		end
		local _, full = Hatchery.buyEgg(d, ledger(d), basic, 3, 0, always("Chick"))
		expect(full).toBe("Your incubators are full. Hatch an egg first.")

		local poor = fresh()
		poor.coins = 10
		local _, short = Hatchery.buyEgg(poor, ledger(poor), basic, 3, 0, always("Chick"))
		expect(short).toBe("Not enough coins.")
		expect(poor.coins).toBe(10)

		local premium = Hatchery.eggById(config.eggs, "PremiumEgg")
		local _, robux = Hatchery.buyEgg(d, ledger(d), premium, 6, 0, always("Penguin"))
		expect(robux).toBe("this egg is bought with Robux")
	end)

	it("hatches only when ready, onto the first free pad", function()
		local d = fresh()
		local basic = Hatchery.eggById(config.eggs, "BasicEgg")
		assert(Hatchery.buyEgg(d, ledger(d), basic, 3, 0, always("Duckling")))
		local early, why = Hatchery.hatch(d, ledger(d), 1, 5, config.creatures, economy)
		expect(early).toBeNil()
		expect(why).toBe(`Ready in {basic.hatchSeconds - 5}s.`)
		local c = Hatchery.hatch(d, ledger(d), 1, basic.hatchSeconds, config.creatures, economy)
		expect(c and c.speciesId).toBe("Duckling")
		expect(c and c.slot).toBe(1)
		expect(#d.incubators).toBe(0)
		expect(d.nextUid).toBe(2)
	end)

	it("places a new hatch on the highest floor with room, else in the inventory", function()
		local d = fresh()
		d.creatures = {}
		for i = 1, 8 do
			table.insert(d.creatures, creature(tostring(i), "Chick", i))
		end
		d.nextUid = 9
		local function hatchOne(outcome: string): any
			table.insert(
				d.incubators,
				{ slot = 1, eggId = "BasicEgg", startedAt = 0, readyAt = 0, outcome = outcome }
			)
			return Hatchery.hatch(d, ledger(d), 1, 0, config.creatures, economy)
		end
		-- Floor 1 is full: the new one waits in the inventory, nothing moves.
		local owlet = hatchOne("Owlet")
		expect(owlet and owlet.slot).toBeNil()
		expect(d.creatures[1].slot).toBe(1)
		expect(Hatchery.padsFull(d, config.creatures, economy)).toBe(true)
		-- With floor 2 built, the next lands up there.
		d.floors = 2
		local duck = hatchOne("Duckling")
		expect(duck and duck.slot).toBe(9)
		expect(Hatchery.padsFull(d, config.creatures, economy)).toBe(false)
	end)

	-- Staging playtest, Nov 12: "if a creature is hatched with no open
	-- slots, they disappear". With the tower full a hatch goes to the
	-- inventory, and when the inventory overflowed the weakest stored
	-- creature was auto-sold, usually the one just hatched (and at 150/150
	-- ten hatches in a row lost six). Nothing is auto-sold now: a hatch
	-- that fits nowhere waits in its incubator.

	-- A tower whose eight ground pads are full, and `stored` Turtles waiting
	-- in the inventory.
	local function fullTower(stored: number): any
		local d = fresh()
		d.coins = 0
		d.creatures = {}
		for i = 1, 8 do
			table.insert(d.creatures, creature(tostring(i), "Owlet", i))
		end
		for i = 1, stored do
			table.insert(d.creatures, creature(tostring(8 + i), "Turtle", nil))
		end
		d.nextUid = 9 + stored
		return d
	end

	local function readyEggs(d: any, count: number)
		for slot = 1, count do
			table.insert(
				d.incubators,
				{ slot = slot, eggId = "BasicEgg", startedAt = 0, readyAt = 0, outcome = "Chick" }
			)
		end
	end

	local function owns(d: any, uid: string): boolean
		for _, c in d.creatures do
			if c.uid == uid then
				return true
			end
		end
		return false
	end

	it("keeps all ten when ten eggs hatch together into a full tower", function()
		local cap = economy.storage.slots
		local d = fullTower(cap - 10)
		readyEggs(d, 10)
		local before = #d.creatures
		for slot = 1, 10 do
			local c, refusal, sold = Hatchery.hatch(d, ledger(d), slot, 0, config.creatures, economy)
			expect(refusal).toBeNil()
			expect(c and c.slot).toBeNil() -- to the inventory
			expect(c and owns(d, c.uid)).toBe(true)
			expect(#sold).toBe(0)
		end
		expect(#d.creatures).toBe(before + 10) -- every stored Turtle is still there too
		expect(Hatchery.storedCount(d)).toBe(cap)
		expect(d.coins).toBe(0)
		expect(#d.incubators).toBe(0)
	end)

	it("never sells anything: a hatch with no room waits in its incubator", function()
		local cap = economy.storage.slots
		local d = fullTower(cap)
		readyEggs(d, 2)
		local before = #d.creatures
		local nextUid = d.nextUid
		local c, refusal, sold = Hatchery.hatch(d, ledger(d), 1, 0, config.creatures, economy)
		expect(c).toBeNil()
		expect(refusal).toBe(
			`Your tower and inventory are full ({cap}). Make room in your inventory, then hatch: your egg waits here.`
		)
		expect(#sold).toBe(0)
		expect(#d.creatures).toBe(before)
		expect(d.coins).toBe(0)
		expect(#d.incubators).toBe(2) -- both eggs still ready
		expect(d.nextUid).toBe(nextUid)
		-- Room on a pad (a creature moved off the tower) lets it hatch there.
		table.remove(d.creatures, 1)
		local placed = Hatchery.hatch(d, ledger(d), 1, 0, config.creatures, economy)
		expect(placed and placed.slot).toBe(1)
		-- Room in the inventory lets the other one hatch into it.
		for i, c2 in d.creatures do
			if c2.slot == nil then
				table.remove(d.creatures, i)
				break
			end
		end
		local stored = Hatchery.hatch(d, ledger(d), 2, 0, config.creatures, economy)
		expect(stored ~= nil and stored.slot == nil).toBe(true)
	end)

	it("stolen and given creatures always arrive, even past the cap", function()
		local cap = economy.storage.slots
		local d = fullTower(cap)
		local got, sold = Hatchery.receive(
			d,
			ledger(d),
			{ speciesId = "Raccoon", mutation = "None", eggId = "BasicEgg", hatchedAt = 3 },
			config.creatures,
			economy
		)
		expect(got.slot).toBeNil()
		expect(#sold).toBe(0)
		expect(owns(d, got.uid)).toBe(true)
		expect(Hatchery.storedCount(d)).toBe(cap + 1)
	end)

	it("the fixed order gives each outcome exactly as often as its odds", function()
		for _, eggId in { "BasicEgg", "MeadowEgg", "MoonlitEgg", "PremiumEgg" } do
			local egg = Hatchery.eggById(config.eggs, eggId)
			local cycle = Hatchery.fixedOrderCycle(egg)
			local total = egg.total or 10000
			local counts: { [string]: number } = {}
			for _, id in cycle do
				counts[id] = (counts[id] or 0) + 1
			end
			for _, o in egg.outcomes do
				expect(counts[o.id]).toBe(o.weight * #cycle // total)
			end
			-- The cycle repeats, so the shown next outcome never changes meaning.
			for _, i in { 0, 1, 2, 777 } do
				expect(Hatchery.fixedOrderOutcome(egg, i + #cycle)).toBe(Hatchery.fixedOrderOutcome(egg, i))
			end
			-- The shown wait always lands on that outcome.
			for _, o in egg.outcomes do
				for _, from in { 0, 5, #cycle - 1 } do
					local wait = Hatchery.fixedOrderWait(egg, from, o.id) :: number
					expect(Hatchery.fixedOrderOutcome(egg, from + wait)).toBe(o.id)
					for ahead = 0, math.min(wait, 200) - 1 do
						expect(Hatchery.fixedOrderOutcome(egg, from + ahead) ~= o.id).toBe(true)
					end
				end
			end
		end
		-- A cycle is at most the total the odds are written in (shorter when
		-- every weight shares a factor), and the rarest Basic outcome (a
		-- Phoenix) comes exactly as often as its odds say.
		local basic = Hatchery.eggById(config.eggs, "BasicEgg")
		local cycle = Hatchery.fixedOrderCycle(basic)
		local basicTotal = basic.total :: number
		expect(basicTotal % #cycle).toBe(0)
		local phoenixes, phoenixWeight = 0, 0
		for _, id in cycle do
			if id == "Phoenix" then
				phoenixes += 1
			end
		end
		for _, o in basic.outcomes do
			if o.id == "Phoenix" then
				phoenixWeight = o.weight
			end
		end
		expect(phoenixWeight > 0).toBe(true)
		expect(phoenixes * basicTotal / #cycle).toBe(phoenixWeight)
		local first = {}
		for i = 0, 3 do
			table.insert(first, Hatchery.fixedOrderOutcome(basic, i))
		end
		expect(first).toEqual({ "BeaglePup", "BeardedDragon", "Bunny", "Canary" })
		expect(Hatchery.fixedOrderWait(basic, 0, "BeaglePup")).toBe(0)
		expect(Hatchery.fixedOrderWait(basic, 0, "Bunny")).toBe(2)
		expect(Hatchery.fixedOrderWait(basic, 0, "GoldenGoose")).toBeNil()
	end)

	it("sums up the fixed order for the odds card in a few lines", function()
		-- Studio gate (#126): the restricted odds card listed all 47 Basic Egg
		-- outcomes, 1,142 px tall on a 672 px screen, NEXT off the top. The
		-- card shows the next few eggs and one line per tier; the full order
		-- is in the scrolling list.
		local basic = Hatchery.eggById(config.eggs, "BasicEgg")
		local species = config.creatures.species
		local function rarityOf(id: string): string
			return species[id].rarity
		end
		local summary = Hatchery.fixedOrderSummary(basic, 0, rarityOf, 3, Eggs.RARITIES)
		expect(#basic.outcomes > 40).toBe(true)
		-- The next three are the order's next three (the names change as
		-- creatures join the egg, so they are not written here).
		local order = {}
		for n = 0, 3 do
			order[n + 1] = Hatchery.fixedOrderOutcome(basic, n)
		end
		expect(summary.upcoming).toEqual({ order[1], order[2], order[3] })
		expect(#summary.tiers <= #Eggs.RARITIES).toBe(true)
		local total, seen = 0, {}
		for _, tier in summary.tiers do
			total += tier.count
			seen[tier.rarity] = true
			-- the tier's wait is its soonest creature's
			local soonest = math.huge
			for _, o in basic.outcomes do
				if rarityOf(o.id) == tier.rarity then
					soonest = math.min(soonest, Hatchery.fixedOrderWait(basic, 0, o.id) :: number)
				end
			end
			expect(tier.wait).toBe(soonest)
		end
		expect(total).toBe(summary.length)
		expect(summary.length).toBe(Hatchery.fixedOrderLength(basic))
		expect(seen.Common and seen.Legendary).toBe(true)
		-- In tier order, Common first.
		expect(summary.tiers[1].rarity).toBe("Common")
		-- After one egg the window moves on by one.
		local after = Hatchery.fixedOrderSummary(basic, 1, rarityOf, 3, Eggs.RARITIES)
		expect(after.upcoming).toEqual({ order[2], order[3], order[4] })
	end)

	it("the fixed order works out any place without building the cycle", function()
		-- Economy thread (Nov 7): egg totals of 10,000,000 (room for dozens of
		-- Legendaries and Epics in one tier) would have built a 10-million
		-- entry cycle per egg. Each place is worked out on its own instead.
		local egg = {
			id = "HugeEgg",
			total = 10000000,
			outcomes = {
				{ id = "A", weight = 9000001 },
				{ id = "B", weight = 999990 },
				{ id = "C", weight = 7 },
				{ id = "D", weight = 2 },
			},
		}
		expect(Hatchery.fixedOrderLength(egg)).toBe(10000000)
		-- Exactly 2 D's per cycle, and the wait to each lands on it.
		local d1 = Hatchery.fixedOrderWait(egg, 0, "D") :: number
		local d2 = d1 + 1 + (Hatchery.fixedOrderWait(egg, d1 + 1, "D") :: number)
		expect(Hatchery.fixedOrderOutcome(egg, d1)).toBe("D")
		expect(Hatchery.fixedOrderOutcome(egg, d2)).toBe("D")
		expect(Hatchery.fixedOrderWait(egg, d2 + 1, "D") :: number + d2 + 1).toBe(d1 + 10000000)
		-- Spread evenly: the two D's sit half a cycle apart.
		expect(math.abs((d2 - d1) - 5000000) <= 1).toBe(true)
		-- Any stretch of 1,000 places holds A and B in their proportion.
		local counts: { [string]: number } = {}
		for n = 4321000, 4321999 do
			local id = Hatchery.fixedOrderOutcome(egg, n)
			counts[id] = (counts[id] or 0) + 1
		end
		expect(math.abs((counts.B or 0) - 100) <= 2).toBe(true)
	end)

	it("rides only creatures on a floor", function()
		local d = fresh()
		d.creatures = {
			{
				uid = "1",
				speciesId = "Chick",
				mutation = "None",
				slot = 1,
				eggId = "BasicEgg",
				hatchedAt = 0,
			},
			{
				uid = "2",
				speciesId = "Turtle",
				mutation = "None",
				slot = nil,
				eggId = "BasicEgg",
				hatchedAt = 0,
			},
		}
		local speed, why = Hatchery.ride(d, "2", config.creatures)
		expect(speed).toBeNil()
		expect(why).toBe("Only a creature on a floor can be ridden.")
		expect(Hatchery.ride(d, "1", config.creatures)).toBe(config.creatures.species.Chick.mountSpeed)
	end)

	it("accrues income while online and shows the pile between ticks", function()
		local d = fresh()
		Hatchery.accrue(d, 1000, 4)
		expect(d.pendingCoins).toBe(0) -- first call only starts the clock
		Hatchery.accrue(d, 1010, 4)
		expect(d.pendingCoins).toBe(40)
		expect(Hatchery.pendingAt(d, 1015, 4)).toBe(60)
		Hatchery.accrue(d, 900, 4) -- clock went backwards: no change, restart
		expect(d.pendingCoins).toBe(40)
		local l = ledger(d)
		d.pendingCoins = 12.75
		expect(Hatchery.collect(d, l)).toBe(12)
		expect(d.pendingCoins).toBeCloseTo(0.75, 1e-9)
	end)

	it("sells slots at the configured prices until all are unlocked", function()
		local d = fresh()
		d.coins = 1e12
		local paid = 0
		for _, cost in economy.incubators.slotCosts do
			expect(Hatchery.nextSlotCost(d, economy)).toBe(cost)
			assert(Hatchery.buySlot(d, ledger(d), economy))
			paid += cost
		end
		expect(d.slots).toBe(economy.incubators.maxSlots)
		expect(d.coins).toBe(1e12 - paid)
		local ok, why = Hatchery.buySlot(d, ledger(d), economy)
		expect(ok).toBe(false)
		expect(why).toBe("Every incubator slot is unlocked.")
		expect(Hatchery.slotCount(d, economy, { doubleCoins = false, extraIncubators = true })).toBe(
			economy.incubators.maxSlots + economy.incubators.passBonusSlots
		)
	end)

	it("rides owned creatures at their species' speed", function()
		local d = fresh()
		d.creatures = { creature("1", "Phoenix", 1) }
		local speed = Hatchery.ride(d, "1", config.creatures)
		expect(speed).toBe(config.creatures.species.Phoenix.mountSpeed)
		expect(d.mountUid).toBe("1")
		local none, why = Hatchery.ride(d, "2", config.creatures)
		expect(none).toBeNil()
		expect(why).toBe("You do not own that creature.")
		Hatchery.dismount(d)
		expect(d.mountUid).toBe("")
	end)

	it("income counts placed creatures only", function()
		local d = fresh()
		d.creatures = { creature("1", "Chick", 1), creature("2", "Phoenix", nil) }
		expect(Hatchery.incomePerSecond(d, config, NO_PERKS)).toBe(1)
	end)

	it("the Hatchery Book notes each species once and adds income", function()
		local d = fresh()
		d.creatures = { creature("1", "Chick", 1) }
		expect(Hatchery.bookBonus(d, config)).toBe(0)
		expect(Hatchery.noteFound(d, "Chick", 10)).toBe(true)
		expect(Hatchery.noteFound(d, "Chick", 20)).toBe(false)
		expect(d.found.Chick).toBe(10)
		expect(Hatchery.foundCount(d, config.creatures)).toBe(1)
		-- One Common of N: the Common share of the capped bonus, split N ways.
		local commons = 0
		for _, s in config.creatures.species do
			if s.rarity == "Common" then
				commons += 1
			end
		end
		local per = economy.book.maxBonus * economy.book.tierShare.Common / commons
		expect(Hatchery.bookBonus(d, config)).toBe(per)
		expect(Hatchery.incomePerSecond(d, config, NO_PERKS)).toBe(1 * (1 + per))
		-- Unknown ids (a species since removed) never count.
		Hatchery.noteFound(d, "NotACreature", 5)
		expect(Hatchery.foundCount(d, config.creatures)).toBe(1)
	end)

	it("hatching and receiving fill the book; join back-fills older saves", function()
		local d = fresh()
		d.creatures = { creature("1", "Chick", 1), creature("2", "Phoenix", nil) }
		d.found = nil -- a save from before the book
		expect(Hatchery.backfillFound(d)).toBe(2)
		expect(Hatchery.backfillFound(d)).toBe(0)
		expect(Hatchery.foundCount(d, config.creatures)).toBe(2)

		local e = fresh()
		e.incubators = { { slot = 1, eggId = "BasicEgg", startedAt = 0, readyAt = 5, outcome = "Bunny" } }
		local hatched = Hatchery.hatch(e, ledger(e), 1, 7, config.creatures, economy)
		expect(hatched ~= nil).toBe(true)
		expect(e.found.Bunny).toBe(7)
		Hatchery.receive(
			e,
			ledger(e),
			{ speciesId = "Raccoon", mutation = "None", eggId = "BasicEgg", hatchedAt = 3 },
			config.creatures,
			economy
		)
		expect(e.found.Raccoon).toBe(3)
		expect(Hatchery.foundCount(e, config.creatures)).toBe(2)
	end)

	it("first-time moments return their step once", function()
		local d = fresh()
		expect(Hatchery.markFirst(d, "FirstHatch", 5)).toBe(3)
		expect(Hatchery.markFirst(d, "FirstHatch", 6)).toBeNil()
		expect(function()
			Hatchery.markFirst(d, "Nope", 1)
		end).toThrow("unknown onboarding moment")
	end)
end)
