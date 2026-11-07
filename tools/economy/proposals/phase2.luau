--!strict
-- Phase 2 (needs Alex's yes, egg art and game code): Phase 1 plus three new
-- coin eggs that unlock with the tower, sold from an Egg Shop counter as
-- well as the belt. Pools here borrow today's creatures (every creature of a
-- tier the egg rolls) until the roster's own themed pools exist.
local phase1 = require("./phase1")
local TOTAL = 10_000_000

local function tiers(t: { [string]: number }): { [string]: number }
	local out = {}
	for k, v in t do
		out[k] = math.floor(v * TOTAL / 100 + 0.5)
	end
	return out
end

return function(config: any)
	phase1(config)
	local new = {
		{
			id = "CrystalEgg",
			priceCoins = 300000,
			hatchSeconds = 180,
			requiresFloor = 4,
			pool = "Crystal",
			tiers = tiers({
				Rare = 58,
				["Ultra Rare"] = 38.1,
				Epic = 3.8873,
				Legendary = 0.0125,
				Godly = 0.0002,
			}),
		},
		{
			id = "MythicEgg",
			priceCoins = 2500000,
			hatchSeconds = 240,
			requiresFloor = 7,
			pool = "Mythic",
			tiers = tiers({ ["Ultra Rare"] = 64, Epic = 35.8839, Legendary = 0.1111, Godly = 0.005 }),
		},
		{
			id = "CelestialEgg",
			priceCoins = 40000000,
			hatchSeconds = 300,
			requiresFloor = 9,
			pool = "Celestial",
			tiers = tiers({ Epic = 97.4, Legendary = 2.5, Godly = 0.1 }),
		},
	}
	for _, egg in new do
		egg.total = TOTAL
		table.insert(config.eggs, egg)
	end
	local rolls = {
		Crystal = { Rare = true, ["Ultra Rare"] = true, Epic = true, Legendary = true, Godly = true },
		Mythic = { ["Ultra Rare"] = true, Epic = true, Legendary = true, Godly = true },
		Celestial = { Epic = true, Legendary = true, Godly = true },
	}
	for _, s in config.creatures.species do
		for pool, set in rolls do
			if set[s.rarity] then
				table.insert(s.pools, pool)
			end
		end
	end
	config.economy.conveyor.weights.CrystalEgg = 6
	config.economy.conveyor.weights.MythicEgg = 3
	config.economy.conveyor.weights.CelestialEgg = 1
end
