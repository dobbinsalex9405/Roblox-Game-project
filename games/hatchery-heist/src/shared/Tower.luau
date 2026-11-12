--!strict
-- The tower: up to 10 floors, each with 8 slots. Only creatures placed on a
-- floor earn, multiplied by that floor's bonus; everything else waits in the
-- inventory. A placed creature's `slot` is the first pad it stands on,
-- counted across the tower (Geometry.pad: 1 to 8 on floor 1, 9 to 16 on
-- floor 2, ...). Rarer creatures take 2 or 3 slots side by side in one row.
--
-- Pure functions over saved data, like Hatchery: the server runs them inside
-- DataService:update, the client uses them to show the same numbers, and
-- tests check every rule.

local Geometry = require("./Geometry")
local Numbers = require("./Numbers")

export type Data = { [string]: any }

local Tower = {}

Tower.FLOORS = Geometry.FLOORS
Tower.SPOTS = Geometry.SPOTS_PER_FLOOR
local COLUMNS = Geometry.SPOT_COLUMNS

-- The parts of Economy's ledger used here.
type Ledger = {
	spend: (self: any, currency: string, amount: number, reason: string) -> boolean,
}

function Tower.floorOf(slot: number): number
	return (slot - 1) // Tower.SPOTS + 1
end

-- Floors the player owns (1 to 10); floor 1 is free.
function Tower.owned(d: Data): number
	return math.clamp(d.floors or 1, 1, Tower.FLOORS)
end

function Tower.upgrades(d: Data, floor: number): number
	local list = d.floorUpgrades
	return if type(list) == "table" then list[floor] or 0 else 0
end

-- Slots a creature takes on a floor.
function Tower.size(creature: any, creatureConfig: any, economy: any): number
	local species = creatureConfig.species[creature.speciesId]
	if species == nil then
		return 1
	end
	return economy.tower.slotsByRarity[species.rarity] or 1
end

-- A floor's income multiplier: x1 on the ground floor; a bought floor starts
-- `startBonus` above the one below's full value and each upgrade adds
-- `upgradeBonus`.
function Tower.multiplier(d: Data, floor: number, economy: any): number
	if floor <= 1 then
		return 1
	end
	local t = economy.tower
	return 1 + t.floorBonus * (floor - 2) + t.startBonus + t.upgradeBonus * Tower.upgrades(d, floor)
end

-- A built floor's name sign: "2. Book Nook  x1.25" (number, theme and its
-- multiplier now).
function Tower.plaqueText(d: Data, floor: number, economy: any): string
	local m = Tower.multiplier(d, floor, economy)
	return `{floor}. {economy.tower.themes[floor]}  x{string.format("%.2f", m)}`
end

-- The multiplier floor `floor` reaches with every upgrade.
function Tower.fullMultiplier(floor: number, economy: any): number
	if floor <= 1 then
		return 1
	end
	local t = economy.tower
	return 1 + t.floorBonus * (floor - 2) + t.startBonus + t.upgradeBonus * #t.upgradeShares
end

-- Pad index -> uid of the creature standing there (a big creature fills
-- every pad it takes).
function Tower.occupancy(d: Data, creatureConfig: any, economy: any): { [number]: string }
	local used: { [number]: string } = {}
	for _, c in d.creatures do
		if c.slot then
			for i = 0, Tower.size(c, creatureConfig, economy) - 1 do
				used[c.slot + i] = c.uid
			end
		end
	end
	return used
end

-- The first pad on `floor` with `size` free pads side by side in one row,
-- or nil when the floor has no room.
function Tower.freeSpot(used: { [number]: string }, floor: number, size: number): number?
	local first = (floor - 1) * Tower.SPOTS
	for spot = 0, Tower.SPOTS - size do
		if spot % COLUMNS + size <= COLUMNS then
			local free = true
			for i = 0, size - 1 do
				if used[first + spot + i + 1] ~= nil then
					free = false
					break
				end
			end
			if free then
				return first + spot + 1
			end
		end
	end
	return nil
end

