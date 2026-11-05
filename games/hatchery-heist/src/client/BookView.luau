--!strict
-- The Hatchery Book (the pet index): every creature in the game on a card,
-- one tab per rarity tier. Creatures the player has owned show in colour with
-- their name; the rest are dark silhouettes marked "???", so there is always
-- something to chase. Each card shows the best egg for it and the exact
-- chance (the same numbers as the odds card), hidden where paid random items
-- are restricted. The header counts the book ("Found 7/53") and its capped
-- income bonus. Cards found since the book was last opened say NEW, and the
-- side-menu button counts them.
--
-- Built for hundreds of cards: a tab's cards are plain frames, and only the
-- ones on screen (and a row either side) hold a 3D model, so a long Common
-- page never has more than a few dozen ViewportFrames alive.
-- Opened from the side menu; the server keeps the book (data.found).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Odds = require(ReplicatedStorage.Core.Odds)
local Shared = ReplicatedStorage.Shared
local Book = require(Shared.Book)
local Layout = require(Shared.Layout)

local Context = require(script.Parent.Context)
local CreatureView = require(script.Parent.CreatureView)
local OddsView = require(script.Parent.OddsView)
local Sfx = require(script.Parent.Sfx)

local BookView = {}

local PANEL = Color3.fromRGB(28, 30, 48)
local GOLD = Color3.fromRGB(255, 210, 63)
local SHADOW = Color3.fromRGB(16, 16, 26)
local FONT = Enum.Font.FredokaOne
local CARD = Vector2.new(104, 150)
local RED = Color3.fromRGB(230, 60, 60)

