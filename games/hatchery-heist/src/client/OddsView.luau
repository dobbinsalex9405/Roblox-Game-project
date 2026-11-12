--!strict
-- Shows exact odds before every egg purchase. The numbers come from the
-- server's odds table for this player (the same table the hatch rolls from,
-- boosts included), never from client config. Until they arrive, eggs cannot
-- be bought. Players who may not receive paid random items see the fixed
-- order their eggs hatch in instead, with the next one marked.
--
-- Eggs roll a tier, then a creature in it, so the card and the board show
-- one line per tier: the tier's exact share is the sum of its creatures'
-- weights. The card's "See chances" button opens the chances screen: a tab
-- per tier, and behind each the exact chance of every creature of it in the
-- egg, which paid random items must show before purchase however many
-- creatures there are.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local CoreClient = require(ReplicatedStorage.CoreClient.CoreClient)
local Modal = require(ReplicatedStorage.CoreClient.Modal)
local Odds = require(ReplicatedStorage.Core.Odds)
local Shared = ReplicatedStorage.Shared
local Eggs = require(Shared.Eggs)
local Hatchery = require(Shared.Hatchery)
local OddsCard = require(Shared.OddsCard)
local OddsTiers = require(Shared.OddsTiers)
local Layout = require(Shared.Layout)

local Context = require(script.Parent.Context)
local RarityTabs = require(script.Parent.RarityTabs)

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
local rowHeight = OddsCard.ROW
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
-- `indent` px at the left of every row are kept for its picture.
local function sameTextSize(container: GuiObject, largest: number?, indent: number?)
	local left = indent or 0
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
	local rowWidth = width
	width -= left
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
		-- The value's share of the whole row, which includes the indent.
		local share = OddsCard.valueShare(widthOf(r.value, size), rowWidth)
		local function settle(l: TextLabel)
			l.TextScaled = false
			l.TextSize = size
			l.TextTruncate = Enum.TextTruncate.AtEnd
		end
		settle(r.name)
		r.name.Position = UDim2.fromOffset(left, 0)
		r.name.Size = UDim2.new(1 - share, -left, 1, 0)
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

-- The card's button that opens the egg's chances screen (OddsView.openList).
-- OddsCard.BUTTON px tall, so it is 40 px or more even at the card's
-- smallest scale on a phone. With a `heading` (the egg's name and price)
-- it is the card's top line: the heading over `text`, so the card needs no
-- separate title line and a coin egg's seven tiers fit under it.
local function listButton(container: GuiObject, eggId: string, text: string, order: number, heading: string?)
	local button = Instance.new("TextButton")
	button.Name = "SeeEvery"
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, OddsCard.BUTTON)
	button.BackgroundColor3 = Color3.fromRGB(70, 110, 200)
	button.Font = FONT
	button.TextSize = 17
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = if heading then "" else text
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = button
	if heading then
		local size = OddsCard.MIN_TEXT_SIZE
		local function line(name: string, value: string, y: number, color: Color3)
			local l = Instance.new("TextLabel")
			l.Name = name
			l.BackgroundTransparency = 1
			l.Position = UDim2.new(0, 6, 0.5, y)
			l.Size = UDim2.new(1, -12, 0, size + 2)
			l.Font = FONT
			l.TextSize = size
			l.TextColor3 = color
			l.TextTruncate = Enum.TextTruncate.AtEnd
			l.Text = value
			l.Parent = button
		end
		line("Heading", heading, -(size + 2), Color3.new(1, 1, 1))
		line("Action", text, 1, Color3.fromRGB(255, 225, 120))
	end
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

	if ctx.restricted() then
		row(container, 0, Layout.displayName(egg.id), price, Color3.new(1, 1, 1), true)
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
		listButton(container, eggId, "See the whole order", 100)
		return
	end

	local display = displays[eggId]
	if display == nil then
		row(container, 0, Layout.displayName(egg.id), price, Color3.new(1, 1, 1), true)
		row(container, 1, "Loading odds...", "", Color3.fromRGB(200, 200, 200), false)
		return
	end
	-- The card's top line: the egg's name and price on the button that opens
	-- every creature's chance. Then one line per tier.
	listButton(container, eggId, "See chances  >", 1, `{Layout.displayName(egg.id)} · {price}`)
	if #display.boosts > 0 then
		row(
			container,
			2,
			`Boosted: {table.concat(display.boosts, ", ")}`,
			"",
			Color3.fromRGB(255, 220, 90),
			true
		)
	end
	for i, tier in OddsView.tiers(display) do
		row(
			container,
			i + 2,
			tier.rarity,
			`{OddsCard.shortPercent(tier.percent)} · {tier.oneIn}`,
			Layout.rarityColor(tier.rarity),
			false
		)
	end
