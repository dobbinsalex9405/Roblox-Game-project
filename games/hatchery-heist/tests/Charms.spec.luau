--!strict
-- Charms: the rules on saved data alone (shared/Charms.luau), with a plain
-- table for the save and a tiny coin ledger.
local Charms = require("../src/shared/Charms")
local DataTemplate = require("../src/shared/DataTemplate")
local Hatchery = require("../src/shared/Hatchery")
local Util = require("@core/Util")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local config = require("../config/charms")
local economy = require("../config/economy")
local creatures = require("../config/creatures")

local function save(): { [string]: any }
	return Util.deepCopy(DataTemplate.template) :: any
end

local function ledger(coins: number)
	local l = { coins = coins, spent = {} :: { { amount: number, reason: string } } }
	function l.balance(self: any, _currency: string): number
		return self.coins
	end
	function l.spend(self: any, _currency: string, amount: number, reason: string): boolean
		if self.coins < amount then
			return false
		end
		self.coins -= amount
		table.insert(self.spent, { amount = amount, reason = reason })
		return true
	end
	return l
end

local function give(d: any, id: string, n: number)
	for _ = 1, n do
		Charms.add(d, id, 1000, "test")
	end
end

describe("Charms config", function()
	it("has 42 charms: six kinds, seven tiers each, values rising with the tier", function()
		expect(#config.charms).toBe(42)
		expect(#config.kinds).toBe(6)
		for _, kind in config.kinds do
			local last = -math.huge
			for rank = 1, #config.tiers do
				local def = Charms.at(config, kind.id, rank)
				assert(def, `{kind.id} has no {config.tiers[rank]}`)
				expect(def.value > last).toBe(true)
				last = def.value
			end
		end
	end)

	it("wakes only Feeder, Clover and Warmer until stealing charms are switched on", function()
		expect(config.stealCharms).toBe(false)
		local active = Charms.activeKinds(config)
		expect(table.concat(active, ",")).toBe("Feeder,Clover,Warmer")
		local d = save()
		give(d, "PicketFence", 1)
		local ok, refusal = Charms.equip(d, config, "PicketFence")
		expect(ok).toBe(false)
		expect(refusal and string.find(refusal, "Egg Heist", 1, true) ~= nil).toBe(true)
	end)

	it("every kind's icon and label are set, and no card text uses a glyph the font lacks", function()
		for _, kind in config.kinds do
			expect(type(kind.icon)).toBe("string")
			expect(type(kind.label)).toBe("string")
		end
		for _, c in config.charms do
			local def = Charms.def(config, c.id) :: Charms.Def
			local text = Charms.effectText(config, def)
			expect(string.find(text, "·", 1, true)).toBeNil()
			expect(string.find(text, "→", 1, true)).toBeNil()
		end
	end)
end)

describe("Equipping charms", function()
	it("opens 3 slots on floor 1, then 4, 5 and 6 as the tower grows", function()
		local d = save()
		expect(Charms.slots(d, config)).toBe(3)
		d.floors = 3
		expect(Charms.slots(d, config)).toBe(4)
		d.floors = 6
		expect(Charms.slots(d, config)).toBe(5)
		d.floors = 10
		expect(Charms.slots(d, config)).toBe(6)
		expect(Charms.slotFloor(config, 4)).toBe(3)
		expect(Charms.slotFloor(config, 6)).toBe(9)
		expect(Charms.slotFloor(config, 1)).toBeNil()
		expect(Charms.maxSlots(config)).toBe(6)
	end)

	it("swaps a charm of the same kind, and one charm of each kind at most", function()
		local d = save()
		give(d, "FeedBag", 1)
		give(d, "HoneyPot", 1)
		expect((Charms.equip(d, config, "FeedBag"))).toBe(true)
		expect((Charms.equip(d, config, "HoneyPot"))).toBe(true)
		local equipped = Charms.equipped(d, config)
		expect(equipped.Feeder.def.id).toBe("HoneyPot")
		local ok, refusal = Charms.equip(d, config, "HoneyPot")
		expect(ok).toBe(false)
		expect(refusal).toBe("Honey Pot is already equipped.")
		local _, missing = Charms.equip(d, config, "Cornucopia")
		expect(missing).toBe("You don't have a Cornucopia.")
	end)

	it("refuses a new kind when every slot is in use, naming the floor that opens one", function()
		local d = save()
		local slotsBefore = config.slotsByFloor
		-- One slot open, so a second kind is refused.
		config.slotsByFloor = { { floors = 1, slots = 1 }, { floors = 3, slots = 2 } }
		give(d, "FeedBag", 1)
		give(d, "CloverSprig", 1)
		expect((Charms.equip(d, config, "FeedBag"))).toBe(true)
		local ok, refusal = Charms.equip(d, config, "CloverSprig")
		config.slotsByFloor = slotsBefore
		expect(ok).toBe(false)
		expect(refusal).toBe("All 1 charm slots are full. Build floor 3 to open another slot.")
	end)

	it("adds up equipped bonuses, hidden ones included", function()
		local d = save()
		give(d, "HoneyPot", 1)
		give(d, "Wishbone", 1)
		give(d, "HeatLamp", 1)
		Charms.equip(d, config, "HoneyPot")
		Charms.equip(d, config, "Wishbone")
		Charms.equip(d, config, "HeatLamp")
		Charms.setShown(d, config, "Feeder", false)
		Charms.setShown(d, config, "all", false)
		local stats = Charms.stats(d, config)
		expect(stats.income).toBeCloseTo(0.03, 1e-9)
		expect(stats.luck).toBeCloseTo(1.11, 1e-9)
		expect(stats.hatchCut).toBeCloseTo(0.07, 1e-9)
		expect(Charms.totalsText(stats)).toBe("+3% coins, x1.11 luck, eggs 7% faster")
	end)
end)

describe("Charm bonuses", function()
	it("the Feeder adds to income alongside the Hatchery Book", function()
		local d = save()
		local perks = { doubleCoins = false, extraIncubators = false }
		local cfg = { economy = economy, creatures = creatures, charms = config }
		local speciesId = next(creatures.species) :: string
		table.insert(d.creatures, { uid = "c1", speciesId = speciesId, slot = 1 })
		local before = Hatchery.incomePerSecond(d, cfg, perks)
		expect(before > 0).toBe(true)
		give(d, "GoldenFeeder", 1)
		Charms.equip(d, config, "GoldenFeeder")
		local after = Hatchery.incomePerSecond(d, cfg, perks)
		local book = Hatchery.bookBonus(d, cfg)
		expect(after / before).toBeCloseTo((1 + book + 0.06) / (1 + book), 1e-6)
		local creature = d.creatures[1]
		expect(Hatchery.earning(d, creature, cfg, perks)).toBeCloseTo(after, 1e-6)
	end)

	it("the Warmer shortens hatching, never by more than half", function()
		local d = save()
		expect(Charms.hatchSeconds(100, d, config)).toBe(100)
		give(d, "DragonsHearth", 1)
		Charms.equip(d, config, "DragonsHearth")
		expect(Charms.hatchSeconds(100, d, config)).toBe(80)
		-- With an event halving hatch time too, the cap holds at 50%.
		expect(Charms.hatchSeconds(100, d, config, 0.5)).toBe(50)
		expect(Charms.hatchSeconds(61, d, config)).toBe(49) -- 48.8 rounds up
	end)

	it("the Clover boosts Rare and rarer only", function()
		local d = save()
		expect(next(Charms.luckMultipliers(d, config))).toBeNil()
		give(d, "StarOfFortune", 1)
		Charms.equip(d, config, "StarOfFortune")
		local m = Charms.luckMultipliers(d, config)
		expect(m.Common).toBeNil()
		expect(m.Uncommon).toBeNil()
		expect(m.Rare).toBe(1.2)
		expect(m.Godly).toBe(1.2)
	end)
end)

describe("Showing and hiding charms", function()
	it("writes what others see, in kind order, without the hidden ones", function()
		local d = save()
		give(d, "HeatLamp", 1)
		give(d, "FeedBag", 1)
		Charms.equip(d, config, "HeatLamp")
		Charms.equip(d, config, "FeedBag")
		expect(Charms.wornAttribute(d, config)).toBe("FeedBag,HeatLamp")
		Charms.setShown(d, config, "Feeder", false)
		expect(Charms.wornAttribute(d, config)).toBe("HeatLamp")
		Charms.setShown(d, config, "Feeder", true)
		Charms.setShown(d, config, "all", false)
		expect(Charms.wornAttribute(d, config)).toBe("")
		-- Hiding never changes the bonus.
		expect(Charms.stats(d, config).income).toBeCloseTo(0.01, 1e-9)
	end)
end)

describe("Fusing charms", function()
	it("turns 5 unequipped copies into 1 of the next tier for the fee", function()
		local d = save()
		give(d, "FeedBag", 6)
		Charms.equip(d, config, "FeedBag")
		local l = ledger(1000)
		-- Six owned, one equipped: five are free.
		local made, refusal = Charms.fuse(d, l, config, "FeedBag", 1, 500, 2000)
		expect(refusal).toBeNil()
		assert(made, "fuse made nothing")
		expect(made[1].id).toBe("CornBucket")
		local all = Charms.counts(d)
		expect(all.FeedBag).toBe(1)
		expect(all.CornBucket).toBe(1)
		expect(l.coins).toBe(500)
		expect(l.spent[1].reason).toBe("Gameplay:CharmFuse")
		-- The equipped one is still equipped.
		expect(Charms.equipped(d, config).Feeder.def.id).toBe("FeedBag")
	end)

	it("refuses without enough copies or coins, changing nothing", function()
		local d = save()
		give(d, "FeedBag", 4)
		local l = ledger(1000)
		local made, refusal = Charms.fuse(d, l, config, "FeedBag", 1, 500, 2000)
		expect(made).toBeNil()
		expect(refusal).toBe("Fusing needs 5 Feed Bag that aren't equipped.")
		give(d, "FeedBag", 1)
		local poor = ledger(100)
		local _, broke = Charms.fuse(d, poor, config, "FeedBag", 1, 500, 2000)
		expect(broke).toBe("Not enough coins: fusing costs 500 coins.")
		expect(Charms.bagCount(d)).toBe(5)
		local _, top = Charms.fuse(d, l, config, "Cornucopia", 1, 500, 2000)
		expect(top).toBe("Cornucopia is Godly: it can't be fused any higher.")
	end)

	it("Fuse all fuses up the tiers, so 25 Commons make one Rare", function()
		local d = save()
		give(d, "CloverSprig", 25)
		local plan, spent = Charms.fuseAllPlan(d, config, 10, 1e9)
		expect(#plan).toBe(2)
		expect(plan[1].times).toBe(5)
		expect(plan[2].times).toBe(1)
		expect(spent).toBe(60)
		local l = ledger(1e9)
		local done = Charms.fuseAll(d, l, config, 10, 5000)
		assert(done, "Fuse all did nothing")
		local all = Charms.counts(d)
		expect(all.CloverSprig).toBeNil()
		expect(all.FourLeafClover).toBeNil()
		expect(all.LuckyHorseshoe).toBe(1)
		expect(Charms.bagCount(d)).toBe(1)
	end)

	it("Fuse all stops when the fees run out", function()
		local d = save()
		give(d, "StrawNest", 10)
		local plan, spent = Charms.fuseAllPlan(d, config, 100, 150)
		expect(#plan).toBe(1)
		expect(plan[1].times).toBe(1)
		expect(spent).toBe(100)
	end)
end)

describe("Charm saves", function()
	it("an old save without charm fields reads as empty", function()
		local d: any = { creatures = {}, coins = 0 }
		expect(Charms.bagCount(d)).toBe(0)
		expect(Charms.wornAttribute(d, config)).toBe("")
		expect(Charms.incomeBonus(d, config)).toBe(0)
		expect(Charms.isShown(d, "Feeder")).toBe(true)
		expect(next(Charms.stacks(d, config))).toBeNil()
	end)
end)
