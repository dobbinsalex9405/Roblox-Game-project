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
-- Built for hundreds of cards: the page is sized for the whole tab, but only
-- the cards on screen (and a couple of rows either side: config/atmosphere
-- book) exist. A small pool of card frames is moved to whichever cards
-- scroll into view (BookGrid), and only those cards are repainted when the
-- player's data changes. A 200-card tab costs the same as a 20-card one.
-- A card shows the creature's picture (Book.picture: a render of its
-- meshes, preloaded at join), black for one not found yet. A creature with
-- no current picture is drawn live in a ViewportFrame made when its card
-- arrives and destroyed when it leaves.
-- Opened from the side menu; the server keeps the book (data.found).

local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Odds = require(ReplicatedStorage.Core.Odds)
local Modal = require(ReplicatedStorage.CoreClient.Modal)
local Shared = ReplicatedStorage.Shared
local Book = require(Shared.Book)
local BookGrid = require(Shared.BookGrid)
local Layout = require(Shared.Layout)
local PreloadQueue = require(Shared.PreloadQueue)
local Viewport = require(Shared.Viewport)

local Context = require(script.Parent.Context)
local CreatureView = require(script.Parent.CreatureView)
local OddsView = require(script.Parent.OddsView)
local Sfx = require(script.Parent.Sfx)

local BookView = {}

local PANEL = Color3.fromRGB(28, 30, 48)
local GOLD = Color3.fromRGB(255, 210, 63)
local SHADOW = Color3.fromRGB(16, 16, 26)
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0) -- a picture's silhouette: no colour shows through
local FONT = Enum.Font.FredokaOne
local CARD = Vector2.new(104, 150)
local GRID: BookGrid.Spec = { width = CARD.X, height = CARD.Y, gap = 8 }
local PAD_TOP, PAD_SIDE, PAD_BOTTOM = 4, 4, 8
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

-- One pooled card frame, showing `entry` while it is bound to a place on
-- the page.
type Card = {
	frame: Frame,
	border: UIStroke,
	entry: Book.Entry?,
	picture: ImageLabel,
	view: ViewportFrame?,
	model: Model?,
	looks: { [BasePart]: { color: Color3, material: Enum.Material, texture: string } },
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
	entries: { Book.Entry },
}

-- Puts a creature in a card: its picture, or else its model with the camera
-- pointed at it. A creature not found yet is darkened BEFORE it shows, so it
-- never shows in colour, not even for a frame (Studio gate, Nov 5).
local function showModel(card: Card, entry: Book.Entry, owned: boolean)
	card.looks = {}
	card.found = owned
	local picture = Book.picture(entry.speciesId)
	if picture then
		card.picture.ImageColor3 = if owned then WHITE else BLACK
		card.picture.Image = picture
		card.picture.Visible = true
		return
	end
	local model, size = CreatureView.staticModel(entry.speciesId)
	if model == nil then
		return
	end
	local view = Instance.new("ViewportFrame")
	view.Name = "View"
	view.BackgroundTransparency = 1
	view.Position = UDim2.fromOffset(4, 4)
	view.Size = UDim2.fromOffset(CARD.X - 8, CARD.X - 8)
	view.Ambient = Color3.fromRGB(170, 170, 185)
	view.LightDirection = Vector3.new(-0.6, -1, 0.5)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = view
	view.CurrentCamera = camera
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local texture = if p:IsA("MeshPart") then p.TextureID else ""
			card.looks[p] = { color = p.Color, material = p.Material, texture = texture }
			if not owned then
				p.Color = SHADOW
				p.Material = Enum.Material.SmoothPlastic
				if p:IsA("MeshPart") then
					p.TextureID = "" -- a texture draws over Color: the silhouette would show
				end
			end
		end
	end
	model.Parent = view
	local fitSize = math.max(size.X, size.Y, size.Z)
	local distance = (fitSize / 2) / math.tan(math.rad(15)) * 1.2
	local target = Vector3.new(0, size.Y / 2, 0)
	local offset = CFrame.Angles(0, math.rad(-28), 0) * CFrame.Angles(math.rad(-12), 0, 0)
	camera.CFrame = CFrame.lookAt(target + offset * Vector3.new(0, 0, -distance), target)
	view.Parent = card.frame
	card.view = view
	card.model = model
