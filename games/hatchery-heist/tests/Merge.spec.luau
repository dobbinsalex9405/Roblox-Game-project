--!strict
-- The creature merger (Alex, Nov 12): 3 copies with the same stars make one
-- with a star more, up to 5; each star adds +50% income (economy thread);
-- the copy on the highest floor stays; ridden, guarding and carried
-- creatures never merge; merged creatures cannot be stolen (stopgap until
-- Egg Heist); used-up copies are archived.
local DataTemplate = require("../src/shared/DataTemplate")
local Fakes = require("../../../packages/core/tests/Fakes")
local Harness = require("./Harness")
local Hatchery = require("../src/shared/Hatchery")
local Merge = require("../src/shared/Merge")
local Tower = require("../src/shared/Tower")
local Util = require("@core/Util")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local economy = require("../config/economy")
local creatures = require("../config/creatures")
local raidsConfig = require("../config/raids")
local config = { economy = economy, creatures = creatures }

local function fresh(): { [string]: any }
	local d = Util.deepCopy(DataTemplate.template)
	d.creatures = {}
	d.floors = 3
	return d
end

local function add(d: any, uid: string, speciesId: string, slot: number?, stars: number?): any
	local c = {
		uid = uid,
		speciesId = speciesId,
		mutation = "None",
		slot = slot,
		stars = stars,
		eggId = "BasicEgg",
		hatchedAt = tonumber(uid) or 0,
	}
	table.insert(d.creatures, c)
	return c
end

local function find(d: any, uid: string): any?
	return Hatchery.creatureByUid(d, uid)
end

