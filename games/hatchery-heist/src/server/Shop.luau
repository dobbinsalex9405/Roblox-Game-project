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

function Shop.register(services: CoreServer.Services, Config: any, ids: Monetization.Resolved)
	local monetization = Config.get("monetization")
	local raids = Config.get("raids")
	local products = monetization.products

	for _, key in Products.COIN_PACKS do
		local coins = products[key].coins
		services.receipts:register(key, ids.products[key], function(_player, _data, ledger)
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
end

return Shop
