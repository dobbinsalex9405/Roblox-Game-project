--!strict
local Hatchery = require("../src/shared/Hatchery")
local DataTemplate = require("../src/shared/DataTemplate")
local Util = require("@core/Util")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local config = {
	economy = require("../config/economy"),
	creatures = require("../config/creatures"),
	eggs = require("../config/eggs"),
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

	it("when pads are full, a better hatch takes the weakest pad and the ridden one stays", function()
		local d = fresh()
		d.creatures = {
			creature("1", "Chick", 1), -- weakest, but ridden
			creature("2", "Duckling", 2),
			creature("3", "Turtle", 3),
		}
		d.mountUid = "1"
		d.nextUid = 4
		table.insert(
			d.incubators,
			{ slot = 1, eggId = "MeadowEgg", startedAt = 0, readyAt = 0, outcome = "Owlet" }
		)
		local small = Util.deepCopy(economy)
		small.creaturePads = 3
		local owlet = Hatchery.hatch(d, ledger(d), 1, 0, config.creatures, small)
		expect(owlet and owlet.slot).toBe(2)
		expect(d.creatures[2].slot).toBeNil() -- Duckling went to storage
		expect(d.creatures[1].slot).toBe(1)

		table.insert(
			d.incubators,
			{ slot = 1, eggId = "BasicEgg", startedAt = 0, readyAt = 0, outcome = "Chick" }
		)
		local chick = Hatchery.hatch(d, ledger(d), 1, 0, config.creatures, small)
		expect(chick and chick.slot).toBeNil() -- not better than anything placed
	end)

	it("sells the weakest stored creature when storage overflows", function()
		local d = fresh()
		local tiny = Util.deepCopy(economy)
		tiny.creaturePads = 1
		tiny.storage.slots = 1
		d.coins = 0
		d.creatures = { creature("1", "Phoenix", 1), creature("2", "Turtle", nil) }
		d.nextUid = 3
		table.insert(
			d.incubators,
			{ slot = 1, eggId = "BasicEgg", startedAt = 0, readyAt = 0, outcome = "Chick" }
		)
		local chick, _, sold = Hatchery.hatch(d, ledger(d), 1, 0, config.creatures, tiny)
		expect(chick and chick.slot).toBeNil()
		expect(#sold).toBe(1)
		expect(sold[1].speciesId).toBe("Chick")
		expect(d.coins).toBe(config.creatures.species.Chick.coinsPerSecond * tiny.storage.sellSeconds)
		expect(#d.creatures).toBe(2)
	end)

	it("the fixed order walks the egg's outcomes in turn", function()
		local basic = Hatchery.eggById(config.eggs, "BasicEgg")
		local n = #basic.outcomes
		for i = 0, n * 2 - 1 do
			expect(Hatchery.fixedOrderOutcome(basic, i)).toBe(basic.outcomes[(i % n) + 1].id)
		end
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

	it("first-time moments return their step once", function()
		local d = fresh()
		expect(Hatchery.markFirst(d, "FirstHatch", 5)).toBe(3)
		expect(Hatchery.markFirst(d, "FirstHatch", 6)).toBeNil()
		expect(function()
			Hatchery.markFirst(d, "Nope", 1)
		end).toThrow("unknown onboarding moment")
	end)
end)
