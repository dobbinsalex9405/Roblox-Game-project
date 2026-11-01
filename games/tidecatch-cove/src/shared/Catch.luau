--!strict
-- Turns fishing config into odds tables: one table per spot and bait, so the
-- odds board for "Reef with Krill" and the roll for a Krill cast at the Reef
-- read the same numbers. The player's rod is applied on top as an odds boost
-- (core Odds setBoosts), so the board updates the moment a better rod is bought.
-- Pure functions: used by the server at start-up, the client and the tests.

export type Outcome = { id: string, weight: number }

export type OddsTable = {
	id: string,
	paid: boolean,
	outcomes: { Outcome },
}

-- Odds.normalize from the core, passed in because the core loads from
-- different places in Roblox and in Lune.
export type Normalize = (raw: { Outcome }) -> { Outcome }

local Catch = {}

-- The bait id for a cast with no bait.
Catch.NO_BAIT = "None"

-- "SandShrimp" -> "Sand Shrimp", "ReefRod" -> "Reef Rod": how every id
-- (species, spots, bait, rods) is shown to players.
function Catch.displayName(id: string): string
	return (string.gsub(id, "(%l)(%u)", "%1 %2"))
end

function Catch.tableId(spotId: string, baitId: string): string
	return `{spotId}_{baitId}`
end

function Catch.spot(fishing: any, spotId: string): any?
	for _, spot in fishing.spots do
		if spot.id == spotId then
			return spot
		end
	end
	return nil
end

function Catch.bait(fishing: any, baitId: string): any?
	for _, bait in fishing.bait do
		if bait.id == baitId then
			return bait
		end
	end
	return nil
end

-- The rod at `tier`, clamped to the tiers that exist.
function Catch.rod(fishing: any, tier: number): any
	local rods = fishing.rods
	return rods[math.clamp(tier, 1, #rods)]
end

-- A cast is a paid random roll when its bait is sold for Robux, or when the
-- game sells coins for Robux (then coin-bought bait counts too, brief Part 7).
-- A cast with no bait is always free.
function Catch.isPaid(bait: any?, sellsCurrency: boolean): boolean
	if bait == nil then
		return false
	end
	return bait.robux == true or sellsCurrency
end

-- Multipliers keyed by species id for the species in `outcomes`, from a
-- rarity -> multiplier map. Species whose multiplier is 1 are left out.
function Catch.speciesMultipliers(
	outcomes: { Outcome },
	byRarity: { [string]: number },
	species: { [string]: any }
): { [string]: number }
	local out = {}
	for _, o in outcomes do
		local m = byRarity[species[o.id].rarity]
		if m and m ~= 1 then
			out[o.id] = m
		end
	end
	return out
end

-- One odds table per spot (no bait) and per spot and bait.
function Catch.oddsTables(
	fishing: any,
	species: { [string]: any },
	normalize: Normalize,
	sellsCurrency: boolean
): { OddsTable }
	local tables = {}
	for _, spot in fishing.spots do
		local base: { Outcome } = {}
		for _, o in spot.outcomes do
			table.insert(base, { id = o.id, weight = o.weight })
		end
		table.insert(tables, { id = Catch.tableId(spot.id, Catch.NO_BAIT), paid = false, outcomes = base })
		for _, bait in fishing.bait do
			local multipliers = Catch.speciesMultipliers(base, bait.rarityMultipliers, species)
			local raw: { Outcome } = {}
			for _, o in base do
				table.insert(raw, { id = o.id, weight = o.weight * (multipliers[o.id] or 1) })
			end
			table.insert(tables, {
				id = Catch.tableId(spot.id, bait.id),
				paid = Catch.isPaid(bait, sellsCurrency),
				outcomes = normalize(raw),
			})
		end
	end
	return tables
end

Catch.MYSTERY_TABLE = "MysteryBait"

-- The Mystery Bait product's odds table: a paid random item.
function Catch.mysteryTable(monetization: any): OddsTable
	local outcomes: { Outcome } = {}
	for _, o in monetization.mysteryBait do
		table.insert(outcomes, { id = o.id, weight = o.weight })
	end
	return { id = Catch.MYSTERY_TABLE, paid = true, outcomes = outcomes }
end

-- The Mystery Bait outcome with this id.
function Catch.mysteryOutcome(monetization: any, outcomeId: string): any?
	for _, o in monetization.mysteryBait do
		if o.id == outcomeId then
			return o
		end
	end
	return nil
end

-- The odds boost a rod puts on one table, or nil when the rod changes nothing.
function Catch.rodBoost(rod: any, outcomes: { Outcome }, species: { [string]: any }): any?
	local multipliers = Catch.speciesMultipliers(outcomes, rod.luck, species)
	if next(multipliers) == nil then
		return nil
	end
	return { id = rod.id, multipliers = multipliers }
end

-- A size in kilograms from `r` in [0, 1), rounded to 0.01 kg.
function Catch.rollKg(speciesDef: any, r: number): number
	local kg = speciesDef.minKg + (speciesDef.maxKg - speciesDef.minKg) * math.clamp(r, 0, 1)
	return math.clamp(math.round(kg * 100) / 100, speciesDef.minKg, speciesDef.maxKg)
end

return Catch
