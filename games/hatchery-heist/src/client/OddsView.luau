--!strict
-- Shows exact odds before every egg purchase. The numbers come from the
-- server's odds table for this player (the same table the hatch rolls from,
-- boosts included), never from client config. Until they arrive, eggs cannot
-- be bought. Players who may not receive paid random items see the fixed
-- order their eggs hatch in instead, with the next one marked.
--
-- Eggs roll a tier, then a creature in it, so the card and the board show
-- one line per tier: the tier's exact share is the sum of its creatures'
-- weights. The card's "See every creature" button opens the exact chance
-- of every creature in the egg, which paid random items must show before
-- purchase however many creatures there are.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local CoreClient = require(ReplicatedStorage.CoreClient.CoreClient)
local Odds = require(ReplicatedStorage.Core.Odds)
local Shared = ReplicatedStorage.Shared
local Eggs = require(Shared.Eggs)
local Hatchery = require(Shared.Hatchery)
local OddsCard = require(Shared.OddsCard)
local Layout = require(Shared.Layout)

local Context = require(script.Parent.Context)

local OddsView = {}

local FONT = Enum.Font.GothamBold
local listEgg: string? = nil -- the egg whose full list is open
local renderList: (() -> ())? = nil

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
			if listEgg == display.tableId and renderList then
				renderList()
			end
		end
	end)
	-- Every egg, not only the belt's: the hatch reveal shows the chance of
	-- whatever hatched, from any egg.
	for _, egg in ctx.config.eggs do
		CoreClient.requestOdds(egg.id)
	end
end

-- This player's chance of `outcomeId` from `eggId` as "1 in N", from the
-- server's odds (boosts included); nil until they have arrived.
function OddsView.oneIn(eggId: string, outcomeId: string): string?
	local display = displays[eggId]
	if display == nil or type(display.rows) ~= "table" then
		return nil
	end
	for _, row in display.rows do
		if row.id == outcomeId and type(row.oneIn) == "string" then
			return row.oneIn
		end
	end
	return nil
end

function OddsView.onChanged(listener: () -> ())
	table.insert(listeners, listener)
end

-- Whether the player can see what this egg may hatch, so it may be sold.
function OddsView.ready(eggId: string): boolean
	return ctx.restricted() or displays[eggId] ~= nil
end

-- Row height in pixels on the odds card, and the share of a row the left
-- text gets.
local rowHeight = 22
local rowSplit = 0.5

local function row(parent: Instance, order: number, left: string, right: string, color: Color3, bold: boolean)
	local frame = Instance.new("Frame")
	frame.Name = `Row{order}`
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, rowHeight)
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(rowSplit, 1)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	name.TextScaled = true
	name.TextColor3 = color
	name.Text = left
	name.Parent = frame
	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.BackgroundTransparency = 1
	value.Position = UDim2.fromScale(rowSplit, 0)
	value.Size = UDim2.fromScale(1 - rowSplit, 1)
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.Font = Enum.Font.GothamBold
	value.TextScaled = true
	value.TextColor3 = Color3.new(1, 1, 1)
	value.Text = right
	value.Parent = frame
	frame.Parent = parent
end