end

local function dropModel(card: Card)
	card.picture.Visible = false
	card.picture.Image = ""
	if card.view then
		card.view:Destroy() -- the model and camera with it
		card.view = nil
	end
	card.model = nil
	card.looks = {}
end

function BookView.start(ctx: Context.Context, menu: Menu)
	local player = Players.LocalPlayer
	local species = ctx.config.creatures.species
	local bookConfig = ctx.config.economy.book
	-- How far past the view cards are drawn and kept built (config/atmosphere book).
	local bookLook = (require(ReplicatedStorage.GameConfig.atmosphere) :: any).book
	local overscan = bookLook.overscanRows :: number
	local warmCards = bookLook.warmCards :: number
	local warmPerFrame = bookLook.warmPerFrame :: number
	local warmDelay = bookLook.warmDelaySeconds :: number
	local gui = Instance.new("ScreenGui")
	gui.Name = "HatcheryBook"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	-- Children always draw over their parent and ZIndex sorts siblings, so a
	-- warming card at 0 hides wholly behind the card on screen at 1.
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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
	body.ScrollBarThickness = 6
	body.BorderSizePixel = 0
	body.Parent = window
	-- The page: as tall as the whole tab, holding only the pooled cards.
	local page = Instance.new("Frame")
	page.Name = "Cards"
	page.BackgroundTransparency = 1
	page.Position = UDim2.fromOffset(PAD_SIDE, PAD_TOP)
	page.Parent = body

	local function fit()
		local cam = Workspace.CurrentCamera
		local screen = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		window.Size = UDim2.fromOffset(Book.windowSize(screen.X, screen.Y, GuiService:GetGuiInset().Y))
	end
	-- Refit when the screen changes size (a window resized, a phone turned):
	-- Studio gate (#125) kept a desktop-sized Book on a phone, title cut off.
	Viewport.watch(Workspace, fit)

	local entries = Book.entries(ctx.config.creatures, ctx.config.eggs, Layout.RARITIES)

	-- Every Book picture loads now, while the player looks round, so a card
	-- shows its creature the moment it first scrolls into view: in page
	-- order (the Common tab first, as the Book opens there), several at a
	-- time, each through an ImageLabel so it is fetched as an image. Studio
	-- gate (#125): one call for all 114 left the first open blank for 1-3 s.
	-- A tab the player opens jumps the queue (selectTab below).
	local preload = PreloadQueue.new(Book.pictures(entries))
	for _ = 1, bookLook.preloadStreams :: number do
		task.spawn(function()
			while true do
				local batch: { Instance } = {}
				for _, picture in PreloadQueue.take(preload, bookLook.preloadBatch :: number) do
					local holder = Instance.new("ImageLabel")
					holder.Image = picture
					table.insert(batch, holder)
				end
				if #batch == 0 then
					break
				end
				pcall(ContentProvider.PreloadAsync, ContentProvider, batch)
			end
		end)
	end
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
				entries = {},
			}
			tabOf[entry.rarity] = tab
			table.insert(tabs, tab)
		end
		table.insert(tab.entries, entry)
	end

	local current: Tab? = nil
	local seenAt = 0 -- the book's last opening, as it stood when this one began
	local columns = 1
	local bound: { [number]: Card } = {} -- the current tab's cards in view, by index
	local pool: { Card } = {} -- card frames not in use

	local function makeCard(): Card
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromOffset(CARD.X, CARD.Y)
		frame.Visible = false
		corner(frame, 12)
		local border = Instance.new("UIStroke")
		border.Thickness = 2
		border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		border.Parent = frame
		frame.Parent = page

		-- The picture's dark well, under the creature's ViewportFrame: a
		-- card never shows a bare gap while its picture draws its first frame.
		local well = Instance.new("Frame")
		well.Name = "Well"
		well.BackgroundColor3 = SHADOW
		well.BackgroundTransparency = 0.45
		well.BorderSizePixel = 0
		well.Position = UDim2.fromOffset(4, 4)
		well.Size = UDim2.fromOffset(CARD.X - 8, CARD.X - 8)
		well.ZIndex = 0 -- under the picture, the name and the NEW badge (Sibling)
		corner(well, 10)
		well.Parent = frame

		-- The creature's picture, over the well (showModel).
		local picture = Instance.new("ImageLabel")
		picture.Name = "Picture"
		picture.BackgroundTransparency = 1
		picture.Position = UDim2.fromOffset(4, 4)
		picture.Size = UDim2.fromOffset(CARD.X - 8, CARD.X - 8)
		picture.ScaleType = Enum.ScaleType.Fit
		picture.ZIndex = 1
		picture.Visible = false
		picture.Parent = frame

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

		return {
			frame = frame,
			border = border,
			entry = nil,
			picture = picture,
			view = nil,
			model = nil,
			looks = {},
			name = name,
			odds = odds,
			new = new,
			found = nil,
		}
	end

	-- A card back to the pool: model gone, frame hidden.
	local function release(index: number)
		local card = bound[index]
		if card == nil then
			return
		end
		bound[index] = nil
		dropModel(card)
		card.entry = nil
		card.found = nil
		card.frame.Visible = false
		table.insert(pool, card)
	end

	local function releaseAll()
		for index in bound do
			release(index)
		end
	end

	local function paintCard(card: Card, found: { [string]: any }, restricted: boolean)
		local entry = card.entry
		if entry == nil then
			return
		end
		local owned = found[entry.speciesId] ~= nil
		if card.found ~= owned then
			card.found = owned
			-- Not found yet: a dark silhouette, glow and all switched off.
			card.picture.ImageColor3 = if owned then WHITE else BLACK
			for part, look in card.looks do
				part.Color = if owned then look.color else SHADOW
				part.Material = if owned then look.material else Enum.Material.SmoothPlastic
				if part:IsA("MeshPart") then
					part.TextureID = if owned then look.texture else ""
				end
			end
		end
		-- Every paint, not only on a change: a card whose model appeared
		-- first already counts as painted (Studio gate: "???" missing).
		local name = if owned then Layout.displayName(entry.speciesId) else "???"
		if card.name.Text ~= name then
			card.name.Text = name
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

	-- Sizes the page for the current tab at the page's width.
	local function layout()
		local tab = current
		local count = if tab then #tab.entries else 0
		columns = BookGrid.columns(body.AbsoluteWindowSize.X - 2 * PAD_SIDE, GRID)
		local height = BookGrid.height(count, columns, GRID)
		page.Size = UDim2.new(1, -2 * PAD_SIDE, 0, height)
		body.CanvasSize = UDim2.fromOffset(0, height + PAD_TOP + PAD_BOTTOM)
		for index, card in bound do
			local x, y = BookGrid.position(index, columns, GRID)
			card.frame.Position = UDim2.fromOffset(x, y)
		end
	end

	-- The cards on screen (no overscan), the drawn range (those and
	-- `overscan` rows either side) and the wider warm range kept built
	-- around it (BookGrid.warm).
	local viewFirst, viewLast = 1, 0
	local drawnFirst, drawnLast, warmFirst, warmLast = 1, 0, 1, 0
	local shownAt = 0 -- when the current tab was shown (os.clock)

	-- A pooled card for the current tab's card `index`, model and all.
	local function bind(tab: Tab, index: number, found: { [string]: any }, restricted: boolean)
		local entry = tab.entries[index]
		local card = table.remove(pool) or makeCard()
		card.entry = entry
		local color = Layout.rarityColor(entry.rarity)
		card.frame.BackgroundColor3 = color:Lerp(SHADOW, 0.78)
		card.border.Color = color
		card.frame.Name = entry.speciesId
		local x, y = BookGrid.position(index, columns, GRID)
		card.frame.Position = UDim2.fromOffset(x, y)
		showModel(card, entry, found[entry.speciesId] ~= nil)
		paintCard(card, found, restricted)
		card.frame.Visible = true
		bound[index] = card
	end

	-- Binds pooled cards to the cards on screen at once, and returns cards
	-- outside the warm range to the pool. warmUp fills the rest of the warm
	-- range, the `overscan` rows first, a few cards a frame.
	local function cull()
		local tab = current
		if tab == nil or not gui.Enabled then
			return
		end
		local count, scroll, height = #tab.entries, body.CanvasPosition.Y - PAD_TOP, body.AbsoluteWindowSize.Y
		viewFirst, viewLast = BookGrid.visible(count, columns, GRID, scroll, height, 0)
		drawnFirst, drawnLast = BookGrid.visible(count, columns, GRID, scroll, height, overscan)
		warmFirst, warmLast = BookGrid.warm(count, drawnFirst, drawnLast, warmCards)
		for index in bound do
			if index < warmFirst or index > warmLast then
				release(index)
			end
		end
		local d = ctx.data()
		local found = if d then d.found or {} else {}
		local restricted = ctx.restricted()
		for index = viewFirst, viewLast do
			if bound[index] == nil then
				bind(tab, index, found, restricted)
			end
		end
	end

	-- Each frame while the book is open: moves cards that have warmed long
	-- enough to their places, then builds up to `warmPerFrame` more cards of
	-- the warm range, nearest the view first.
	local function warmUp()
		local tab = current
		if tab == nil or not gui.Enabled or drawnLast < drawnFirst then
			return
		end
		local now = os.clock()
		local d = ctx.data()
		local found = if d then d.found or {} else {}
		local restricted = ctx.restricted()
		local budget = BookGrid.warmBudget(now - shownAt, warmDelay, warmPerFrame)
		if budget <= 0 or viewLast < viewFirst then
			return
		end
		local built = 0
		local function try(index: number): boolean
			if index >= warmFirst and index <= warmLast and bound[index] == nil then
				bind(tab, index, found, restricted)
				built += 1
			end
			return built >= budget
		end
		local reach = math.max(viewFirst - warmFirst, warmLast - viewLast)
		for step = 1, reach do
			if try(viewLast + step) or try(viewFirst - step) then
				return
			end
		end
	end
	RunService.Heartbeat:Connect(warmUp)

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
		end
		-- Only the cards in view exist, so only they are repainted.
		for _, card in bound do
			paintCard(card, found, restricted)
		end
		local bonus = Book.bonus(found, species, bookConfig)
		local pct = math.floor(bonus * 1000 + 0.5) / 10
		local cap = math.floor(bookConfig.maxBonus * 1000 + 0.5) / 10
		summary.Text = `Found {have}/{total}  ·  Income +{pct}% (max +{cap}%)`
		fill.Size = UDim2.fromScale(if total > 0 then have / total else 0, 1)
	end

	local function selectTab(tab: Tab)
		if current ~= tab then
			releaseAll()
			-- This tab's pictures load next (Studio gate, #134: a cold
			-- Uncommon tab waited 3 s+ behind the Common tab's).
			PreloadQueue.prioritize(preload, Book.pictures(tab.entries))
		end
		current = tab
		shownAt = os.clock()
		body.CanvasPosition = Vector2.zero
		layout()
		refresh()
		cull()
		-- The window's size settles a frame later; lay out again once it has.
		task.defer(function()
			layout()
			cull()
		end)
	end

	for _, tab in tabs do
		tab.button.Activated:Connect(function()
			Sfx.play("click")
			selectTab(tab)
		end)
	end
	body:GetPropertyChangedSignal("CanvasPosition"):Connect(cull)
	body:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function()
		layout()
		cull()
	end)

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
			-- The built cards stay (hidden with the gui), so reopening the
			-- book shows drawn pictures at once.
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
	-- Reachable in first person too: frees the mouse, closes on a tap
	-- outside, gamepad B or Escape (CoreClient/Modal).
	Modal.attach(gui, window, function()
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
