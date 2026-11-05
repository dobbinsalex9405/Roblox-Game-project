--!strict
-- Merging into stars (plan, Nov 5): 3 copies of one creature at one star
-- make 1 at the next, up to Star 3 (x2.5, then x6 income). A merge costs 30
-- (then 100) minutes of the creature's Star 1 income and takes 1 min (Common)
-- to 45 min (Legendary), 3 times as long into Star 3. Godlies never merge.
-- One merge slot free, a second for 10,000 coins; cancel gives everything
-- back; "Finish now" ends the soonest merge or is kept for the next one.
local DataTemplate = require("../src/shared/DataTemplate")
local Hatchery = require("../src/shared/Hatchery")
local Merge = require("../src/shared/Merge")
local Tower = require("../src/shared/Tower")
local Util = require("@core/Util")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local economy = require("../config/economy")
local creatures = require("../config/creatures")
local config = { economy = economy, creatures = creatures }

local function ledger(d: { [string]: any })
	local l = {}
	function l.spend(_self: any, _currency: string, amount: number, _reason: string): boolean
		if d.coins < amount then
			return false
		end
		d.coins -= amount
		return true
	end
	function l.add(_self: any, _currency: string, amount: number, _reason: string): number
		d.coins += amount
		return amount
	end
	function l.balance(_self: any, _currency: string): number
		return d.coins
	end
	return l
end

local function fresh(coins: number?): { [string]: any }
	local d = Util.deepCopy(DataTemplate.template)
	d.creatures = {}
	d.coins = coins or 1e9
	d.nextUid = 100
	return d
end

local function add(d: any, uid: string, speciesId: string, slot: number?, star: number?): any
	local c =
		{ uid = uid, speciesId = speciesId, mutation = "None", slot = slot, star = star, eggId = "BasicEgg" }
	table.insert(d.creatures, c)
	return c
end

local function count(d: any, speciesId: string, star: number): number
	local n = 0
	for _, c in d.creatures do
		if c.speciesId == speciesId and (c.star or 1) == star then
			n += 1
		end
	end
	return n
end

describe("Stars", function()
	it("multiply income: Star 1 x1, Star 2 x2.5, Star 3 x6", function()
		local base = creatures.species.Chick.coinsPerSecond
		expect(Hatchery.creatureIncome({ speciesId = "Chick", mutation = "None" }, creatures)).toBe(base)
		expect(Hatchery.creatureIncome({ speciesId = "Chick", mutation = "None", star = 2 }, creatures)).toBe(
			base * 2.5
		)
		expect(Hatchery.creatureIncome({ speciesId = "Chick", mutation = "None", star = 3 }, creatures)).toBe(
			base * 6
		)
	end)

	it("never make coins out of nothing: a merge earns less than its copies did", function()
		for star = 2, #creatures.stars do
			expect(creatures.stars[star] < economy.merge.copies * creatures.stars[star - 1]).toBe(true)
		end
	end)

	it("cost 30 then 100 minutes of Star 1 income and take longer at each rarity", function()
		expect(Merge.cost("Chick", "None", 2, config)).toBe(1800)
		expect(Merge.cost("Chick", "None", 3, config)).toBe(6000)
		expect(Merge.cost("Chick", "Golden", 2, config)).toBe(3600)
		expect(Merge.seconds("Chick", 2, config)).toBe(60)
		expect(Merge.seconds("Chick", 3, config)).toBe(180)
		expect(Merge.seconds("Phoenix", 2, config)).toBe(2700)
	end)
end)