end

function OddsView.render(container: GuiObject, eggId: string)
	fill(container, eggId)
	-- Every line at the card's text size (OddsCard.MIN_TEXT_SIZE: 11 px or
	-- more on a phone); a long name ends in "..." before its odds do.
	sameTextSize(container, OddsCard.MIN_TEXT_SIZE)
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

-- The chances screen, opened from the odds card (Alex, Nov 12): one square
-- tab per rarity tier with a standout creature on its face, its exact
-- chance and how many creatures it holds; tapping a tab lists every
-- creature of that tier with its picture and exact chance. The numbers are
-- the server's table for this player, the same one the hatch rolls from.
-- A player under the fixed-order rule sees the whole order instead.
local look = (require(ReplicatedStorage.GameConfig.atmosphere) :: any).oddsScreen
local HEADER = 40 -- the header's buttons: tall enough to tap on a phone
local EGG_TAB_WIDTH = 96
local CLOSE_WIDTH = 44
local BACK_WIDTH = 84
local LIST_TEXT_SIZE = 15
local TAB_GAP = 6
local PAD = 10
-- Under this window width the egg tabs get their own row below the title.
local ONE_HEADER_ROW = 600
local TIER_BAR = 32
local DARK_TEXT = Color3.fromRGB(20, 20, 28)
local LOCKED = RarityTabs.LOCKED
local tabsView: RarityTabs.RarityTabs? = nil -- the open screen's tier tabs
local rowsIndent = 0 -- px kept for pictures at the left of the list's rows
local listTier: string? = nil -- the tier whose creatures are open, nil for the tabs

