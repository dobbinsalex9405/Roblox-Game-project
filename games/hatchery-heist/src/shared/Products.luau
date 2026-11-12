--!strict
-- What Hatchery Heist's shop lists, as a pure function, so the Lune tests and
-- the pricing tool (tools/pricing) read the exact names the server shows.
-- The grants live in src/server/Shop.luau.
--
-- Instant Hatch, Premium Egg and Luck Boost come with the M5 shop, so nothing
-- is listed that the game cannot deliver yet.

export type CatalogItem = {
	key: string,
	kind: "product" | "pass",
	name: string,
	description: string,
	-- Bought at its own place in the world, not from a Golden Egg Shop
	-- display (shared/ShopPlan skips it): the Giant Egg on the Golden Nest.
	soldAt: string?,
	-- A random item (src/server/Purchases in packages/core): the odds table
	-- the player must have seen before Roblox's prompt opens, and the
	-- PolicyService check that refuses restricted players its Robux price.
	oddsTable: string?,
	paidRandom: boolean?,
}

local Numbers = require("./Numbers")

local Products = {}

-- The coin packs, in shop order.
Products.COIN_PACKS = table.freeze({ "CoinPackSmall", "CoinPackMedium", "CoinPackBig", "CoinPackLarge" })

local function short(n: number): string
	if n >= 1e6 then
		return `{n / 1e6}M`
	elseif n >= 1e3 then
		return `{n / 1e3}K`
	end
	return tostring(n)
end

-- A number rounded down to its first three digits (123,456 -> 123,000),
-- so a pack's amount reads cleanly and only changes when income really does.
local function three(n: number): number
	if n < 1000 then
		return math.floor(n)
	end
	local unit = 10 ^ (math.floor(math.log10(n)) - 2)
	return math.floor(n / unit) * unit
end

-- What a coin pack gives a player earning `incomePerSecond` right now: its
-- fixed coins, or its `incomeMinutes` of that income, whichever is more.
function Products.packCoins(
	product: { coins: number, incomeMinutes: number? },
	incomePerSecond: number
): number
	local minutes = product.incomeMinutes or 0
	return math.max(product.coins, three(math.max(0, incomePerSecond) * 60 * minutes))
end

-- "1.25M", "80K", "5,000"-style short amounts for a pack's name.
function Products.short(n: number): string
	return Numbers.short(three(n))
end

function Products.catalog(monetization: any, raids: any): { CatalogItem }
	local products = monetization.products
	local catalog: { CatalogItem } = {}
	for _, key in Products.COIN_PACKS do
		local coins = products[key].coins
		table.insert(catalog, {
			key = key,
			kind = "product",
			name = `{short(coins)} Coins`,
			description = `Adds {coins} coins right away.`,
		})
	end
	table.insert(catalog, {
		key = "ShieldRefill",
		kind = "product",
		name = "Shield Refill",
		description = `Shields your base for {raids.shieldSeconds // 60} more minutes. Raiders can't enter.`,
	})
	table.insert(catalog, {
		key = "DoubleCoins",
		kind = "pass",
		name = "Double Coins",
		description = "Every creature earns twice as many coins.",
	})
	table.insert(catalog, {
		key = "ExtraIncubators",
		kind = "pass",
		name = "Extra Incubators",
		description = "Two more incubators to hatch in.",
	})
	table.insert(catalog, {
		key = "AutoCollect",
		kind = "pass",
		name = "Auto-Collect",
		description = "Your earnings move into your coins every 30 seconds, no trip to the collect pad.",
	})
	-- The Giant Golden Egg (Alex, Nov 12): Epic or better on its own odds
	-- table, once per player per day; src/server/GiantEgg.luau.
	table.insert(catalog, {
		key = "GiantEgg",
		kind = "product",
		name = "Giant Golden Egg",
		description = "The giant egg in the middle of the map: Epic or better, with far better odds than any other egg. One each day.",
		soldAt = "GiantEgg",
		oddsTable = "GiantEgg",
		paidRandom = true,
	})
	return catalog
end

return Products
