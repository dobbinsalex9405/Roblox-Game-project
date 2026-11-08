--!strict
-- Getting started: a welcome screen on a brand-new player's first join, a
-- Guide button in the side menu that reopens it, and the first-session goal
-- (src/shared/Guide.luau) as a line under the coin bar with a beam and a
-- bouncing arrow to the place to go.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Guide = require(Shared.Guide)
local Geometry = require(Shared.Geometry)
local Layout = require(Shared.Layout)

local Context = require(script.Parent.Context)

local GuideView = {}

local GOLD = Color3.fromRGB(255, 210, 63)
local PANEL = Color3.fromRGB(28, 30, 48)

export type SideMenu = {
	add: (name: string, text: string, onClick: () -> ()) -> TextButton,
}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function text(parent: Instance, name: string, value: string, size: number, bold: boolean?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	l.TextSize = size
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextWrapped = true
	l.Text = value
	l.Parent = parent
	return l
end

-- What the welcome screen teaches, in play order.
local STEPS = {
	{
		icon = "🥚",
		title = "Buy eggs",
		body = "Eggs ride the Egg Market in the middle of the map. Walk up to one and buy it with coins, before someone else does!",
	},
	{
		icon = "🐣",
		title = "Hatch them",
		body = "Eggs go into your incubators. When one is ready, hatch it to see what you got.",
	},
	{
		icon = "💰",
		title = "Earn coins",
		body = "Creatures on your pads earn coins every second. Collect them at the green pad.",
	},
	{
		icon = "🦊",
		title = "Raid and defend",
		body = "Sneak into other bases and carry creatures home. Raise your shield and set traps to protect yours.",
	},
}

-- The card never grows past 90% of the screen: on a phone the steps scroll
-- and the "Let's go!" button stays pinned at the bottom.
local GO_AREA = 64 -- button plus its margin

local function welcomeWindow(gui: ScreenGui): (Frame, TextButton)
	local shade = Instance.new("Frame")
	shade.Name = "Welcome"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.45
	shade.Visible = false
	shade.ZIndex = 10
	shade.Parent = gui

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(460, 400)
	card.BackgroundColor3 = PANEL
	card.ZIndex = 11
	corner(card, 16)
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 3
	stroke.Parent = card
	card.Parent = shade

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(0, 0)
	body.Size = UDim2.new(1, 0, 1, -GO_AREA)
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollBarThickness = 6
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.ZIndex = 11
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = body
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = body
	body.Parent = card

	local title = text(body, "Title", "Welcome to Hatchery Heist!", 26, true)
	title.TextColor3 = GOLD
	title.Size = UDim2.new(1, 0, 0, 32)
	title.LayoutOrder = 1
	title.ZIndex = 12
	local sub =
		text(body, "Subtitle", "Hatch rare creatures, grow your coin empire, and steal from your rivals.", 16)
	sub.Size = UDim2.new(1, 0, 0, 40)
	sub.TextColor3 = Color3.fromRGB(210, 215, 235)
	sub.LayoutOrder = 2
	sub.ZIndex = 12

	local rows: { { name: TextLabel, about: TextLabel, pad: UIPadding, title: string, body: string } } = {}
	for index, step in STEPS do
		local row = Instance.new("Frame")
		row.Name = `Step{index}`
		row.LayoutOrder = 2 + index
		row.Size = UDim2.fromScale(1, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.BackgroundColor3 = Color3.fromRGB(44, 48, 74)
		row.ZIndex = 11
		corner(row, 10)
		local icon = text(row, "Icon", step.icon, 28)
		icon.Size = UDim2.fromOffset(44, 44)
		icon.Position = UDim2.fromOffset(6, 4)
		icon.ZIndex = 12
		local name = text(row, "Name", step.title, 17, true)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Position = UDim2.fromOffset(56, 6)
		name.Size = UDim2.new(1, -64, 0, 20)
		name.ZIndex = 12
		local about = text(row, "Body", step.body, 14)
		about.TextXAlignment = Enum.TextXAlignment.Left
		about.TextYAlignment = Enum.TextYAlignment.Top
		about.TextColor3 = Color3.fromRGB(215, 220, 240)
		about.Position = UDim2.fromOffset(56, 28)
		about.Size = UDim2.new(1, -64, 0, 0)
		about.AutomaticSize = Enum.AutomaticSize.Y
		about.ZIndex = 12
		local rowPad = Instance.new("UIPadding")
		rowPad.PaddingBottom = UDim.new(0, 8)
		rowPad.Parent = row
		row.Parent = body
		table.insert(rows, { name = name, about = about, pad = rowPad, title = step.title, body = step.body })
	end

	local go = Instance.new("TextButton")
	go.Name = "Go"
	go.AnchorPoint = Vector2.new(0.5, 1)
	go.Position = UDim2.new(0.5, 0, 1, -10)
	go.Size = UDim2.fromOffset(200, 46)
	go.BackgroundColor3 = Color3.fromRGB(70, 180, 90)
	go.Font = Enum.Font.GothamBold
	go.TextSize = 22
	go.TextColor3 = Color3.new(1, 1, 1)
	go.Text = "Let's go!"
	go.ZIndex = 12
	corner(go, 12)
	go.Parent = card

	-- Fit the card to its content, the screen and a 460 px maximum width.
	-- On a short screen (a phone held sideways) the card goes wide, drops
	-- the subtitle and puts each step's name at the start of its text, so
	-- all four steps show without scrolling (Studio gate, Nov 5).
	local compact: boolean? = nil
	local function fit()
		local screen = shade.AbsoluteSize
		if screen.X <= 0 or screen.Y <= 0 then
			return
		end
		local short = screen.Y < 500
		if short ~= compact then
			compact = short
			sub.Visible = not short
			title.TextSize = if short then 22 else 26
			title.Size = UDim2.new(1, 0, 0, if short then 26 else 32)
			list.Padding = UDim.new(0, if short then 6 else 8)
			pad.PaddingTop = UDim.new(0, if short then 8 else 14)
			-- A slimmer "Let's go!" strip.
			body.Size = UDim2.new(1, 0, 1, -(if short then GO_AREA - 12 else GO_AREA))
			go.Size = UDim2.fromOffset(200, if short then 38 else 46)
			go.Position = UDim2.new(0.5, 0, 1, if short then -8 else -10)
			for _, r in rows do
				r.name.Visible = not short
				r.about.RichText = short
				r.about.Text = if short then `<b>{r.title}</b>   {r.body}` else r.body
				r.about.Position = UDim2.fromOffset(56, if short then 8 else 28)
				r.pad.PaddingBottom = UDim.new(0, if short then 6 else 8)
				r.about.TextSize = if short then 13 else 14
			end
		end
		local width = math.min(if short then 720 else 460, math.floor(screen.X * 0.92))
		local wanted = list.AbsoluteContentSize.Y + 20 + (if short then GO_AREA - 12 else GO_AREA)
		local height = math.min(wanted, math.floor(screen.Y * (if short then 0.94 else 0.9)))
		card.Size = UDim2.fromOffset(width, height)
	end
	shade:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
	shade:GetPropertyChangedSignal("Visible"):Connect(fit)
	fit()
	return shade, go
end

-- A column of buttons on the right edge of the screen.
local function sideMenu(gui: ScreenGui): SideMenu
	local column = Instance.new("Frame")
	column.Name = "SideMenu"
	column.AnchorPoint = Vector2.new(1, 0.5)
	column.Position = UDim2.new(1, -10, 0.45, 0)
	column.Size = UDim2.fromOffset(84, 0)
	column.AutomaticSize = Enum.AutomaticSize.Y
	column.BackgroundTransparency = 1
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = column
	column.Parent = gui
	local count = 0
	return {
		add = function(name: string, label: string, onClick: () -> ()): TextButton
			count += 1
			local b = Instance.new("TextButton")
			b.Name = name
			b.LayoutOrder = count
			b.Size = UDim2.fromOffset(84, 44)
			b.BackgroundColor3 = PANEL
			b.BackgroundTransparency = 0.1
			b.Font = Enum.Font.GothamBold
			b.TextSize = 16
			b.TextColor3 = Color3.new(1, 1, 1)
			b.Text = label
			corner(b, 10)
			local stroke = Instance.new("UIStroke")
			stroke.Color = GOLD
			stroke.Thickness = 1.5
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = b
			b.Activated:Connect(onClick)
			b.Parent = column
			return b
		end,
	}
end

-- Marks the player's own base, for them only: a gold outline around the
-- floor and a big "Your hatchery" sign that can be seen from the yard.
local function markOwnBase(plot: Model)
	if plot:FindFirstChild("YourBase") then
		return
	end
	local floor = plot:FindFirstChild("Floor")
	local sign = plot:FindFirstChild("Sign")
	if floor == nil or not floor:IsA("BasePart") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "YourBase"
	local half = Layout.PLOT_SIZE / 2
	local function strip(offset: Vector3, size: Vector3)
		local p = Instance.new("Part")
		p.Name = "Outline"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = GOLD
		p.Size = size
		p.CFrame = floor.CFrame * CFrame.new(offset)
		p.Parent = folder
	end
	local y = floor.Size.Y / 2 + 0.06
	strip(Vector3.new(0, y, -half + 0.4), Vector3.new(Layout.PLOT_SIZE, 0.1, 0.8))
	strip(Vector3.new(0, y, half - 0.4), Vector3.new(Layout.PLOT_SIZE, 0.1, 0.8))
	strip(Vector3.new(-half + 0.4, y, 0), Vector3.new(0.8, 0.1, Layout.PLOT_SIZE))
	strip(Vector3.new(half - 0.4, y, 0), Vector3.new(0.8, 0.1, Layout.PLOT_SIZE))
	if sign and sign:IsA("BasePart") then
		local gui = Instance.new("BillboardGui")
		gui.Name = "YourBaseLabel"
		gui.ResetOnSpawn = false -- no effect in the world; the client GUI rule
		local banner = Geometry.YOUR_BASE_LABEL
		gui.Size = UDim2.fromScale(banner.width, banner.height)
		gui.StudsOffset = Vector3.new(0, banner.above, 0)
		gui.MaxDistance = 400
		gui.LightInfluence = 0
		gui.Adornee = sign
		local l = text(gui, "Text", "⭐ YOUR HATCHERY ⭐", 40, true)
		l.Size = UDim2.fromScale(1, 1)
		l.TextScaled = true
		l.TextColor3 = GOLD
		l.TextStrokeTransparency = 0.2
		gui.Parent = folder
	end
	folder.Parent = plot
end

local function findTarget(plot: Model, target: Guide.Target): BasePart?
	local found: Instance? = nil
	if target.kind == "Belt" then
		-- The Egg Market's edge facing this base.
		local market = Workspace:FindFirstChild("EggMarket")
		local stops = market and market:FindFirstChild("Stops")
		local index = plot:GetAttribute("PlotIndex")
		found = stops and type(index) == "number" and stops:FindFirstChild(`Stop{index}`) or nil
	elseif target.kind == "CollectPad" then
		found = plot:FindFirstChild("CollectPad")
	elseif target.kind == "Incubator" then
		local folder = plot:FindFirstChild("Incubators")
		found = folder and folder:FindFirstChild(`Incubator{target.slot}`)
	end
	return if found and found:IsA("BasePart") then found else nil
end

function GuideView.start(ctx: Context.Context): SideMenu
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "HatcheryGuide"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Roblox's desktop player list covers the side menu's top button
	-- (config/atmosphere guide.playerList).
	local guideConfig = (require(ReplicatedStorage.GameConfig.atmosphere) :: any).guide
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, guideConfig.playerList == true)

	-- The goal line, under the coin bar (Hud).
	local goal = Instance.new("Frame")
	goal.Name = "Goal"
	goal.AnchorPoint = Vector2.new(0.5, 0)
	goal.Position = UDim2.new(0.5, 0, 0, 80)
	goal.Size = UDim2.new(0.92, 0, 0, 38)
	goal.BackgroundColor3 = PANEL
	goal.BackgroundTransparency = 0.1
	goal.Visible = false
	corner(goal, 10)
	local goalLimit = Instance.new("UISizeConstraint")
	goalLimit.MaxSize = Vector2.new(420, 38)
	goalLimit.Parent = goal
	local goalStroke = Instance.new("UIStroke")
	goalStroke.Color = GOLD
	goalStroke.Thickness = 2
	goalStroke.Parent = goal
	-- A gold "GOAL" tag, drawn rather than a glyph: arrow characters are not
	-- in the game's fonts and showed as a missing-glyph box.
	local tag = Instance.new("TextLabel")
	tag.Name = "Tag"
	tag.AnchorPoint = Vector2.new(0, 0.5)
	tag.Position = UDim2.new(0, 6, 0.5, 0)
	tag.Size = UDim2.fromOffset(46, 24)
	tag.BackgroundColor3 = GOLD
	tag.Font = Enum.Font.GothamBold
	tag.TextSize = 13
	tag.TextColor3 = PANEL
	tag.Text = "GOAL"
	corner(tag, 6)
	tag.Parent = goal
	local goalText = text(goal, "Text", "", 16, true)
	goalText.Position = UDim2.fromOffset(58, 3)
	goalText.Size = UDim2.new(1, -66, 1, -6)
	goal.Parent = gui

	local welcome, go = welcomeWindow(gui)
	go.Activated:Connect(function()
		welcome.Visible = false
	end)

	local menu = sideMenu(gui)
	-- An open window (Book, Daily, Tower, Pets, odds list, Core Shop: its
	-- Window frame showing, DisplayOrder 20 to 49) hides the side menu, so its
	-- buttons never poke out past the window's edge on a phone (Studio gate,
	-- Nov 5). Each window has an X. Guide.windowOpen decides.
	local column = gui:FindFirstChild("SideMenu") :: Frame
	local playerGui = player:WaitForChild("PlayerGui")
	task.spawn(function()
		while true do
			local screens: { Guide.Screen } = {}
			for _, g in playerGui:GetChildren() do
				if g:IsA("ScreenGui") then
					local frame = g:FindFirstChild("Window") or g:FindFirstChild("Form")
					table.insert(screens, {
						name = g.Name,
						enabled = g.Enabled,
						displayOrder = g.DisplayOrder,
						windowVisible = if frame and frame:IsA("GuiObject") then frame.Visible else nil,
					})
				end
			end
			column.Visible = not Guide.windowOpen(screens)
			task.wait(0.1)
		end
	end)
	menu.add("Guide", "📖 Guide", function()
		welcome.Visible = not welcome.Visible
	end)

	local shownWelcome = false
	ctx.onData(function(d: { [string]: any })
		if not shownWelcome then
			shownWelcome = true
			if Guide.isNewPlayer(d) then
				welcome.Visible = true
			end
		end
	end)

	local arrivedStuds = (require(ReplicatedStorage.GameConfig.atmosphere) :: any).guide.arrivedStuds

	-- The beam from the player to the goal, and an arrow over it.
	local fromAttachment: Attachment? = nil
	local toAttachment = Instance.new("Attachment")
	toAttachment.Name = "GuideTarget"
	local beam = Instance.new("Beam")
	beam.Name = "GuideBeam"
	beam.Color = ColorSequence.new(GOLD)
	beam.Transparency = NumberSequence.new(0.25)
	beam.Width0 = 0.5
	beam.Width1 = 0.5
	beam.FaceCamera = true
	beam.LightEmission = 0.6
	beam.Segments = 1
	beam.Attachment1 = toAttachment
	beam.Enabled = false
	local arrow = Instance.new("BillboardGui")
	arrow.Name = "GuideArrow"
	arrow.ResetOnSpawn = false -- no effect in the world; the client GUI rule
	arrow.Size = UDim2.fromOffset(60, 60)
	arrow.AlwaysOnTop = true
	arrow.LightInfluence = 0
	arrow.Enabled = false
	-- A downward arrow drawn from two frames (a stem and a diamond tip): the
	-- triangle character is not in every font and could show as a box.
	local stem = Instance.new("Frame")
	stem.Name = "Stem"
	stem.AnchorPoint = Vector2.new(0.5, 0)
	stem.Position = UDim2.fromScale(0.5, 0.05)
	stem.Size = UDim2.fromScale(0.26, 0.45)
	stem.BackgroundColor3 = GOLD
	stem.BorderSizePixel = 0
	stem.Parent = arrow
	local tip = Instance.new("Frame")
	tip.Name = "Tip"
	tip.AnchorPoint = Vector2.new(0.5, 0.5)
	tip.Position = UDim2.fromScale(0.5, 0.58)
	tip.Size = UDim2.fromScale(0.5, 0.5)
	tip.Rotation = 45
	tip.BackgroundColor3 = GOLD
	tip.BorderSizePixel = 0
	tip.Parent = arrow
	for _, piece in { stem, tip } do
		local edge = Instance.new("UIStroke")
		edge.Color = PANEL
		edge.Thickness = 2
		edge.Parent = piece
	end

	local function attachToCharacter(): Attachment?
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root == nil then
			return nil
		end
		if fromAttachment == nil or fromAttachment.Parent ~= root then
			local a = Instance.new("Attachment")
			a.Name = "GuideFrom"
			a.Position = Vector3.new(0, -1.5, 0)
			a.Parent = root
			fromAttachment = a
			beam.Attachment0 = a
			beam.Parent = root
		end
		return fromAttachment
	end

	local function hidePointer()
		beam.Enabled = false
		arrow.Enabled = false
	end

	task.spawn(function()
		local bounce = 0
		while true do
			local d = ctx.data()
			local plot = ctx.plot()
			if plot then
				markOwnBase(plot)
			end
			local step = if d
				then Guide.next(d, ctx.config.economy, ctx.serverNow(), Layout.shortNumber)
				else nil
			if step == nil or plot == nil then
				goal.Visible = false
				hidePointer()
			else
				goal.Visible = true
				goalText.Text = step.text
				local target = step.target and findTarget(plot, step.target)
				local from = attachToCharacter()
				local arrived = false
				local root = from and from.Parent
				if target and root and root:IsA("BasePart") then
					local flat = (target.Position - root.Position) * Vector3.new(1, 0, 1)
					arrived = flat.Magnitude <= arrivedStuds
				end
				if target and from and not arrived then
					-- Half the part's height in the world (incubators lie on their side).
					local top = math.abs(target.CFrame:VectorToWorldSpace(target.Size).Y) / 2
					toAttachment.Parent = target
					toAttachment.WorldPosition = target.Position + Vector3.new(0, top + 0.5, 0)
					arrow.Adornee = target
					arrow.Parent = target
					bounce = (bounce + 1) % 8
					arrow.StudsOffsetWorldSpace = Vector3.new(0, top + 3 + math.abs(4 - bounce) * 0.25, 0)
					beam.Enabled = true
					arrow.Enabled = true
				else
					hidePointer()
				end
			end
			task.wait(0.15)
		end
	end)

	-- A new character needs a new beam start.
	player.CharacterAdded:Connect(function()
		fromAttachment = nil
	end)

	return menu
end

return GuideView
