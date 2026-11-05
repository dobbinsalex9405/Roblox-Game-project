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
}

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
	return catalog
end

return Products
