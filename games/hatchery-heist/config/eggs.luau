--!strict
-- Eggs and their exact odds. An egg rolls a rarity tier first, by the tier
-- weights below, then a creature from that tier in the egg's pool (the
-- creatures listing the pool in config/creatures, by their in-tier weight).
-- So adding a creature to a pool only splits its tier's share, and no other
-- tier's chance ever moves. Weights are whole numbers out of `total`
-- (100,000, so 1 = 0.001%; Moonlit uses 1,000,000 so every Godly fits) and
-- must add up to exactly that.
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
		total = TOTAL,
		pool = "Barnyard",
		tiers = {
			Common = 92000, -- 92%
			Uncommon = 7000, -- 7%
			Rare = 800, -- 1 in 125
			["Ultra Rare"] = 180, -- 1 in 556
			Epic = 18, -- 1 in 5,556
			Legendary = 2, -- 1 in 50,000
		},
	},
	{
		id = "MeadowEgg",
		priceCoins = 2500,
		hatchSeconds = 60,
		total = TOTAL,
		pool = "Meadow",
		tiers = {
			Common = 67000, -- 67%
			Uncommon = 31000, -- 31%
			Rare = 1700, -- 1.7%
			["Ultra Rare"] = 280, -- 1 in 357
			Epic = 17, -- 1 in 5,882
			Legendary = 3, -- 1 in 33,333
		},
	},
	{
		id = "MoonlitEgg",
		priceCoins = 15000,
		hatchSeconds = 120,
		-- Out of 1,000,000, not 100,000: every creature in a tier needs a
		-- whole weight of at least 1, and 19 Godlies hatch from this egg.
		-- Same odds as at 100,000, each weight times 10.
		total = 1000000,
		pool = "Moonlit",
		tiers = {
			Uncommon = 580000, -- 58%
			Rare = 380000, -- 38%
			["Ultra Rare"] = 37000, -- 3.7%
			Epic = 2900, -- 1 in 345
			Legendary = 80, -- 1 in 12,500
			Godly = 20, -- 1 in 50,000 (each of the 19 Godlies about 1 in 1,000,000)
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
