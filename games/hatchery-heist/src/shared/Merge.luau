--!strict
-- The creature merger (Alex, Nov 12): `copies` (3) of one creature with the
-- same mutation and the same stars become one creature with a star more, up
-- to `maxStars` (5). Each star past the first adds `bonusPerStar` (+50%) to
-- its income, so a 5-star earns x3 (economy.merge). Merging is free.
--
-- Placed and stashed copies merge together. The copy that stays keeps its
-- uid and its place: the one on the highest floor, else the one the player
-- picked. The other copies leave the save; the last few are kept in
-- `mergeArchive` so support can restore them. The creature being ridden, the
-- guard and any creature a raider is carrying never merge.
--
-- Pure functions over saved data, like Tower: the server runs them inside
-- DataService:update, the client uses them to show the same choices, and
-- tests check every rule.

local Tower = require("./Tower")

export type Data = { [string]: any }

local Merge = {}

-- Merged-away copies kept for support, newest last.
Merge.ARCHIVE = 100

-- A creature's stars, 1 for every creature from before the merger.
function Merge.stars(creature: any): number
	local s = creature.stars
	if type(s) ~= "number" or s < 1 then
		return 1
	end
	return math.floor(s)
end

-- Income multiplier from stars: 1 + bonusPerStar * (stars - 1).
function Merge.multiplier(creature: any, economy: any): number
	return 1 + economy.merge.bonusPerStar * (Merge.stars(creature) - 1)
end

-- Creatures that merge together share species, mutation and stars.
function Merge.key(creature: any): string
	return `{creature.speciesId}|{creature.mutation or "None"}|{Merge.stars(creature)}`
end

-- Why `creature` cannot take part in a merge right now, or nil.
function Merge.blocked(d: Data, creature: any, economy: any, carried: { [string]: boolean }?): string?
	if creature.uid == d.mountUid then
		return "Get off it first."
	end
	if creature.uid == d.guardUid then
		return "It is guarding your base. Stand it down first."
	end
	if carried and carried[creature.uid] then
		return "A raider is carrying it!"
	end
	if Merge.stars(creature) >= economy.merge.maxStars then
		return "It already has the most stars."
	end
	return nil
end

-- Floor a creature stands on, 0 in the inventory (for picking who stays).
local function floorOf(creature: any): number
	return if creature.slot then Tower.floorOf(creature.slot) else 0
end

-- Every creature that could merge with `creature` (itself included), in the
-- order they are used: stashed first, then the lowest floors, so merging
-- empties as few good spots as possible.
local function matches(d: Data, creature: any, economy: any, carried: { [string]: boolean }?): { any }
	local key = Merge.key(creature)
	local list = {}
	for _, c in d.creatures do
		if c ~= creature and Merge.key(c) == key and Merge.blocked(d, c, economy, carried) == nil then
			table.insert(list, c)
		end
	end
	table.sort(list, function(a: any, b: any): boolean
		local fa, fb = floorOf(a), floorOf(b)
		if fa ~= fb then
			return fa < fb
		end
		local ha, hb = a.hatchedAt or 0, b.hatchedAt or 0
		if ha ~= hb then
			return ha < hb
		end
		return a.uid < b.uid
	end)
	return list
end

-- How many copies (itself included) are ready to merge with `creature`.
function Merge.count(d: Data, creature: any, economy: any, carried: { [string]: boolean }?): number
	if Merge.blocked(d, creature, economy, carried) then
		return 0
	end
	return #matches(d, creature, economy, carried) + 1
end

-- uid -> true for every creature that has enough copies to merge now.
function Merge.ready(d: Data, economy: any, carried: { [string]: boolean }?): { [string]: boolean }
	local groups: { [string]: { any } } = {}
	for _, c in d.creatures do
		if Merge.blocked(d, c, economy, carried) == nil then
			local key = Merge.key(c)
			local g = groups[key]
			if g == nil then
				g = {}
				groups[key] = g
			end
			table.insert(g, c)
		end
	end
	local ready: { [string]: boolean } = {}
	for _, g in groups do
		if #g >= economy.merge.copies then
			for _, c in g do
				ready[c.uid] = true
			end
		end
	end
	return ready
end

-- Keeps creatures that left the save (merged away or sold) in
-- `mergeArchive`, the last ARCHIVE of them, for support.
function Merge.keep(d: Data, gone: { any }, into: string, now: number)
	if type(d.mergeArchive) ~= "table" then
		d.mergeArchive = {}
	end
	for _, c in gone do
		table.insert(d.mergeArchive, { creature = c, into = into, at = now })
	end
	while #d.mergeArchive > Merge.ARCHIVE do
		table.remove(d.mergeArchive, 1)
	end
end

-- Merges `uid` with copies-1 matching creatures. Returns the creature that
-- stays (now a star higher), or nil and a refusal, plus the copies used up.
function Merge.merge(
	d: Data,
	uid: string,
	economy: any,
	now: number,
	carried: { [string]: boolean }?
): (any?, string?, { any })
	local creature: any = nil
	for _, c in d.creatures do
		if c.uid == uid then
			creature = c
		end
	end
	if creature == nil then
		return nil, "You do not own that creature.", {}
	end
	local refusal = Merge.blocked(d, creature, economy, carried)
	if refusal then
		return nil, refusal, {}
	end
	local need = economy.merge.copies
	local others = matches(d, creature, economy, carried)
	if #others + 1 < need then
		return nil, `You need {need} of these with the same stars to merge ({#others + 1} now).`, {}
	end
	local group = { creature }
	for i = 1, need - 1 do
		table.insert(group, others[i])
	end
	-- The copy on the highest floor stays (the picked one wins a tie).
	local keep = creature
	for _, c in group do
		if floorOf(c) > floorOf(keep) then
			keep = c
		end
	end
	local gone = {}
	local leaving: { [any]: boolean } = {}
	for _, c in group do
		if c ~= keep then
			leaving[c] = true
			table.insert(gone, c)
		end
	end
	for i = #d.creatures, 1, -1 do
		if leaving[d.creatures[i]] then
			table.remove(d.creatures, i)
		end
	end
	keep.stars = Merge.stars(keep) + 1
	Merge.keep(d, gone, keep.uid, now)
	return keep, nil, gone
end

-- Merges every group it can, fewest stars first so new stars can merge
-- again. Returns how many merges were made and the copies used up.
function Merge.mergeAll(
	d: Data,
	economy: any,
	now: number,
	carried: { [string]: boolean }?
): (number, { any })
	local merges = 0
	local gone = {}
	for _ = 1, #d.creatures do
		local ready = Merge.ready(d, economy, carried)
		local pick: any = nil
		for _, c in d.creatures do
			if ready[c.uid] then
				local better = pick == nil
					or Merge.stars(c) < Merge.stars(pick)
					or (Merge.stars(c) == Merge.stars(pick) and Merge.key(c) < Merge.key(pick))
				if better then
					pick = c
				end
			end
		end
		if pick == nil then
			break
		end
		local kept, _, used = Merge.merge(d, pick.uid, economy, now, carried)
		if kept == nil then
			break
		end
		merges += 1
		for _, c in used do
			table.insert(gone, c)
		end
	end
	return merges, gone
end

return Merge
