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
			Common = 919947, -- 91.9947% (71 x 12,957)
			Uncommon = 72048, -- 7.2048% (19 x 3,792)
			Rare = 7005, -- 1 in 143 (1 x 7,005)
			["Ultra Rare"] = 900, -- 1 in 1,111 (1 x 900)
			Epic = 80, -- 1 in 12,500 (1 x 80)
			Legendary = 20, -- 1 in 50,000 (1 x 20)
		},
	},
	{
		id = "MeadowEgg",
		priceCoins = 1500,
		hatchSeconds = 30,
		total = 1000000,
		pool = "Meadow",
		tiers = {
			Common = 580224, -- 58.0224% (128 x 4,533)
			Uncommon = 369818, -- 36.9818% (73 x 5,066)
			Rare = 44960, -- 4.496% (40 x 1,124)
			["Ultra Rare"] = 4498, -- 1 in 222 (13 x 346)
			Epic = 450, -- 1 in 2,222 (6 x 75)
			Legendary = 50, -- 1 in 20,000 (1 x 50)
		},
	},
	{
		id = "MoonlitEgg",
		priceCoins = 20000,
		hatchSeconds = 120,
		-- Every Godly here is exactly 1 in 2,000,000, however many there are.
		total = 10000000,
		pool = "Moonlit",
		tiers = {
			Uncommon = 6660012, -- 66.6001% (6 x 1,110,002)
			Rare = 3000000, -- 30% (20 x 150,000)
			["Ultra Rare"] = 319986, -- 3.19986% (58 x 5,517)
			Epic = 19008, -- 1 in 526 (54 x 352)
			Legendary = 899, -- 1 in 11,123 (1 x 899)
			Godly = 95, -- 1 in 105,263 (19 x 5)
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
