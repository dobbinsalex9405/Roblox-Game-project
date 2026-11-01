--!strict
-- Every sea creature, its rarity, what it sells for and how big it can be.
--
-- `value` is the coin price of a Tiny (stage 1) creature of average size.
-- A creature's size is rolled when it is caught, between `minKg` and `maxKg`;
-- the smallest sells for `sizeValue.min` times value, the largest for
-- `sizeValue.max` times. Growth multiplies value again (config/pools.luau).
return {
	species = {
		-- Common
		SandShrimp = { rarity = "Common", value = 4, minKg = 0.1, maxKg = 0.4 },
		TideMinnow = { rarity = "Common", value = 5, minKg = 0.2, maxKg = 0.6 },
		PebbleCrab = { rarity = "Common", value = 6, minKg = 0.3, maxKg = 1.2 },
		BubbleGoby = { rarity = "Common", value = 6, minKg = 0.2, maxKg = 0.8 },
		SeaSnail = { rarity = "Common", value = 5, minKg = 0.1, maxKg = 0.5 },
		MoonJelly = { rarity = "Common", value = 8, minKg = 0.5, maxKg = 2 },
		StripedPerch = { rarity = "Common", value = 9, minKg = 0.8, maxKg = 3 },
		KelpPipefish = { rarity = "Common", value = 10, minKg = 0.2, maxKg = 0.9 },
		-- Uncommon
		HermitCrab = { rarity = "Uncommon", value = 25, minKg = 0.4, maxKg = 1.5 },
		Starfish = { rarity = "Uncommon", value = 28, minKg = 0.3, maxKg = 1.4 },
		Pufferfish = { rarity = "Uncommon", value = 32, minKg = 1, maxKg = 4 },
		Seahorse = { rarity = "Uncommon", value = 35, minKg = 0.1, maxKg = 0.5 },
		BlueTang = { rarity = "Uncommon", value = 38, minKg = 0.5, maxKg = 2 },
		SeaUrchin = { rarity = "Uncommon", value = 30, minKg = 0.3, maxKg = 1.2 },
		Octopus = { rarity = "Uncommon", value = 45, minKg = 3, maxKg = 12 },
		-- Rare
		Lionfish = { rarity = "Rare", value = 120, minKg = 0.8, maxKg = 3 },
		MantaRay = { rarity = "Rare", value = 160, minKg = 20, maxKg = 90 },
		SeaTurtle = { rarity = "Rare", value = 180, minKg = 30, maxKg = 160 },
		MorayEel = { rarity = "Rare", value = 140, minKg = 5, maxKg = 25 },
		Nautilus = { rarity = "Rare", value = 200, minKg = 1, maxKg = 4 },
		-- Epic
		GlowSquid = { rarity = "Epic", value = 750, minKg = 4, maxKg = 18 },
		CoralDragon = { rarity = "Epic", value = 900, minKg = 8, maxKg = 30 },
		GhostShark = { rarity = "Epic", value = 1100, minKg = 60, maxKg = 300 },
		-- Legendary
		PearlWhale = { rarity = "Legendary", value = 4500, minKg = 400, maxKg = 1500 },
		TideLeviathan = { rarity = "Legendary", value = 6000, minKg = 800, maxKg = 3000 },
	},

	-- What size does to value: the smallest possible catch sells for `min`
	-- times value, the largest for `max` times, in a straight line between.
	sizeValue = { min = 0.8, max = 1.25 },

	-- Mutations multiply value. "None" must exist and equal 1. Glow-tide gives
	-- pool creatures a chance of Glowing (milestone M4).
	mutations = {
		None = 1,
		Glowing = 3,
	},
}