local function mark(used: { [number]: string }, slot: number, size: number, uid: string)
	for i = 0, size - 1 do
		used[slot + i] = uid
	end
end

-- Puts a creature from the inventory on the highest owned floor with room
-- for it (new hatches land here). Returns whether it was placed.
function Tower.autoPlace(d: Data, creature: any, creatureConfig: any, economy: any): boolean
	local used = Tower.occupancy(d, creatureConfig, economy)
	local size = Tower.size(creature, creatureConfig, economy)
	for floor = Tower.owned(d), 1, -1 do
		local slot = Tower.freeSpot(used, floor, size)
		if slot then
			creature.slot = slot
			return true
		end
	end
	return false
end

-- Whether a 1-slot creature still fits anywhere.
function Tower.full(d: Data, creatureConfig: any, economy: any): boolean
	local used = Tower.occupancy(d, creatureConfig, economy)
	for floor = 1, Tower.owned(d) do
		if Tower.freeSpot(used, floor, 1) then
			return false
		end
	end
	return true
end

local function byUid(d: Data, uid: string): any?
	for _, c in d.creatures do
		if c.uid == uid then
			return c
		end
	end
	return nil
end

-- Moves one of the player's creatures onto `floor` (from the inventory or
-- another floor).
function Tower.place(
	d: Data,
	uid: string,
	floor: number,
	creatureConfig: any,
	economy: any
): (boolean, string?)
	local creature = byUid(d, uid)
	if creature == nil then
		return false, "You do not own that creature."
	end
	if floor < 1 or floor > Tower.owned(d) then
		return false, "You do not own that floor yet."
	end
	if uid == d.mountUid then
		return false, "Get off it first."
	end
	if creature.slot and Tower.floorOf(creature.slot) == floor then
		return true, nil
	end
	local old = creature.slot
	creature.slot = nil
	local used = Tower.occupancy(d, creatureConfig, economy)
	local slot = Tower.freeSpot(used, floor, Tower.size(creature, creatureConfig, economy))
	if slot == nil then
		creature.slot = old
		return false, `Floor {floor} has no room for it.`
	end
	creature.slot = slot
	return true, nil
end

-- Puts a placed creature back in the inventory.
function Tower.takeBack(d: Data, uid: string): (boolean, string?)
	local creature = byUid(d, uid)
	if creature == nil then
		return false, "You do not own that creature."
	end
	if uid == d.mountUid then
		return false, "Get off it first."
	end
	if uid == d.guardUid then
		return false, "It is guarding your base. Stand it down first."
	end
	creature.slot = nil
	return true, nil
end

-- Income per slot, the order "Place best" fills the tower in.
local function perSlot(c: any, creatureConfig: any, economy: any, income: (any) -> number): number
	return income(c) / Tower.size(c, creatureConfig, economy)
end

-- Place best: every creature but the one being ridden and the guard leaves
-- its floor, then the tower fills from the top floor down with the best
-- earners per slot. Returns how many creatures are placed.
function Tower.placeBest(d: Data, creatureConfig: any, economy: any, income: (any) -> number): number
	local movable = {}
	for _, c in d.creatures do
		if c.uid ~= d.mountUid and c.uid ~= d.guardUid then
			c.slot = nil
			table.insert(movable, c)
		end
	end
	table.sort(movable, function(a: any, b: any): boolean
		local pa, pb =
			perSlot(a, creatureConfig, economy, income), perSlot(b, creatureConfig, economy, income)
		if pa ~= pb then
			return pa > pb
		end
		local ia, ib = income(a), income(b)
		if ia ~= ib then
			return ia > ib
		end
		return a.uid < b.uid
	end)
	local used = Tower.occupancy(d, creatureConfig, economy)
	local placed = 0
	for _, c in d.creatures do
		if c.slot then
			placed += 1
		end
	end
	for floor = Tower.owned(d), 1, -1 do
		for _, c in movable do
			if c.slot == nil then
				local size = Tower.size(c, creatureConfig, economy)
				local slot = Tower.freeSpot(used, floor, size)
				if slot then
					c.slot = slot
					mark(used, slot, size, c.uid)
					placed += 1
				end
			end
		end
	end
	return placed
