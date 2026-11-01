--!strict
-- Eggs and their exact odds. Weights are whole numbers out of 10,000
-- (1 = 0.01%) and must total exactly 10,000; the odds screen shows them as-is.
-- Every egg here is a paid random item: Premium Egg costs Robux, and coin
-- eggs cost coins that coin packs sell for Robux. So every egg shows its odds
-- before purchase and is policy-checked on every hatch (src/shared/Eggs.luau).
return {
	{
		id = "BasicEgg",
		priceCoins = 50,
		hatchSeconds = 15,
		outcomes = {
			{ id = "Chick", weight = 6000 },
			{ id = "Duckling", weight = 3000 },
			{ id = "Gosling", weight = 800 },
			{ id = "Turtle", weight = 200 },
		},
	},
	{
		id = "MeadowEgg",
		priceCoins = 2500,
		hatchSeconds = 60,
		outcomes = {
			{ id = "Gosling", weight = 5000 },
			{ id = "Turtle", weight = 3500 },
			{ id = "Penguin", weight = 1200 },
			{ id = "Owlet", weight = 300 },
		},
	},
	{
		id = "PremiumEgg",
		productKey = "PremiumEgg",
		hatchSeconds = 30,
		outcomes = {
			{ id = "Penguin", weight = 6000 },
			{ id = "Owlet", weight = 3000 },
			{ id = "Dragonling", weight = 900 },
			{ id = "Phoenix", weight = 100 },
		},
	},
}
