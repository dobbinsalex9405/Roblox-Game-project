--!strict
-- The Creatures window (Alex, Nov 12): everything the player owns, placed or
-- stashed, in the style of the egg chances screen. A row of square rarity
-- tabs (All, Common ... Godly) with the player's best creature of that tier
-- on each face and how many they own; a search box, filters (All, Placed,
-- Stashed, Can merge) and an order (best first, newest, A to Z); then a grid
-- of cards: picture, name and stars, coins per second, where it is.
--
-- Tap a card and its actions take the toolbar's place: Merge (3 alike make
-- one with a star more, shared/Merge), Stash or Place, and the floor buttons
-- to move it. The header has Merge all (tap twice: it uses copies up) and
-- Place best. Phone first: every button at least 40 px, text at least 12.
--
-- The client only asks; the server checks every move (Actions).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Book = require(Shared.Book)
local Hatchery = require(Shared.Hatchery)
local InventoryList = require(Shared.InventoryList)
local Layout = require(Shared.Layout)
local Merge = require(Shared.Merge)
local Tower = require(Shared.Tower)

local Context = require(script.Parent.Context)
local RarityTabs = require(script.Parent.RarityTabs)
local Sfx = require(script.Parent.Sfx)

local InventoryView = {}

-- Redraws the open window; set by start.
InventoryView.redraw = function() end

local PANEL = Color3.fromRGB(28, 30, 48)
local CARD = Color3.fromRGB(44, 47, 72)
local CHIP = Color3.fromRGB(58, 60, 88)
local GOLD = Color3.fromRGB(255, 210, 63)
local GREEN = Color3.fromRGB(80, 200, 100)
local BLUE = Color3.fromRGB(70, 150, 230)
local PURPLE = Color3.fromRGB(150, 95, 230)
local GREY = Color3.fromRGB(110, 110, 125)
local SHADOW = Color3.fromRGB(16, 16, 26)
local SOFT = Color3.fromRGB(210, 210, 225)
local ALL_COLOR = Color3.fromRGB(235, 235, 245)
local FONT = Enum.Font.FredokaOne

local TAP = 40 -- px: the phone tap minimum
local CARD_HEIGHT = 64
local CARD_MIN_WIDTH = 168
local PAGE = 90 -- cards drawn at once; "Show more" adds the next lot
local CONFIRM_SECONDS = 3 -- Merge all waits this long for its second tap

