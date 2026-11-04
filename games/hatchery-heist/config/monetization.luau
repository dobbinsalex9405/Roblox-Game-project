--!strict
-- Game passes and developer products. Each item's name, Robux price and
-- description are in `listings` below; the laptop creates the item on Roblox
-- from them and records its id. Ids stay 0 until then; an id of 0 is never
-- prompted and never owned (the Studio test panel can still grant it). Each
-- experience has its own ids: put Staging's and Production's under
-- `environments` below.
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
		CoinPackBig = { id = 0, coins = 80000 },
		CoinPackLarge = { id = 0, coins = 200000 },
		ShieldRefill = { id = 0 },
		InstantHatch = { id = 0 },
		PremiumEgg = { id = 0 },
		LuckBoost = { id = 0 },
	},
	-- Ids in the Staging and Production experiences. A key left out keeps the
	-- id above (0 = not created there yet).
	environments = {
		staging = {
			passes = {
				AutoCollect = 2064038784,
				ExtraIncubators = 2063927014,
				DoubleCoins = 2063914971,
			},
			products = {
				CoinPackSmall = 3726412639,
				ShieldRefill = 3726413289,
				CoinPackMedium = 3726413675,
				CoinPackLarge = 3726413903,
				CoinPackBig = 3728152137,
			},
		},
		production = { passes = {}, products = {} },
	},
	-- Paid odds boosts. While one runs, the odds screen shows the boosted table.
	-- What each item is called, costs and says on Roblox. The laptop creates
	-- the Game Passes and Developer Products from these lines, so `name`
	-- matches the shop's name exactly. Prices follow the studio price ladder
	-- (ops/PRICING.md); `lune run tools/pricing/run` rewrites that file's table
	-- from here, and a test fails if the two disagree.
	listings = {
		passes = {
			DoubleCoins = {
				name = "Double Coins",
				robux = 149,
				description = "Every creature you own earns twice as many coins, forever.",
			},
			ExtraIncubators = {
				name = "Extra Incubators",
				robux = 99,
				description = "Two more incubators, so you can hatch more eggs at once.",
			},
			AutoCollect = {
				name = "Auto-Collect",
				robux = 99,
				description = "Your earnings flow into your coins by themselves. No more trips to the collect pad.",
			},
		},
		products = {
			CoinPackSmall = { name = "5K Coins", robux = 25, description = "5,000 coins, added right away." },
			CoinPackMedium = {
				name = "30K Coins",
				robux = 99,
				description = "30,000 coins, added right away.",
			},
			CoinPackBig = {
				name = "80K Coins",
				robux = 199,
				description = "80,000 coins, added right away.",
			},
			CoinPackLarge = {
				name = "200K Coins",
				robux = 399,
				description = "200,000 coins, added right away. The best value per Robux.",
			},
			ShieldRefill = {
				name = "Shield Refill",
				robux = 49,
				description = "Shields your base for 10 more minutes. Raiders can't get in while it's up.",
			},
			InstantHatch = {
				name = "Instant Hatch",
				robux = 25,
				description = "Finishes hatching an egg right now.",
			},
			PremiumEgg = {
				name = "Premium Egg",
				robux = 49,
				description = "One Premium Egg, with a chance at a Dragonling or Phoenix. Exact odds are shown before you buy.",
			},
			LuckBoost = {
				name = "Luck Boost",
				robux = 49,
				description = "Better odds of Rare, Epic and Legendary hatches for 15 minutes. The boosted odds are shown.",
			},
		},
	},
	boosts = {
		LuckBoost = {
			durationSeconds = 900,
			-- Multiplier per rarity on the eggs listed.
			eggs = { "BasicEgg", "MeadowEgg", "PremiumEgg" },
			rarityMultipliers = { Rare = 1.5, Epic = 2, Legendary = 2 },
		},
	},
}