describe("Merging", function()
	it("takes 3 copies, charges the cost and finishes into one creature a star higher", function()
		local d = fresh(10000)
		add(d, "1", "Chick")
		add(d, "2", "Chick")
		add(d, "3", "Chick")
		add(d, "4", "Duckling")
		local job, refusal = Merge.start(d, ledger(d), "Chick", "None", 1, 1000, config)
		expect(refusal).toBe(nil)
		assert(job)
		expect(job.star).toBe(2)
		expect(#job.copies).toBe(3)
		expect(d.coins).toBe(10000 - 1800)
		expect(count(d, "Chick", 1)).toBe(0) -- in the station, earning nothing
		expect(#Merge.finish(d, 1059, config)).toBe(0) -- not ready yet
		local made = Merge.finish(d, 1060, config)
		expect(#made).toBe(1)
		expect(made[1].star).toBe(2)
		expect(count(d, "Chick", 2)).toBe(1)
		expect(#d.merges).toBe(0)
	end)

	it("places the merged creature on the tower like a hatch", function()
		local d = fresh()
		add(d, "1", "Chick", 1)
		add(d, "2", "Chick", 2)
		add(d, "3", "Chick", 3)
		Merge.start(d, ledger(d), "Chick", "None", 1, 0, config)
		local made = Merge.finish(d, 60, config)
		expect(made[1].slot ~= nil).toBe(true)
		expect(Hatchery.incomePerSecond(d, config, { doubleCoins = false, extraIncubators = false })).toBeCloseTo(
			creatures.species.Chick.coinsPerSecond * 2.5 * (1 + Hatchery.bookBonus(d, config)),
			1e-9
		)
	end)

	it("takes inventory copies first, then the lowest floors", function()
		local d = fresh()
		add(d, "1", "Chick", Tower.SPOTS * 2 + 1) -- floor 3
		add(d, "2", "Chick", 1) -- floor 1
		add(d, "3", "Chick", nil)
		add(d, "4", "Chick", Tower.SPOTS + 1) -- floor 2
		local job = Merge.start(d, ledger(d), "Chick", "None", 1, 0, config)
		assert(job)
		local uids = {}
		for _, c in job.copies do
			table.insert(uids, c.uid)
		end
		table.sort(uids)
		expect(table.concat(uids, ",")).toBe("2,3,4")
		expect(count(d, "Chick", 1)).toBe(1)
	end)

	it("merges Star 2s into Star 3, and no further", function()
		local d = fresh()
		for i = 1, 3 do
			add(d, tostring(i), "Chick", nil, 2)
		end
		local job = Merge.start(d, ledger(d), "Chick", "None", 2, 0, config)
		assert(job)
		expect(job.star).toBe(3)
		expect(job.readyAt).toBe(180)
		Merge.finish(d, 180, config)
		for i = 4, 5 do
			add(d, tostring(i), "Chick", nil, 3)
		end
		local _, refusal = Merge.start(d, ledger(d), "Chick", "None", 3, 200, config)
		expect(refusal).toBe("That creature is already at the top star.")
	end)

	it("refuses Godlies, too few copies, the ridden or guarding copy, a full station and no coins", function()
		local d = fresh()
		for i = 1, 3 do
			add(d, `{i}`, "GoldenGoose")
		end
		local _, godly = Merge.start(d, ledger(d), "GoldenGoose", "None", 1, 0, config)
		expect(godly).toBe("Godly creatures can't merge.")

		add(d, "10", "Chick")
		add(d, "11", "Chick")
		local _, few = Merge.start(d, ledger(d), "Chick", "None", 1, 0, config)
		expect(few).toBe("You need 3 to merge (you have 2 free).")
		add(d, "12", "Chick", 1)
		d.mountUid = "12"
		local _, riding = Merge.start(d, ledger(d), "Chick", "None", 1, 0, config)
		expect(riding).toBe("You need 3 to merge (you have 2 free).")
		d.mountUid = ""

		local poor = fresh(100)
		for i = 1, 3 do
			add(poor, `{i}`, "Chick")
		end
		local _, coins = Merge.start(poor, ledger(poor), "Chick", "None", 1, 0, config)
		expect(coins).toBe("Not enough coins.")
		expect(count(poor, "Chick", 1)).toBe(3)

		expect(Merge.start(d, ledger(d), "Chick", "None", 1, 0, config) ~= nil).toBe(true)
		for i = 20, 22 do
			add(d, `{i}`, "Duckling")
		end
		local _, full = Merge.start(d, ledger(d), "Duckling", "None", 1, 0, config)
		expect(full).toBe("The Merge Station is busy. Wait for a merge or unlock another slot.")
		local ok = Merge.buySlot(d, ledger(d), economy)
		expect(ok).toBe(true)
		expect(Merge.start(d, ledger(d), "Duckling", "None", 1, 0, config) ~= nil).toBe(true)
		local more, none = Merge.buySlot(d, ledger(d), economy)
		expect(more).toBe(false)
		expect(none).toBe("Every merge slot is unlocked.")
	end)

	it("keeps mutations apart and passes the mutation on", function()
		local d = fresh()
		add(d, "1", "Chick")
		add(d, "2", "Chick")
		local golden = add(d, "3", "Chick")
		golden.mutation = "Golden"
		local _, refusal = Merge.start(d, ledger(d), "Chick", "None", 1, 0, config)
		expect(refusal).toBe("You need 3 to merge (you have 2 free).")
		add(d, "4", "Chick").mutation = "Golden"
		add(d, "5", "Chick").mutation = "Golden"
		local job = Merge.start(d, ledger(d), "Chick", "Golden", 1, 0, config)
		assert(job)
		local made = Merge.finish(d, 60, config)
		expect(made[1].mutation).toBe("Golden")
	end)

	it("gives back the copies and the coins on a cancel", function()
		local d = fresh(5000)
		for i = 1, 3 do
			add(d, `{i}`, "Chick", i)
		end
		local job = Merge.start(d, ledger(d), "Chick", "None", 1, 0, config)
		assert(job)
		local back = Merge.cancel(d, ledger(d), job.id)
		expect(back ~= nil).toBe(true)
		expect(d.coins).toBe(5000)
		expect(count(d, "Chick", 1)).toBe(3)
		for _, c in d.creatures do
			expect(c.slot).toBe(nil) -- back in the inventory
		end
		local _, gone = Merge.cancel(d, ledger(d), job.id)
		expect(gone).toBe("That merge has already finished.")
	end)
end)

describe("Finish now", function()
	it("ends the merge that would finish soonest", function()
		local d = fresh()
		Merge.buySlot(d, ledger(d), economy)
		for i = 1, 3 do
			add(d, `{i}`, "Phoenix")
			add(d, `{i + 10}`, "Chick")
		end
		local slow = Merge.start(d, ledger(d), "Phoenix", "None", 1, 0, config)
		local quick = Merge.start(d, ledger(d), "Chick", "None", 1, 0, config)
		assert(slow and quick)
		local rushed = Merge.rush(d, 10)
		expect(rushed).toBe(quick)
		local made = Merge.finish(d, 10, config)
		expect(#made).toBe(1)
		expect(made[1].speciesId).toBe("Chick")
		expect(#d.merges).toBe(1)
	end)

	it("is kept for the next merge when none is running, and used once", function()
		local d = fresh()
		expect(Merge.rush(d, 0)).toBe(nil)
		expect(d.mergeRushes).toBe(1)
		for i = 1, 6 do
			add(d, `{i}`, "Chick")
		end
		local job = Merge.start(d, ledger(d), "Chick", "None", 1, 50, config)
		assert(job)
		expect(job.readyAt).toBe(50)
		expect(d.mergeRushes).toBe(0)
		Merge.finish(d, 50, config)
		local next = Merge.start(d, ledger(d), "Chick", "None", 1, 60, config)
		assert(next)
		expect(next.readyAt).toBe(120)
	end)
end)

describe("Merge groups and the Book", function()
	it("lists ready groups first and counts copies riding or guarding apart", function()
		local d = fresh()
		add(d, "1", "Chick")
		add(d, "2", "Phoenix")
		add(d, "3", "Duckling")
		add(d, "4", "Duckling")
		add(d, "5", "Duckling", 1)
		add(d, "6", "GoldenGoose")
		d.guardUid = "2"
		local groups = Merge.groups(d, config)
		expect(#groups).toBe(3) -- no Godly group
		expect(groups[1].speciesId).toBe("Duckling")
		expect(#groups[1].uids).toBe(3)
		local phoenix = nil
		for _, g in groups do
			if g.speciesId == "Phoenix" then
				phoenix = g
			end
		end
		assert(phoenix)
		expect(#phoenix.uids).toBe(0)
		expect(phoenix.busy).toBe(1)
	end)

	it("shows the highest star of each creature, merging ones included", function()
		local d = fresh()
		add(d, "1", "Chick", nil, 2)
		add(d, "2", "Chick")
		for i = 3, 5 do
			add(d, `{i}`, "Duckling", nil, 2)
		end
		Merge.start(d, ledger(d), "Duckling", "None", 2, 0, config)
		local best = Merge.bestStars(d)
		expect(best.Chick).toBe(2)
		expect(best.Duckling).toBe(2)
	end)

	it("keeps a stolen creature's star", function()
		local d = fresh()
		local got = Hatchery.receive(d, ledger(d), {
			speciesId = "Chick",
			mutation = "None",
			star = 3,
			eggId = "BasicEgg",
			hatchedAt = 0,
		}, creatures, economy)
		expect(got.star).toBe(3)
	end)
end)
