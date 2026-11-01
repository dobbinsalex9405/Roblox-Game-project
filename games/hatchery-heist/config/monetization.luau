--!strict
-- Game passes and developer products. Ids stay 0 until the item is created on
-- Roblox (at M5, after Alex approves prices); an id of 0 is never prompted and
-- never owned (the Studio test panel can still grant it). Robux prices live on
-- Roblox, not here. Each experience has its own ids: put Staging's and
-- Production's under `environments` below.
-- No permanent raid immunity is ever sold (brief, Part 3).
return {
	passes = {
		DoubleCoins = 0,
		ExtraIncubators = 0,
		AutoCollect = 0,
	},
	products = {
		CoinPackSmall = { id = 0, coins = 5000 },
		CoinPackMedium = { id = 0, coins = 30000 },
		CoinPackLarge = { id = 0, coins = 200000 },
		ShieldRefill = { id = 0 },
		InstantHatch = { id = 0 },
		PremiumEgg = { id = 0 },
		LuckBoost = { id = 0 },
	},
	-- Ids in the Staging and Production experiences. A key left out keeps the
	-- id above (0 = not created there yet).
	environments = {
		staging = { passes = {}, products = {} },
		production = { passes = {}, products = {} },
	},
	-- Paid odds boosts. While one runs, the odds screen shows the boosted table.
	boosts = {
		LuckBoost = {
			durationSeconds = 900,
			-- Multiplier per rarity on the eggs listed.
			eggs = { "BasicEgg", "MeadowEgg", "PremiumEgg" },
			rarityMultipliers = { Rare = 1.5, Epic = 2, Legendary = 2 },
		},
	},
}
