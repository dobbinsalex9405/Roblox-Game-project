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
	-- Random results (claw pulls): the core shop refuses them to players
	-- PolicyService restricts, and until this odds table was shown.
	oddsTable: string?,
	paidRandom: boolean?,
	oddsLabels: { [string]: string }?,
}

local Claw = require("./Claw")
local Numbers = require("./Numbers")

local Products = {}

-- The claw machine's Robux pulls, in shop order.
Products.CLAW_PULLS = table.freeze({ "ClawPull10", "ClawPull100" })

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

-- `charms` (config/charms.luau), when given, names the claw's charms on its
-- odds list.
function Products.catalog(monetization: any, raids: any, charms: any?): { CatalogItem }
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
	-- Claw machine pulls (src/server/CharmService.luau grants them). Sold at
	-- the claw machine, with its odds on screen; Robux only for 10 and 100.
	local labels: { [string]: string }? = nil
	if charms then
		local names: { [string]: string } = {}
		for _, c in charms.charms do
			names[c.id] = c.name
		end
		labels = names
	end
	for _, key in Products.CLAW_PULLS do
		local listing = monetization.listings.products[key]
		table.insert(catalog, {
			key = key,
			kind = "product",
			name = listing.name,
			description = listing.description,
			oddsTable = Claw.TABLE,
			paidRandom = true,
			oddsLabels = labels,
		})
	end
	return catalog
end

return Products
