--!strict
-- Registers developer products with the core's receipt handler. A product
-- whose id is still 0 has not been created on Roblox yet and is skipped.
-- Products that depend on M2 gameplay (Instant Hatch, Premium Egg, Luck Boost)
-- are registered when that gameplay lands, so nothing can be sold that the
-- game cannot deliver.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoreServer = require(ServerScriptService.CoreServer.CoreServer)
local Log = require(ReplicatedStorage.Core.Log)

local log = Log.new("Shop")

local Shop = {}

function Shop.register(services: CoreServer.Services, Config: any)
	local monetization = Config.get("monetization")
	local raids = Config.get("raids")
	local products = monetization.products

	for _, key in { "CoinPackSmall", "CoinPackMedium", "CoinPackLarge" } do
		local product = products[key]
		if product.id > 0 then
			services.receipts:register(key, product.id, function(_player, _data, ledger)
				ledger:add("coins", product.coins, `IAP:{key}`)
			end)
		end
	end

	local shield = products.ShieldRefill
	if shield.id > 0 then
		services.receipts:register("ShieldRefill", shield.id, function(_player, data)
			local now = os.time()
			data.shieldUntil = math.max(now, data.shieldUntil or 0) + raids.shieldSeconds
		end)
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
