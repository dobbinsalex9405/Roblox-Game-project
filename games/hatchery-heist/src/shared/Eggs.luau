--!strict
-- Turns egg config into odds tables, and luck boosts into odds multipliers.
-- Pure functions: used by the server at start-up and by the tests.

local Eggs = {}

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