-- One text size for every row of a list. With TextScaled each label shrinks
-- to its own text, so long names (Thunder Griffin) came out smaller than
-- their neighbours. This finds the largest size at which every row's name
-- and value fit side by side and gives it to all of them, never below
-- MIN_TEXT_SIZE. Each value then gets the width its text needs and its
-- name the rest (OddsCard.valueShare), so if a row is still too long its
-- name ends in "...", never its odds. Before the list has a width on
-- screen, the labels keep TextScaled.
local MIN_TEXT_SIZE = OddsCard.MIN_TEXT_SIZE -- 11 px or more on screen at the card's smallest
local function sameTextSize(container: GuiObject, largest: number?)
	local width = container.AbsoluteSize.X
	local pad = container:FindFirstChildOfClass("UIPadding")
	if pad then
		width -= pad.PaddingLeft.Offset + pad.PaddingRight.Offset
	end
	if container:IsA("ScrollingFrame") then
		width -= container.ScrollBarThickness
	end
	-- The card is drawn smaller on a phone (UIScale): measure unscaled.
	local scaled = container:FindFirstAncestorWhichIsA("GuiObject")
	local scale = scaled and scaled:FindFirstChildOfClass("UIScale")
	if scale and scale.Scale > 0 then
		width /= scale.Scale
	end
	if width <= 4 then
		return
	end
	type Row = { name: TextLabel, value: TextLabel? }
	local rows: { Row } = {}
	for _, frame in container:GetChildren() do
		local name = frame:FindFirstChild("Name")
		local value = frame:FindFirstChild("Value")
		if name and name:IsA("TextLabel") then
			local hasValue = value ~= nil and value:IsA("TextLabel") and value.Text ~= ""
			table.insert(rows, { name = name, value = if hasValue then value :: TextLabel else nil })
		end
	end
	local bounds = Vector2.new(10000, 10000)
	local function widthOf(l: TextLabel?, size: number): number
		if l == nil then
			return 0
		end
		return TextService:GetTextSize(l.Text, size, l.Font, bounds).X
	end
	local size = largest or rowHeight - 4
	while size > MIN_TEXT_SIZE do
		local fits = true
		for _, r in rows do
			if not OddsCard.fits(widthOf(r.name, size), widthOf(r.value, size), width) then
				fits = false
				break
			end
		end
		if fits then
			break
		end
		size -= 1
	end
	for _, r in rows do
		local share = OddsCard.valueShare(widthOf(r.value, size), width)
		local function settle(l: TextLabel)
			l.TextScaled = false
			l.TextSize = size
			l.TextTruncate = Enum.TextTruncate.AtEnd
		end
		settle(r.name)
		r.name.Size = UDim2.fromScale(1 - share, 1)
		local value = r.value
		if value then
			settle(value)
			value.Position = UDim2.fromScale(1 - share, 0)
			value.Size = UDim2.fromScale(share, 1)
		end
	end
end

-- One line per tier, most common first: the tier's exact share of the
-- server's table (boosts included) as a percentage and as "1 in N".
function OddsView.tiers(display: any): { { rarity: string, weight: number, percent: string, oneIn: string } }
	local species = ctx.config.creatures.species
	local sums: { [string]: number } = {}
	for _, r in display.rows do
		local rarity = if species[r.id] then species[r.id].rarity else "Common"
		sums[rarity] = (sums[rarity] or 0) + r.weight
	end
	local out = {}
	for _, rarity in Eggs.RARITIES do
		local weight = sums[rarity]
		if weight then
			table.insert(out, {
				rarity = rarity,
				weight = weight,
				percent = Odds.formatPercent(weight, display.total),
				oneIn = Odds.formatOneIn(weight, display.total),
			})
		end
	end
	return out
end

-- The card's button that opens the egg's full list (OddsView.openList).
local function listButton(container: GuiObject, eggId: string, text: string)
	local button = Instance.new("TextButton")
	button.Name = "SeeEvery"
	button.LayoutOrder = 100
	button.Size = UDim2.new(1, 0, 0, 30)
	button.BackgroundColor3 = Color3.fromRGB(70, 110, 200)
	button.Font = FONT
	button.TextSize = 15
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = text
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = button
	button.Activated:Connect(function()
		OddsView.openList(eggId)
	end)
	button.Parent = container
end

-- How a fixed-order wait reads: 0 is the next egg.
local function waitText(wait: number): string
	return if wait == 0 then "NEXT" else `in {wait + 1} eggs`
end

