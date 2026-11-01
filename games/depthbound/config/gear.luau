--!strict
-- Pick, pack and lamp upgrade tiers, bought with coins at camp. Tier 1 of
-- each is what a new player starts with (cost 0). Costs must not decrease.
return {
	-- power: damage per swing. tier: compared with a layer's minPickTier.
	pick = {
		{ name = "Rusty Pick", power = 1, cost = 0 },
		{ name = "Iron Pick", power = 2, cost = 150 },
		{ name = "Steel Pick", power = 4, cost = 900 },
		{ name = "Cobalt Pick", power = 7, cost = 4000 },
		{ name = "Ember Pick", power = 12, cost = 30000 },
	},
	-- capacity: pieces of ore the pack holds.
	pack = {
		{ name = "Satchel", capacity = 15, cost = 0 },
		{ name = "Rucksack", capacity = 30, cost = 100 },
		{ name = "Miner's Pack", capacity = 50, cost = 600 },
		{ name = "Hauler's Frame", capacity = 80, cost = 2500 },
		{ name = "Deep Pack", capacity = 120, cost = 18000 },
	},
	-- oilSeconds: oil a full lamp holds, in seconds of burning at 1 oil per second.
	lamp = {
		{ name = "Candle Lamp", oilSeconds = 60, cost = 0 },
		{ name = "Oil Lantern", oilSeconds = 90, cost = 120 },
		{ name = "Brass Lantern", oilSeconds = 130, cost = 700 },
		{ name = "Miner's Lamp", oilSeconds = 180, cost = 3000 },
		{ name = "Carbide Lamp", oilSeconds = 240, cost = 22000 },
	},
	-- What the passes add on top of the player's tier.
	passes = {
		biggerPackSlots = 25, -- Bigger Pack pass
		betterLampMultiplier = 1.5, -- Better Lamp pass
	},
}
