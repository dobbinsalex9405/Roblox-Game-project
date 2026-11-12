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
local Daily = require(ReplicatedStorage.Shared.Daily)
local Hatchery = require(ReplicatedStorage.Shared.Hatchery)
local Products = require(ReplicatedStorage.Shared.Products)

local Shop = {}

-- Which incubator each player last asked Instant Hatch for: the receipt
-- finishes that egg (or, if it hatched meanwhile, the longest wait left).
local hatchTarget: { [Player]: number } = {}

-- `incomeOf(player)`: the player's coins a second right now (nil before
-- their data loads); coin packs scale with it. `notify` shows the player a
-- notice line once a purchase has landed.
function Shop.register(
	services: CoreServer.Services,
	Config: any,
	ids: Monetization.Resolved,
	incomeOf: (player: Player) -> number?,
	notify: (player: Player, text: string) -> ()
)
	local monetization = Config.get("monetization")
	local raids = Config.get("raids")
	local economy = Config.get("economy")
	local products = monetization.products
	local function later(player: Player, text: string)
		task.defer(notify, player, text)
	end

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

	-- Instant Hatch: the egg the player asked for is ready now. Paid for while
	-- no egg is hatching (it hatched between prompt and payment), it is kept
	-- in `instantHatches` and used on the next egg they finish.
	services.receipts:register("InstantHatch", ids.products.InstantHatch, function(player, data)
		if Hatchery.finishEgg(data, hatchTarget[player], os.time()) then
			later(player, "Instant Hatch: your egg is ready!")
		else
			data.instantHatches = (data.instantHatches or 0) + 1
			later(player, "No egg was hatching, so your Instant Hatch is saved for the next one.")
		end
		hatchTarget[player] = nil
	end)
	services.shop:guard("InstantHatch", function(player: Player): string?
		local d = services.data:get(player)
		if d == nil or Hatchery.hatchingEgg(d, nil, os.time()) == nil then
			return "No egg is hatching right now."
		end
		return nil
	end)

	-- Double Offline Earnings: the coins the welcome back just added, again.
	-- Paid for after its window (the prompt was opened in time), it still
	-- gives what was offered, or the small coin pack's amount if nothing is.
	services.receipts:register("DoubleOffline", ids.products.DoubleOffline, function(player, data, ledger)
		local bonus = data.offlineBonus
		local coins = if bonus and bonus.coins > 0
			then bonus.coins
			else Products.packCoins(products.CoinPackSmall, incomeOf(player) or 0)
		ledger:add("coins", coins, "IAP:DoubleOffline")
		data.offlineBonus = { coins = 0, untilAt = 0 }
		later(player, `Offline earnings doubled: +{coins} coins!`)
	end)
	services.shop:guard("DoubleOffline", function(player: Player): string?
		local d = services.data:get(player)
		local bonus = d and d.offlineBonus
		if bonus == nil or bonus.coins <= 0 or os.time() > bonus.untilAt then
			return "Double Offline Earnings is offered when you come back after a while away."
		end
		return nil
	end)

	-- Streak Saver: held until the broken streak's reward is claimed.
	services.receipts:register("StreakSaver", ids.products.StreakSaver, function(player, data)
		Daily.addSaver(data)
		later(player, "Streak saved! Claim today's reward to keep it going.")
	end)
	services.shop:guard("StreakSaver", function(player: Player): string?
		local d = services.data:get(player)
		if d == nil then
			return "Your save is still loading."
		end
		return Daily.saverRefusal(d, os.time(), #economy.daily.rewards)
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
		hatchTarget[player] = nil
	end)
end

-- Instant Hatch on incubator `slot`: remembers it for the receipt and opens
-- Roblox's prompt (with every check the shop makes).
function Shop.promptInstantHatch(services: CoreServer.Services, player: Player, slot: number)
	hatchTarget[player] = slot
	services.shop:prompt(player, "product", "InstantHatch", "Incubator")
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
