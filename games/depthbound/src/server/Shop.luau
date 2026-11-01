--!strict
-- Registers developer products with the core's receipt handler. Every
-- Depthbound product (Oil Refill, Ore Boost, Geode Crate) arrives with the M5
-- shop, once Alex approves prices, so nothing can be sold that the game
-- cannot deliver. Until then this only reports what is not created yet.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoreServer = require(ServerScriptService.CoreServer.CoreServer)
local Log = require(ReplicatedStorage.Core.Log)

local log = Log.new("Shop")

local Shop = {}

function Shop.register(_services: CoreServer.Services, Config: any)
	local products = Config.get("monetization").products
	local waiting = {}
	for key, product in products do
		if product.id == 0 then
			table.insert(waiting, key)
		else
			-- Created on Roblox before its M5 handler exists: the receipt is never
			-- granted (so never charged for good), but say so loudly.
			log:error("product has an id but no handler yet; add it in Shop.luau (M5)", { product = key })
		end
	end
	table.sort(waiting)
	if #waiting > 0 then
		log:info("products not created on Roblox yet", { products = table.concat(waiting, ",") })
	end
end

return Shop
