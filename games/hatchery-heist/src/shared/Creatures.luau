--!strict
-- Income math for hatched creatures. Pure, so it is unit-tested and the
-- server and client agree on the numbers shown.

export type Creature = { uid: string, speciesId: string, mutation: string, slot: number? }

local Creatures = {}

-- Income multiplier from rebirths and the Double Coins pass.
function Creatures.multiplier(rebirths: number, hasDoubleCoins: boolean, economy: any): number
	local m = 1 + rebirths * economy.rebirth.incomeBonusPerRebirth
	if hasDoubleCoins then
		m *= economy.doubleCoinsMultiplier
	end
	return m
end

-- Coins per second from creatures placed on the base (slot ~= nil), before multipliers.
function Creatures.baseIncome(creatures: { Creature }, creatureConfig: any): number
	local total = 0
	for _, creature in creatures do
		if creature.slot ~= nil then
			local species = creatureConfig.species[creature.speciesId]
			local mutation = creatureConfig.mutations[creature.mutation] or 1
			if species then
				total += species.coinsPerSecond * mutation
			end
		end
	end
	return total
end

-- Whole coins earned over `seconds`, never fractional so the economy stays integer.
function Creatures.earned(perSecond: number, seconds: number): number
	return math.floor(perSecond * math.max(0, seconds))
end

-- Coins for time offline: a fraction of normal income, capped.
function Creatures.offlineEarnings(perSecond: number, secondsAway: number, economy: any): number
	local seconds = math.min(math.max(0, secondsAway), economy.offline.maxSeconds)
	return math.floor(perSecond * seconds * economy.offline.rate)
end

function Creatures.rebirthCost(rebirths: number, economy: any): number
	return math.floor(economy.rebirth.baseCost * economy.rebirth.costGrowth ^ rebirths)
end

return Creatures
