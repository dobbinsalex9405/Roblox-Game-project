--!strict
-- The tower (Alex, Nov 5): 10 floors of 8 slots, only placed creatures earn,
-- each floor up adds up to +0.25 once fully upgraded, rarer creatures take
-- more slots, and Place best fills the top floors with the best earners.
local Geometry = require("../src/shared/Geometry")
local DataTemplate = require("../src/shared/DataTemplate")
local Hatchery = require("../src/shared/Hatchery")
local Tower = require("../src/shared/Tower")
local Util = require("@core/Util")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local economy = require("../config/economy")
local creatures = require("../config/creatures")
local config = { economy = economy, creatures = creatures }
local NO_PERKS = { doubleCoins = false, extraIncubators = false }

local function ledger(d: { [string]: any })
	local l = {}
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
	local d = Util.deepCopy(DataTemplate.template)
	d.creatures = {}
	return d
end

local function add(d: any, uid: string, speciesId: string, slot: number?): any
	local c = { uid = uid, speciesId = speciesId, mutation = "None", slot = slot }
	table.insert(d.creatures, c)
	return c
end

local function income(c: any): number
	return Hatchery.creatureIncome(c, creatures)
end

describe("Tower floors", function()
	it("gives each floor its bonus: x1 on the ground, +0.05 when bought, +0.25 fully upgraded", function()
		local d = fresh()
		expect(Tower.multiplier(d, 1, economy)).toBe(1)
		expect(Tower.multiplier(d, 2, economy)).toBeCloseTo(1.05, 1e-9)
		d.floorUpgrades = { 0, 4 }
		expect(Tower.multiplier(d, 2, economy)).toBeCloseTo(1.25, 1e-9)
		expect(Tower.fullMultiplier(10, economy)).toBeCloseTo(3.25, 1e-9)
		-- A new floor starts just above the full floor below it.
		for floor = 3, 10 do
			expect(Tower.multiplier(fresh(), floor, economy)).toBeCloseTo(
				Tower.fullMultiplier(floor - 1, economy) + 0.05,
				1e-9
			)
		end
	end)

	it("sells floors in order, each dearer than the one below, and four upgrades each", function()
		local d = fresh()
		d.coins = 10 ^ 12
		local prices = {}
		for _ = 2, 10 do
			table.insert(prices, Tower.nextFloorPrice(d, economy))
			expect((Tower.buyFloor(d, ledger(d), economy))).toBe(true)
		end
		expect(prices[1]).toBe(20000)
		expect(prices[9]).toBe(475000000)
		-- Steep early, gentler late (economy proposal, Nov 7; retuned Nov 12): never less
		-- than x2.5 nor more than x6 the floor below.
		for i = 2, 9 do
			expect(prices[i] / prices[i - 1]).toBeAtLeast(2.5)
			expect(prices[i] / prices[i - 1]).toBeAtMost(6)
		end
		expect(Tower.owned(d)).toBe(10)
		expect(Tower.nextFloorPrice(d, economy)).toBeNil()
		expect((Tower.buyFloor(d, ledger(d), economy))).toBe(false)
		-- Floor 2's upgrades: 20, 35, 50 and 75% of 20,000.
		local upgrades = {}
		for _ = 1, 4 do
			table.insert(upgrades, Tower.nextUpgradePrice(d, 2, economy))
			expect((Tower.upgradeFloor(d, ledger(d), 2, economy))).toBe(true)
		end
		expect(upgrades).toEqual({ 4000, 7000, 10000, 15000 })
		expect((Tower.upgradeFloor(d, ledger(d), 2, economy))).toBe(false)
		expect((Tower.upgradeFloor(d, ledger(d), 1, economy))).toBe(false)
		-- Saved as a list with no gaps.
		expect(#d.floorUpgrades).toBe(2)
	end)

	it("upgrades every floor from 2 to 10, in any order, four times each", function()
		-- The Studio gate on #91 could not upgrade floors 5 to 10: prove the
		-- rules do (the cost is the only thing that grows: about 443M coins).
		local d = fresh()
		d.coins = 10 ^ 12
		for _ = 2, 10 do
			expect((Tower.buyFloor(d, ledger(d), economy))).toBe(true)
		end
		expect(Tower.owned(d)).toBe(10)
		local spent = d.coins
		for _, floor in { 10, 5, 7, 2, 9, 3, 6, 8, 4 } do
			for _ = 1, 4 do
				local ok, why = Tower.upgradeFloor(d, ledger(d), floor, economy)
				expect(if ok then floor else `floor {floor}: {why}`).toBe(floor)
			end
			expect((Tower.upgradeFloor(d, ledger(d), floor, economy))).toBe(false)
		end
		for floor = 2, 10 do
			expect(Tower.upgrades(d, floor)).toBe(4)
		end
		expect(#d.floorUpgrades).toBe(10)
		-- 1.8 x the price of floors 2 to 10
		local total = 0
		for _, p in economy.tower.floorPrices do
			total += p
		end
		expect(spent - d.coins).toBe(math.floor(total * 1.8 + 0.5))
	end)

	it("redraws the Tower menu only when a button changes, not on every coin", function()
		-- Bug: the menu redrew whenever coins crossed a thousand, so with a big
		-- income an Upgrade button was rebuilt between press and release and
		-- the click was lost (Studio gate, floors 5 to 10).
		local d = fresh()
		d.coins = 10 ^ 9
		for _ = 2, 10 do
			Tower.buyFloor(d, ledger(d), economy)
		end
		d.coins = 1000
		local before = Tower.menuKey(d, economy)
		d.coins = 3999 -- still short of the cheapest upgrade (floor 2: 4,000)
		expect(Tower.menuKey(d, economy)).toBe(before)
		d.coins = 4000 -- floor 2's Upgrade turns green
		expect(Tower.menuKey(d, economy) ~= before).toBe(true)
		local green = Tower.menuKey(d, economy)
		d.coins = 6000
		expect(Tower.menuKey(d, economy)).toBe(green)
		-- buying changes it too
		Tower.upgradeFloor(d, ledger(d), 2, economy)
		expect(Tower.menuKey(d, economy) ~= green).toBe(true)
	end)

	it("refuses a floor the player cannot afford and leaves coins alone", function()
		local d = fresh()
		d.coins = 19999
		local ok, why = Tower.buyFloor(d, ledger(d), economy)
		expect(ok).toBe(false)
		expect(why).toBe("Not enough coins.")
		expect(d.coins).toBe(19999)
		expect(Tower.owned(d)).toBe(1)
	end)
end)

describe("Tower slots", function()
	it("lets rarer creatures take 2 or 3 slots side by side in one row", function()
		local d = fresh()
		-- Floor 1's front row: a Common in slot 2 leaves no 3-wide gap there.
		add(d, "1", "Chick", 2)
		local used = Tower.occupancy(d, creatures, economy)
		expect(Tower.freeSpot(used, 1, 3)).toBe(5)
		expect(Tower.freeSpot(used, 1, 2)).toBe(3)
		expect(Tower.freeSpot(used, 1, 1)).toBe(1)
		local phoenix = add(d, "2", "Phoenix", nil)
		expect(Tower.size(phoenix, creatures, economy)).toBe(3)
		expect(Tower.autoPlace(d, phoenix, creatures, economy)).toBe(true)
		expect(phoenix.slot).toBe(5)
		-- Slots 5 to 7 are taken; slot 8 is free but a second Phoenix has no room.
		local other = add(d, "3", "Phoenix", nil)
		expect(Tower.autoPlace(d, other, creatures, economy)).toBe(false)
		expect(Tower.full(d, creatures, economy)).toBe(false)
	end)

	it("earns only from placed creatures, each times its floor's bonus", function()
		local d = fresh()
		d.floors = 2
		add(d, "1", "Chick", 1)
		add(d, "2", "Chick", 9) -- floor 2
		add(d, "3", "Phoenix", nil) -- inventory
		local chick = creatures.species.Chick.coinsPerSecond
		local expected = (chick + chick * 1.05) * (1 + Hatchery.bookBonus(d, config))
		expect(Hatchery.incomePerSecond(d, config, NO_PERKS)).toBeCloseTo(expected, 1e-9)
		expect(Hatchery.earning(d, d.creatures[3], config, NO_PERKS)).toBe(0)
	end)

	it("moves creatures between floors and the inventory", function()
		local d = fresh()
		d.floors = 2
		add(d, "1", "Chick", 1)
		expect((Tower.place(d, "1", 2, creatures, economy))).toBe(true)
		expect(d.creatures[1].slot).toBe(9)
		expect((Tower.place(d, "1", 3, creatures, economy))).toBe(false) -- not built
		expect((Tower.takeBack(d, "1"))).toBe(true)
		expect(d.creatures[1].slot).toBeNil()
		d.mountUid = "1"
		expect((Tower.place(d, "1", 1, creatures, economy))).toBe(false)
		d.mountUid = ""
		-- A full floor refuses, and the creature stays where it was.
		for i = 2, 9 do
			add(d, tostring(i), "Chick", 8 + i - 1)
		end
		local ok, why = Tower.place(d, "1", 2, creatures, economy)
		expect(ok).toBe(false)
		expect(why).toBe("Floor 2 has no room for it.")
		expect(d.creatures[1].slot).toBeNil()
	end)

	it("Place best puts the best earners per slot on the highest floors", function()
		local d = fresh()
		d.floors = 2
		for i = 1, 14 do
			add(d, tostring(i), "Chick", nil)
		end
		add(d, "15", "Penguin", nil)
		add(d, "16", "Phoenix", 1)
		add(d, "17", "Owlet", nil)
		d.mountUid = "17"
		d.creatures[17].slot = 4
		local placed = Tower.placeBest(d, creatures, economy, income)
		-- The ridden Owlet keeps its slot; 16 slots minus its 1 hold the rest.
		expect(d.creatures[17].slot).toBe(4)
		expect(Tower.floorOf(d.creatures[16].slot :: number)).toBe(2) -- Phoenix up top
		expect(Tower.floorOf(d.creatures[15].slot :: number)).toBe(2) -- then the Penguin
		local used = Tower.occupancy(d, creatures, economy)
		local filled = 0
		for _ in used do
			filled += 1
		end
		expect(filled).toBe(16)
		expect(placed).toBe(14) -- Owlet, Phoenix, Penguin and 11 Chicks
	end)

	it("tidies saves with creatures off the built floors or on top of each other", function()
		local d = fresh()
		add(d, "1", "Chick", 1)
		add(d, "2", "Chick", 1) -- on top of the first
		add(d, "3", "Chick", 12) -- floor 2, not built
		add(d, "4", "Phoenix", 3) -- would run past the end of the row
		d.guardUid = "3"
		Tower.tidy(d, creatures, economy)
		expect(d.creatures[1].slot).toBe(1)
		expect(d.creatures[2].slot).toBeNil()
		expect(d.creatures[3].slot).toBeNil()
		expect(d.creatures[4].slot).toBeNil()
		expect(d.guardUid).toBe("")
	end)
end)

describe("Tower reach", function()
	it("measures a big creature from the middle of its pads", function()
		local x1, z1 = Geometry.pad(1)
		local x, z, height = Geometry.padCentre(1, 1)
		expect(x).toBe(x1)
		expect(z).toBe(z1)
		expect(height).toBe(0)
		-- A Legendary on pads 9 to 11 (floor 2) stands over pad 10, the middle one.
		local x10, z10 = Geometry.pad(10)
		local cx, cz, ch = Geometry.padCentre(9, 3)
		expect(cx).toBe(x10)
		expect(cz).toBe(z10)
		expect(ch).toBe(Geometry.FLOOR_HEIGHT)
	end)

	it("lets a raider take a creature only from the floor it stands on", function()
		local standing = 3 -- a standing R15 root above the deck it is on
		-- Pad 1 is on floor 1, pad 9 on floor 2 (12 studs up).
		expect(Geometry.onFloorOfPad(1, standing)).toBe(true)
		expect(Geometry.onFloorOfPad(9, standing)).toBe(false) -- under floor 2
		expect(Geometry.onFloorOfPad(9, Geometry.FLOOR_HEIGHT + standing)).toBe(true)
		expect(Geometry.onFloorOfPad(1, Geometry.FLOOR_HEIGHT + standing)).toBe(false) -- floor 2, looking down
		expect(Geometry.onFloorOfPad(80, 9 * Geometry.FLOOR_HEIGHT + standing)).toBe(true)
		expect(Geometry.onFloorOfPad(80, 8 * Geometry.FLOOR_HEIGHT + standing)).toBe(false)
	end)
end)

describe("Tower ladder", function()
	-- Studio gate, Nov 5: climbing from the tower side, the character stuck
	-- under the floor-2 deck because the decks ran right up to the ladder.
	it("leaves an opening in the decks beside the ladder a character fits through", function()
		local lx, lz = Geometry.LADDER[1], Geometry.LADDER[2]
		local lo, hi = Geometry.LADDER_HOLE_MIN, Geometry.LADDER_HOLE_MAX
		local truss = 2 -- studs
		local body = 2 -- an R15 character's width, studs
		-- The opening reaches the decks' edge right next to the ladder ...
		expect(hi[1]).toBe(Geometry.TOWER_MAX[1])
		expect(lx - truss / 2 - hi[1] < 0.5).toBe(true)
		-- ... and is deep and wide enough for a body on the ladder's tower side.
		expect(hi[1] - lo[1] >= body + 0.5).toBe(true)
		expect(lo[2] <= lz - truss / 2 - 0.5 and hi[2] >= lz + truss / 2 + 0.5).toBe(true)
	end)

	it("keeps the opening clear of every spot's pad and wander area", function()
		local lo, hi = Geometry.LADDER_HOLE_MIN, Geometry.LADDER_HOLE_MAX
		for spot = 1, Geometry.SPOTS_PER_FLOOR do
			local x, z = Geometry.pad(spot)
			-- a spot is 10 by 10 studs around its pad
			local apart = x + 5 <= lo[1] or x - 5 >= hi[1] or z + 5 <= lo[2] or z - 5 >= hi[2]
			expect(apart and "clear" or `spot {spot} overlaps the ladder opening`).toBe("clear")
		end
	end)
end)

describe("Next-floor label", function()
	-- Studio gate (#84): "Floor 2: 25K coins" filled 166 px of its 168 px
	-- box. Since #184 the label is plaque-sized (12 studs, so it reads whole
	-- from the side), so the text shrinks to fit the width: it must still be
	-- at least as tall as the longest floor name's on the plaque above it,
	-- and no shorter than 0.8 studs.
	it("fits every floor's price at a readable text height", function()
		local CHAR = 0.62 -- GothamBold's average character width, in text heights
		local box = Geometry.FLOOR_LABEL
		local plaque = Geometry.FLOOR_PLAQUE
		local longestName = 0
		for floor = 1, Tower.FLOORS do
			longestName = math.max(longestName, #Tower.plaqueText({}, floor, economy))
		end
		local nameHeight = math.min(plaque.height, plaque.width / (longestName * CHAR))
		for floor = 2, Tower.FLOORS do
			local label = Tower.floorLabel(floor, economy.tower.floorPrices[floor - 1])
			local height = math.min(box.height, box.width / (#label * CHAR * 1.1))
			local ok = height >= 0.8 and height >= nameHeight
			expect(ok and "fits" or `"{label}" shows {height} studs tall`).toBe("fits")
		end
		expect(Tower.floorLabel(10, 165e6)).toBe("Floor 10: 165M coins")
		-- ... and is no wider than the tower.
		expect(box.width <= Geometry.TOWER_MAX[1] - Geometry.TOWER_MIN[1]).toBe(true)
	end)

	it("stays clear of the YOUR HATCHERY banner over the base sign", function()
		-- Studio gate (Nov 5): from spawn the floor 2 label and the banner sat
		-- at the same height, one behind the other, and read as one crowded
		-- line. Since issue #183 the label hangs in front of the tower and
		-- the banner stands behind it (the base sign is past the back wall),
		-- so the whole tower is between them; otherwise the banner must float
		-- above the label with a clear gap. Heights in the base's own space.
		local box = Geometry.FLOOR_LABEL
		local banner = Geometry.YOUR_BASE_LABEL
		local signZ = 30 -- Layout.SIGN (needs Vector3, so not required here)
		local apart = Geometry.priceSignZ() < Geometry.TOWER_MIN[2] and signZ > Geometry.TOWER_MAX[2]
		local floor2 = Geometry.FLOOR_TOP + Geometry.FLOOR_HEIGHT -- floor 2's walking height
		local labelTop = floor2 + box.above + box.height / 2
		local bannerBottom = Geometry.SIGN_TOP - 4 + banner.above - banner.height / 2 -- from the 8-stud post's centre
		local clear = apart or bannerBottom - labelTop >= 1.5
		expect(clear and "clear" or `gap {bannerBottom - labelTop}`).toBe("clear")
	end)
end)