describe("Merge rules", function()
	it("reads stars as 1 for creatures from before the merger", function()
		expect(Merge.stars({ uid = "1" })).toBe(1)
		expect(Merge.stars({ uid = "1", stars = 3 })).toBe(3)
		expect(Merge.stars({ uid = "1", stars = 0 })).toBe(1)
	end)

	it("adds +50% income per star, x3 at 5 stars", function()
		local base = creatures.species.Chick.coinsPerSecond
		for stars, mult in { 1, 1.5, 2, 2.5, 3 } do
			local c = { uid = "1", speciesId = "Chick", mutation = "None", stars = stars }
			expect(Merge.multiplier(c, economy)).toBeCloseTo(mult, 1e-9)
			expect(Hatchery.creatureIncome(c, creatures, economy)).toBeCloseTo(base * mult, 1e-9)
		end
	end)

	it("merges 3 copies into one with a star more; the highest floor's copy stays", function()
		local d = fresh()
		add(d, "1", "Chick", nil) -- stashed
		add(d, "2", "Chick", 17) -- floor 3
		add(d, "3", "Chick", 1) -- floor 1
		add(d, "4", "Chick", nil, 2) -- different stars: not used
		add(d, "5", "Duckling", nil) -- different species: not used
		local kept, refusal, used = Merge.merge(d, "1", economy, 100)
		expect(refusal).toBeNil()
		assert(kept, "the merge kept a copy")
		expect(kept.uid).toBe("2")
		expect(kept.slot).toBe(17)
		expect(kept.stars).toBe(2)
		expect(#used).toBe(2)
		expect(#d.creatures).toBe(3)
		expect(find(d, "1")).toBeNil()
		expect(find(d, "3")).toBeNil()
		expect(#d.mergeArchive).toBe(2)
		expect(d.mergeArchive[1].into).toBe("2")
	end)

	it("keeps the picked copy (stashed) when none is placed", function()
		local d = fresh()
		add(d, "1", "Chick", nil)
		add(d, "2", "Chick", nil)
		add(d, "3", "Chick", nil)
		add(d, "4", "Chick", nil)
		local kept = Merge.merge(d, "3", economy, 100)
		assert(kept, "the merge kept a copy")
		expect(kept.uid).toBe("3")
		expect(kept.slot).toBeNil()
		-- The oldest other copies are used first; the newest one is left.
		expect(find(d, "4")).toBeTruthy()
	end)

	it("refuses with too few copies, a different mutation, or at max stars", function()
		local d = fresh()
		add(d, "1", "Chick", nil)
		add(d, "2", "Chick", nil)
		local golden = add(d, "3", "Chick", nil)
		golden.mutation = "Golden"
		local kept, refusal = Merge.merge(d, "1", economy, 100)
		expect(kept).toBeNil()
		expect(refusal).toContain("need 3")
		expect(#d.creatures).toBe(3)

		local top = fresh()
		for i = 1, 3 do
			add(top, tostring(i), "Chick", nil, economy.merge.maxStars)
		end
		local none, why = Merge.merge(top, "1", economy, 100)
		expect(none).toBeNil()
		expect(why).toBe("It already has the most stars.")
	end)

	it("never uses the ridden creature, the guard or one being carried", function()
		local d = fresh()
		for i = 1, 5 do
			add(d, tostring(i), "Chick", i)
		end
		d.mountUid = "1"
		d.guardUid = "2"
		local carried = { ["3"] = true }
		local _, refusal = Merge.merge(d, "1", economy, 100, carried)
		expect(refusal).toBe("Get off it first.")
		local _, refusal2 = Merge.merge(d, "3", economy, 100, carried)
		expect(refusal2).toBe("A raider is carrying it!")
		-- Only 4 and 5 are free: not enough.
		local none = Merge.merge(d, "4", economy, 100, carried)
		expect(none).toBeNil()
		local ready = Merge.ready(d, economy, carried)
		expect(next(ready)).toBeNil()
		expect(Merge.count(d, find(d, "4"), economy, carried)).toBe(2)
	end)

	it("merge all climbs the stars: 9 copies make one 3-star", function()
		local d = fresh()
		for i = 1, 10 do
			add(d, tostring(i), "Chick", if i <= 8 then i else nil)
		end
		local merges, gone = Merge.mergeAll(d, economy, 100)
		expect(merges).toBe(4) -- 3 two-stars, then one three-star
		expect(#gone).toBe(8)
		expect(#d.creatures).toBe(2)
		local stars = {}
		for _, c in d.creatures do
			table.insert(stars, Merge.stars(c))
		end
		table.sort(stars)
		expect(stars[1]).toBe(1)
		expect(stars[2]).toBe(3)
		-- Never more than one creature per pad afterwards.
		local used = Tower.occupancy(d, creatures, economy)
		local count = 0
		for _ in used do
			count += 1
		end
		expect(count <= 2).toBe(true)
	end)

	it("keeps the archive to its last 100 copies", function()
		local d = fresh()
		for i = 1, 160 do
			add(d, tostring(i), "Chick", nil)
		end
		Merge.mergeAll(d, economy, 100)
		expect(#d.mergeArchive).toBe(Merge.ARCHIVE)
	end)
end)

describe("Stash", function()
	it("stashes a placed creature and refuses when the inventory is full", function()
		local d = fresh()
		add(d, "1", "Chick", 1)
		for i = 1, economy.storage.slots do
			add(d, tostring(100 + i), "Chick", nil)
		end
		local ok, why = Tower.takeBack(d, "1", economy)
		expect(ok).toBe(false)
		expect(why).toContain("inventory is full")
		expect((find(d, "1") :: any).slot).toBe(1)
		table.remove(d.creatures, #d.creatures)
		expect((Tower.takeBack(d, "1", economy))).toBe(true)
		expect((find(d, "1") :: any).slot).toBeNil()
	end)
end)

describe("Merge through the server", function()
	local function setup()
		local h = Harness.new()
		local owner = Fakes.player(1)
		local raider = Fakes.player(2)
		h.join(owner)
		h.join(raider)
		h.data:update(owner, function(d)
			d.creatures = {}
			for i = 1, 4 do
				table.insert(d.creatures, {
					uid = tostring(i),
					speciesId = "Chick",
					mutation = "None",
					slot = i,
					eggId = "BasicEgg",
					hatchedAt = i,
				})
			end
			d.nextUid = 5
		end)
		h.clock.advance(raidsConfig.newPlayerProtectionSeconds + 1)
		return h, owner, raider
	end

	it("merges, tells the player, and pays the new rate from then on", function()
		local h, owner = setup()
		local noPerks = { doubleCoins = false, extraIncubators = false }
		local before = Hatchery.incomePerSecond(h.get(owner), config, noPerks)
		expect((h.actions:merge(owner, "1"))).toBe(true)
		expect(h.lastNotice(owner)).toBe("Merged 3 into one 2-star Chick!")
		local d = h.get(owner)
		expect(#d.creatures).toBe(2)
		local after = Hatchery.incomePerSecond(d, config, noPerks)
		-- 4 Chicks on floor 1 earned 4x; now one 2-star (x1.5) and one plain.
		expect(after).toBeCloseTo(before * 2.5 / 4, 1e-6)
		expect((h.actions:mergeAll(owner))).toBe(false)
	end)

	it("a creature being carried cannot be merged, stashed or moved", function()
		local h, owner, raider = setup()
		assert(h.raids:enter(raider, owner))
		assert(h.raids:steal(raider, 1, 2))
		expect((h.actions:merge(owner, "1"))).toBe(false)
		expect((h.actions:takeBack(owner, "1"))).toBe(false)
		expect((h.actions:place(owner, "1", 1))).toBe(false)
		-- The other three still merge, leaving the carried one alone.
		expect((h.actions:merge(owner, "2"))).toBe(true)
		expect(find(h.get(owner), "1")).toBeTruthy()
	end)

	it("merged creatures cannot be stolen (until Egg Heist)", function()
		local h, owner, raider = setup()
		assert(h.actions:merge(owner, "4"))
		local kept = find(h.get(owner), "4")
		assert(kept, "the merge kept a copy")
		expect(kept.stars).toBe(2)
		assert(h.raids:enter(raider, owner))
		local ok, why = h.raids:steal(raider, kept.slot, 2)
		expect(ok).toBe(false)
		expect(why).toBe("Merged creatures cannot be stolen.")
	end)

	it("Place puts a stashed creature on the highest floor with room", function()
		local h, owner = setup()
		assert(h.actions:takeBack(owner, "2"))
		expect((find(h.get(owner), "2") :: any).slot).toBeNil()
		assert(h.actions:placeAuto(owner, "2"))
		expect((find(h.get(owner), "2") :: any).slot).toBeTruthy()
		expect(h.lastNotice(owner)).toBe("Placed on floor 1.")
	end)
end)

describe("Creatures window list", function()
	local InventoryList = require("../src/shared/InventoryList")

	local function sample(): { [string]: any }
		local d = fresh()
		add(d, "1", "Chick", 1)
		add(d, "2", "Chick", nil)
		add(d, "3", "Chick", nil)
		add(d, "4", "Penguin", 2, 2)
		add(d, "5", "Duckling", nil)
		return d
	end

	local function uidsOf(list: { any }): string
		local out = {}
		for _, e in list do
			table.insert(out, e.creature.uid)
		end
		return table.concat(out, ",")
	end

	it("filters by tier, placed, stashed, can merge and search", function()
		local d = sample()
		local chick = creatures.species.Chick.rarity
		expect(#InventoryList.build(d, config, {})).toBe(5)
		for _, e in InventoryList.build(d, config, { tier = chick }) do
			expect(e.rarity).toBe(chick)
		end
		expect(uidsOf(InventoryList.build(d, config, { filter = "Placed", sort = "Newest" }))).toBe("4,1")
		expect(#InventoryList.build(d, config, { filter = "Stashed" })).toBe(3)
		expect(uidsOf(InventoryList.build(d, config, { filter = "Merge", sort = "Newest" }))).toBe("3,2,1")
		expect(uidsOf(InventoryList.build(d, config, { search = "  pEnG " }))).toBe("4")
		expect(#InventoryList.build(d, config, { search = "zzz" })).toBe(0)
	end)

	it("sorts best first, newest first or by name", function()
		local d = sample()
		local best = InventoryList.build(d, config, { sort = "Best" })
		for i = 2, #best do
			expect(best[i - 1].income >= best[i].income).toBe(true)
		end
		local names = InventoryList.build(d, config, { sort = "Name" })
		for i = 2, #names do
			expect(names[i - 1].name <= names[i].name).toBe(true)
		end
	end)

	it("counts each tab and puts the best creature on its face", function()
		local d = sample()
		local tabs = InventoryList.tabs(d, config)
		expect(tabs.All.count).toBe(5)
		local penguin = creatures.species.Penguin.rarity
		expect(tabs[penguin].face).toBeTruthy()
		local total = 0
		for key, tab in tabs do
			if key ~= "All" then
				total += tab.count
			end
		end
		expect(total).toBe(5)
	end)
end)
