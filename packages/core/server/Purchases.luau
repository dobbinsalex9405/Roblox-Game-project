--!strict
-- The shared shop: what a game sells, and Roblox's purchase prompt.
--
-- A game lists its catalog once (after registering each product's grant with
-- services.receipts). The client asks to buy by key; the server checks the
-- item exists on Roblox here, that a pass is not already owned, and, for
-- anything with random results, that the player may receive paid random items
-- and was shown the item's odds within the last ODDS_FRESH_SECONDS. Only then
-- does it open Roblox's prompt. Delivery stays where it was: Receipts (exactly
-- once, after the save) for products, Passes for passes.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Core.Log)
local Passes = require(ReplicatedStorage.Core.Passes)
local Policy = require(ReplicatedStorage.Core.Policy)
local Receipts = require(ReplicatedStorage.Core.Receipts)
local ShopRemotes = require(ReplicatedStorage.Core.ShopRemotes)

local ServerNet = require(script.Parent.ServerNet)

local ODDS_FRESH_SECONDS = 600

export type Kind = "product" | "pass"

-- One item as the game lists it.
export type CatalogItem = {
	key: string, -- product key in receipts, or pass key
	kind: Kind,
	name: string,
	description: string,
	-- An odds table the player must have been shown before buying. Anything
	-- with random results must set this and `paidRandom`.
	oddsTable: string?,
	paidRandom: boolean?, -- refused for players PolicyService restricts
}

-- One item as the client receives it.
export type CatalogEntry = {
	key: string,
	kind: Kind,
	name: string,
	description: string,
	id: number, -- Roblox id here (0 = not created on Roblox yet)
	available: boolean,
	owned: boolean, -- passes only
	blocked: boolean, -- paid random item this player may not buy
	oddsTable: string?,
}

export type Deps = {
	net: ServerNet.ServerNet,
	receipts: Receipts.Receipts,
	passes: Passes.Passes,
	passIds: { [string]: number },
	policy: Policy.Policy,
	studio: boolean,
}

export type Shop = {
	-- Sets what the shop sells. Every product must already be registered
	-- with services.receipts and every pass listed in CoreServer's passes.
	setCatalog: (self: Shop, items: { CatalogItem }) -> (),
	catalogFor: (self: Shop, player: Player) -> { CatalogEntry },
	-- Called by CoreServer whenever odds are sent to a player.
	oddsShown: (self: Shop, player: Player, tableId: string) -> (),
	-- Re-sends the catalog (after a pass changes hands, for example).
	refresh: (self: Shop, player: Player) -> (),
	forget: (self: Shop, player: Player) -> (),
}

local log = Log.new("Shop")

local Purchases = {}

function Purchases.start(deps: Deps): Shop
	local items: { CatalogItem } = {}
	local byKey: { [string]: CatalogItem } = {}
	local oddsSeen: { [Player]: { [string]: number } } = {}

	local shop = {}

	local function idOf(item: CatalogItem): number
		if item.kind == "pass" then
			return deps.passIds[item.key] or 0
		end
		return deps.receipts:productId(item.key) or 0
	end

	function shop.setCatalog(_self: Shop, list: { CatalogItem })
		local seen: { [string]: boolean } = {}
		for _, item in list do
			assert(not seen[`{item.kind}:{item.key}`], `shop lists {item.kind} {item.key} twice`)
			seen[`{item.kind}:{item.key}`] = true
			if item.kind == "product" then
				assert(
					deps.receipts:productId(item.key) ~= nil,
					`shop lists product {item.key} but no grant is registered for it`
				)
			else
				assert(
					deps.passIds[item.key] ~= nil,
					`shop lists pass {item.key} but CoreServer has no such pass`
				)
			end
			assert(
				not item.paidRandom or item.oddsTable ~= nil,
				`{item.key} has random results, so it needs an oddsTable to show before purchase`
			)
		end
		items = table.clone(list)
		byKey = {}
		for _, item in items do
			byKey[`{item.kind}:{item.key}`] = item
		end
		for _, player in Players:GetPlayers() do
			shop.refresh(shop :: any, player)
		end
	end

	function shop.catalogFor(_self: Shop, player: Player): { CatalogEntry }
		local out = {}
		local restricted = not deps.policy:paidRandomAllowed(player)
		for _, item in items do
			local id = idOf(item)
			table.insert(out, {
				key = item.key,
				kind = item.kind,
				name = item.name,
				description = item.description,
				id = id,
				available = id > 0,
				owned = item.kind == "pass" and deps.passes:owns(player, item.key),
				blocked = item.paidRandom == true and restricted,
				oddsTable = item.oddsTable,
			})
		end
		return out
	end

	function shop.oddsShown(_self: Shop, player: Player, tableId: string)
		local seen = oddsSeen[player] or {}
		oddsSeen[player] = seen
		seen[tableId] = os.clock()
	end

	function shop.refresh(self: Shop, player: Player)
		if player.Parent == Players then
			deps.net:fire(ShopRemotes["Shop:Catalog"], player, self:catalogFor(player))
		end
	end

	function shop.forget(_self: Shop, player: Player)
		oddsSeen[player] = nil
	end

	local function notice(player: Player, text: string)
		deps.net:fire(ShopRemotes["Shop:Notice"], player, text)
	end

	deps.net:on(ShopRemotes["Shop:RequestCatalog"], function(player: Player)
		shop.refresh(shop :: any, player)
	end)

	deps.net:on(ShopRemotes["Shop:Buy"], function(player: Player, kind: Kind, key: string)
		local item = byKey[`{kind}:{key}`]
		if item == nil then
			return
		end
		local id = idOf(item)
		if id <= 0 then
			notice(
				player,
				if deps.studio
					then `{item.name} is not on Roblox yet. Use the Test panel to grant it.`
					else `{item.name} is not available yet.`
			)
			return
		end
		if item.paidRandom and not deps.policy:paidRandomAllowed(player) then
			notice(player, `{item.name} is not available in your region.`)
			return
		end
		if item.oddsTable then
			local seenAt = oddsSeen[player] and oddsSeen[player][item.oddsTable]
			if seenAt == nil or os.clock() - seenAt > ODDS_FRESH_SECONDS then
				notice(player, `Check the odds for {item.name} first.`)
				return
			end
		end
		if kind == "pass" then
			if deps.passes:owns(player, key) then
				notice(player, `You already own {item.name}.`)
				return
			end
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			MarketplaceService:PromptProductPurchase(player, id)
		end
		log:info("purchase prompted", { userId = player.UserId, kind = kind, key = key })
	end)

	return (shop :: any) :: Shop
end

return Purchases