export type Menu = {
	add: (name: string, text: string, onClick: () -> ()) -> TextButton,
}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function text(parent: Instance, name: string, value: string, size: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextSize = size
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Text = value
	local s = Instance.new("UIStroke")
	s.Thickness = 1.5
	s.Color = SHADOW
	s.Parent = l
	l.Parent = parent
	return l
end

type Card = {
	frame: Frame,
	entry: Book.Entry,
	view: ViewportFrame,
	camera: Camera,
	model: Model?,
	looks: { [BasePart]: { color: Color3, material: Enum.Material } },
	name: TextLabel,
	odds: TextLabel,
	new: TextLabel,
	found: boolean?,
}

type Tab = {
	rarity: string,
	button: TextButton,
	label: TextLabel,
	dot: Frame,
	grid: Frame?,
	cards: { Card },
	entries: { Book.Entry },
}

-- Puts a creature's model in a card and points the camera at it. A creature
-- not found yet is darkened BEFORE it goes in the card, so it never shows in
-- colour, not even for a frame (Studio gate, Nov 5).
local function showModel(card: Card, owned: boolean)
	local model, size = CreatureView.staticModel(card.entry.speciesId)
	card.looks = {}
	card.found = owned
	if model == nil then
		return
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			card.looks[p] = { color = p.Color, material = p.Material }
			if not owned then
				p.Color = SHADOW
				p.Material = Enum.Material.SmoothPlastic
			end
		end
	end
	model.Parent = card.view
	local fitSize = math.max(size.X, size.Y, size.Z)
	local distance = (fitSize / 2) / math.tan(math.rad(15)) * 1.2
	local target = Vector3.new(0, size.Y / 2, 0)
	local offset = CFrame.Angles(0, math.rad(-28), 0) * CFrame.Angles(math.rad(-12), 0, 0)
	card.camera.CFrame = CFrame.lookAt(target + offset * Vector3.new(0, 0, -distance), target)
	card.model = model
end

local function dropModel(card: Card)
	if card.model then
		card.model:Destroy()
		card.model = nil
		card.looks = {}
	end
end

function BookView.start(ctx: Context.Context, menu: Menu)
	local player = Players.LocalPlayer
	local species = ctx.config.creatures.species
	local bookConfig = ctx.config.economy.book
	local gui = Instance.new("ScreenGui")
	gui.Name = "HatcheryBook"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.BackgroundColor3 = PANEL
	corner(window, 16)
	stroke(window, GOLD, 3)
	window.Parent = gui

	local title = text(window, "Title", "Hatchery Book", 30, GOLD)
	title.Position = UDim2.fromOffset(16, 8)
	title.Size = UDim2.new(1, -80, 0, 36)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(44, 40)
	close.BackgroundColor3 = Color3.fromRGB(215, 70, 70)
	close.Font = FONT
	close.TextSize = 24
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Text = "X"
	corner(close, 10)
	close.Parent = window

	local summary = text(window, "Summary", "", 17)
	summary.Position = UDim2.fromOffset(16, 46)
	summary.Size = UDim2.new(1, -32, 0, 22)
	summary.TextXAlignment = Enum.TextXAlignment.Left

	local bar = Instance.new("Frame")
	bar.Name = "Progress"
	bar.Position = UDim2.fromOffset(16, 74)
	bar.Size = UDim2.new(1, -32, 0, 12)
	bar.BackgroundColor3 = SHADOW
	corner(bar, 6)
	bar.Parent = window
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(110, 220, 120)
	fill.Size = UDim2.fromScale(0, 1)
	corner(fill, 6)
	fill.Parent = bar

	-- One tab per tier, scrolling sideways on a narrow phone.
	local tabBar = Instance.new("ScrollingFrame")
	tabBar.Name = "Tabs"
	tabBar.BackgroundTransparency = 1
	tabBar.Position = UDim2.fromOffset(12, 94)
	tabBar.Size = UDim2.new(1, -24, 0, 46)
	tabBar.CanvasSize = UDim2.fromScale(0, 0)
	tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
	tabBar.ScrollingDirection = Enum.ScrollingDirection.X
	tabBar.ScrollBarThickness = 4
	tabBar.BorderSizePixel = 0
	local tabList = Instance.new("UIListLayout")
	tabList.FillDirection = Enum.FillDirection.Horizontal
	tabList.SortOrder = Enum.SortOrder.LayoutOrder
	tabList.Padding = UDim.new(0, 4)
	tabList.Parent = tabBar
	local tabPad = Instance.new("UIPadding")
	tabPad.PaddingTop = UDim.new(0, 4)
	tabPad.PaddingLeft = UDim.new(0, 4)
	tabPad.PaddingRight = UDim.new(0, 4)
	tabPad.Parent = tabBar
	tabBar.Parent = window

	local body = Instance.new("ScrollingFrame")
	body.Name = "Pages"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(10, 146)
	body.Size = UDim2.new(1, -20, 1, -154)
	body.CanvasSize = UDim2.fromScale(0, 0)
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollBarThickness = 6
	body.BorderSizePixel = 0
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)
	pad.Parent = body
	body.Parent = window

	local function fit()
		local cam = Workspace.CurrentCamera
		local screen = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		window.Size = UDim2.fromOffset(math.min(760, screen.X - 24), math.min(560, screen.Y - 40))
	end

	local entries = Book.entries(ctx.config.creatures, ctx.config.eggs, Layout.RARITIES)
	local tabs: { Tab } = {}
	local tabOf: { [string]: Tab } = {}
	for _, entry in entries do
		local tab = tabOf[entry.rarity]
		if tab == nil then
			local color = Layout.rarityColor(entry.rarity)
			local button = Instance.new("TextButton")
			button.Name = `Tab{entry.rank}`
			button.LayoutOrder = entry.rank
			button.Size = UDim2.fromOffset(0, 36)
			button.AutomaticSize = Enum.AutomaticSize.X
			button.Text = ""
			button.BackgroundColor3 = color:Lerp(SHADOW, 0.7)
			corner(button, 10)
			stroke(button, color, 2)
			local bpad = Instance.new("UIPadding")
			bpad.PaddingLeft = UDim.new(0, 8)
			bpad.PaddingRight = UDim.new(0, 8)
			bpad.Parent = button
			button.Parent = tabBar
			local label = text(button, "Label", entry.rarity, 14)
			label.Size = UDim2.fromScale(0, 1)
			label.AutomaticSize = Enum.AutomaticSize.X
			-- A red dot while the tier has NEW cards.
			local dot = Instance.new("Frame")
			dot.Name = "New"
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Position = UDim2.new(1, 10, 0, -2)
			dot.Size = UDim2.fromOffset(12, 12)
			dot.BackgroundColor3 = RED
			dot.Visible = false
			corner(dot, 6)
			dot.Parent = button
			tab = {
				rarity = entry.rarity,
				button = button,
				label = label,
				dot = dot,
				grid = nil,
				cards = {},
				entries = {},
			}
			tabOf[entry.rarity] = tab
			table.insert(tabs, tab)
		end
		table.insert(tab.entries, entry)
	end

	local current: Tab? = nil
	local seenAt = 0 -- the book's last opening, as it stood when this one began

	-- A tab's cards, built the first time it is shown: frames only, no models.
	local function buildTab(tab: Tab)
		local grid = Instance.new("Frame")
		grid.Name = `Cards{tab.rarity}`
		grid.BackgroundTransparency = 1
		grid.Size = UDim2.fromScale(1, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.fromOffset(CARD.X, CARD.Y)
		layout.CellPadding = UDim2.fromOffset(8, 8)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		grid.Parent = body
		tab.grid = grid
		local color = Layout.rarityColor(tab.rarity)
		for i, entry in tab.entries do
			local frame = Instance.new("Frame")
			frame.Name = entry.speciesId
			frame.LayoutOrder = i
			frame.BackgroundColor3 = color:Lerp(SHADOW, 0.78)
			corner(frame, 12)
			stroke(frame, color, 2)
			frame.Parent = grid

			local view = Instance.new("ViewportFrame")
			view.Name = "View"
			view.BackgroundTransparency = 1
			view.Position = UDim2.fromOffset(4, 4)
			view.Size = UDim2.fromOffset(CARD.X - 8, CARD.X - 8)
			view.Ambient = Color3.fromRGB(170, 170, 185)
			view.LightDirection = Vector3.new(-0.6, -1, 0.5)
			view.Parent = frame
			local camera = Instance.new("Camera")
			camera.FieldOfView = 30
			camera.Parent = view
			view.CurrentCamera = camera

			local name = text(frame, "Species", "", 14)
			name.Position = UDim2.fromOffset(4, CARD.X - 6)
			name.Size = UDim2.new(1, -8, 0, 18)
			name.TextScaled = true
			local cap = Instance.new("UITextSizeConstraint")
			cap.MaxTextSize = 14
			cap.Parent = name
			local odds = text(frame, "Odds", "", 13, Color3.fromRGB(255, 226, 120))
			odds.Position = UDim2.fromOffset(2, CARD.X + 12)
			odds.Size = UDim2.new(1, -4, 0, 32)
			odds.TextWrapped = true
			odds.TextYAlignment = Enum.TextYAlignment.Top

			local new = text(frame, "NewBadge", "NEW", 13)
			new.BackgroundTransparency = 0
			new.BackgroundColor3 = RED
			new.Position = UDim2.fromOffset(4, 4)
			new.Size = UDim2.fromOffset(40, 20)
			new.ZIndex = 2
			new.Visible = false
			corner(new, 8)

			table.insert(tab.cards, {
				frame = frame,
				entry = entry,
				view = view,
				camera = camera,
				model = nil,
				looks = {},
				name = name,
				odds = odds,
				new = new,
				found = nil,
			})
		end
	end

	-- Models only for the cards on screen and a row either side.
	local function cull()
		local tab = current
		if tab == nil or not gui.Enabled then
			return
		end
		local d = ctx.data()
		local found = if d then d.found or {} else {}
		local top = body.AbsolutePosition.Y - CARD.Y
		local bottom = body.AbsolutePosition.Y + body.AbsoluteSize.Y + CARD.Y
		for _, card in tab.cards do
			local y = card.frame.AbsolutePosition.Y
			local near = y + CARD.Y >= top and y <= bottom
			if near and card.model == nil then
				showModel(card, found[card.entry.speciesId] ~= nil)
			elseif not near and card.model then
				dropModel(card)
			end
		end
	end

	local function paintCard(card: Card, found: { [string]: any }, restricted: boolean)
		local entry = card.entry
		local owned = found[entry.speciesId] ~= nil
		if card.found ~= owned then
			card.found = owned
			-- Not found yet: a dark silhouette, glow and all switched off.
			for part, look in card.looks do
				part.Color = if owned then look.color else SHADOW
				part.Material = if owned then look.material else Enum.Material.SmoothPlastic
			end
			card.name.Text = if owned then Layout.displayName(entry.speciesId) else "???"
		end
		card.new.Visible = Book.isNew(found, entry.speciesId, seenAt)
		if entry.eggId and not restricted then
			-- The player's own odds (boosts included) once the server sent
			-- them, so the book never disagrees with the odds card.
			local oneIn = OddsView.oneIn(entry.eggId, entry.speciesId)
				or Odds.formatOneIn(entry.weight, entry.total)
			card.odds.Text = `{Layout.displayName(entry.eggId)}\n{oneIn}`
		else
			card.odds.Text = ""
		end
	end

	local function refresh()
		local d = ctx.data()
		local found = if d then d.found or {} else {}
		local restricted = ctx.restricted()
		local counts = Book.tiers(found, species)
		local have, total = 0, 0
		for _, tab in tabs do
			local tier = counts[tab.rarity] or { have = 0, total = 0 }
			have += tier.have
			total += tier.total
			tab.label.Text = `{tab.rarity}  {tier.have}/{tier.total}`
			local anyNew = false
			for _, entry in tab.entries do
				if Book.isNew(found, entry.speciesId, seenAt) then
					anyNew = true
					break
				end
			end
			tab.dot.Visible = anyNew
			local selected = tab == current
			local color = Layout.rarityColor(tab.rarity)
			tab.button.BackgroundColor3 = if selected
				then color:Lerp(SHADOW, 0.25)
				else color:Lerp(SHADOW, 0.7)
			for _, card in tab.cards do
				paintCard(card, found, restricted)
			end
		end
		local bonus = Book.bonus(found, species, bookConfig)
		local pct = math.floor(bonus * 1000 + 0.5) / 10
		local cap = math.floor(bookConfig.maxBonus * 1000 + 0.5) / 10
		summary.Text = `Found {have}/{total}  ·  Income +{pct}% (max +{cap}%)`
		fill.Size = UDim2.fromScale(if total > 0 then have / total else 0, 1)
	end

	local function selectTab(tab: Tab)
		if current and current ~= tab then
			for _, card in current.cards do
				dropModel(card)
			end
			if current.grid then
				current.grid.Visible = false
			end
		end
		current = tab
		if tab.grid == nil then
			buildTab(tab)
		end
		(tab.grid :: Frame).Visible = true
		body.CanvasPosition = Vector2.zero
		refresh()
		cull()
		-- Layout settles a frame later; cull again once it has.
		task.defer(cull)
	end

	for _, tab in tabs do
		tab.button.Activated:Connect(function()
			Sfx.play("click")
			selectTab(tab)
		end)
	end
	body:GetPropertyChangedSignal("CanvasPosition"):Connect(cull)
	body:GetPropertyChangedSignal("AbsoluteSize"):Connect(cull)

	-- The side-menu button counts the NEW cards.
	local button: TextButton
	local badge = Instance.new("TextLabel")

	local function newCount(): number
		local d = ctx.data()
		if d == nil then
			return 0
		end
		return Book.newCount(d.found, species, d.bookSeenAt or 0)
	end

	local function setOpen(open: boolean)
		if open then
			local d = ctx.data()
			seenAt = if d then d.bookSeenAt or 0 else 0
			fit()
			gui.Enabled = true
			-- Open on the first tier with NEW cards, else where the player was.
			local pick = current or tabs[1]
			if d then
				for _, tab in tabs do
					local hasNew = false
					for _, entry in tab.entries do
						if Book.isNew(d.found, entry.speciesId, seenAt) then
							hasNew = true
							break
						end
					end
					if hasNew then
						pick = tab
						break
					end
				end
			end
			if pick then
				selectTab(pick)
			end
			if newCount() > 0 then
				ctx.fire(ctx.remotes["HH:BookSeen"])
			end
		else
			gui.Enabled = false
			if current then
				for _, card in current.cards do
					dropModel(card)
				end
			end
			-- Anything found while the book was open has now been seen.
			if newCount() > 0 then
				ctx.fire(ctx.remotes["HH:BookSeen"])
			end
		end
	end

	close.Activated:Connect(function()
		Sfx.play("click")
		setOpen(false)
	end)
	button = menu.add("Book", "📗 Book", function()
		Sfx.play("click")
		setOpen(not gui.Enabled)
	end)
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromOffset(4, 4)
	badge.Size = UDim2.fromOffset(24, 22)
	badge.BackgroundColor3 = RED
	badge.Font = FONT
	badge.TextSize = 15
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.Visible = false
	corner(badge, 11)
	badge.Parent = button

	local function onChange()
		local n = newCount()
		badge.Visible = n > 0 and not gui.Enabled
		badge.Text = if n > 9 then "9+" else tostring(n)
		if gui.Enabled then
			refresh()
		end
	end
	ctx.onData(onChange)
	OddsView.onChanged(onChange)
	gui:GetPropertyChangedSignal("Enabled"):Connect(onChange)
end

return BookView
