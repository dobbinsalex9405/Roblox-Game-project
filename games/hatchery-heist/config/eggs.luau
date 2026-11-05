--!strict
-- Eggs and their exact odds. Weights are whole numbers out of `total`
-- (100,000 here, so 1 = 0.001%, one in 100,000) and must add up to exactly
-- that; the odds screen shows them as-is, as a percentage and as "1 in N".
-- Every egg here is a paid random item: Premium Egg costs Robux, and coin
-- eggs cost coins that coin packs sell for Robux. So every egg shows its odds
-- before purchase and is policy-checked on every hatch (src/shared/Eggs.luau).
type Egg = {
	id: string,
	priceCoins: number?, -- bought with coins...
	productKey: string?, -- ...or with Robux (a key in monetization.products)
	hatchSeconds: number,
	total: number,
	outcomes: { { id: string, weight: number } },
}

local TOTAL = 100000

local eggs: { Egg } = {
	{
		id = "BasicEgg",
		priceCoins = 50,
		hatchSeconds = 10,
		total = TOTAL,
		outcomes = {
			{ id = "Chick", weight = 26000 }, -- Common 92%
			{ id = "Duckling", weight = 22000 },
			{ id = "Bunny", weight = 16000 },
			{ id = "Piglet", weight = 12000 },
			{ id = "Mouse", weight = 9000 },
			{ id = "Hamster", weight = 7000 },
			{ id = "Gosling", weight = 4500 }, -- Uncommon 7%
			{ id = "Turtle", weight = 2500 },
			{ id = "Raccoon", weight = 800 }, -- Rare, 1 in 125
			{ id = "EmberFox", weight = 180 }, -- Ultra Rare, 1 in 556
			{ id = "Dragonling", weight = 18 }, -- Epic, 1 in 5,556
			{ id = "Phoenix", weight = 2 }, -- Legendary, 1 in 50,000
		},
	},
	{
		id = "MeadowEgg",
		priceCoins = 2500,
		hatchSeconds = 60,
		total = TOTAL,
		outcomes = {
			{ id = "Frog", weight = 22000 }, -- Common 67%
			{ id = "Snail", weight = 18000 },
			{ id = "Lamb", weight = 15000 },
			{ id = "Ladybug", weight = 12000 },
			{ id = "FoxKit", weight = 12000 }, -- Uncommon 31%
			{ id = "Hedgehog", weight = 9000 },
			{ id = "Squirrel", weight = 6000 },
			{ id = "Puppy", weight = 4000 },
			{ id = "Penguin", weight = 1200 }, -- Rare 1.7%
			{ id = "Owlet", weight = 500 },
			{ id = "FrostWolf", weight = 220 }, -- Ultra Rare, 1 in 455
			{ id = "Axolotl", weight = 60 },
			{ id = "CrystalStag", weight = 17 }, -- Epic, 1 in 5,882
			{ id = "ThunderGriffin", weight = 3 }, -- Legendary, 1 in 33,333
		},
	},
	{
		id = "MoonlitEgg",
		priceCoins = 15000,
		hatchSeconds = 120,
		total = TOTAL,
		outcomes = {
			{ id = "Kitten", weight = 40000 }, -- Uncommon 58%
			{ id = "Puppy", weight = 18000 },
			{ id = "Fennec", weight = 20000 }, -- Rare 38%
			{ id = "PandaCub", weight = 12000 },
			{ id = "Owlet", weight = 6000 },
			{ id = "StormHawk", weight = 2500 }, -- Ultra Rare 3.7%
			{ id = "Axolotl", weight = 1200 },
			{ id = "MoonUnicorn", weight = 250 }, -- Epic, 1 in 400
			{ id = "Dragonling", weight = 40 },
			{ id = "Phoenix", weight = 8 }, -- Legendary, 1 in 12,500
			{ id = "NebulaSerpent", weight = 2 }, -- Godly, 1 in 50,000
		},
	},
	{
		id = "PremiumEgg",
		productKey = "PremiumEgg",
		hatchSeconds = 30,
		total = TOTAL,
		outcomes = {
			{ id = "PandaCub", weight = 40000 }, -- Rare 65%
			{ id = "Fennec", weight = 25000 },
			{ id = "StormHawk", weight = 18000 }, -- Ultra Rare 28%
			{ id = "FrostWolf", weight = 10000 },
			{ id = "Dragonling", weight = 5000 }, -- Epic 6.5%
			{ id = "CrystalStag", weight = 1500 },
			{ id = "Phoenix", weight = 350 }, -- Legendary, 1 in 286
			{ id = "ThunderGriffin", weight = 140 },
			{ id = "GoldenGoose", weight = 10 }, -- Godly, 1 in 10,000
		},
	},
}

return eggs
