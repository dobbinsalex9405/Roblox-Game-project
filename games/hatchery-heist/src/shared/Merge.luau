--!strict
-- Merging creatures into stars, as pure functions over saved data.
--
-- Every hatch is Star 1. Three copies of one creature at one star (same
-- species, same mutation) merge into one at the next star, which earns more
-- (config/creatures `stars`). A merge costs coins and takes time; while it
-- runs, the copies sit in the Merge Station (`d.merges`) and earn nothing.
-- Cancelling gives the copies and the coins back. Godlies never merge.
--
-- The 25 Robux "Finish now" finishes the running merge that would end
-- soonest. If no merge is running when the purchase lands, it is kept
-- (`d.mergeRushes`) and the next merge started finishes at once, so a
-- purchase always does what it says.
--
-- Like Hatchery.luau: nothing here yields, reads a clock or rolls dice.

local Tower = require("./Tower")

export type Data = { [string]: any }

export type Ledger = {
	add: (self: any, currency: string, amount: number, reason: string) -> number,
	spend: (self: any, currency: string, amount: number, reason: string) -> boolean,
	balance: (self: any, currency: string) -> number,
}

-- A merge in the station: the copies it holds, what it makes and when.
export type Job = {
	id: string,
	speciesId: string,
	mutation: string,
	star: number, -- the star it makes
	copies: { any }, -- the creatures merged, kept whole for a cancel
	cost: number, -- coins paid, refunded on a cancel
	startedAt: number,
	readyAt: number,
}

-- Copies of one creature at one star that the player could merge.
export type Group = {
	speciesId: string,
	mutation: string,
	star: number,
	uids: { string }, -- usable copies, the ones a merge takes first first
	busy: number, -- copies riding or guarding (not usable until freed)
}

local Merge = {}

function Merge.star(creature: any): number
	return creature.star or 1
end

function Merge.maxStar(creatureConfig: any): number
	return #creatureConfig.stars
end

-- Income multiplier for a creature's star.
function Merge.multiplier(creature: any, creatureConfig: any): number
	return creatureConfig.stars[Merge.star(creature)] or 1
end

-- "★★" for Star 2. Star 1 shows nothing unless `always`.
function Merge.stars(star: number, always: boolean?): string
	if star <= 1 and not always then
		return ""
	end
	return string.rep("★", star)
end

-- Whether a creature of this species at `star` can merge into the next star.
function Merge.allowed(speciesId: string, star: number, config: any): (boolean, string?)
	local species = config.creatures.species[speciesId]
	if species == nil then
		return false, "unknown creature"
	end
	if table.find(config.economy.merge.excluded, species.rarity) then
		return false, `{species.rarity} creatures can't merge.`
	end
	if star >= Merge.maxStar(config.creatures) then
		return false, "That creature is already at the top star."
	end
	return true, nil
end

-- Coins a merge into `target` costs: minutes of the creature's Star 1 income.
function Merge.cost(speciesId: string, mutation: string, target: number, config: any): number
	local species = config.creatures.species[speciesId]
	local minutes = config.economy.merge.costMinutes[target - 1] or 0
	local base = species.coinsPerSecond * (config.creatures.mutations[mutation] or 1)
	return math.max(1, math.floor(base * 60 * minutes))
end

-- Seconds a merge into `target` takes.
function Merge.seconds(speciesId: string, target: number, config: any): number
	local merge = config.economy.merge
	local rarity = config.creatures.species[speciesId].rarity
	return math.floor((merge.secondsByRarity[rarity] or 60) * merge.timeFactor ^ (target - 2))
end

-- Merges that can run at once.
function Merge.slotCount(d: Data, economy: any): number
	return economy.merge.freeSlots + (d.mergeSlotsBought or 0)
end

function Merge.nextSlotCost(d: Data, economy: any): number?
	return economy.merge.slotCosts[(d.mergeSlotsBought or 0) + 1]
end

function Merge.buySlot(d: Data, ledger: Ledger, economy: any): (boolean, string?)
	local cost = Merge.nextSlotCost(d, economy)
	if cost == nil then
		return false, "Every merge slot is unlocked."
	end
	if not ledger:spend("coins", cost, "Shop:MergeSlot") then
		return false, "Not enough coins."
	end
	d.mergeSlotsBought = (d.mergeSlotsBought or 0) + 1
	return true, nil
end

local function key(speciesId: string, mutation: string, star: number): string
	return `{speciesId}|{mutation}|{star}`
end

-- Every creature the player could merge, grouped. Within a group the copies
-- a merge would take come first: the inventory, then the lowest floors
-- (they earn the least there). Ready groups (enough copies) come first,
-- then the strongest.
function Merge.groups(d: Data, config: any): { Group }
	local byKey: { [string]: Group } = {}
	local list: { Group } = {}
	local order: { [string]: number } = {}
	for _, c in d.creatures do
		local star = Merge.star(c)
		if not Merge.allowed(c.speciesId, star, config) then
			continue
		end
		local k = key(c.speciesId, c.mutation, star)
		local group = byKey[k]
		if group == nil then
			group = { speciesId = c.speciesId, mutation = c.mutation, star = star, uids = {}, busy = 0 }
			byKey[k] = group
			table.insert(list, group)
		end
		if c.uid == d.mountUid or c.uid == d.guardUid then
			group.busy += 1
		else
			table.insert(group.uids, c.uid)
			-- 0 for the inventory, else the floor
			order[c.uid] = if c.slot then Tower.floorOf(c.slot) else 0
		end
	end
	local copies = config.economy.merge.copies
	local function income(g: Group): number
		local species = config.creatures.species[g.speciesId]
		return species.coinsPerSecond
			* (config.creatures.mutations[g.mutation] or 1)
			* (config.creatures.stars[g.star] or 1)
	end
	for _, g in list do
		table.sort(g.uids, function(a: string, b: string): boolean
			if order[a] ~= order[b] then
				return order[a] < order[b]
			end
			return (tonumber(a) or 0) < (tonumber(b) or 0)
		end)
	end
	table.sort(list, function(a: Group, b: Group): boolean
		local readyA, readyB = #a.uids >= copies, #b.uids >= copies
		if readyA ~= readyB then
			return readyA
		end
		if income(a) ~= income(b) then
			return income(a) > income(b)
		end
		return key(a.speciesId, a.mutation, a.star) < key(b.speciesId, b.mutation, b.star)
	end)
	return list
