--!strict
-- The minimal interface, phone first: coins, income, the uncollected pile,
-- rebirths, a Get off button while riding, short notices, a raid banner, a welcome-back
-- message, hatch reveals, the odds card shown before buying an egg, and the
-- odds board at the conveyor. Built from code; art comes after the gate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Hatchery = require(Shared.Hatchery)
local Layout = require(Shared.Layout)
local OddsCard = require(Shared.OddsCard)
local Viewport = require(Shared.Viewport)

local Context = require(script.Parent.Context)
local HatchReveal = require(script.Parent.HatchReveal)
local OddsView = require(script.Parent.OddsView)

-- The odds boards are 26 x 7 studs: 520 x 140 pixels, two columns of five
-- 24-pixel lines.

local Hud = {}

local function label(parent: Instance, name: string, size: UDim2, position: UDim2?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = position or UDim2.new()
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5
	l.Text = ""
	l.Parent = parent
	return l
end

local function panel(parent: Instance, name: string, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = position
	f.AnchorPoint = anchor
	f.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	f.BackgroundTransparency = 0.05 -- nearly solid: world signs behind it showed through (Studio gate)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = f
	f.Parent = parent
	return f
end

local function listLayout(parent: Instance, padding: number)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = parent
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, padding)
	pad.PaddingBottom = UDim.new(0, padding)
	pad.PaddingLeft = UDim.new(0, padding)
	pad.PaddingRight = UDim.new(0, padding)
	pad.Parent = parent
end

function Hud.start(ctx: Context.Context)
	local gui = Instance.new("ScreenGui")
	gui.Name = "HatcheryHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = ctx.player:WaitForChild("PlayerGui")

	-- Top bar: coins, income, uncollected, rebirths.
	local bar = panel(gui, "Bar", UDim2.fromOffset(360, 64), UDim2.new(0.5, 0, 0, 8), Vector2.new(0.5, 0))
	local coins = label(bar, "Coins", UDim2.new(0.55, -8, 0.6, 0), UDim2.fromOffset(8, 2))
	coins.TextXAlignment = Enum.TextXAlignment.Left
	coins.TextColor3 = Color3.fromRGB(255, 220, 90)
	local income = label(bar, "Income", UDim2.new(0.45, -8, 0.6, 0), UDim2.new(0.55, 0, 0, 2))
	income.TextXAlignment = Enum.TextXAlignment.Right
	local pending = label(bar, "Pending", UDim2.new(0.65, -8, 0.38, 0), UDim2.new(0, 8, 0.6, 0))
	pending.TextXAlignment = Enum.TextXAlignment.Left
	pending.Font = Enum.Font.Gotham
	local rebirths = label(bar, "Rebirths", UDim2.new(0.35, -8, 0.38, 0), UDim2.fromScale(0.65, 0.6))
	rebirths.TextXAlignment = Enum.TextXAlignment.Right
	rebirths.Font = Enum.Font.Gotham
	-- Never an empty bar: say so while the save loads.
	coins.Text = "Loading..."
	pending.Text = "Loading your hatchery"

	-- Get off button while riding.
	local getOff = Instance.new("TextButton")
	getOff.Name = "GetOff"
	getOff.Size = UDim2.fromOffset(140, 48)
	getOff.Position = UDim2.new(1, -16, 1, -150)
	getOff.AnchorPoint = Vector2.new(1, 1)
	getOff.BackgroundColor3 = Color3.fromRGB(220, 90, 70)
	getOff.Font = Enum.Font.GothamBold
	getOff.TextScaled = true
	getOff.TextColor3 = Color3.new(1, 1, 1)
	getOff.Text = "Get off"
	getOff.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = getOff
	getOff.Parent = gui
	getOff.Activated:Connect(function()
		ctx.fire(ctx.remotes["HH:Dismount"])
	end)

	-- Notices: one line at a time under the bar and the guide's goal line.
	local notice =
		panel(gui, "Notice", UDim2.fromOffset(360, 36), UDim2.new(0.5, 0, 0, 124), Vector2.new(0.5, 0))
	notice.Visible = false
	local noticeText = label(notice, "Text", UDim2.new(1, -16, 1, -8), UDim2.fromOffset(8, 4))
	local noticeId = 0
	local function show(text: string, seconds: number?)
		noticeId += 1
		local id = noticeId
		noticeText.Text = text
		notice.Visible = true
		task.delay(seconds or 3, function()
			if noticeId == id then
				notice.Visible = false
			end
		end)
	end

	-- Raid banner under the notices: what you are carrying and how long you
	-- have left, or an alarm while raiders are on your base.
	local banner =
		panel(gui, "RaidBanner", UDim2.fromOffset(360, 40), UDim2.new(0.5, 0, 0, 166), Vector2.new(0.5, 0))
	banner.Visible = false
	local bannerText = label(banner, "Text", UDim2.new(1, -16, 1, -8), UDim2.fromOffset(8, 4))
	local function updateBanner()
		local carrying = ctx.player:GetAttribute("Carrying")
		if type(carrying) == "string" then
			local started = ctx.player:GetAttribute("CarryStartedAt")
			local left = if type(started) == "number"
				then math.max(0, math.ceil(started + ctx.config.raids.maxCarrySeconds - ctx.serverNow()))
				else ctx.config.raids.maxCarrySeconds
			banner.BackgroundColor3 = Color3.fromRGB(200, 140, 30)
			bannerText.Text = `Carrying a {Layout.displayName(carrying)}! Run home: {left}s`
			banner.Visible = true
			return
		end
		local own = ctx.plot()
		local raiders = if own then own:GetAttribute("Raiders") else nil
		if type(raiders) == "number" and raiders > 0 then
			banner.BackgroundColor3 = Color3.fromRGB(190, 40, 40)
			bannerText.Text = if raiders == 1
				then "A raider is on your base!"
				else `{raiders} raiders are on your base!`
			banner.Visible = true
			return
		end
		banner.Visible = false
	end

	ctx.on(ctx.remotes["HH:Notice"], function(text: string)
		show(text)
	end)
	-- The reveal plays each hatch; a notice covers any it has no room for.
	local reveal = HatchReveal.start(ctx, function(text: string)
		show(text, 6)
	end)
	ctx.on(ctx.remotes["HH:Hatched"], function(speciesId: string, eggId: string, isNew: boolean)
		if reveal.show(speciesId, eggId, isNew) then
			return
		end
		local species = ctx.config.creatures.species[speciesId]
		local rarity = if species then species.rarity else "Common"
		show(`You hatched a {rarity} {Layout.displayName(speciesId)}!`, 4)
	end)
	ctx.on(ctx.remotes["HH:WelcomeBack"], function(earned: number, readyEggs: number)
		local parts = {}
		if earned > 0 then
			table.insert(parts, `you earned {Layout.shortNumber(earned)} coins`)
		end
		if readyEggs > 0 then
			table.insert(parts, `{readyEggs} egg{if readyEggs == 1 then "" else "s"} finished hatching`)
		end
		show(`Welcome back! While you were away, {table.concat(parts, " and ")}.`, 8)
	end)

	-- Odds card, shown while an egg's Buy prompt is up.
	local card = panel(
		gui,
		"OddsCard",
		UDim2.fromOffset(OddsCard.WIDTH, 0),
		UDim2.new(0, 16, 0.5, 0),
		Vector2.new(0, 0.5)
	)
	card.Visible = false
	-- The rows scroll inside the card, which is never taller than the screen
	-- (Studio gate, #126: a long card ran off a phone, 86 px below it).
	local cardRows = Instance.new("ScrollingFrame")
	cardRows.Name = "Rows"
	cardRows.BackgroundTransparency = 1
	cardRows.BorderSizePixel = 0
	cardRows.Size = UDim2.fromScale(1, 1)
	cardRows.CanvasSize = UDim2.new()
	cardRows.AutomaticCanvasSize = Enum.AutomaticSize.Y
	cardRows.ScrollingDirection = Enum.ScrollingDirection.Y
	cardRows.ScrollBarThickness = 4
	cardRows.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	cardRows.Parent = card
	listLayout(cardRows, 8)
	local cardEgg: string? = nil
	-- Smaller on a phone held sideways, so the card leaves the egg and its
	-- Buy prompt in view (Studio gate, Nov 5): 75% at 392 px tall.
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card
	local cardLayout = cardRows:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	local function fitCard()
		local cam = Workspace.CurrentCamera
		local screen = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		-- On a short screen the card starts below the notice line (124 +
		-- 36 px), so a refusal is never half under it.
		local short = screen.Y < 500
		if short then
			card.AnchorPoint = Vector2.new(0, 0)
			card.Position = UDim2.fromOffset(16, 168)
		else
			card.AnchorPoint = Vector2.new(0, 0.5)
			card.Position = UDim2.new(0, 16, 0.5, 0)
		end
		-- As tall as its rows (measured at the current scale) and its 8 px
		-- padding, but never past the screen; the rows scroll beyond that.
		-- The GUI starts below Roblox's top bar (Studio gate, #126: 4 px
		-- off a 392 px phone, the 58 px bar not counted).
		local rows = cardLayout.AbsoluteContentSize.Y / math.max(cardScale.Scale, 0.01) + 16
		local guiHeight = screen.Y - GuiService:GetGuiInset().Y
		local scale, height = OddsCard.fit(rows, screen.Y, guiHeight, if short then 168 else 8)
		if math.abs(cardScale.Scale - scale) > 0.001 then
			cardScale.Scale = scale
		end
		if math.abs(card.Size.Y.Offset - height) >= 1 then
			card.Size = UDim2.fromOffset(OddsCard.WIDTH, height)
		end
	end
	-- Refit whenever the rows change (another egg, a fixed order moving on)
	-- and whenever the screen changes size (Studio gate, #126: the card kept
	-- its phone scale after a phone to desktop resize).
	cardLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitCard)
	Viewport.watch(Workspace, fitCard)

	-- The Egg Market's odds signs, one beside each stop. Everyone sees their
	-- title; this client draws its own odds (fixed order for a restricted
	-- player) over them: one belt egg at a time, cheapest first, the next
	-- every `conveyor.signSeconds` (all signs together).
	local signGuis: { [BasePart]: SurfaceGui } = {}
	local signGui: SurfaceGui? = nil -- set once the signs are found
	local signPage = 1
	local function renderBoard()
		local market = Workspace:FindFirstChild("EggMarket")
		local signs = market and market:FindFirstChild("Signs")
		if signs == nil then
			return
		end
		local ids = Hatchery.marketEggs(ctx.config.eggs, ctx.config.economy.conveyor.weights)
		if #ids == 0 then
			return
		end
		local pps = OddsView.SIGN_PIXELS_PER_STUD
		for _, sign in signs:GetChildren() do
			if not sign:IsA("BasePart") then
				continue
			end
			local title = sign:FindFirstChild("Title")
			if title and title:IsA("SurfaceGui") then
				title.Enabled = false
			end
			local sg: SurfaceGui? = signGuis[sign]
			if sg == nil then
				local g = Instance.new("SurfaceGui")
				g.Name = `Odds{sign.Name}`
				g.Face = Enum.NormalId.Front
				g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				g.PixelsPerStud = pps
				g.LightInfluence = 0 -- readable in shade
				g.Adornee = sign
				local holder = Instance.new("Frame")
				holder.Name = "Holder"
				holder.Size = UDim2.fromScale(1, 1)
				holder.BackgroundTransparency = 1
				holder.Parent = g
				g.Parent = ctx.player:WaitForChild("PlayerGui")
				signGuis[sign] = g
				signGui = g
				sg = g
			end
			local holder = (sg :: SurfaceGui):FindFirstChild("Holder") :: Frame
			OddsView.renderSign(
				holder,
				ids[(signPage - 1) % #ids + 1],
				Vector2.new(sign.Size.X, sign.Size.Y) * pps
			)
		end
	end

	task.spawn(function()
		while true do
			task.wait(ctx.config.economy.conveyor.signSeconds)
			signPage += 1
			if signGui then
				renderBoard()
			end
		end
	end)

	local function renderCard()
		if cardEgg then
			OddsView.render(cardRows, cardEgg)
		end
	end

	OddsView.onChanged(function()
		renderBoard()
		renderCard()
	end)

	local function onData(d: { [string]: any })
		rebirths.Text = `Rebirths: {d.rebirths}`
		getOff.Visible = d.mountUid ~= ""
		-- The fixed-order list moves on after each purchase.
		if ctx.restricted() then
			renderBoard()
			renderCard()
		end
	end
	ctx.onData(onData)

	-- Numbers that move every frame: coins, income and the uncollected pile.
	task.spawn(function()
		while true do
			local d = ctx.data()
			if d then
				local perSecond = Hatchery.incomePerSecond(d, ctx.config, ctx.perks())
				coins.Text = `{Layout.shortNumber(d.coins)} coins`
				income.Text = `+{Layout.shortNumber(perSecond)}/s`
				local pile = Hatchery.pendingAt(d, ctx.serverNow(), perSecond)
				pending.Text = if ctx.autoCollect()
					then `Auto-collecting {Layout.shortNumber(pile)}`
					else `Uncollected: {Layout.shortNumber(pile)}`
			end
			updateBanner()
			if signGui == nil then
				renderBoard()
			end
			task.wait(0.2)
		end
	end)

	return {
		showOdds = function(eggId: string)
			cardEgg = eggId
			fitCard()
			renderCard()
			card.Visible = true
		end,
		hideOdds = function()
			cardEgg = nil
			card.Visible = false
		end,
	}
end

return Hud
