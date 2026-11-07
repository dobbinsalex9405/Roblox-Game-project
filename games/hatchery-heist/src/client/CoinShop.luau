--!strict
-- The shop's Coins tab (the shop opens on it; Robux items are the next tab):
-- the next incubator, the free shield, traps and decoy eggs for the first
-- free spot on the player's base, and the coin eggs at the Egg Market. Buttons only
-- ask; the server checks coins, spots and cooldowns.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoreClient = require(ReplicatedStorage.CoreClient.CoreClient)
local UiKit = require(ReplicatedStorage.CoreClient.UiKit)
local Shared = ReplicatedStorage.Shared
local Defenses = require(Shared.Defenses)
local Geometry = require(Shared.Geometry)
local Hatchery = require(Shared.Hatchery)
local Layout = require(Shared.Layout)

local Context = require(script.Parent.Context)

local CoinShop = {}

local GOLD = Color3.fromRGB(255, 220, 90)

local function freeSpot(count: number, taken: (spot: number) -> any?): number?
	for spot = 1, count do
		if taken(spot) == nil then
			return spot
		end
	end
	return nil
end

function CoinShop.start(ctx: Context.Context)
	local raids = ctx.config.raids
	local economy = ctx.config.economy

	local function item(
		body: ScrollingFrame,
		order: number,
		name: string,
		about: string,
		price: string,
		action: string?,
		enabled: boolean,
		onBuy: (() -> ())?
	)
		local card = UiKit.card(body)
		card.LayoutOrder = order
		UiKit.label(card, name, 22, true)
		UiKit.label(card, about, 34)
		UiKit.label(card, price, 18).TextColor3 = GOLD
		if action then
			local row = UiKit.row(card, UiKit.TOUCH_ROW)
			local b =
				UiKit.button(row, action, 150, UiKit.TOUCH, if enabled then UiKit.ACCENT else UiKit.MUTED)
			b.AutoButtonColor = enabled
			b.Activated:Connect(function()
				if enabled and onBuy then
					onBuy()
				end
			end)
		end
	end

	CoreClient.addShopTab("Coins", function(body: ScrollingFrame, api)
		local d = ctx.data()
		if d == nil then
			UiKit.label(body, "Loading...", 24)
			return
		end
		local now = ctx.serverNow()
		local coins = d.coins
		local balance = UiKit.label(body, `You have {Layout.shortNumber(coins)} coins`, 26, true)
		balance.TextColor3 = GOLD
		balance.LayoutOrder = 0

		local slotCost = Hatchery.nextSlotCost(d, economy)
		item(
			body,
			1,
			"New incubator",
			"Hatch one more egg at a time.",
			if slotCost then `{Layout.shortNumber(slotCost)} coins` else "Every incubator is unlocked",
			if slotCost then "Unlock" else nil,
			slotCost ~= nil and coins >= slotCost,
			function()
				ctx.fire(ctx.remotes["HH:BuySlot"])
			end
		)

		local shieldText, shieldReady
		if d.shieldUntil > now then
			shieldText, shieldReady = `Up for {math.ceil(d.shieldUntil - now)}s`, false
		elseif d.shieldReadyAt > now then
			shieldText, shieldReady = `Recharging: {math.ceil(d.shieldReadyAt - now)}s`, false
		else
			shieldText, shieldReady = "Free", true
		end
		item(
			body,
			2,
			"Shield",
			`Keeps raiders out of your base for {raids.freeShieldSeconds}s.`,
			shieldText,
			"Raise",
			shieldReady,
			function()
				ctx.fire(ctx.remotes["HH:Shield"])
			end
		)

		local trapSpot = freeSpot(#Geometry.TRAP_SPOTS, function(spot)
			return (Defenses.trapAt(d, spot))
		end)
		for index, kind in { "Snare", "Slime" } do
			local def = raids.traps[kind]
			local about = if kind == "Snare"
				then "Stops a raider and sends your creature home."
				else "Slows raiders down so you can catch them."
			item(
				body,
				2 + index,
				`{kind} trap`,
				about .. " Set on a free trap spot on your base.",
				if trapSpot then `{Layout.shortNumber(def.price)} coins` else "Every trap spot is in use",
				"Set trap",
				trapSpot ~= nil and coins >= def.price,
				function()
					if trapSpot then
						ctx.fire(ctx.remotes["HH:BuyTrap"], trapSpot, kind)
					end
				end
			)
		end

		local decoySpot = freeSpot(#Geometry.DECOY_SPOTS, function(spot)
			return (Defenses.decoyAt(d, spot))
		end)
		item(
			body,
			5,
			"Decoy egg",
			"Looks like a creature to raiders. Grabbing it stuns them.",
			if decoySpot
				then `{Layout.shortNumber(raids.decoy.price)} coins`
				else "Every decoy spot is in use",
			"Place decoy",
			decoySpot ~= nil and coins >= raids.decoy.price,
			function()
				if decoySpot then
					ctx.fire(ctx.remotes["HH:BuyDecoy"], decoySpot)
				end
			end
		)

		local order = 6
		for _, egg in ctx.config.eggs do
			if egg.priceCoins then
				order += 1
				item(
					body,
					order,
					Layout.displayName(egg.id),
					`Rides the Egg Market in the middle. Walk up to it to see its odds and buy it. Hatches in {egg.hatchSeconds}s.`,
					`{Layout.shortNumber(egg.priceCoins)} coins`,
					nil,
					false,
					nil
				)
			end
		end

		local more = UiKit.card(body)
		more.LayoutOrder = 100
		UiKit.label(more, "Need more coins?", 22, true)
		local row = UiKit.row(more, UiKit.TOUCH_ROW)
		UiKit.button(row, "See Robux items", 170, UiKit.TOUCH, UiKit.ACCENT).Activated:Connect(api.showRobux)
	end)

	-- Keep prices and states current while the shop is open.
	ctx.onData(function()
		CoreClient.refreshShop()
	end)
end

return CoinShop