local function label(parent: Instance, name: string, text: string, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextSize = size
	l.TextColor3 = color
	l.Text = text
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

local function button(parent: Instance, name: string, text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.BackgroundColor3 = color
	b.Font = FONT
	b.TextSize = 15
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.TextTruncate = Enum.TextTruncate.AtEnd
	corner(b, 8)
	b.Parent = parent
	return b
end

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
	window.Size = UDim2.new(1, -24, 1, -90)
	window.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	corner(window, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 210, 63)
	stroke.Thickness = 3
	stroke.Parent = window
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(look.maxWidth, look.maxHeight)
	limit.Parent = window
	window.Parent = gui

	local back = button(window, "Back", "< Back", Color3.fromRGB(70, 70, 122))
	back.Position = UDim2.fromOffset(PAD, 8)
	back.Size = UDim2.fromOffset(BACK_WIDTH, HEADER)
	back.Visible = false
	local title = label(window, "Title", "", 20, Color3.fromRGB(255, 220, 90))
	title.TextXAlignment = Enum.TextXAlignment.Left
	local close = button(window, "Close", "X", Color3.fromRGB(215, 70, 70))
	close.Name = "Close" -- the Modal guard test finds windows by this line
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 8)
	close.Size = UDim2.fromOffset(CLOSE_WIDTH, HEADER)
	close.TextSize = 22
	close.Activated:Connect(function()
		listEgg = nil
		listTier = nil
		gui.Enabled = false
	end)
	-- Reachable in first person too: frees the mouse, closes on a tap
	-- outside, gamepad B or Escape (CoreClient/Modal).
	Modal.attach(gui, window, function()
		listEgg = nil
		listTier = nil
		gui.Enabled = false
	end)
	-- One tab per belt egg: a rare egg rides past its Buy prompt in about a
	-- second (Studio gate, #131: Moonlit 0.98 s), too short to reach its
	-- card's button, so any egg's screen opens every other egg's.
	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.BackgroundTransparency = 1
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, TAB_GAP)
	tabLayout.Parent = tabs
	tabs.Parent = window

	-- The tier tabs, then a line on what tapping one does.
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollBarThickness = 6
	grid.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	local gridLayout = Instance.new("UIListLayout")
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.Padding = UDim.new(0, 10)
	gridLayout.Parent = grid
	local hint = label(
		grid,
		"Hint",
		"Tap a rarity to see every creature in it and its exact chance",
		15,
		Color3.fromRGB(205, 205, 215)
	)
	hint.LayoutOrder = 2
	hint.Size = UDim2.new(1, -8, 0, 22)
	hint.TextWrapped = true
	hint.AutomaticSize = Enum.AutomaticSize.Y
	hint.TextTruncate = Enum.TextTruncate.None
	grid.Parent = window

	-- A tier's header bar above its creatures.
	local bar = Instance.new("Frame")
	bar.Name = "TierBar"
	bar.Visible = false
	corner(bar, 8)
	local barName = label(bar, "Name", "", 17, DARK_TEXT)
	barName.TextXAlignment = Enum.TextXAlignment.Left
	barName.Position = UDim2.fromOffset(10, 0)
	barName.Size = UDim2.new(0.55, -10, 1, 0)
	local barValue = label(bar, "Value", "", 15, DARK_TEXT)
	barValue.TextXAlignment = Enum.TextXAlignment.Right
	barValue.Position = UDim2.fromScale(0.55, 0)
	barValue.Size = UDim2.new(0.45, -10, 1, 0)
	bar.Parent = window

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Rows"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
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
	scroll.Visible = false
	scroll.Parent = window
	return gui
end

-- How a tier's chance reads on its tab: "1 in N", or the share under 1 in 2.
local function tileChance(tier: OddsTiers.Tier): string
	if not tier.inEgg then
		return "Not in egg"
	end
	return Odds.formatOneIn(tier.weight, tier.total)
end

local function plural(n: number, one: string): string
	return if n == 1 then `1 {one}` else `{Layout.shortNumber(n)} {one}s`
end

-- The tier bar's two texts side by side at one size, 17 px down to 13: the
-- chance gets the width it needs and the name the rest (it ends in "..."
-- before the chance is ever cut).
local function fitBar(bar: Frame)
	local name = bar:FindFirstChild("Name") :: TextLabel
	local value = bar:FindFirstChild("Value") :: TextLabel
	local width = bar.AbsoluteSize.X - 20
	if width <= 0 then
		return
	end
	local bounds = Vector2.new(10000, 10000)
	local size = 17
	local nameWidth, valueWidth = 0, 0
	while true do
		nameWidth = TextService:GetTextSize(name.Text, size, name.Font, bounds).X
		valueWidth = TextService:GetTextSize(value.Text, size, value.Font, bounds).X
		if size <= 13 or OddsCard.fits(nameWidth, valueWidth, width) then
			break
		end
		size -= 1
	end
	name.TextSize = size
	value.TextSize = size
	local valueBox = math.min(width, valueWidth + 4)
	value.Position = UDim2.new(1, -(10 + valueBox), 0, 0)
	value.Size = UDim2.new(0, valueBox, 1, 0)
	name.Position = UDim2.fromOffset(10, 0)
	name.Size = UDim2.new(1, -(20 + valueBox + OddsCard.GAP), 1, 0)
end

-- A creature's line in a tier's list: picture, name, exact chance.
local function creatureRow(parent: Instance, order: number, id: string, value: string, color: Color3)
	local h = look.rowHeight
	local frame = Instance.new("Frame")
	frame.Name = `Row{order}`
	frame.LayoutOrder = order
	frame.BackgroundTransparency = if order % 2 == 0 then 1 else 0.94
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BorderSizePixel = 0
	frame.Size = UDim2.new(1, 0, 0, h)
	local well = Instance.new("Frame")
	well.Name = "Well"
	well.BackgroundTransparency = 1
	well.AnchorPoint = Vector2.new(0, 0.5)
	well.Position = UDim2.new(0, 2, 0.5, 0)
	well.Size = UDim2.fromOffset(look.rowPicture, look.rowPicture)
	well.Parent = frame
	-- Pictures only: a tier holds up to hundreds of creatures, too many
	-- live models for a phone.
	RarityTabs.picture(well, id, false, false)
	local name = label(frame, "Name", Layout.displayName(id), LIST_TEXT_SIZE, color)
	name.Font = Enum.Font.GothamBold
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Position = UDim2.fromOffset(look.rowPicture + 10, 0)
	name.Size = UDim2.new(0.5, -(look.rowPicture + 10), 1, 0)
	local v = label(frame, "Value", value, LIST_TEXT_SIZE, Color3.new(1, 1, 1))
	v.TextXAlignment = Enum.TextXAlignment.Right
	v.Position = UDim2.fromScale(0.5, 0)
	v.Size = UDim2.fromScale(0.5, 1)
	frame.Parent = parent
end

function OddsView.openList(eggId: string, rarity: string?)
	local playerGui = ctx.player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("OddsList") :: ScreenGui?
	local list: ScreenGui = existing or buildList()
	list.Parent = playerGui
	local window = list:FindFirstChild("Window") :: Frame
	local scroll = window:FindFirstChild("Rows") :: ScrollingFrame
	local grid = window:FindFirstChild("Grid") :: ScrollingFrame
	local hint = grid:FindFirstChild("Hint") :: TextLabel
	local bar = window:FindFirstChild("TierBar") :: Frame
	local title = window:FindFirstChild("Title") :: TextLabel
	local back = window:FindFirstChild("Back") :: TextButton
	local tabs = window:FindFirstChild("Tabs") :: Frame
	local previous = if list.Enabled then listEgg else nil
	local previousTier = if list.Enabled then listTier else nil
	listEgg = eggId
	-- A tab switch keeps the open tier, so a player can compare eggs.
	listTier = if rarity ~= nil then rarity elseif previous ~= nil then listTier else nil
	local egg = Hatchery.eggById(ctx.config.eggs, eggId)
	local species = ctx.config.creatures.species
	local restricted = ctx.restricted()
	local ids = Hatchery.marketEggs(ctx.config.eggs, ctx.config.economy.conveyor.weights)
	-- An egg sold elsewhere (Premium Egg): its own screen, no egg tabs.
	local showTabs = table.find(ids, eggId) ~= nil

	local function renderTabs()
		for _, child in tabs:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		tabs.Visible = showTabs
		if not showTabs then
			return
		end
		for i, id in ids do
			local on = id == eggId
			local tab = button(
				tabs,
				id,
				(string.gsub(Layout.displayName(id), " Egg$", "")),
				if on then Color3.fromRGB(255, 200, 70) else Color3.fromRGB(55, 55, 75)
			)
			tab.LayoutOrder = i
			tab.Size = UDim2.new(0, EGG_TAB_WIDTH, 1, 0)
			tab.AutoButtonColor = not on
			tab.TextColor3 = if on then Color3.fromRGB(30, 25, 10) else Color3.new(1, 1, 1)
			tab.Activated:Connect(function()
				if id ~= listEgg then
					OddsView.openList(id)
				end
			end)
		end
	end

	-- The header and the content area for the window's width: on a narrow
	-- screen the egg tabs take a row of their own under the title.
	local function place()
		local width = window.AbsoluteSize.X
		local wide = width >= ONE_HEADER_ROW
		local titleLeft = if back.Visible then PAD + BACK_WIDTH + 8 else PAD + 4
		local right = CLOSE_WIDTH + 16
		local tabsWidth = if showTabs then #ids * EGG_TAB_WIDTH + (#ids - 1) * TAB_GAP else 0
		local top = 8 + HEADER + 8
		local tabLayout = tabs:FindFirstChildOfClass("UIListLayout") :: UIListLayout
		tabLayout.HorizontalAlignment = if wide
			then Enum.HorizontalAlignment.Right
			else Enum.HorizontalAlignment.Center
		if showTabs and wide then
			tabs.AnchorPoint = Vector2.new(1, 0)
			tabs.Position = UDim2.new(1, -right, 0, 8)
			tabs.Size = UDim2.fromOffset(tabsWidth, HEADER)
			title.Size = UDim2.new(1, -(titleLeft + right + tabsWidth + 8), 0, HEADER)
		else
			tabs.AnchorPoint = Vector2.zero
			tabs.Position = UDim2.fromOffset(PAD, top)
			tabs.Size = UDim2.new(1, -2 * PAD, 0, HEADER)
			title.Size = UDim2.new(1, -(titleLeft + right), 0, HEADER)
			if showTabs then
				top += HEADER + 8
			end
		end
		title.Position = UDim2.fromOffset(titleLeft, 8)
		grid.Position = UDim2.fromOffset(PAD, top)
		grid.Size = UDim2.new(1, -2 * PAD, 1, -(top + PAD))
		bar.Position = UDim2.fromOffset(PAD, top)
		bar.Size = UDim2.new(1, -2 * PAD, 0, TIER_BAR)
		local rowsTop = if bar.Visible then top + TIER_BAR + 6 else top
		scroll.Position = UDim2.fromOffset(PAD, rowsTop)
		scroll.Size = UDim2.new(1, -2 * PAD, 1, -(rowsTop + PAD))
	end

	local function clear(container: Instance)
		for _, child in container:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	-- The whole fixed order, soonest first, for a player under that rule.
	local function renderOrder()
		if egg == nil then
			return
		end
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
		local saved = rowHeight
		rowHeight = 24
		-- The wait gets its own column, wide enough for "in 25011 eggs"
		-- (Studio gate, #126: "· in 2…").
		rowSplit = 1 -- one line across the whole row
		row(scroll, 0, `How many of every {cycle} eggs:`, "", Color3.fromRGB(200, 200, 200), false)
		rowSplit = 0.62
		for i, line in lines do
			local r = species[line.id].rarity
			row(
				scroll,
				i,
				`{Layout.displayName(line.id)} ({line.count})`,
				waitText(line.wait),
				Layout.rarityColor(r),
				line.wait == 0
			)
		end
		rowSplit = 0.5
		rowHeight = saved
		for _, frame in scroll:GetChildren() do
			for _, l in frame:GetChildren() do
				if l:IsA("TextLabel") then
					l.TextScaled = false
					l.TextSize = LIST_TEXT_SIZE
				end
			end
		end
		sameTextSize(scroll, LIST_TEXT_SIZE)
	end

	local function tiersNow(): { OddsTiers.Tier }?
		local display = displays[eggId]
		if display == nil then
			return nil
		end
		return OddsTiers.build(display, species, Eggs.RARITIES, look.faces)
	end

	-- The tabs, as big as fit the window's width.
	local function renderGrid(tiers: { OddsTiers.Tier })
		title.Text = `{Layout.displayName(eggId)} chances`
		if tabsView then
			tabsView:destroy()
		end
		local tabList: { RarityTabs.Tab } = {}
		local every = 0
		for _, tier in tiers do
			every += #tier.members
			table.insert(tabList, {
				rarity = tier.rarity,
				face = tier.face,
				caption = tileChance(tier),
				under = if tier.inEgg then plural(#tier.members, "creature") else "In other eggs",
				locked = not tier.inEgg,
			})
		end
		-- Before the window is drawn its width is 0: the first draw resizes
		-- it and this runs again.
		tabsView = RarityTabs.new(grid, {
			tabs = tabList,
			onPick = function(rarity: string)
				OddsView.openList(eggId, rarity)
			end,
		}, grid.AbsoluteSize.X - grid.ScrollBarThickness, 1)
		hint.Text =
			`Tap a rarity to see every creature in it and its exact chance. {plural(every, "creature")} can hatch from this egg.`
	end

	-- One tier's creatures, standouts first, each with its exact chance.
	local function renderTier(tier: OddsTiers.Tier)
		title.Text = Layout.displayName(eggId)
		local color = if tier.inEgg then Layout.rarityColor(tier.rarity) else LOCKED
		bar.BackgroundColor3 = color
		local barName = bar:FindFirstChild("Name") :: TextLabel
		local barValue = bar:FindFirstChild("Value") :: TextLabel
		if not tier.inEgg then
			barName.Text = tier.rarity
			barValue.Text = "Not in this egg"
			barName.TextColor3 = Color3.new(1, 1, 1)
			barValue.TextColor3 = Color3.new(1, 1, 1)
			local where = OddsTiers.eggsWith(ctx.config.eggs, species, tier.rarity)
			local names = {}
			for _, id in where do
				table.insert(names, Layout.displayName(id))
			end
			local text = if #names > 0
				then `{tier.rarity} creatures hatch from: {table.concat(names, ", ")}`
				else `No egg hatches {tier.rarity} creatures yet`
			local note = label(scroll, "Note", text, LIST_TEXT_SIZE, Color3.fromRGB(220, 220, 230))
			note.Size = UDim2.new(1, 0, 0, 44)
			note.TextWrapped = true
			note.TextTruncate = Enum.TextTruncate.None
			note.TextXAlignment = Enum.TextXAlignment.Left
			return
		end
		barName.TextColor3 = DARK_TEXT
		barValue.TextColor3 = DARK_TEXT
		barName.Text = `{tier.rarity} · {plural(#tier.members, "creature")}`
		barValue.Text =
			`{Odds.formatPercent(tier.weight, tier.total)} · {Odds.formatOneIn(tier.weight, tier.total)}`
		for i, m in tier.members do
			creatureRow(
				scroll,
				i,
				m.id,
				`{Odds.formatPercent(m.weight, tier.total)} · {Odds.formatOneIn(m.weight, tier.total)}`,
				color
			)
		end
		-- Each value gets the room it needs and its name the rest, so a long
		-- name is shortened before any odds are.
		rowsIndent = look.rowPicture + 10
		sameTextSize(scroll, LIST_TEXT_SIZE, rowsIndent)
	end

	local function render()
		clear(scroll)
		rowsIndent = 0
		local tiers = if restricted then nil else tiersNow()
		local open: OddsTiers.Tier? = nil
		if tiers and listTier then
			for _, tier in tiers do
				if tier.rarity == listTier then
					open = tier
				end
			end
		end
		back.Visible = open ~= nil
		bar.Visible = open ~= nil
		grid.Visible = not restricted and open == nil
		scroll.Visible = restricted or open ~= nil
		place()
		if restricted then
			renderOrder()
		elseif tiers == nil then
			title.Text = `{Layout.displayName(eggId)} chances`
			if tabsView then
				tabsView:destroy()
				tabsView = nil
			end
			hint.Text = "Loading odds..."
		elseif open then
			renderTier(open)
			fitBar(bar)
		else
			listTier = nil
			renderGrid(tiers)
		end
	end

	if not window:GetAttribute("Wired") then
		window:SetAttribute("Wired", true)
		back.Activated:Connect(function()
			if listEgg then
				listTier = nil
				OddsView.openList(listEgg)
			end
		end)
		-- The header depends on the window's width, the tiles on the grid's
		-- and the rows' columns on the list's: all known once drawn.
		window:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if list.Enabled and renderList then
				renderList()
			end
		end)
		bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			fitBar(bar)
		end)
		grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if tabsView then
				tabsView:resize(grid.AbsoluteSize.X - grid.ScrollBarThickness)
			end
		end)
		scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			sameTextSize(scroll, LIST_TEXT_SIZE, rowsIndent)
		end)
	end
	renderTabs()
	renderList = render
	list.Enabled = true
	if previous ~= eggId or previousTier ~= listTier then
		-- Another list starts at its top (Studio gate, #131: a tab switch
		-- kept the old scroll position).
		scroll.CanvasPosition = Vector2.zero
		grid.CanvasPosition = Vector2.zero
	end
	render()
end

return OddsView
