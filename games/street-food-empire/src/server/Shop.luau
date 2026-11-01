--!strict
-- Registers developer products with the core's receipt handler. A product
-- whose id is still 0 has not been created on Roblox yet and is skipped.
-- Instant Build and Speed Boost (Restaurant.finishBuilds, Restaurant.startBoost)
-- are registered with the M5 shop, once Alex approves prices and the shop
-- screen can offer them only when they do something, so nothing can be sold
-- that the game cannot deliver.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoreServer = require(ServerScriptService.CoreServer.CoreServer)
local Log = require(ReplicatedStorage.Core.Log)

local log = Log.new("Shop")

local Shop = {}

function Shop.register(services: CoreServer.Services, Config: any)
	local products = Config.get("monetization").products

	for _, key in { "CashPackSmall", "CashPackMedium", "CashPackLarge" } do
		local product = products[key]
		if product.id > 0 then
			services.receipts:register(key, product.id, function(_player, _data, ledger)
				ledger:add("cash", product.cash, `IAP:{key}`)
			end)
		end
	end

	local skipped = {}
	for key, product in products do
		if product.id == 0 then
			table.insert(skipped, key)
		end
	end
	table.sort(skipped)
	if #skipped > 0 then
		log:info("products not created on Roblox yet", { products = table.concat(skipped, ",") })
	end
end

return Shop
