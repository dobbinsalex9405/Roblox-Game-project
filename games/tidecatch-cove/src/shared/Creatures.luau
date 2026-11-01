--!strict
-- What a sea creature is worth and how far it has grown. Pure, so it is
-- unit-tested and the server and client agree on every number shown.

export type Creature = {
	uid: string,
	speciesId: string,
	kg: number,
	mutation: string,
}

-- A creature in a pool. Growth runs from `placedAt` by the clock, plus `fed`
-- seconds from feeding.
export type Pooled = Creature & {
	slot: number,
	placedAt: number,
	fed: number,
	lastFedAt: number,
}

local Creatures = {}

-- Value multiplier from size: `sizeValue.min` for the smallest possible catch
-- of a species, `sizeValue.max` for the largest.
function Creatures.sizeFactor(kg: number, speciesDef: any, sizeValue: any): number
	local span = speciesDef.maxKg - speciesDef.minKg
	local t = if span > 0 then math.clamp((kg - speciesDef.minKg) / span, 0, 1) else 0.5
	return sizeValue.min + (sizeValue.max - sizeValue.min) * t
end

-- Whole coins a creature sells for at growth `stage` (1 = Tiny, as caught).
-- Never less than 1.
function Creatures.value(creature: Creature, stage: number, speciesConfig: any, pools: any): number
	local def = speciesConfig.species[creature.speciesId]
	if def == nil then
		return 0
	end
	local stageDef = pools.stages[math.clamp(stage, 1, #pools.stages)]
	local mutation = speciesConfig.mutations[creature.mutation] or 1
	local size = Creatures.sizeFactor(creature.kg, def, speciesConfig.sizeValue)
	return math.max(1, math.floor(def.value * stageDef.valueMultiplier * size * mutation))
end

-- Seconds of growth from Tiny to the last stage for a rarity.
function Creatures.growthSeconds(rarity: string, pools: any): number
	return pools.stageSeconds[rarity] * (#pools.stages - 1)
end

-- Seconds a pooled creature has grown by `now` (online time; a capped
-- absence is folded into `placedAt` on rejoin), at most the full growth.
function Creatures.grown(pooled: Pooled, now: number, rarity: string, pools: any): number
	local total = Creatures.growthSeconds(rarity, pools)
	return math.min(total, math.max(0, now - pooled.placedAt) + pooled.fed)
end

-- Growth stage for `grown` seconds of growth: 1 (Tiny) to #stages (Giant).
function Creatures.stageFor(grown: number, rarity: string, pools: any): number
	local per = pools.stageSeconds[rarity]
	return math.clamp(1 + grown // per, 1, #pools.stages)
end

function Creatures.stage(pooled: Pooled, now: number, speciesConfig: any, pools: any): number
	local def = speciesConfig.species[pooled.speciesId]
	if def == nil then
		return 1
	end
	return Creatures.stageFor(Creatures.grown(pooled, now, def.rarity, pools), def.rarity, pools)
end

-- Seconds until the next stage, or nil when fully grown.
function Creatures.nextStageIn(pooled: Pooled, now: number, speciesConfig: any, pools: any): number?
	local def = speciesConfig.species[pooled.speciesId]
	if def == nil then
		return nil
	end
	local grown = Creatures.grown(pooled, now, def.rarity, pools)
	local stage = Creatures.stageFor(grown, def.rarity, pools)
	if stage >= #pools.stages then
		return nil
	end
	return stage * pools.stageSeconds[def.rarity] - grown
end

-- "0.35 kg", "12.4 kg", "1,250 kg".
function Creatures.formatKg(kg: number): string
	if kg < 10 then
		return string.format("%.2f kg", kg)
	elseif kg < 1000 then
		return string.format("%.1f kg", kg)
	end
	local whole = tostring(math.floor(kg + 0.5))
	local withCommas = string.reverse((string.gsub(string.reverse(whole), "(%d%d%d)", "%1,")))
	if string.sub(withCommas, 1, 1) == "," then
		withCommas = string.sub(withCommas, 2)
	end
	return withCommas .. " kg"
end

return Creatures
