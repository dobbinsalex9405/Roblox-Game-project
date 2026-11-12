--!strict
-- Eggs and their exact odds. An egg rolls a rarity tier first, by the tier
-- weights below, then a creature from that tier in the egg's pool (the
-- creatures listing the pool in config/creatures, by their in-tier weight).
-- So adding a creature to a pool only splits its tier's share, and no other
-- tier's chance ever moves. Weights are whole numbers out of `total`
-- and must add up to exactly that (a power of ten, so the odds screen's
-- percentages are exact and add up to 100%).
-- Every creature in a tier gets the same whole weight, so every odds card in
-- a tier reads the same: the coin eggs' tier weights are written by
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

local TOTAL = 100000

local eggs: { Egg } = {
	{
		id = "BasicEgg",
		priceCoins = 50,
		hatchSeconds = 10,
		total = 1000000,
		pool = "Barnyard",
		tiers = {
			Common = 920018, -- 92.0018% (71 x 12,958)
			Uncommon = 69996, -- 6.9996% (19 x 3,684)
			Rare = 7986, -- 1 in 125 (1 x 7,986)
			["Ultra Rare"] = 1800, -- 1 in 556 (1 x 1,800)
			Epic = 180, -- 1 in 5,556 (1 x 180)
			Legendary = 20, -- 1 in 50,000 (1 x 20)
		},
	},
	{
		id = "MeadowEgg",
		priceCoins = 2500,
		hatchSeconds = 60,
		total = 1000000,
		pool = "Meadow",
		tiers = {
			Common = 669696, -- 66.9696% (128 x 5,232)
			Uncommon = 310323, -- 31.0323% (73 x 4,251)
			Rare = 16988, -- 1.6988% (62 x 274)
			["Ultra Rare"] = 2795, -- 1 in 358 (13 x 215)
			Epic = 168, -- 1 in 5,952 (6 x 28)
			Legendary = 30, -- 1 in 33,333 (1 x 30)
		},
	},
	{
		id = "MoonlitEgg",
		priceCoins = 15000,
		hatchSeconds = 120,
		-- Every Godly here is exactly 1 in 1,000,000, however many there are.
		total = 10000000,
		pool = "Moonlit",
		tiers = {
			Uncommon = 5799996, -- 58% (6 x 966,666)
			Rare = 3800000, -- 38% (38 x 100,000)
			["Ultra Rare"] = 370016, -- 3.70016% (62 x 5,968)
			Epic = 28998, -- 1 in 345 (54 x 537)
			Legendary = 800, -- 1 in 12,500 (1 x 800)
			Godly = 190, -- 1 in 52,632 (19 x 10)
		},
	},
	{
		id = "PremiumEgg",
		productKey = "PremiumEgg",
		hatchSeconds = 30,
		total = TOTAL,
		pool = "Premium",
		tiers = {
			Rare = 65000, -- 65%
			["Ultra Rare"] = 28000, -- 28%
			Epic = 6500, -- 6.5%
			Legendary = 490, -- 1 in 204
			Godly = 10, -- 1 in 10,000
		},
	},
}

return eggs
