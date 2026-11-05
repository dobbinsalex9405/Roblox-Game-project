--!strict
-- The Hatchery Book (the pet index): every creature in the game on a card,
-- grouped by rarity. Creatures the player has owned show in colour with
-- their name; the rest are dark silhouettes marked "???", so there is always
-- something to chase. Each card shows the best egg for it and the exact
-- chance (the same numbers as the odds card), hidden where paid random items are
-- restricted. The header counts the book ("Found 7/33") and its income bonus.
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
	model: Model?,
	looks: { [BasePart]: { color: Color3, material: Enum.Material } },
	name: TextLabel,
	odds: TextLabel,
	found: boolean?,
}

function BookView.start(ctx: Context.Context, menu: Menu)
	local player = Players.LocalPlayer
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

	local summary = text(window, "Summary", "", 18)
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

	local body = Instance.new("ScrollingFrame")
	body.Name = "Pages"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(10, 96)
	body.Size = UDim2.new(1, -20, 1, -104)
	body.CanvasSize = UDim2.fromScale(0, 0)
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollBarThickness = 6
	body.BorderSizePixel = 0
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = body
	local pad = Instance.new("UIPadding")
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
	local cards: { Card } = {}
	local tierCounts: { [string]: TextLabel } = {}
	local built = false

	-- Built on first open: one card per species, a heading per tier.
	local function build()
		built = true
		local order = 0
		local lastRarity = ""
		local grid: Frame? = nil
		for _, entry in entries do
			if entry.rarity ~= lastRarity then
				lastRarity = entry.rarity
				order += 1
				local heading = text(body, `Tier{entry.rank}`, string.upper(entry.rarity), 20)
				heading.TextColor3 = Layout.rarityColor(entry.rarity)
				heading.TextXAlignment = Enum.TextXAlignment.Left
				heading.Size = UDim2.new(1, 0, 0, 26)
				heading.LayoutOrder = order
				tierCounts[entry.rarity] = heading
				order += 1
				local g = Instance.new("Frame")
				g.Name = `Cards{entry.rank}`
				g.BackgroundTransparency = 1
				g.Size = UDim2.fromScale(1, 0)
				g.AutomaticSize = Enum.AutomaticSize.Y
				g.LayoutOrder = order
				local layout = Instance.new("UIGridLayout")
				layout.CellSize = UDim2.fromOffset(CARD.X, CARD.Y)
				layout.CellPadding = UDim2.fromOffset(8, 8)
				layout.SortOrder = Enum.SortOrder.LayoutOrder
				layout.Parent = g
				g.Parent = body
				grid = g
			end
			local color = Layout.rarityColor(entry.rarity)
			local frame = Instance.new("Frame")
			frame.Name = entry.speciesId
			frame.LayoutOrder = #cards + 1
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

			local model, size = CreatureView.staticModel(entry.speciesId)
			local looks: { [BasePart]: { color: Color3, material: Enum.Material } } = {}
			if model then
				for _, p in model:GetDescendants() do
					if p:IsA("BasePart") then
						looks[p] = { color = p.Color, material = p.Material }
					end
				end
				model.Parent = view
				local fitSize = math.max(size.X, size.Y, size.Z)
				local distance = (fitSize / 2) / math.tan(math.rad(15)) * 1.2
				local target = Vector3.new(0, size.Y / 2, 0)
				local offset = CFrame.Angles(0, math.rad(-28), 0) * CFrame.Angles(math.rad(-12), 0, 0)
				camera.CFrame = CFrame.lookAt(target + offset * Vector3.new(0, 0, -distance), target)
			end

			local name = text(frame, "Species", "", 14)
			name.Position = UDim2.fromOffset(4, CARD.X - 6)
			name.Size = UDim2.new(1, -8, 0, 18)
			name.TextScaled = true
			local odds = text(frame, "Odds", "", 13, Color3.fromRGB(255, 226, 120))
			odds.Position = UDim2.fromOffset(2, CARD.X + 12)
			odds.Size = UDim2.new(1, -4, 0, 32)
			odds.TextWrapped = true
			odds.TextYAlignment = Enum.TextYAlignment.Top

			table.insert(cards, {
				frame = frame,
				entry = entry,
				model = model,
				looks = looks,
				name = name,
				odds = odds,
				found = nil,
			})
		end
	end

	local function refresh()
		local d = ctx.data()
		local found = if d then d.found or {} else {}
		local restricted = ctx.restricted()
		local total, have = 0, 0
		local perTier: { [string]: { have: number, total: number } } = {}
		for _, card in cards do
			local entry = card.entry
			local owned = found[entry.speciesId] ~= nil
			total += 1
			local tier = perTier[entry.rarity] or { have = 0, total = 0 }
			perTier[entry.rarity] = tier
			tier.total += 1
			if owned then
				have += 1
				tier.have += 1
			end
			if card.found ~= owned then
				card.found = owned
				-- Not found yet: a dark silhouette, glow and all switched off.
				for part, look in card.looks do
					part.Color = if owned then look.color else SHADOW
					part.Material = if owned then look.material else Enum.Material.SmoothPlastic
				end
				card.name.Text = if owned then Layout.displayName(entry.speciesId) else "???"
			end
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
		for rarity, heading in tierCounts do
			local tier = perTier[rarity]
			if tier then
				heading.Text = `{string.upper(rarity)}  {tier.have}/{tier.total}`
			end
		end
		local bonus = if d then math.floor(have * ctx.config.economy.book.incomePerSpecies * 100 + 0.5) else 0
		summary.Text = `Found {have}/{total}  ·  Income +{bonus}%`
		fill.Size = UDim2.fromScale(if total > 0 then have / total else 0, 1)
	end

	local function setOpen(open: boolean)
		if open and not built then
			build()
		end
		if open then
			fit()
			refresh()
		end
		gui.Enabled = open
	end

	close.Activated:Connect(function()
		Sfx.play("click")
		setOpen(false)
	end)
	menu.add("Book", "📗 Book", function()
		Sfx.play("click")
		setOpen(not gui.Enabled)
	end)
	local function refreshIfOpen()
		if gui.Enabled then
			refresh()
		end
	end
	ctx.onData(refreshIfOpen)
	OddsView.onChanged(refreshIfOpen)
end

return BookView
