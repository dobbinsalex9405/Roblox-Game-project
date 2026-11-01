--!strict
-- Depthbound's products and passes, wired into the core's shop (ops/SHOP.md).
--
-- Every product the game can deliver is registered with the core's receipt
-- handler, even before it exists on Roblox (id 0), so the Studio test panel
-- can run it through the real receipt path. The shop only prompts items whose
-- id is set for this experience (config/monetization.luau, `environments`).
-- The grants and the catalog live in Shared/Products so the tests run them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local CoreServer = require(ServerScriptService.CoreServer.CoreServer)
local Purchases = require(ServerScriptService.CoreServer.Purchases)
local Log = require(ReplicatedStorage.Core.Log)
local Monetization = require(ReplicatedStorage.Core.Monetization)
local Products = require(ReplicatedStorage.Shared.Products)

local log = Log.new("Shop")

local Shop = {}

function Shop.register(services: CoreServer.Services, Config: any, ids: Monetization.Resolved, actions: any)
	local monetization = Config.get("monetization")
	local grants = Products.grants({
		monetization = monetization,
		actions = actions,
		now = function()
			return Workspace:GetServerTimeNow()
		end,
		after = function(fn: () -> ())
			task.defer(fn)
		end,
	})
	for _, key in Products.SOLD do
		services.receipts:register(key, ids.products[key], grants[key])
	end

	-- A product created on Roblox before the game can deliver it would take
	-- Robux for nothing: Roblox would retry its receipt forever. Say so loudly.
	for key, id in ids.products do
		if id > 0 and table.find(Products.SOLD, key) == nil then
			log:error("product has an id but is not sold yet; remove the id until it is", { product = key })
		end
	end

	local catalog: { Purchases.CatalogItem } = {}
	for _, item in Products.catalog(monetization, Config.get("gear")) do
		table.insert(catalog, {
			key = item.key,
			kind = item.kind,
			name = item.name,
			description = item.description,
			oddsTable = item.oddsTable,
			paidRandom = item.paidRandom,
		})
	end
	services.shop:setCatalog(catalog)
end

return Shop
