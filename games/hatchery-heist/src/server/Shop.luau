--!strict
-- Hatchery Heist's products and passes, wired into the core's shop.
--
-- Every product the game can deliver is registered with the core's receipt
-- handler, even before it exists on Roblox (id 0), so the Studio test panel
-- can run it through the real receipt path. The shop only prompts items whose
-- id is set for this experience (config/monetization.luau, `environments`).
-- Instant Hatch, Premium Egg and Luck Boost come with the M5 shop, once Alex
-- approves prices, so nothing is listed that the game cannot deliver yet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CoreServer = require(ServerScriptService.CoreServer.CoreServer)
local Purchases = require(ServerScriptService.CoreServer.Purchases)
local Monetization = require(ReplicatedStorage.Core.Monetization)

local Shop = {}

local function short(n: number): string
	if n >= 1e6 then
		return `{n / 1e6}M`
	elseif n >= 1e3 then
		return `{n / 1e3}K`
	end
	return tostring(n)
end

function Shop.register(services: CoreServer.Services, Config: any, ids: Monetization.Resolved)
	local monetization = Config.get("monetization")
	local raids = Config.get("raids")
	local products = monetization.products
	local catalog: { Purchases.CatalogItem } = {}

	for _, key in { "CoinPackSmall", "CoinPackMedium", "CoinPackLarge" } do
		local coins = products[key].coins
		services.receipts:register(key, ids.products[key], function(_player, _data, ledger)
			ledger:add("coins", coins, `IAP:{key}`)
		end)
		table.insert(catalog, {
			key = key,
			kind = "product",
			name = `{short(coins)} Coins`,
			description = `Adds {coins} coins right away.`,
		})
	end

	services.receipts:register("ShieldRefill", ids.products.ShieldRefill, function(_player, data)
		local now = os.time()
		data.shieldUntil = math.max(now, data.shieldUntil or 0) + raids.shieldSeconds
	end)
	table.insert(catalog, {
		key = "ShieldRefill",
		kind = "product",
		name = "Shield Refill",
		description = `Shields your base for {raids.shieldSeconds // 60} more minutes. Raiders can't enter.`,
	})

	local passes = {
		{
			key = "DoubleCoins",
			name = "Double Coins",
			description = "Every creature earns twice as many coins.",
		},
		{
			key = "ExtraIncubators",
			name = "Extra Incubators",
			description = "Two more incubators to hatch in.",
		},
		{
			key = "AutoCollect",
			name = "Auto-Collect",
			description = "Your earnings move into your coins every 30 seconds, no trip to the collect pad.",
		},
	}
	for _, pass in passes do
		table.insert(
			catalog,
			{ key = pass.key, kind = "pass", name = pass.name, description = pass.description }
		)
	end

	services.shop:setCatalog(catalog)
end

return Shop
