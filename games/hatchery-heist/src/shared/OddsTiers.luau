--!strict
-- The egg chances screen as plain data (Alex, Nov 12): one square tab per
-- rarity tier, a standout creature on its face, and behind each tab every
-- creature of that tier with its exact chance from the egg. Built from the
-- server's odds display for this player (boosts included), so the screen
-- always shows the numbers the hatch rolls from. Pure, for tests.

export type Row = { id: string, weight: number }

export type Tier = {
	rarity: string,
	weight: number, -- the tier's share of `total`: the sum of its members' weights
	total: number,
	members: { Row }, -- the egg's creatures of this tier, standouts first
	face: string?, -- the creature drawn on the tab
	inEgg: boolean, -- false: no creature of this tier hatches from the egg
}

local OddsTiers = {}

-- Standouts first: highest income, then by id, so the order is the same
-- on every screen.
local function standoutFirst(species: { [string]: any }): (string, string) -> boolean
	return function(a: string, b: string): boolean
		local ia = species[a] and species[a].coinsPerSecond or 0
		local ib = species[b] and species[b].coinsPerSecond or 0
		if ia ~= ib then
			return ia > ib
		end
		return a < b
	end
end

-- The creature on a tier's tab: `faces[rarity]` when it is one of `ids`
-- (or `ids` is empty and it is of that rarity), else the first of `ids`.
local function faceOf(
	rarity: string,
	ids: { string },
	faces: { [string]: string },
	species: { [string]: any }
): string?
	local chosen = faces[rarity]
	if chosen and species[chosen] and species[chosen].rarity == rarity then
		if #ids == 0 or table.find(ids, chosen) then
			return chosen
		end
	end
	return ids[1]
end

-- One tier per rarity that has creatures in the game, most common first.
-- `display` is the server's odds display (rows of id and weight, and the
-- total). A tier the egg cannot hatch is kept, marked not `inEgg`, with
-- the game's own standout of that tier on its face.
function OddsTiers.build(
	display: { rows: { Row }, total: number },
	species: { [string]: any },
	rarities: { string },
	faces: { [string]: string }
): { Tier }
	local byRarity: { [string]: { Row } } = {}
	for _, row in display.rows do
		local s = species[row.id]
		if s then
			local list = byRarity[s.rarity] or {}
			byRarity[s.rarity] = list
			table.insert(list, { id = row.id, weight = row.weight })
		end
	end
	local order = standoutFirst(species)
	local everyByRarity: { [string]: { string } } = {}
	for id, s in species do
		local list = everyByRarity[s.rarity] or {}
		everyByRarity[s.rarity] = list
		table.insert(list, id)
	end
	local out: { Tier } = {}
	for _, rarity in rarities do
		local members: { Row } = byRarity[rarity] or {}
		table.sort(members, function(a: Row, b: Row): boolean
			return order(a.id, b.id)
		end)
		local weight = 0
		local ids: { string } = {}
		for _, m in members do
			weight += m.weight
			table.insert(ids, m.id)
		end
		local inEgg: boolean = weight > 0
		local every: { string } = everyByRarity[rarity] or {}
		if not inEgg and #every == 0 then
			continue -- no creature of this tier in the game: no tab
		end
		if not inEgg then
			table.sort(every, order)
			ids = every
		end
		local none: { Row } = {}
		local tier: Tier = {
			rarity = rarity,
			weight = weight,
			total = display.total,
			members = if inEgg then members else none,
			face = faceOf(rarity, ids, faces, species),
			inEgg = inEgg,
		}
		table.insert(out, tier)
	end
	return out
end

-- The eggs (ids, in `eggs` order) that can hatch a creature of `rarity`:
-- where to look for a tier this egg lacks.
function OddsTiers.eggsWith(eggs: { any }, species: { [string]: any }, rarity: string): { string }
	local out = {}
	for _, egg in eggs do
		for _, outcome in egg.outcomes or {} do
			local s = species[outcome.id]
			if s and s.rarity == rarity and outcome.weight > 0 then
				table.insert(out, egg.id)
				break
			end
		end
	end
	return out
end

-- How many tiles fit a row `width` px wide, and their side in px: as many
-- as fit at `minSide` or more (up to one row for every tier), each no
-- bigger than `maxSide`.
function OddsTiers.grid(
	width: number,
	count: number,
	gap: number,
	minSide: number,
	maxSide: number
): (number, number)
	if count <= 0 then
		return 1, minSide
	end
	local columns = math.clamp(math.floor((width + gap) / (minSide + gap)), 1, count)
	-- Even rows when it wraps (4 + 3, not 6 + 1).
	local rows = math.ceil(count / columns)
	columns = math.ceil(count / rows)
	local side = math.floor((width - gap * (columns - 1)) / columns)
	return columns, math.clamp(side, math.min(minSide, width), maxSide)
end

return OddsTiers