export type Menu = {
	add: (name: string, text: string, onClick: () -> ()) -> TextButton,
}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function label(parent: Instance, name: string, value: string, size: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextSize = size
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Text = value
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	local s = Instance.new("UIStroke")
	s.Thickness = 1.5
	s.Color = SHADOW
	s.Parent = l
	l.Parent = parent
	return l
end

local function button(parent: Instance, name: string, text: string, color: Color3, width: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.fromOffset(width, TAP)
	b.BackgroundColor3 = color
	b.Font = FONT
	b.TextSize = 15
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.AutoButtonColor = true
	corner(b, 8)
	stroke(b, SHADOW, 1.5)
	b.Parent = parent
	return b
end

local function row(parent: Instance, name: string, order: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.LayoutOrder = order
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, TAP)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = f
	f.Parent = parent
	return f
end

-- A horizontal strip of buttons that scrolls sideways when it runs out of room.
local function strip(parent: Instance, name: string, order: number): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.Name = name
	s.LayoutOrder = order
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.Size = UDim2.new(1, 0, 0, TAP + 6)
	s.CanvasSize = UDim2.fromScale(0, 0)
	s.AutomaticCanvasSize = Enum.AutomaticSize.X
	s.ScrollingDirection = Enum.ScrollingDirection.X
	s.ScrollBarThickness = 4
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = s
	s.Parent = parent
	return s
end

local function clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function InventoryView.start(ctx: Context.Context, menu: Menu)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local config = ctx.config
	local economy = config.economy

	local gui = Instance.new("ScreenGui")
	gui.Name = "CreaturesMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 23
	gui.Enabled = false
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Window"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.BackgroundColor3 = PANEL
	corner(frame, 16)
	stroke(frame, GOLD, 3)
	frame.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = frame
	local stack = Instance.new("UIListLayout")
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Padding = UDim.new(0, 6)
	stack.Parent = frame

	---------------------------------------------------------------- header
	local header = row(frame, "Header", 1)
	local title = label(header, "Title", "Your Creatures", 22, GOLD)
	title.LayoutOrder = 1
	title.Size = UDim2.new(0, 170, 1, 0)
	local counts = label(header, "Counts", "", 13, SOFT)
	counts.LayoutOrder = 2
	counts.TextWrapped = true
	counts.TextTruncate = Enum.TextTruncate.None
	local mergeAll = button(header, "MergeAll", "Merge all", PURPLE, 112)
	mergeAll.LayoutOrder = 3
	local placeBest =
		button(header, "PlaceBest", "Place best", GOLD:Lerp(Color3.fromRGB(200, 120, 0), 0.4), 112)
	placeBest.LayoutOrder = 4
	local close = button(header, "Close", "X", Color3.fromRGB(215, 70, 70), 44)
	close.LayoutOrder = 5
	close.TextSize = 22

	------------------------------------------------------------------ tabs
	local tabHolder = Instance.new("Frame")
	tabHolder.Name = "Tabs"
	tabHolder.LayoutOrder = 2
	tabHolder.BackgroundTransparency = 1
	tabHolder.AutomaticSize = Enum.AutomaticSize.Y
	tabHolder.Size = UDim2.new(1, 0, 0, 0)
	tabHolder.Parent = frame

	--------------------------------------------------------------- toolbar
	local toolbar = row(frame, "Toolbar", 3)
	local search = Instance.new("TextBox")
	search.Name = "Search"
	search.LayoutOrder = 1
	search.Size = UDim2.fromOffset(170, TAP)
	search.BackgroundColor3 = Color3.fromRGB(18, 19, 32)
	search.Font = FONT
	search.TextSize = 15
	search.TextColor3 = Color3.new(1, 1, 1)
	search.PlaceholderText = "Search names"
	search.PlaceholderColor3 = GREY
	search.Text = ""
	search.ClearTextOnFocus = false
	search.TextXAlignment = Enum.TextXAlignment.Left
	local searchPad = Instance.new("UIPadding")
	searchPad.PaddingLeft = UDim.new(0, 10)
	searchPad.Parent = search
	corner(search, 8)
	stroke(search, GREY, 1.5)
	search.Parent = toolbar
	local filterButtons: { [string]: TextButton } = {}
	for i, f in InventoryList.FILTERS do
		local b = button(
			toolbar,
			`Filter{f}`,
			InventoryList.FILTER_LABELS[f],
			CHIP,
			if f == "Merge" then 104 else 84
		)
		b.LayoutOrder = 1 + i
		filterButtons[f] = b
	end
	local sortButton = button(toolbar, "Sort", "", CHIP, 112)
	sortButton.LayoutOrder = 10

	------------------------------------------- the picked creature's actions
	local actions = Instance.new("Frame")
	actions.Name = "Actions"
	actions.LayoutOrder = 3
	actions.BackgroundTransparency = 1
	actions.Size = UDim2.new(1, 0, 0, TAP + 6)
	actions.Visible = false
	actions.Parent = frame
	local actionInfo = label(actions, "Picked", "", 14)
	actionInfo.Size = UDim2.new(0, 190, 1, 0)
	actionInfo.TextWrapped = true
	actionInfo.TextTruncate = Enum.TextTruncate.None
	actionInfo.TextYAlignment = Enum.TextYAlignment.Center
	local actionStrip = strip(actions, "Buttons", 1)
	actionStrip.Position = UDim2.fromOffset(196, 0)
	actionStrip.Size = UDim2.new(1, -196, 1, 0)

	------------------------------------------------------------------ grid
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.LayoutOrder = 4
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.CanvasSize = UDim2.fromScale(0, 0)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollBarThickness = 6
	grid.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	grid.Parent = frame
	local cells = Instance.new("UIGridLayout")
	cells.SortOrder = Enum.SortOrder.LayoutOrder
	cells.CellPadding = UDim2.fromOffset(6, 6)
	cells.Parent = grid
	local empty = label(frame, "Empty", "", 15, SOFT)
	empty.LayoutOrder = 5
	empty.Size = UDim2.new(1, 0, 0, 0)
	empty.TextWrapped = true
	empty.TextXAlignment = Enum.TextXAlignment.Center
	empty.Visible = false

	-------------------------------------------------------------- state
	local tier: string? = nil -- nil = All
	local filter: InventoryList.Filter = "All"
	local sortIndex = 1
	local picked: string? = nil
	local shown = PAGE
	local confirmUntil = 0
	local tabs: RarityTabs.RarityTabs? = nil
	local tabWidth = 0

	local function carried(): { [string]: boolean }
		return {} -- the server refuses carried creatures and says why
	end

	-- Sizes the window to the screen: as wide as fits (up to 820), as tall
	-- as fits (up to 560), the grid taking what the rows above leave.
	local function fit()
		local screen = gui.AbsoluteSize
		if screen.X < 10 then
			screen = Vector2.new(1280, 720)
		end
		local width = math.min(820, screen.X - 16)
		local height = math.min(560, screen.Y - 12)
		frame.Size = UDim2.fromOffset(width, height)
		local inner = width - 20
		counts.Size = UDim2.new(0, math.max(80, inner - 170 - 112 - 112 - 44 - 24), 1, 0)
		local cols = math.max(2, math.floor((inner - 12) / CARD_MIN_WIDTH))
		local cardWidth = math.floor((inner - 12 - 6 * (cols - 1)) / cols)
		cells.CellSize = UDim2.fromOffset(cardWidth, CARD_HEIGHT)
		if tabs and tabWidth ~= inner then
			tabWidth = inner
			tabs:resize(inner)
		end
		local above = TAP + tabHolder.AbsoluteSize.Y + (TAP + 6) + 6 * 3 + 16
		grid.Size = UDim2.new(1, 0, 0, math.max(CARD_HEIGHT + 8, height - above))
	end

	-- One card: picture, name and stars, coins per second, where it is.
	local function card(entry: InventoryList.Entry, order: number, d: { [string]: any })
		local c = entry.creature
		local color = Layout.rarityColor(entry.rarity)
		local isPicked = picked == c.uid
		local b = Instance.new("TextButton")
		b.Name = `Creature{c.uid}`
		b.LayoutOrder = order
		b.Text = ""
		b.AutoButtonColor = true
		b.BackgroundColor3 = if isPicked then CARD:Lerp(color, 0.3) else CARD
		corner(b, 10)
		stroke(b, if isPicked then Color3.new(1, 1, 1) else color, if isPicked then 3 else 2)
		local pic = Instance.new("ImageLabel")
		pic.Name = "Picture"
		pic.BackgroundColor3 = color:Lerp(PANEL, 0.7)
		pic.Position = UDim2.fromOffset(4, 4)
		pic.Size = UDim2.fromOffset(CARD_HEIGHT - 8, CARD_HEIGHT - 8)
		pic.ScaleType = Enum.ScaleType.Fit
		pic.Image = Book.picture(c.speciesId) or ""
		corner(pic, 8)
		pic.Parent = b
		if pic.Image == "" then
			local initial = label(pic, "Initial", string.sub(entry.name, 1, 1), 24, color)
			initial.Size = UDim2.fromScale(1, 1)
			initial.TextXAlignment = Enum.TextXAlignment.Center
		end
		local x = CARD_HEIGHT + 2
		local name = label(b, "Name", entry.name, 15, color)
		name.Position = UDim2.fromOffset(x, 4)
		name.Size = UDim2.new(1, -x - 4, 0, 18)
		local stars = Merge.stars(c)
		local rate = `{Layout.shortNumber(entry.income)}/s`
		local line = label(b, "Rate", if stars > 1 then `{Layout.stars(stars)} · {rate}` else rate, 13, GOLD)
		line.Position = UDim2.fromOffset(x, 23)
		line.Size = UDim2.new(1, -x - 4, 0, 16)
		local where = if c.uid == d.mountUid
			then "Riding"
			elseif c.uid == d.guardUid then "Guarding"
			elseif c.slot then `Floor {Tower.floorOf(c.slot)}`
			else "Stashed"
		local place = label(b, "Where", where, 13, if c.slot then GREEN else SOFT)
		place.Position = UDim2.fromOffset(x, 41)
		place.Size = UDim2.new(1, -x - 4, 0, 16)
		if entry.canMerge then
			local badge = label(b, "Merge", "Merge!", 12, Color3.new(1, 1, 1))
			badge.AnchorPoint = Vector2.new(1, 1)
			badge.Position = UDim2.new(1, -4, 1, -4)
			badge.Size = UDim2.fromOffset(52, 18)
			badge.BackgroundTransparency = 0
			badge.BackgroundColor3 = PURPLE
			badge.TextXAlignment = Enum.TextXAlignment.Center
			corner(badge, 6)
		end
		b.Activated:Connect(function()
			Sfx.play("click")
			picked = if picked == c.uid then nil else c.uid
			InventoryView.redraw()
		end)
		b.Parent = grid
	end

	-- The picked creature's buttons, in the toolbar's place.
	local function drawActions(d: { [string]: any })
		clear(actionStrip)
		local c = if picked then Hatchery.creatureByUid(d, picked) else nil
		if c == nil then
			picked = nil
			actions.Visible = false
			toolbar.Visible = true
			return
		end
		actions.Visible = true
		toolbar.Visible = false
		local species = config.creatures.species[c.speciesId]
		local rarity = if species then species.rarity else "Common"
		local stars = Merge.stars(c)
		actionInfo.Text = `{Layout.displayName(c.speciesId)}{Layout.stars(stars)}`
		actionInfo.TextColor3 = Layout.rarityColor(rarity)
		local order = 0
		local function add(name: string, text: string, color: Color3, width: number): TextButton
			order += 1
			local b = button(actionStrip, name, text, color, width)
			b.LayoutOrder = order
			return b
		end
		local blocked = Merge.blocked(d, c, economy, carried())
		local have = Merge.count(d, c, economy, carried())
		local need = economy.merge.copies
		if stars < economy.merge.maxStars then
			local m = add(
				"Merge",
				if blocked then "Merge" else `Merge {math.min(have, need)}/{need}`,
				if blocked == nil and have >= need then PURPLE else GREY,
				120
			)
			m.Activated:Connect(function()
				Sfx.play("click")
				ctx.fire(ctx.remotes["HH:Merge"], c.uid)
			end)
		end
		if c.slot then
			local s = add("Stash", "Stash", BLUE, 92)
			s.Activated:Connect(function()
				Sfx.play("click")
				ctx.fire(ctx.remotes["HH:TakeBack"], c.uid)
			end)
		else
			local full = Tower.full(d, config.creatures, economy)
			local p = add("Place", if full then "Tower full" else "Place", if full then GREY else GREEN, 110)
			p.Activated:Connect(function()
				Sfx.play("click")
				ctx.fire(ctx.remotes["HH:PlaceAuto"], c.uid)
			end)
		end
		-- One button per built floor: green with room, gold where it is.
		local used = Tower.occupancy(d, config.creatures, economy)
		local mine: { [number]: string } = {}
		for spot, uid in used do
			if uid ~= c.uid then
				mine[spot] = uid
			end
		end
		local size = Tower.size(c, config.creatures, economy)
		for floor = 1, Tower.owned(d) do
			local here = c.slot ~= nil and Tower.floorOf(c.slot) == floor
			local room = Tower.freeSpot(mine, floor, size) ~= nil
			local f = add(
				`Floor{floor}`,
				`F{floor}`,
				if here then GOLD elseif room then GREEN:Lerp(GREY, 0.4) else GREY,
				48
			)
			f.Activated:Connect(function()
				Sfx.play("click")
				ctx.fire(ctx.remotes["HH:Place"], c.uid, floor)
			end)
		end
		local done = add("Done", "Done", Color3.fromRGB(215, 70, 70), 72)
		done.Activated:Connect(function()
			Sfx.play("click")
			picked = nil
			InventoryView.redraw()
		end)
	end

	local function drawTabs(d: { [string]: any })
		local counted = InventoryList.tabs(d, config)
		local list: { RarityTabs.Tab } = {}
		local all: InventoryList.Tab = counted.All or { count = 0, face = nil }
		table.insert(list, {
			rarity = "All",
			face = all.face,
			caption = `{all.count} owned`,
			color = ALL_COLOR,
		})
		for _, rarity in Layout.RARITIES do
			local tab: InventoryList.Tab = counted[rarity] or { count = 0, face = nil }
			table.insert(list, {
				rarity = rarity,
				face = tab.face,
				caption = `{tab.count} owned`,
				locked = tab.count == 0,
			})
		end
		if tabs then
			tabs:destroy()
		end
		tabWidth = frame.AbsoluteSize.X - 20
		local made = RarityTabs.new(tabHolder, {
			tabs = list,
			onPick = function(rarity: string)
				Sfx.play("click")
				tier = if rarity == "All" then nil else rarity
				picked = nil
				shown = PAGE
				InventoryView.redraw()
			end,
			-- 88 px: the smallest tile whose count line still reads at 12 px;
			-- eight of them fit a phone held sideways.
			tileMin = 88,
			tileMax = 96,
			tileGap = 6,
		}, tabWidth, 1)
		made:select(tier or "All")
		tabs = made
	end

	local function draw()
		local d = ctx.data()
		if d == nil then
			return
		end
		fit()
		drawTabs(d)
		local stashed = Tower.stashed(d)
		local placed = #d.creatures - stashed
		counts.Text = `{placed} placed · {stashed}/{economy.storage.slots} stashed`
		for f, b in filterButtons do
			b.BackgroundColor3 = if f == filter then BLUE else CHIP
		end
		local sort: InventoryList.Sort = InventoryList.SORTS[sortIndex]
		sortButton.Text = InventoryList.SORT_LABELS[sort]
		drawActions(d)
		fit()

		clear(grid)
		local entries = InventoryList.build(d, config, {
			tier = tier,
			search = search.Text,
			filter = filter,
			sort = sort,
		}, carried())
		for i, entry in entries do
			if i > shown then
				local more = button(grid, "ShowMore", `Show more ({#entries - shown})`, CHIP, 120)
				more.LayoutOrder = i
				more.Activated:Connect(function()
					Sfx.play("click")
					shown += PAGE
					InventoryView.redraw()
				end)
				break
			end
			card(entry, i, d)
		end
		empty.Visible = #entries == 0
		empty.Size = UDim2.new(1, 0, 0, if #entries == 0 then 40 else 0)
		empty.Text = if #d.creatures == 0
			then "No creatures yet. Buy an egg at the Egg Market and hatch it!"
			elseif
				filter == "Merge"
			then "Nothing to merge here yet: you need 3 of one creature with the same stars."
			else "No creatures match."
	end
	InventoryView.redraw = draw

	-------------------------------------------------------------- wiring
	close.Activated:Connect(function()
		Sfx.play("click")
		gui.Enabled = false
	end)
	placeBest.Activated:Connect(function()
		Sfx.play("reward")
		ctx.fire(ctx.remotes["HH:PlaceBest"])
	end)
	mergeAll.Activated:Connect(function()
		local now = os.clock()
		if now > confirmUntil then
			Sfx.play("click")
			confirmUntil = now + CONFIRM_SECONDS
			mergeAll.Text = "Tap again"
			task.delay(CONFIRM_SECONDS, function()
				if os.clock() >= confirmUntil then
					mergeAll.Text = "Merge all"
				end
			end)
			return
		end
		confirmUntil = 0
		mergeAll.Text = "Merge all"
		Sfx.play("reward")
		ctx.fire(ctx.remotes["HH:MergeAll"])
	end)
	for f, b in filterButtons do
		b.Activated:Connect(function()
			Sfx.play("click")
			filter = f :: InventoryList.Filter
			shown = PAGE
			draw()
		end)
	end
	sortButton.Activated:Connect(function()
		Sfx.play("click")
		sortIndex = sortIndex % #InventoryList.SORTS + 1
		draw()
	end)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		if gui.Enabled then
			shown = PAGE
			draw()
		end
	end)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if gui.Enabled then
			fit()
		end
	end)

	menu.add("Creatures", "🐾 Pets", function()
		Sfx.play("click")
		if gui.Enabled then
			gui.Enabled = false
		else
			picked = nil
			shown = PAGE
			gui.Enabled = true
			draw()
		end
	end)

	-- Redraw an open window when what it shows changes (a move, a stash, a
	-- merge, a hatch), never on every coin.
	local last = ""
	ctx.onData(function(d: { [string]: any })
		if not gui.Enabled then
			last = ""
			return
		end
		local parts = { tostring(Tower.owned(d)), d.mountUid, d.guardUid }
		for _, c in d.creatures do
			table.insert(parts, `{c.uid}:{c.slot or 0}:{Merge.stars(c)}`)
		end
		local key = table.concat(parts, ",")
		if key ~= last then
			last = key
			draw()
		end
	end)
end

return InventoryView