-- Eggs of the fixed order shown one by one on the card; the rest is per
-- tier (Studio gate, #126: all 47 Basic Egg lines ran off the screen).
OddsView.FIXED_UPCOMING = 3

-- Eggs bought of this kind so far: where this player is in its fixed order.
local function boughtOf(eggId: string): number
	local data = ctx.data()
	return if data then data.eggsBought[eggId] or 0 else 0
end

-- Fills `container` (which should have a UIListLayout) with one egg's odds:
-- the card beside the Buy prompt.
local function fill(container: GuiObject, eggId: string)
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
		-- The next few eggs by name, then one line per tier: how many of
		-- every cycle and how soon its first one comes. The whole order is
		-- in the list.
		local function rarityOf(id: string): string
			return species[id].rarity
		end
		local summary = Hatchery.fixedOrderSummary(
			egg,
			boughtOf(egg.id),
			rarityOf,
			OddsView.FIXED_UPCOMING,
			Eggs.RARITIES
		)
		-- Short texts in columns sized to them, so the card keeps main's
		-- text size on a phone (Studio gate, #126: 5.6 px at 844x392).
		local grey = Color3.fromRGB(200, 200, 200)
		rowSplit = 1
		row(container, 1, "Fixed order, no chance:", "", grey, false)
		rowSplit = 0.66
		for n, id in summary.upcoming do
			local rarity = rarityOf(id)
			row(container, 1 + n, Layout.displayName(id), waitText(n - 1), Layout.rarityColor(rarity), n == 1)
		end
		rowSplit = 1
		row(container, 9, `Of every {summary.length} eggs:`, "", grey, false)
		rowSplit = 0.5
		for i, tier in summary.tiers do
			row(
				container,
				10 + i,
				`{tier.rarity} {tier.count}`,
				waitText(tier.wait),
				Layout.rarityColor(tier.rarity),
				false
			)
		end
		rowSplit = 0.5
		listButton(container, eggId, "See the whole order")
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
	for i, tier in OddsView.tiers(display) do
		row(
			container,
			i + 1,
			tier.rarity,
			`{tier.percent} · {tier.oneIn}`,
			Layout.rarityColor(tier.rarity),
			false
		)
	end
	listButton(container, eggId, "See every creature")
end

function OddsView.render(container: GuiObject, eggId: string)
	fill(container, eggId)
	sameTextSize(container)
end

-- The odds sign beside each Egg Market stop (Studio gate, Nov 5): three
-- big lines, readable from 10 studs on a phone. The egg's name and price,
-- then its two rarest tiers with their exact "1 in N". The odds card beside
-- the Buy prompt has every tier. `size` is the sign's face in pixels; every
-- line gets one text size, the largest that fits. A player under the
-- fixed-order rule sees that instead of chances.
OddsView.SIGN_PIXELS_PER_STUD = 40
OddsView.SIGN_TIERS = 2

function OddsView.signLines(eggId: string): { { text: string, color: Color3 } }
	local egg = Hatchery.eggById(ctx.config.eggs, eggId)
	if egg == nil then
		return {}
	end
	local price = if egg.priceCoins then ` · {Layout.shortNumber(egg.priceCoins)}` else ""
	local lines = { { text = `{Layout.displayName(egg.id)}{price}`, color = Color3.fromRGB(255, 210, 63) } }
	if ctx.restricted() then
		local grey = Color3.fromRGB(220, 220, 220)
		table.insert(lines, { text = "Set order, no chance", color = grey })
		table.insert(lines, { text = "Tap an egg to see it", color = grey })
		return lines
	end
	local rarest: { string } = {}
	for i = #Eggs.RARITIES, 1, -1 do
		local rarity = Eggs.RARITIES[i]
		if egg.tiers and egg.tiers[rarity] and #rarest < OddsView.SIGN_TIERS then
			table.insert(rarest, 1, rarity)
		end
	end
	local display = displays[eggId]
	for _, rarity in rarest do
		local oneIn = "..."
		if display then
			for _, tier in OddsView.tiers(display) do
				if tier.rarity == rarity then
					oneIn = tier.oneIn
				end
			end
		end
		table.insert(lines, { text = `{rarity} {oneIn}`, color = Layout.rarityColor(rarity) })
	end
	return lines
end

function OddsView.renderSign(container: GuiObject, eggId: string, size: Vector2)
	container:ClearAllChildren()
	local lines = OddsView.signLines(eggId)
	if #lines == 0 then
		return
	end
	local margin = 8
	local width = size.X - 2 * margin
	local line = math.floor((size.Y - 2 * margin) / #lines)
	local labels: { TextLabel } = {}
	for i, entry in lines do
		local l = Instance.new("TextLabel")
		l.Name = `Line{i}`
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(margin, margin + (i - 1) * line)
		l.Size = UDim2.fromOffset(width, line)
		l.Font = Enum.Font.GothamBold
		l.TextColor3 = entry.color
		l.TextStrokeTransparency = 0.3
		l.Text = entry.text
		l.Parent = container
		table.insert(labels, l)
	end
	local textSize = line - 2
	local bounds = Vector2.new(10000, 10000)
	while textSize > 8 do
		local fits = true
		for _, l in labels do
			if TextService:GetTextSize(l.Text, textSize, l.Font, bounds).X > width - 4 then
				fits = false
				break
			end
		end
		if fits then
			break
		end
		textSize -= 1
	end
	for _, l in labels do
		l.TextSize = textSize
	end
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

-- A window listing every creature an egg can hatch with its exact chance,
-- opened from the odds card: the same numbers the server rolls from.
local TAB_HEIGHT = 40 -- tall enough to tap on a phone
local LIST_WIDTH = 420
local LIST_TEXT_SIZE = 15
local TAB_GAP = 6
local function buildList(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "OddsList"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 25
	gui.Enabled = false
	local window = Instance.new("Frame")
	window.Name = "Window"
	-- Below the HUD's coin bar (8 + 64 px from the top), so a phone still
	-- shows the player's coins while the list is open.
	window.AnchorPoint = Vector2.new(0.5, 0)
	window.Position = UDim2.new(0.5, 0, 0, 80)
	-- 420 px wide where the screen allows, so "Dalmatian Pup (Common)" and
	-- its odds share a row in full (Studio gate, #131: names cut at 161 px).
	window.Size = UDim2.new(1, -24, 1, -90)
	window.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	corner(window, 12)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(LIST_WIDTH, 560)
	limit.Parent = window
	window.Parent = gui
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(14, 8)
	title.Size = UDim2.new(1, -76, 0, 32)
	title.Font = FONT
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(255, 220, 90)
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Parent = window
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 8)
	close.Size = UDim2.fromOffset(44, 40)
	close.BackgroundColor3 = Color3.fromRGB(215, 70, 70)
	close.Font = FONT
	close.TextSize = 22
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Text = "X"
	corner(close, 10)
	close.Activated:Connect(function()
		listEgg = nil
		gui.Enabled = false
	end)
	close.Parent = window
	-- One tab per belt egg: a rare egg rides past its Buy prompt in about a
	-- second (Studio gate, #131: Moonlit 0.98 s), too short to reach its
	-- card's button, so any egg's list opens every other egg's.
	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.BackgroundTransparency = 1
	tabs.Position = UDim2.fromOffset(10, 52)
	tabs.Size = UDim2.new(1, -20, 0, TAB_HEIGHT)
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, TAB_GAP)
	tabLayout.Parent = tabs
	tabs.Parent = window
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Rows"
	scroll.BackgroundTransparency = 1
	scroll.Position = UDim2.fromOffset(10, 52 + TAB_HEIGHT + 8)
	scroll.Size = UDim2.new(1, -20, 1, -(52 + TAB_HEIGHT + 8 + 10))
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 6
	scroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = scroll
	-- Rows stop short of the scroll bar: on a phone its 6 px cut off the end
	-- of every right-aligned "1 in N" (Studio gate, Nov 5).
	local inset = Instance.new("UIPadding")
	inset.PaddingRight = UDim.new(0, 10)
	inset.Parent = scroll
	scroll.Parent = window
	-- The rows' columns depend on the list's width, known once it is drawn.
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		sameTextSize(scroll, LIST_TEXT_SIZE)
	end)
	return gui
end

function OddsView.openList(eggId: string)
	local playerGui = ctx.player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("OddsList") :: ScreenGui?
	local list: ScreenGui = existing or buildList()
	list.Parent = playerGui
	local window = list:FindFirstChild("Window") :: Frame
	local scroll = window:FindFirstChild("Rows") :: ScrollingFrame
	local title = window:FindFirstChild("Title") :: TextLabel
	local tabs = window:FindFirstChild("Tabs") :: Frame
	local previous = if list.Enabled then listEgg else nil
	listEgg = eggId
	local function renderTabs()
		for _, child in tabs:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		local ids = Hatchery.marketEggs(ctx.config.eggs, ctx.config.economy.conveyor.weights)
		if table.find(ids, eggId) == nil then
			-- An egg sold elsewhere (Premium Egg): its own list, no tabs.
			tabs.Visible = false
			return
		end
		tabs.Visible = true
		for i, id in ids do
			local tab = Instance.new("TextButton")
			tab.Name = id
			tab.LayoutOrder = i
			tab.Size = UDim2.new(1 / #ids, -TAB_GAP * (#ids - 1) / #ids, 1, 0)
			tab.AutoButtonColor = id ~= eggId
			tab.BackgroundColor3 = if id == eggId
				then Color3.fromRGB(255, 200, 70)
				else Color3.fromRGB(55, 55, 75)
			tab.Font = FONT
			tab.TextSize = 15
			tab.TextColor3 = if id == eggId then Color3.fromRGB(30, 25, 10) else Color3.new(1, 1, 1)
			tab.TextTruncate = Enum.TextTruncate.AtEnd
			tab.Text = (string.gsub(Layout.displayName(id), " Egg$", ""))
			corner(tab, 8)
			tab.Activated:Connect(function()
				if id ~= eggId then
					OddsView.openList(id)
				end
			end)
			tab.Parent = tabs
		end
	end
	renderTabs()
	local function render()
		for _, child in scroll:GetChildren() do
			-- Keep the layout and the inset that holds rows off the scroll bar.
			if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
				child:Destroy()
			end
		end
		local species = ctx.config.creatures.species
		local saved = rowHeight
		rowHeight = 24
		local egg = Hatchery.eggById(ctx.config.eggs, eggId)
		if ctx.restricted() and egg then
			-- Every creature in the order it next comes, soonest first, with
			-- how many of every cycle it is. The wait gets its own column, wide
			-- enough for "in 25011 eggs" (Studio gate, #126: "· in 2…").
			title.Text = `{Layout.displayName(eggId)}: fixed order`
			local bought = boughtOf(eggId)
			local cycle = Hatchery.fixedOrderLength(egg)
			local lines = {}
			for _, outcome in egg.outcomes do
				local wait = Hatchery.fixedOrderWait(egg, bought, outcome.id)
				if wait then
					table.insert(lines, {
						id = outcome.id,
						wait = wait,
						count = outcome.weight * cycle // (egg.total or 10000),
					})
				end
			end
			table.sort(lines, function(a, b)
				return a.wait < b.wait
			end)
			rowSplit = 1 -- one line across the whole row
			row(scroll, 0, `How many of every {cycle} eggs:`, "", Color3.fromRGB(200, 200, 200), false)
			rowSplit = 0.62
			for i, line in lines do
				local rarity = species[line.id].rarity
				row(
					scroll,
					i,
					`{Layout.displayName(line.id)} ({line.count})`,
					waitText(line.wait),
					Layout.rarityColor(rarity),
					line.wait == 0
				)
			end
			rowSplit = 0.5
		else
			title.Text = `{Layout.displayName(eggId)}: every creature`
			local display = displays[eggId]
			if display == nil then
				rowHeight = saved
				return
			end
			for i, r in display.rows do
				local rarity = if species[r.id] then species[r.id].rarity else "Common"
				row(
					scroll,
					i,
					`{Layout.displayName(r.id)} ({rarity})`,
					`{r.percent} · {r.oneIn}`,
					Layout.rarityColor(rarity),
					false
				)
			end
		end
		rowHeight = saved
		for _, frame in scroll:GetChildren() do
			for _, l in frame:GetChildren() do
				if l:IsA("TextLabel") then
					l.TextScaled = false
					l.TextSize = LIST_TEXT_SIZE
					l.TextTruncate = Enum.TextTruncate.AtEnd
				end
			end
		end
		-- Each value gets the room it needs and its name the rest, so a
		-- long name is shortened before any odds are.
		sameTextSize(scroll, LIST_TEXT_SIZE)
	end
	renderList = render
	list.Enabled = true
	if previous ~= eggId then
		-- Another egg's list starts at its top (Studio gate, #131: a tab
		-- switch kept the old scroll position).
		scroll.CanvasPosition = Vector2.zero
	end
	render()
end

return OddsView
