--!strict
-- Tidecatch Cove's products and passes, wired into the core's shared shop
-- (ops/SHOP.md). What each product does is in src/shared/Products.luau.
--
-- Every product is registered with the core's receipt handler even while its
-- Roblox id is 0, so the Studio test panel can run it through the real
-- receipt path. The shop only prompts items whose id is set for this
-- experience (config/monetization.luau, `environments`), and prices wait for
-- Alex's approval.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CoreServer = require(ServerScriptService.CoreServer.CoreServer)
local Monetization = require(ReplicatedStorage.Core.Monetization)

local Shared = ReplicatedStorage.Shared
local Catch = require(Shared.Catch)
local Cove = require(Shared.Cove)
local Products = require(Shared.Products)

local Shop = {}

function Shop.register(
	services: CoreServer.Services,
	config: Cove.Config,
	ids: Monetization.Resolved,
	notify: (player: Player, text: string) -> ()
)
	local grants = Products.grants({
		config = config,
		now = os.time,
		rollMystery = function(player: Player): string?
			return (services.odds:rollPaid(Catch.MYSTERY_TABLE, player, services.policy))
		end,
		notify = function(player: Player, text: string)
			-- After the receipt's data update returns.
			task.defer(notify, player, text)
		end,
	})
	for key in config.monetization.products do
		local grant = grants[key]
		assert(grant, `product {key} has no grant (src/shared/Products.luau)`)
		services.receipts:register(key, ids.products[key], grant)
	end
	services.shop:setCatalog(Products.catalog(config) :: any)
end

return Shop
