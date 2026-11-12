--!strict
-- What Hatchery Heist's shop lists, as a pure function, so the Lune tests and
-- the pricing tool (tools/pricing) read the exact names the server shows.
-- The grants live in src/server/Shop.luau.
--
-- Premium Egg and Luck Boost come later, so nothing is listed that the game
-- cannot deliver yet.

export type CatalogItem = {
	key: string,
	kind: "product" | "pass",
	name: string,
	description: string,
	-- A random item (packages/core server/Purchases): the odds table shown
	-- before Roblox's prompt opens, and the PolicyService check.
	oddsTable: string?,
	paidRandom: boolean?,
	-- Sold from its own button (an incubator, the welcome back, the daily
	-- window), never as a card in the Shop window.
	hidden: boolean?,
}

local DisplayName = require("./DisplayName")
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
	-- VIP gives a free egg every day, so it is a paid random item: the shop
	-- shows that egg's odds before Buy, and restricted players can't buy it.
	local vipEgg = monetization.perks.vip.dailyEgg
	table.insert(catalog, {
		key = "VIP",
		kind = "pass",
		name = "VIP",
		description = `10% more coins from every creature, a gold VIP tag, and a free {DisplayName(vipEgg)} every day.`,
		oddsTable = vipEgg,
		paidRandom = true,
	})
	table.insert(catalog, {
		key = "InstantHatch",
		kind = "product",
		name = "Instant Hatch",
		description = "Finishes hatching an egg right now.",
		hidden = true,
	})
	table.insert(catalog, {
		key = "DoubleOffline",
		kind = "product",
		name = "Double Offline Earnings",
		description = "Doubles the coins your creatures earned while you were away.",
		hidden = true,
	})
	table.insert(catalog, {
		key = "StreakSaver",
		kind = "product",
		name = "Streak Saver",
		description = "Keeps your daily reward streak going after a missed day.",
		hidden = true,
	})
	return catalog
end

return Products
