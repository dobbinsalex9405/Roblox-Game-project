--!strict
-- Street Food Empire's developer products and passes: what each one grants,
-- and how the shop lists it (ops/SHOP.md).
--
-- Runs only on the server (src/server/Shop.luau). It lives in Shared so the
-- Lune tests run the exact same grants through the core's real receipt path.
--
-- Every product the game can deliver is registered, even before it exists on
-- Roblox (id 0), so the Studio test panel can run it. The shop only prompts
-- items whose id is set for this experience. Instant Build comes with the M5
-- shop, once the shop can offer it only while something is being built, so
-- nothing is sold that would do nothing. Festival Bundle comes with the
-- festival (M4).

local Actions = require("./Actions")

-- The shop's catalog item (packages/core/server/Purchases.luau, CatalogItem).
-- Nothing in this game is random, so no item names an odds table.
export type CatalogItem = {
	key: string,
	kind: "product" | "pass",
	name: string,
	description: string,
}

local Products = {}

-- Products the game can deliver today, in shop order.
Products.SOLD = table.freeze({ "CashPackSmall", "CashPackMedium", "CashPackLarge", "SpeedBoost" })

-- Passes the game honours today, in shop order.
Products.PASSES = table.freeze({ "DoubleCash", "AutoCollect" })

local function short(n: number): string
	if n >= 1e6 and n % 1e5 == 0 then
		return `{n / 1e6}M`
	elseif n >= 1e3 and n % 100 == 0 then
		return `{n / 1e3}K`
	end
	return tostring(n)
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	return (string.gsub(out, "^,", ""))
end

-- Registers every product with `receipts` and returns the shop's catalog.
-- `productIds` maps product keys to this experience's ids (Monetization.resolve).
function Products.register(
	receipts: any, -- the core's Receipts
	productIds: { [string]: number },
	monetization: any,
	economy: any,
	actions: Actions.Actions
): { CatalogItem }
	local catalog: { CatalogItem } = {}

	for _, key in { "CashPackSmall", "CashPackMedium", "CashPackLarge" } do
		local cash = monetization.products[key].cash
		receipts:register(key, productIds[key], function(_player, _data, ledger)
			ledger:add("cash", cash, `IAP:{key}`)
		end)
		table.insert(catalog, {
			key = key,
			kind = "product",
			name = `{short(cash)} Cash`,
			description = `Adds {commas(cash)} cash right away.`,
		})
	end

	local speed = monetization.boosts.SpeedBoost
	receipts:register("SpeedBoost", productIds.SpeedBoost, function(player, data)
		actions:boost(player, data, "SpeedBoost")
	end)
	table.insert(catalog, {
		key = "SpeedBoost",
		kind = "product",
		name = "Speed Boost",
		description = `Customers come {speed.customerMultiplier}x as fast for {speed.durationSeconds // 60} minutes. Buying again adds more time.`,
	})

	table.insert(catalog, {
		key = "DoubleCash",
		kind = "pass",
		name = "2x Cash",
		description = `Every sale pays {economy.doubleCashMultiplier}x, at the counter and from your cooks.`,
	})
	table.insert(catalog, {
		key = "AutoCollect",
		kind = "pass",
		name = "Auto-Collect",
		description = `Your register empties into your cash every {economy.autoCollectSeconds} seconds, no trip to the register.`,
	})

	return catalog
end

return Products
