--!strict
-- Eggs and their exact odds. An egg rolls a rarity tier first, by the tier
-- weights below, then a creature from that tier in the egg's pool (the
-- creatures listing the pool in config/creatures, by their in-tier weight).
-- Every egg's pool is "All": each egg can hatch every creature of the tiers
-- it rolls (Alex, Nov 12), and eggs differ only by their tier odds.
-- So adding a creature to a pool only splits its tier's share, and no other
-- tier's chance ever moves. Weights are whole numbers out of `total`
-- and must add up to exactly that (a power of ten, so the odds screen's
-- percentages are exact and add up to 100%).
-- Every creature in a tier gets the same whole weight, so every odds card in
-- a tier reads the same, and above an egg's likeliest creature a rarer
-- creature is always less likely: the tier weights are written by
-- tools/economy/even_eggs.py from its target odds and the pools' member
-- counts. Rerun it whenever a pool changes (CI and Eggs.spec fail until you
-- do). Hatchery's fixed order is lazy, so totals up to 10,000,000 are fine.
-- src/shared/Eggs.expand turns tiers into each creature's whole weight
-- (largest remainder inside each tier, so every tier stays exact); the odds
-- screen shows the result as-is, as a percentage and as "1 in N".
-- Every egg here is a paid random item: Premium Egg costs Robux, and coin
-- eggs cost coins that coin packs sell for Robux. So every egg shows its odds
-- before purchase and is policy-checked on every hatch (src/shared/Eggs.luau).
type Egg = {
	id: string,
	priceCoins: number?, -- bought with coins...
	productKey: string?, -- ...or with Robux (a key in monetization.products)
	hatchSeconds: number,
	total: number,
	pool: string,
	tiers: { [string]: number },
}

local eggs: { Egg } = {
	{
		id = "BasicEgg",
		priceCoins = 50,
		hatchSeconds = 10,
		total = 10000000,
		pool = "All",
		tiers = {
			Common = 9193999, -- 91.94% (199 x 46,201)
			Uncommon = 726142, -- 7.26142% (97 x 7,486)
			Rare = 70020, -- 1 in 143 (60 x 1,167)
			["Ultra Rare"] = 9017, -- 1 in 1,109 (71 x 127)
			Epic = 780, -- 1 in 12,821 (60 x 13)
			Legendary = 22, -- 1 in 454,545 (2 x 11)
			Godly = 20, -- 1 in 500,000 (20 x 1)
		},
	},
	{
		id = "MeadowEgg",
		priceCoins = 1500,
		hatchSeconds = 30,
		total = 10000000,
		pool = "All",
		tiers = {
			Common = 5806024, -- 58.0602% (199 x 29,176)
			Uncommon = 3694342, -- 36.9434% (97 x 38,086)
			Rare = 450000, -- 4.5% (60 x 7,500)
			["Ultra Rare"] = 45014, -- 1 in 222 (71 x 634)
			Epic = 4500, -- 1 in 2,222 (60 x 75)
			Legendary = 100, -- 1 in 100,000 (2 x 50)
			Godly = 20, -- 1 in 500,000 (20 x 1)
		},
	},
	{
		id = "MoonlitEgg",
		priceCoins = 20000,
		hatchSeconds = 120,
		-- Every Godly here is exactly 1 in 2,000,000, however many there are.
		total = 10000000,
		pool = "All",
		tiers = {
			Common = 199000, -- 1.99% (199 x 1,000)
			Uncommon = 6461461, -- 64.6146% (97 x 66,613)
			Rare = 3000000, -- 30% (60 x 50,000)
			["Ultra Rare"] = 319997, -- 3.19997% (71 x 4,507)
			Epic = 19020, -- 1 in 526 (60 x 317)
			Legendary = 422, -- 1 in 23,697 (2 x 211)
			Godly = 100, -- 1 in 100,000 (20 x 5)
		},
	},
	{
		id = "PremiumEgg",
		productKey = "PremiumEgg",
		hatchSeconds = 30,
		total = 1000000,
		pool = "All",
		tiers = {
			Rare = 655440, -- 65.544% (60 x 10,924)
			["Ultra Rare"] = 278036, -- 27.8036% (71 x 3,916)
			Epic = 64980, -- 6.498% (60 x 1,083)
			Legendary = 1444, -- 1 in 693 (2 x 722)
			Godly = 100, -- 1 in 10,000 (20 x 5)
		},
	},
}

return eggs
