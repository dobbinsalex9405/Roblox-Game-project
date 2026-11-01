--!strict
-- Developer products. Nothing is registered yet: every product id is still 0
-- because prices wait for Alex's approval at milestone M5, and a product the
-- game cannot deliver must never be sold. M5 adds the handlers here (growth
-- boost, restock skip, bait packs with their odds screen, mystery bait).

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoreServer = require(ServerScriptService.CoreServer.CoreServer)
local Log = require(ReplicatedStorage.Core.Log)

local log = Log.new("Shop")

local Shop = {}

function Shop.register(_services: CoreServer.Services, Config: any)
	local products = Config.get("monetization").products
	local skipped = {}
	for key, product in products do
		if product.id == 0 then
			table.insert(skipped, key)
		else
			-- Not registered, so the core's receipt handler never grants it
			-- and Roblox refunds the purchase. Config.spec keeps this from
			-- shipping.
			log:error("product has an id but no handler yet (milestone M5)", { product = key })
		end
	end
	table.sort(skipped)
	if #skipped > 0 then
		log:info("products not created on Roblox yet", { products = table.concat(skipped, ",") })
	end
end

return Shop
