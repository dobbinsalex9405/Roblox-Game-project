--!strict
-- Wires Street Food Empire's products and passes (src/shared/Products.luau)
-- into the core's receipt handler and shop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CoreServer = require(ServerScriptService.CoreServer.CoreServer)
local Monetization = require(ReplicatedStorage.Core.Monetization)
local Actions = require(ReplicatedStorage.Shared.Actions)
local Products = require(ReplicatedStorage.Shared.Products)

local Shop = {}

function Shop.register(
	services: CoreServer.Services,
	Config: any,
	ids: Monetization.Resolved,
	actions: Actions.Actions
)
	local catalog = Products.register(
		services.receipts,
		ids.products,
		Config.get("monetization"),
		Config.get("economy"),
		actions
	)
	services.shop:setCatalog(catalog :: any)
end

return Shop
