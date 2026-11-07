--!strict
-- Eggs and their exact odds. An egg rolls a rarity tier first, by the tier
-- weights below, then a creature from that tier in the egg's pool (the
-- creatures listing the pool in config/creatures, by their in-tier weight).
-- So adding a creature to a pool only splits its tier's share, and no other
-- tier's chance ever moves. Weights are whole numbers out of `total`
-- (100,000, so 1 = 0.001%) and must add up to exactly that.
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

-- The fixed-order alternative builds one cycle of `total` eggs per egg
-- (Hatchery.fixedOrderCycle), so totals stay 100,000 until it computes the
-- n-th outcome without the table.
local TOTAL = 100000

-- Odds tuned Nov 7 with tools/economy (ops/ECONOMY.md): the Meadow Egg is now
-- the step up from Basic (it was 6x cheaper than Moonlit for 22x worse Rare
-- odds, so players skipped it), and the Moonlit Egg's Rare-and-up odds come
-- down so a regular player's first Epic lands on day 2-3, not in hour one.

local eggs: { Egg } = {
	{
		id = "BasicEgg",
		priceCoins = 50,
		hatchSeconds = 10,
		total = TOTAL,
		pool = "Barnyard",
		tiers = {
			Common = 92000, -- 92%
			Uncommon = 7200, -- 7.2%
			Rare = 700, -- 1 in 143
			["Ultra Rare"] = 90, -- 1 in 1,111
			Epic = 8, -- 1 in 12,500
			Legendary = 2, -- 1 in 50,000
		},
	},
	{
		id = "MeadowEgg",
		priceCoins = 1500,
		hatchSeconds = 30,
		total = TOTAL,
		pool = "Meadow",
		tiers = {
			Common = 58000, -- 58%
			Uncommon = 37000, -- 37%
			Rare = 4500, -- 4.5%
			["Ultra Rare"] = 450, -- 1 in 222
			Epic = 45, -- 1 in 2,222
			Legendary = 5, -- 1 in 20,000
		},
	},
	{
		id = "MoonlitEgg",
		priceCoins = 20000,
		hatchSeconds = 120,
		total = TOTAL,
		pool = "Moonlit",
		tiers = {
			Uncommon = 66600, -- 66.6%
			Rare = 30000, -- 30%
			["Ultra Rare"] = 3200, -- 3.2%
			Epic = 190, -- 1 in 526
			Legendary = 9, -- 1 in 11,111
			Godly = 1, -- 1 in 100,000
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
