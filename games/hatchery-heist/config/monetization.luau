--!strict
-- Game passes and developer products. Ids stay 0 until the item is created on
-- Roblox (at M5, after Alex approves prices); an id of 0 is never offered,
-- never registered and never owned. Robux prices live on Roblox, not here.
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
