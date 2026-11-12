--!strict
-- Turns egg config into odds tables, and luck boosts into odds multipliers.
-- Pure functions: used by the server at start-up and by the tests.

local Eggs = {}

-- Rarity tiers, most common first. An egg's outcomes are listed in this order.
Eggs.RARITIES = { "Common", "Uncommon", "Rare", "Ultra Rare", "Epic", "Legendary", "Godly" }

-- The pool that holds every creature in an egg pool, whatever its pools
-- (the Giant Egg: every Epic, Legendary and Godly), so a new creature joins
-- it without listing it.
Eggs.ALL = "All"

-- Whether creature `s` is in `pool`.
function Eggs.inPool(s: any, pool: string): boolean
	if type(s.pools) ~= "table" then
		return false
	end
	return pool == Eggs.ALL and #s.pools > 0 or table.find(s.pools, pool) ~= nil
end

-- The creatures of `rarity` in `pool`, sorted by income then id, so the
-- order (and the odds list) is the same everywhere.
function Eggs.members(species: { [string]: any }, pool: string, rarity: string): { string }
	local ids = {}
	for id, s in species do
		if s.rarity == rarity and Eggs.inPool(s, pool) then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		local ia, ib = species[a].coinsPerSecond, species[b].coinsPerSecond
		if ia ~= ib then
			return ia < ib
		end
		return a < b
	end)
	return ids
end

-- Splits a tier's whole weight between its members by their in-tier weights
-- (1 when left out), largest remainder first, so the parts add up to exactly
-- the tier's weight and the tier's chance is exact whatever the pool size.
-- Ties go to the earlier member. Every member gets at least 1 (Config.spec
-- checks a tier's weight is at least its member count).
function Eggs.split(weight: number, ids: { string }, species: { [string]: any }): { number }
	local sum = 0
	for _, id in ids do
		sum += species[id].weight or 1
	end
	local parts = {}
	local given = 0
	local remainders = {}
	for i, id in ids do
		local exact = weight * (species[id].weight or 1) / sum
		parts[i] = math.max(1, math.floor(exact))
		given += parts[i]
		table.insert(remainders, { i = i, r = exact - math.floor(exact) })
	end
	table.sort(remainders, function(a, b)
		if a.r ~= b.r then
			return a.r > b.r
		end
		return a.i < b.i
	end)
	local k = 1
	while given < weight and #remainders > 0 do
		local i = remainders[(k - 1) % #remainders + 1].i
		parts[i] += 1
		given += 1
		k += 1
	end
	return parts
end

-- Each egg with its `outcomes`: one whole weight per creature, rolled from
-- the egg's tier weights and its pool's members. The server, the client and
-- the tests all read eggs through this, so they always agree.
function Eggs.expand(eggs: { any }, species: { [string]: any }): { any }
	local out = {}
	for _, egg in eggs do
		local copy = table.clone(egg)
		if egg.tiers then
			local outcomes = {}
			for _, rarity in Eggs.RARITIES do
				local weight = egg.tiers[rarity]
				if weight then
					local ids = Eggs.members(species, egg.pool, rarity)
					local parts = Eggs.split(weight, ids, species)
					for i, id in ids do
						table.insert(outcomes, { id = id, weight = parts[i] })
					end
				end
			end
			copy.outcomes = outcomes
		end
		table.insert(out, copy)
	end
	return out
end

export type OddsTable = {
	id: string,
	paid: boolean,
	outcomes: { { id: string, weight: number } },
	total: number?,
}

-- Every Hatchery Heist egg is a paid random item: Premium Egg costs Robux, and
-- coin eggs cost coins that players can buy with Robux (coin packs). The
-- policy covers both (brief, Part 7), so every egg table is marked paid and
-- every hatch goes through Odds.rollPaid and its policy check.
function Eggs.isPaid(egg: any, sellsCurrency: boolean): boolean
	return egg.productKey ~= nil or sellsCurrency
end

function Eggs.oddsTables(eggs: { any }, sellsCurrency: boolean): { OddsTable }
	local tables = {}
	for _, egg in eggs do
		local outcomes = {}
		for _, outcome in egg.outcomes do
			table.insert(outcomes, { id = outcome.id, weight = outcome.weight })
		end
		table.insert(
			tables,
			{ id = egg.id, paid = Eggs.isPaid(egg, sellsCurrency), total = egg.total, outcomes = outcomes }
		)
	end
	return tables
end

-- The multipliers a boost applies to one egg, keyed by species id.
function Eggs.boostMultipliers(egg: any, boost: any, species: { [string]: any }): { [string]: number }
	local multipliers = {}
	for _, outcome in egg.outcomes do
		local rarity = species[outcome.id].rarity
		local m = boost.rarityMultipliers[rarity]
		if m and m ~= 1 then
			multipliers[outcome.id] = m
		end
	end
	return multipliers
end

return Eggs
