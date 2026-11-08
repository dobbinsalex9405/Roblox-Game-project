--!strict
-- Hatchery Heist's products and passes, wired into the core's shop.
--
-- Every product the game can deliver is registered with the core's receipt
-- handler, even before it exists on Roblox (id 0), so the Studio test panel
-- can run it through the real receipt path. The shop only prompts items whose
-- id is set for this experience (config/monetization.luau, `environments`).
-- What the shop lists comes from src/shared/Products.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CoreServer = require(ServerScriptService.CoreServer.CoreServer)
local Purchases = require(ServerScriptService.CoreServer.Purchases)
local Monetization = require(ReplicatedStorage.Core.Monetization)
local Products = require(ReplicatedStorage.Shared.Products)

local Shop = {}

-- `incomeOf(player)`: the player's coins a second right now (nil before
-- their data loads); coin packs scale with it.
function Shop.register(
	services: CoreServer.Services,
	Config: any,
	ids: Monetization.Resolved,
	incomeOf: (player: Player) -> number?
)
	local monetization = Config.get("monetization")
	local raids = Config.get("raids")
	local products = monetization.products

	-- The amount each player was last shown for each pack: a purchase never
	-- gives less than what the shop showed, even if income dropped since.
	local shown: { [Player]: { [string]: number } } = {}
	local function amountFor(player: Player, key: string): number
		return Products.packCoins(products[key], incomeOf(player) or 0)
	end

	for _, key in Products.COIN_PACKS do
		services.receipts:register(key, ids.products[key], function(player, _data, ledger)
			local seen = shown[player]
			local coins = math.max(amountFor(player, key), seen and seen[key] or 0)
			ledger:add("coins", coins, `IAP:{key}`)
		end)
	end

	services.receipts:register("ShieldRefill", ids.products.ShieldRefill, function(_player, data)
		local now = os.time()
		data.shieldUntil = math.max(now, data.shieldUntil or 0) + raids.shieldSeconds
	end)

	-- Passes need no registration: the core checks ownership by id.
	local catalog: { Purchases.CatalogItem } = Products.catalog(monetization, raids) :: any
	services.shop:setCatalog(catalog)
	for _, key in Products.COIN_PACKS do
		local product = products[key]
		services.shop:personalize(key, function(player: Player): (string, string)
			local coins = amountFor(player, key)
			local mine = shown[player] or {}
			shown[player] = mine
			mine[key] = coins
			return `{Products.short(coins)} Coins`,
				if coins > product.coins
					then `{coins} coins right away: {product.incomeMinutes} minutes of what you earn now.`
					else `{coins} coins right away.`
		end)
	end

	-- Forget a player's shown amounts when they leave.
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		shown[player] = nil
	end)
end

-- The coin packs' amounts for a player right now, to tell when the shop
-- should be refreshed (only when one changes, so not every tick).
function Shop.packAmounts(Config: any, incomePerSecond: number): string
	local products = Config.get("monetization").products
	local parts = {}
	for _, key in Products.COIN_PACKS do
		table.insert(parts, tostring(Products.packCoins(products[key], incomePerSecond)))
	end
	return table.concat(parts, ",")
end

return Shop
