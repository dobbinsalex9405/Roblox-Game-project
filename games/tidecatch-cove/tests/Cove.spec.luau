--!strict
local Cove = require("../src/shared/Cove")
local Creatures = require("../src/shared/Creatures")
local DataTemplate = require("../src/shared/DataTemplate")
local Util = require("@core/Util")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local config = {
	fishing = require("../config/fishing"),
	species = require("../config/species"),
	pools = require("../config/pools"),
	economy = require("../config/economy"),
	monetization = require("../config/monetization"),
}
local NO_PERKS = { autoReel = false, extraPools = false, sellMultiplier = false }

-- A minimal ledger over a data table, like Economy's.
local function ledger(d: { [string]: any })
	local l = {}
	function l.balance(_self: any, _currency: string): number
		return d.coins
	end
	function l.add(_self: any, _currency: string, amount: number, _reason: string): number
		assert(amount > 0 and amount // 1 == amount, "whole positive amounts only")
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

local function catch(speciesId: string, kg: number?): Cove.Catch
	return { speciesId = speciesId, kg = kg or 0.25, mutation = "None", spotId = "Shallows" }
end

describe("Cove", function()
	it("lands catches in the bucket and records the journal", function()
		local d = fresh()
		local first = Cove.land(d, ledger(d), catch("SandShrimp", 0.2), 100, config, NO_PERKS)
		local second = Cove.land(d, ledger(d), catch("SandShrimp", 0.3), 101, config, NO_PERKS)
		expect(first.isNew).toBe(true)
		expect(second.isNew).toBe(false)
		expect(#d.bucket).toBe(2)
		expect(d.bucket[1].uid).toBe("1")
		expect(d.journal.SandShrimp.caught).toBe(2)
		expect(d.journal.SandShrimp.bestKg).toBe(0.3)
		expect(d.stats.biggestSpecies).toBe("SandShrimp")
		expect(Cove.journalCount(d, config.species)).toBe(1)
	end)

	it("sells a catch at once when the bucket is full", function()
		local d = fresh()
		for _ = 1, config.fishing.bucketSlots do
			Cove.land(d, ledger(d), catch("SandShrimp"), 100, config, NO_PERKS)
		end
		local coins = d.coins
		local landed = Cove.land(d, ledger(d), catch("Octopus", 5), 100, config, NO_PERKS)
		expect(landed.soldFor).toBe(
			Creatures.value(catch("Octopus", 5) :: any, 1, config.species, config.pools)
		)
		expect(d.coins).toBe(coins + landed.soldFor)
		expect(#d.bucket).toBe(config.fishing.bucketSlots)
	end)

	it("sells from the bucket, one or all, with the Sell Multiplier pass", function()
		local d = fresh()
		Cove.land(d, ledger(d), catch("SandShrimp"), 100, config, NO_PERKS)
		Cove.land(d, ledger(d), catch("Octopus", 5), 100, config, NO_PERKS)
		Cove.land(d, ledger(d), catch("Starfish", 1), 100, config, NO_PERKS)
		local coins = d.coins
		local single = Cove.sellFromBucket(d, ledger(d), "1", config, NO_PERKS) :: number
		expect(d.coins).toBe(coins + single)
		local doubled = { autoReel = false, extraPools = false, sellMultiplier = true }
		local total, count = Cove.sellBucket(d, ledger(d), config, doubled)
		expect(count).toBe(2)
		local plain = Creatures.value(catch("Octopus", 5) :: any, 1, config.species, config.pools)
			+ Creatures.value(catch("Starfish", 1) :: any, 1, config.species, config.pools)
		expect(total).toBeAtLeast(plain * config.monetization.sellMultiplier - 2)
		expect(#d.bucket).toBe(0)
		expect(d.stats.sold).toBe(3)
		expect((Cove.sellFromBucket(d, ledger(d), "1", config, NO_PERKS))).toBeNil()
	end)

	it("places into the first free pool and refuses when every pool is full", function()
		local d = fresh()
		for _ = 1, 3 do
			Cove.land(d, ledger(d), catch("SandShrimp"), 100, config, NO_PERKS)
		end
		local count = Cove.poolCount(d, config.pools, NO_PERKS)
		expect(count).toBe(config.pools.startingSlots)
		expect(Cove.place(d, "1", 200, count)).toBe(1)
		expect(Cove.place(d, "2", 200, count)).toBe(2)
		local slot, refusal = Cove.place(d, "3", 200, count)
		expect(slot).toBeNil()
		expect(refusal).toContain("Every pool is full")
		expect(#d.bucket).toBe(1)
		local withPass =
			Cove.poolCount(d, config.pools, { autoReel = false, extraPools = true, sellMultiplier = false })
		expect(withPass).toBe(config.pools.startingSlots + config.pools.passBonusSlots)
		expect(Cove.place(d, "3", 200, withPass)).toBe(3)
		expect(d.pools[1].placedAt).toBe(200)
	end)

	it("feeding adds growth on a cooldown and stops at full growth", function()
		local d = fresh()
		Cove.land(d, ledger(d), catch("SandShrimp"), 0, config, NO_PERKS)
		Cove.place(d, "1", 1000, 2)
		local per = config.pools.stageSeconds.Common
		expect(Cove.feed(d, 1, 1000, config)).toBe(true)
		expect(d.pools[1].fed).toBe(per * config.pools.feed.stageFraction)
		local ok, refusal = Cove.feed(d, 1, 1001, config)
		expect(ok).toBe(false)
		expect(refusal).toContain("Not hungry")
		expect(Cove.feed(d, 1, 1000 + config.pools.feed.cooldownSeconds, config)).toBe(true)
		local _, full = Cove.feed(d, 1, 1000 + 100 * per, config)
		expect(full).toContain("fully grown")
		expect((Cove.feed(d, 2, 1000, config))).toBe(false)
	end)

	it("sells a pool creature at its current stage", function()
		local d = fresh()
		Cove.land(d, ledger(d), catch("SandShrimp", 0.4), 0, config, NO_PERKS)
		Cove.place(d, "1", 1000, 2)
		local at = 1000 + 2 * config.pools.stageSeconds.Common
		local coins, stage = Cove.sellFromPool(d, ledger(d), 1, at, config, NO_PERKS)
		expect(stage).toBe(3)
		expect(coins).toBe(Creatures.value(catch("SandShrimp", 0.4) :: any, 3, config.species, config.pools))
		expect(#d.pools).toBe(0)
	end)

	it("pays for growth while away only up to the offline cap, once", function()
		local cfg = table.clone(config)
		cfg.pools = Util.deepCopy(config.pools)
		cfg.pools.offline.maxSeconds = 1200 -- below a Legendary's full growth
		local d = fresh()
		Cove.land(d, ledger(d), catch("PearlWhale", 500), 0, cfg, NO_PERKS)
		Cove.place(d, "1", 1000, 2)
		d.lastSeenAt = 1600 -- online for 600 s after placing
		local cap = cfg.pools.offline.maxSeconds
		local now = 1600 + 10 * cap
		local grew = Cove.welcomeBack(d, now, cfg)
		local pooled = d.pools[1]
		expect(Creatures.grown(pooled, now, "Legendary", config.pools)).toBe(600 + cap)
		expect(grew).toBe(1)
		expect(d.lastSeenAt).toBe(now)
		-- Rejoining again at once credits nothing more.
		local again = Cove.welcomeBack(d, now, cfg)
		expect(again).toBe(0)
		expect(Creatures.grown(pooled, now, "Legendary", config.pools)).toBe(600 + cap)
	end)

	it("a short absence counts in full", function()
		local d = fresh()
		Cove.land(d, ledger(d), catch("SandShrimp"), 0, config, NO_PERKS)
		Cove.place(d, "1", 1000, 2)
		d.lastSeenAt = 1010
		Cove.welcomeBack(d, 1040, config)
		expect(Creatures.grown(d.pools[1], 1040, "Common", config.pools)).toBe(40)
	end)

	it("the bait shop sells within stock and restocks on the server clock", function()
		local d = fresh()
		d.coins = 1e6
		local worm = config.fishing.bait[1]
		local period = config.economy.restockSeconds
		local start = 10 * period + 5
		expect(Cove.buyBait(d, ledger(d), worm.id, worm.stock, start, config)).toBe(true)
		expect(d.bait[worm.id]).toBe(worm.stock)
		local ok, refusal = Cove.buyBait(d, ledger(d), worm.id, 1, start + 10, config)
		expect(ok).toBe(false)
		expect(refusal).toContain("Sold out")
		expect(Cove.stockLeft(d, worm, start + period, config.economy)).toBe(worm.stock)
		expect(Cove.buyBait(d, ledger(d), worm.id, 1, start + period, config)).toBe(true)
		expect(d.coins).toBe(1e6 - worm.priceCoins * (worm.stock + 1))
		expect((Cove.buyBait(d, ledger(d), "Dynamite", 1, start, config))).toBe(false)
		expect((Cove.buyBait(d, ledger(d), worm.id, 0, start, config))).toBe(false)
	end)

	it("rods and pools cost coins and only go up", function()
		local d = fresh()
		d.coins = 100
		expect((Cove.buyRod(d, ledger(d), 2, config.fishing))).toBe(false)
		d.coins = 1e6
		expect(Cove.buyRod(d, ledger(d), 3, config.fishing)).toBe(true)
		expect((Cove.buyRod(d, ledger(d), 2, config.fishing))).toBe(false)
		expect(d.rodTier).toBe(3)
		local bought = 0
		while Cove.buyPool(d, ledger(d), config.pools) do
			bought += 1
		end
		expect(d.poolSlots).toBe(config.pools.maxSlots)
		expect(bought).toBe(#config.pools.slotCosts)
	end)

	it("uses bait one at a time; no bait always works", function()
		local d = fresh()
		d.bait.Worm = 1
		expect(Cove.useBait(d, "Worm")).toBe(true)
		expect(Cove.useBait(d, "Worm")).toBe(false)
		expect(Cove.useBait(d, "None")).toBe(true)
		expect(d.bait.Worm).toBe(0)
	end)

	it("reports each first-time moment once", function()
		local d = fresh()
		local first, step = Cove.markFirst(d, "FirstCast", 5)
		expect(first).toBe(true)
		expect(step).toBe(2)
		expect((Cove.markFirst(d, "FirstCast", 6))).toBe(false)
		local sale, saleStep = Cove.markFirst(d, "FirstSale", 7)
		expect(sale).toBe(true)
		expect(saleStep).toBeNil()
	end)
end)
