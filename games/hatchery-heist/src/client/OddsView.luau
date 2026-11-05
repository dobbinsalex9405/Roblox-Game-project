--!strict
-- Shows exact odds before every egg purchase. The numbers come from the
-- server's odds table for this player (the same table the hatch rolls from,
-- boosts included), never from client config. Until they arrive, eggs cannot
-- be bought. Players who may not receive paid random items see the fixed
-- order their eggs hatch in instead, with the next one marked.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoreClient = require(ReplicatedStorage.CoreClient.CoreClient)
local Shared = ReplicatedStorage.Shared
local Hatchery = require(Shared.Hatchery)
local Layout = require(Shared.Layout)

local Context = require(script.Parent.Context)

local OddsView = {}

local displays: { [string]: any } = {}
local listeners: { () -> () } = {}
local ctx: Context.Context

function OddsView.start(context: Context.Context)
	ctx = context
	CoreClient.onOdds(function(display: any)
		if type(display) == "table" and type(display.tableId) == "string" then
			displays[display.tableId] = display
			for _, listener in listeners do
				task.spawn(listener)
			end
		end
	end)
	for eggId in ctx.config.economy.conveyor.weights do
		CoreClient.requestOdds(eggId)
	end
end

function OddsView.onChanged(listener: () -> ())
	table.insert(listeners, listener)
end

-- Whether the player can see what this egg may hatch, so it may be sold.
function OddsView.ready(eggId: string): boolean
	return ctx.restricted() or displays[eggId] ~= nil
end

-- Row height in pixels: 22 on the odds card, 16 on the board over the belt,
-- which lists up to 15 rows per egg.
local rowHeight = 22

local function row(parent: Instance, order: number, left: string, right: string, color: Color3, bold: boolean)
	local frame = Instance.new("Frame")
	frame.Name = `Row{order}`
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, rowHeight)
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(0.5, 1)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	name.TextScaled = true
	name.TextColor3 = color
	name.Text = left
	name.Parent = frame
	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.Position = UDim2.fromScale(0.5, 0)
	value.Size = UDim2.fromScale(0.5, 1)
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.Font = Enum.Font.GothamBold
	value.TextScaled = true
	value.TextColor3 = Color3.new(1, 1, 1)
	value.Text = right
	value.Parent = frame
	frame.Parent = parent
end

-- Fills `container` (which should have a UIListLayout) with one egg's odds.
-- `compact` is the board over the belt: names without the rarity word (the
-- colour says it) and the exact percentage only. The card beside the Buy
-- prompt always shows the full rows.
function OddsView.render(container: GuiObject, eggId: string, compact: boolean?)
	rowHeight = if compact then 16 else 22
	for _, child in container:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	local egg = Hatchery.eggById(ctx.config.eggs, eggId)
	if egg == nil then
		return
	end
	local species = ctx.config.creatures.species
	local price = if egg.priceCoins then `{Layout.shortNumber(egg.priceCoins)} coins` else "Robux"
	row(container, 0, Layout.displayName(egg.id), price, Color3.new(1, 1, 1), true)

	if ctx.restricted() then
		local data = ctx.data()
		local bought = if data then data.eggsBought[egg.id] or 0 else 0
		local nextId = Hatchery.fixedOrderOutcome(egg, bought)
		row(container, 1, "Fixed order, no chance involved:", "", Color3.fromRGB(200, 200, 200), false)
		local cycle = #Hatchery.fixedOrderCycle(egg)
		for i, outcome in egg.outcomes do
			local rarity = species[outcome.id].rarity
			local wait = Hatchery.fixedOrderWait(egg, bought, outcome.id)
			local isNext = outcome.id == nextId
			local count = outcome.weight * cycle // (egg.total or 10000)
			row(
				container,
				i + 1,
				`{Layout.displayName(outcome.id)} ({rarity}): {count} in every {cycle}`,
				if isNext then "NEXT" elseif wait then `in {wait + 1} eggs` else "",
				Layout.rarityColor(rarity),
				isNext
			)
		end
		return
	end

	local display = displays[eggId]
	if display == nil then
		row(container, 1, "Loading odds...", "", Color3.fromRGB(200, 200, 200), false)
		return
	end
	if #display.boosts > 0 then
		row(
			container,
			1,
			`Boosted: {table.concat(display.boosts, ", ")}`,
			"",
			Color3.fromRGB(255, 220, 90),
			true
		)
	end
	for i, r in display.rows do
		local rarity = if species[r.id] then species[r.id].rarity else "Common"
		row(
			container,
			i + 1,
			if compact then Layout.displayName(r.id) else `{Layout.displayName(r.id)} ({rarity})`,
			if compact then r.percent else `{r.percent} · {r.oneIn}`,
			Layout.rarityColor(rarity),
			false
		)
	end
end

return OddsView