end

function Merge.jobById(d: Data, id: string): (Job?, number?)
	for index, job in d.merges or {} do
		if job.id == id then
			return job, index
		end
	end
	return nil, nil
end

-- Starts merging `copies` of a creature at `star` into the next star.
-- Takes the copies Merge.groups lists first. Returns the job, or nil and a
-- refusal.
function Merge.start(
	d: Data,
	ledger: Ledger,
	speciesId: string,
	mutation: string,
	star: number,
	now: number,
	config: any
): (Job?, string?)
	local ok, refusal = Merge.allowed(speciesId, star, config)
	if not ok then
		return nil, refusal
	end
	d.merges = d.merges or {}
	if #d.merges >= Merge.slotCount(d, config.economy) then
		return nil, "The Merge Station is busy. Wait for a merge or unlock another slot."
	end
	local copies = config.economy.merge.copies
	local group: Group? = nil
	for _, g in Merge.groups(d, config) do
		if g.speciesId == speciesId and g.mutation == mutation and g.star == star then
			group = g
		end
	end
	if group == nil or #group.uids < copies then
		local have = if group then #group.uids else 0
		return nil, `You need {copies} to merge (you have {have} free).`
	end
	local target = star + 1
	local cost = Merge.cost(speciesId, mutation, target, config)
	if not ledger:spend("coins", cost, "Gameplay:Merge") then
		return nil, "Not enough coins."
	end
	local taking: { [string]: boolean } = {}
	for i = 1, copies do
		taking[group.uids[i]] = true
	end
	local taken = {}
	for index = #d.creatures, 1, -1 do
		local c = d.creatures[index]
		if taking[c.uid] then
			table.remove(d.creatures, index)
			c.slot = nil
			table.insert(taken, 1, c)
		end
	end
	local readyAt = now + Merge.seconds(speciesId, target, config)
	if (d.mergeRushes or 0) > 0 then
		d.mergeRushes -= 1
		readyAt = now
	end
	local job: Job = {
		id = tostring(d.nextUid),
		speciesId = speciesId,
		mutation = mutation,
		star = target,
		copies = taken,
		cost = cost,
		startedAt = now,
		readyAt = readyAt,
	}
	d.nextUid += 1
	table.insert(d.merges, job)
	return job, nil
end

-- Stops a merge: its copies go back to the inventory and its coins back to
-- the wallet.
function Merge.cancel(d: Data, ledger: Ledger, id: string): (Job?, string?)
	local job, index = Merge.jobById(d, id)
	if job == nil or index == nil then
		return nil, "That merge has already finished."
	end
	table.remove(d.merges, index)
	for _, c in job.copies do
		c.slot = nil
		table.insert(d.creatures, c)
	end
	ledger:add("coins", job.cost, "Gameplay:MergeCancel")
	return job, nil
end

-- Finishes every merge that is ready at `now`: each becomes one creature at
-- its new star, placed like a hatch. Returns the new creatures.
function Merge.finish(d: Data, now: number, config: any): { any }
	local made = {}
	local jobs = d.merges or {}
	for index = 1, #jobs do
		local job = jobs[index]
		if job.readyAt > now then
			continue
		end
		local first = job.copies[1] or {}
		local creature = {
			uid = tostring(d.nextUid),
			speciesId = job.speciesId,
			mutation = job.mutation,
			star = job.star,
			slot = nil :: number?,
			eggId = first.eggId,
			hatchedAt = now,
		}
		d.nextUid += 1
		Tower.autoPlace(d, creature, config.creatures, config.economy)
		table.insert(d.creatures, creature)
		table.insert(made, creature)
	end
	if #made > 0 then
		local running = {}
		for _, job in jobs do
			if job.readyAt > now then
				table.insert(running, job)
			end
		end
		d.merges = running
	end
	return made
end

-- "Finish now": the running merge that ends soonest is ready at `now`.
-- With none running, the finish is kept for the next merge. Returns the job
-- finished, or nil when it was kept.
function Merge.rush(d: Data, now: number): Job?
	local soonest: Job? = nil
	for _, job in d.merges or {} do
		if job.readyAt > now and (soonest == nil or job.readyAt < soonest.readyAt) then
			soonest = job
		end
	end
	if soonest == nil then
		d.mergeRushes = (d.mergeRushes or 0) + 1
		return nil
	end
	soonest.readyAt = now
	return soonest
end

-- The highest star the player has of each species right now (the Book).
function Merge.bestStars(d: Data): { [string]: number }
	local best: { [string]: number } = {}
	for _, c in d.creatures do
		best[c.speciesId] = math.max(best[c.speciesId] or 0, Merge.star(c))
	end
	for _, job in d.merges or {} do
		for _, c in job.copies do
			best[c.speciesId] = math.max(best[c.speciesId] or 0, Merge.star(c))
		end
	end
	return best
end

return Merge