end

-- Clears what an older save or a config change left behind: creatures on
-- floors the player does not own, outside the tower, or on top of each
-- other go back to the inventory.
function Tower.tidy(d: Data, creatureConfig: any, economy: any)
	local used: { [number]: string } = {}
	local last = Tower.owned(d) * Tower.SPOTS
	for _, c in d.creatures do
		if c.slot then
			local size = Tower.size(c, creatureConfig, economy)
			local slot = c.slot
			local column = (slot - 1) % Tower.SPOTS % COLUMNS
			local ok = slot >= 1 and slot + size - 1 <= last and column + size <= COLUMNS
			for i = 0, size - 1 do
				if used[slot + i] ~= nil then
					ok = false
				end
			end
			if ok then
				mark(used, slot, size, c.uid)
			else
				c.slot = nil
				if c.uid == d.guardUid then
					d.guardUid = ""
				end
			end
		end
	end
end

-- Price of the next floor, or nil when the player has all ten.
function Tower.nextFloorPrice(d: Data, economy: any): number?
	return economy.tower.floorPrices[Tower.owned(d)]
end

function Tower.buyFloor(d: Data, ledger: Ledger, economy: any): (boolean, string?)
	local price = Tower.nextFloorPrice(d, economy)
	if price == nil then
		return false, "Your tower has every floor."
	end
	if not ledger:spend("coins", price, "Shop:TowerFloor") then
		return false, "Not enough coins."
	end
	d.floors = Tower.owned(d) + 1
	return true, nil
end

-- Price of floor `floor`'s next upgrade, or nil when it has them all (or is
-- the ground floor, or not owned).
function Tower.nextUpgradePrice(d: Data, floor: number, economy: any): number?
	if floor < 2 or floor > Tower.owned(d) then
		return nil
	end
	local t = economy.tower
	local share = t.upgradeShares[Tower.upgrades(d, floor) + 1]
	if share == nil then
		return nil
	end
	return math.floor(t.floorPrices[floor - 1] * share + 0.5)
end

-- What the Tower menu shows, as one string: floors built, each floor's
-- upgrades, and which Build / Upgrade buttons the player can afford. The
-- menu redraws only when this changes, so a rising coin count does not
-- rebuild a button while it is being pressed.
function Tower.menuKey(d: Data, economy: any): string
	local owned = Tower.owned(d)
	local coins = d.coins or 0
	local parts = { tostring(owned) }
	for floor = 2, owned do
		local price = Tower.nextUpgradePrice(d, floor, economy)
		table.insert(parts, `{Tower.upgrades(d, floor)}{if price and coins >= price then "+" else ""}`)
	end
	local build = Tower.nextFloorPrice(d, economy)
	table.insert(parts, if build and coins >= build then "B+" else "B")
	return table.concat(parts, ",")
end

function Tower.upgradeFloor(d: Data, ledger: Ledger, floor: number, economy: any): (boolean, string?)
	if floor < 2 or floor > Tower.owned(d) then
		return false, "You can upgrade a floor you own above the ground floor."
	end
	local price = Tower.nextUpgradePrice(d, floor, economy)
	if price == nil then
		return false, "That floor is fully upgraded."
	end
	if not ledger:spend("coins", price, "Shop:FloorUpgrade") then
		return false, "Not enough coins."
	end
	if type(d.floorUpgrades) ~= "table" then
		d.floorUpgrades = {}
	end
	-- Saved as a list: fill any gap below so it stays one.
	for f = 1, floor - 1 do
		d.floorUpgrades[f] = d.floorUpgrades[f] or 0
	end
	d.floorUpgrades[floor] = Tower.upgrades(d, floor) + 1
	return true, nil
end

-- The label over the next floor to buy.
function Tower.floorLabel(floor: number, price: number): string
	return `Floor {floor}: {Numbers.short(price)} coins`
end

return Tower
