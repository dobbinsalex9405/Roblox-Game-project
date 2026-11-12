--!strict
-- Timed events and the Giant Golden Egg on screen (Alex, Nov 7 2026):
--
-- * The event banner, in the middle of the top bar: the running event and
--   the time left, or the next one and when it starts (a live countdown in
--   its last hour). Tap it for a card saying what the event does and what
--   the Giant Egg costs. Phone first: the banner and the card's button
--   are at least 40 px tall, and nothing else on the HUD sits under them.
-- * The Giant Egg's sign: its best odds (Epic or better, Alex Nov 12), its
--   price, and "Yours today" with the time to the next one once this player
--   has bought it (the Buy prompt turns off for them until then). The full
--   odds card (client/Hud) shows while its Buy prompt is up, like every egg.
-- * The egg's shell rocks now and then, as if about to hatch.
--
-- The schedule comes from client/EventClock (the servers' own schedule on
-- the server clock); purchases go through the server's prompt.

local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ClientNet = require(ReplicatedStorage.CoreClient.ClientNet)
local CoreClient = require(ReplicatedStorage.CoreClient.CoreClient)
local Odds = require(ReplicatedStorage.Core.Odds)
local ShopRemotes = require(ReplicatedStorage.Core.ShopRemotes)
local Shared = ReplicatedStorage.Shared
local Events = require(Shared.Events)
local GiantEggRules = require(Shared.GiantEgg)
local Hatchery = require(Shared.Hatchery)
local Layout = require(Shared.Layout)
local ShopPlan = require(Shared.ShopPlan)

local Context = require(script.Parent.Context)
local EventClock = require(script.Parent.EventClock)
local OddsView = require(script.Parent.OddsView)

local EventView = {}

local BANNER_WIDTH = 240
local MIN_BANNER_WIDTH = 170 -- narrower and "Speedy Incubators" no longer fits
local CARD_WIDTH = 340
local TOPBAR_BUTTON = 72 -- UiKit.topbarButton's Shop and Test buttons
local FEEDBACK_WIDTH = 112 -- FeedbackUi's top-bar button
local GOLD = Color3.fromRGB(255, 196, 60)
local DARK = Color3.fromRGB(25, 25, 35)
local SIGN_SIZE = Vector2.new(11, 4.2) -- studs
local ROCK_EVERY = 7 -- seconds between the shell's wobbles
local ROCK_SECONDS = 1.4
local ROCK_ANGLE = math.rad(4)
local ROCK_RANGE = 220 -- studs from the camera

-- A short mark per event for the banner's badge (plain text: every font has it).
local BADGES: { [string]: string } = {
	EggSale = "%",
	FastHatch = "x2",
	MoneyRush = "$$",
	LuckyHatch = "x3",
}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function text(parent: Instance, name: string, size: UDim2, position: UDim2, bold: boolean?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.Font = if bold == false then Enum.Font.Gotham else Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.6
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = ""
	l.Parent = parent
	return l
end

function EventView.start(ctx: Context.Context)
	local config = EventClock.config
	local listings = (require(ReplicatedStorage.GameConfig.monetization) :: any).listings
	local listed = listings.products.GiantEgg and listings.products.GiantEgg.robux

	local playerGui = ctx.player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "EventBanner"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.None -- full-screen pixels: it sits in the top bar
	gui.DisplayOrder = 2
	gui.Parent = playerGui

	-- The banner: a button, so the whole thing is one big tap target.
	local banner = Instance.new("TextButton")
	banner.Name = "Banner"
	banner.AutoButtonColor = true
	banner.Text = ""
	banner.Size = UDim2.fromOffset(BANNER_WIDTH, 46)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.BackgroundColor3 = DARK
	banner.BackgroundTransparency = 0.05
	corner(banner, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = banner
	banner.Parent = gui

	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(0, 5, 0.5, 0)
	badge.Size = UDim2.new(0, 36, 1, -10)
	corner(badge, 10)
	badge.Parent = banner
	local badgeText = text(badge, "Text", UDim2.fromScale(1, 1), UDim2.new())
	badgeText.TextScaled = false
	badgeText.TextSize = 16
	badgeText.TextXAlignment = Enum.TextXAlignment.Center
	local title = text(banner, "Title", UDim2.new(1, -54, 0.5, -3), UDim2.fromOffset(48, 4))
	title.TextScaled = false
	title.TextSize = 15
	local line = text(banner, "Line", UDim2.new(1, -54, 0.5, -3), UDim2.new(0, 48, 0.5, 0), false)
	line.TextScaled = false
	line.TextSize = 14

	-- The card: a small window in the middle of the screen saying what the
	-- event does and what today's Giant Egg holds. A "Window" in its own
	-- ScreenGui at DisplayOrder 22, so the side menu steps aside while it
	-- is open, like every other window (GuideView).
	local cardGui = Instance.new("ScreenGui")
	cardGui.Name = "EventCard"
	cardGui.ResetOnSpawn = false
	cardGui.DisplayOrder = 22
	cardGui.Parent = playerGui
	local card = Instance.new("Frame")
	card.Name = "Window"
	card.Size = UDim2.fromOffset(CARD_WIDTH, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.BackgroundColor3 = DARK
	card.BackgroundTransparency = 0.05
	card.Visible = false
	corner(card, 12)
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Thickness = 2
	cardStroke.Parent = card
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = card
	local pad = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(pad :: any)[side] = UDim.new(0, 12)
	end
	pad.Parent = card
	card.Parent = cardGui

	local function cardLine(order: number, height: number, bold: boolean?): TextLabel
		local l = text(card, `Line{order}`, UDim2.new(1, 0, 0, height), UDim2.new(), bold)
		l.TextScaled = false
		l.TextSize = height
		l.TextWrapped = true
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.Size = UDim2.fromScale(1, 0)
		l.LayoutOrder = order
		return l
	end
	local cardTitle = cardLine(1, 20)
	local cardBlurb = cardLine(2, 16, false)
	local cardWhen = cardLine(3, 16, false)
	local cardEgg = cardLine(4, 16, false)
	cardEgg.TextColor3 = GOLD
	local cardRule = cardLine(5, 14, false)
	cardRule.Text = `One {config.windowMinutes}-minute event every day, at a different time.`
	cardRule.TextColor3 = Color3.fromRGB(200, 200, 210)
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.fromOffset(140, 44)
	close.LayoutOrder = 6
	close.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
	close.Font = Enum.Font.GothamBold
	close.TextSize = 20
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Text = "Got it"
	corner(close, 10)
	close.Parent = card

	banner.Activated:Connect(function()
		card.Visible = not card.Visible
	end)
	close.Activated:Connect(function()
		card.Visible = false
	end)

	-- In the top bar's free middle, between the Shop (and Studio's Test)
	-- buttons on the left and Feedback on the right (packages/core's
	-- UiKit.topbarButton and FeedbackUi), centred on the screen when it
	-- fits. With no top bar, or too little of it, just under it on the
	-- left, below where Feedback then goes.
	local function fit()
		local cam = Workspace.CurrentCamera
		local screen = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		card.Size = UDim2.fromOffset(math.min(CARD_WIDTH, screen.X - 32), 0)
		local inset = GuiService.TopbarInset
		local left = inset.Min.X + 8 + (if RunService:IsStudio() then 2 else 1) * (TOPBAR_BUTTON + 8)
		local right = inset.Max.X - 8 - FEEDBACK_WIDTH - 8
		local room = right - left
		if inset.Width > 0 and inset.Height >= 40 and room >= MIN_BANNER_WIDTH then
			local width = math.min(BANNER_WIDTH, room)
			local x = math.clamp(screen.X / 2, left + width / 2, right - width / 2)
			banner.Size = UDim2.fromOffset(width, inset.Height - 8)
			banner.Position = UDim2.fromOffset(x, inset.Min.Y + 4)
		else
			local top = GuiService:GetGuiInset().Y
			banner.Size = UDim2.fromOffset(BANNER_WIDTH, 46)
			banner.Position = UDim2.fromOffset(12 + BANNER_WIDTH / 2, top + 56)
		end
	end

	-- The Giant Egg: its sign (per player), its prompt and its rocking shell.
	local model: Model? = nil
	local signTitle: TextLabel? = nil
	local signOdds: TextLabel? = nil
	local signPrice: TextLabel? = nil
	local shellParts: { { part: BasePart, base: CFrame } } = {}
	local pivot = Vector3.zero

	local catalogEntry: any = nil
	local robloxPrice: number? = nil
	local fetching = false
	ClientNet.on(ShopRemotes["Shop:Catalog"], function(entries: { any })
		if type(entries) ~= "table" then
			return
		end
		for _, entry in entries do
			if entry.kind == "product" and entry.key == GiantEggRules.EGG_ID then
				catalogEntry = entry
				if entry.available and robloxPrice == nil and not fetching then
					fetching = true
					task.spawn(function()
						local ok, info = pcall(function()
							return MarketplaceService:GetProductInfo(entry.id, Enum.InfoType.Product)
						end)
						local price = ok and type(info) == "table" and (info :: any).PriceInRobux
						if type(price) == "number" then
							robloxPrice = price
						end
						fetching = false
					end)
				end
			end
		end
	end)

	local function buildSign(m: Model)
		local hitbox = m:FindFirstChild("Hitbox") :: BasePart?
		if hitbox == nil then
			return
		end
		local g = Instance.new("BillboardGui")
		g.Name = "GiantEggSign"
		g.Adornee = hitbox
		g.Size = UDim2.fromScale(SIGN_SIZE.X, SIGN_SIZE.Y) -- studs
		-- Beside the egg at about its middle (the server's SignY), shifted
		-- to the camera's right so the egg never hides it, and low enough that a phone's follow camera never puts
		-- it under the coin bar (Studio gate, Nov 7).
		local y = m:GetAttribute("SignY")
		g.StudsOffsetWorldSpace = Vector3.new(0, if type(y) == "number" then y - hitbox.Position.Y else 0, 0)
		g.StudsOffset = Vector3.new(hitbox.Size.Y / 2 + SIGN_SIZE.X / 2 + 1, 0, 0)
		g.MaxDistance = 260
		g.LightInfluence = 0
		g.AlwaysOnTop = false
		g.ResetOnSpawn = false
		local back = Instance.new("Frame")
		back.Size = UDim2.fromScale(1, 1)
		back.BackgroundColor3 = DARK
		back.BackgroundTransparency = 0.15
		corner(back, 16)
		local edge = Instance.new("UIStroke")
		edge.Color = GOLD
		edge.Thickness = 3
		edge.Parent = back
		back.Parent = g
		local t = text(back, "Title", UDim2.new(1, -16, 0.34, 0), UDim2.new(0, 8, 0.04, 0))
		t.TextXAlignment = Enum.TextXAlignment.Center
		t.TextColor3 = GOLD
		t.Text = "GIANT GOLDEN EGG"
		local s = text(back, "Odds", UDim2.new(1, -16, 0.28, 0), UDim2.new(0, 8, 0.38, 0))
		s.TextXAlignment = Enum.TextXAlignment.Center
		local p = text(back, "Price", UDim2.new(1, -16, 0.26, 0), UDim2.new(0, 8, 0.69, 0), false)
		p.TextXAlignment = Enum.TextXAlignment.Center
		g.Parent = ctx.player:WaitForChild("PlayerGui")
		signTitle, signOdds, signPrice = t, s, p
	end

	local function attach(m: Model)
		model = m
		buildSign(m)
		local shell = m:FindFirstChild("Shell")
		table.clear(shellParts)
		if shell then
			for _, part in shell:GetChildren() do
				if part:IsA("BasePart") then
					table.insert(shellParts, { part = part, base = part.CFrame })
				end
			end
		end
		local at = m:GetAttribute("ShellPivot")
		pivot = if typeof(at) == "Vector3" then at else Vector3.zero
	end
	task.spawn(function()
		local m = Workspace:WaitForChild("GiantEgg", 60)
		if m and m:IsA("Model") then
			attach(m)
		end
	end)

	-- Its best odds in a line, e.g. "Legendary 1 in 57, Godly 1 in 200" (the
	-- egg's own tiers, which events never change), or the fixed order's
	-- note for a player under it.
	local giant = Hatchery.eggById(ctx.config.eggs, GiantEggRules.EGG_ID)
	local function oddsLine(): string
		if ctx.restricted() then
			return "in a set order (see its card)"
		end
		local parts = {}
		for _, rarity in { "Legendary", "Godly" } do
			local weight = giant and giant.tiers[rarity]
			if weight then
				table.insert(parts, `{rarity} {Odds.formatOneIn(weight, giant.total)}`)
			end
		end
		return table.concat(parts, ", ")
	end

	-- The shop sells a random item only to a player shown its odds in the
	-- last ten minutes (packages/core Purchases), so each time the Buy
	-- prompt comes up (and the Hud's odds card with it) the odds are asked
	-- for again, which marks them as shown on the server.
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		if prompt:GetAttribute("HHEggId") == GiantEggRules.EGG_ID then
			CoreClient.requestOdds(GiantEggRules.EGG_ID)
		end
	end)

	local function updateEgg(now: number)
		local m = model
		if m == nil then
			return
		end
		local endsAt = m:GetAttribute("CycleEndsAt")
		local status = GiantEggRules.status(ctx.data(), now, config)
		if signOdds then
			signOdds.Text = oddsLine()
		end
		-- An event special (Alex, Nov 7): coins while the day's event runs,
		-- Robux the rest of the day.
		local d = ctx.data()
		local duringEvent = EventClock.banner().active
		local coinPrice = if d
			then GiantEggRules.coinPrice(config, Hatchery.incomePerSecond(d, ctx.config, ctx.perks()))
			else nil
		-- A player PolicyService keeps from paid random items gets the fixed
		-- order for coins, but its Robux price is refused (catalog `blocked`).
		local blocked = catalogEntry ~= nil and catalogEntry.blocked == true
		local robuxReady = catalogEntry ~= nil and catalogEntry.available == true and not blocked
		local available = if duringEvent then coinPrice ~= nil else robuxReady
		local priceText = if duringEvent
			then `{Layout.shortNumber(coinPrice or 0)} coins`
			else ShopPlan.priceText(robuxReady, false, robloxPrice or listed)
		local left = if type(endsAt) == "number" then endsAt - now else status.endsAt - now
		if signPrice then
			signPrice.Text = if status.bought
				then `Yours today! Next one in {Events.countdown(left)}`
				elseif duringEvent then `EVENT SPECIAL: {priceText}  ·  one a day`
				elseif blocked then "For coins during the daily event"
				else `{priceText}  ·  one a day`
		end
		if signTitle then
			signTitle.TextColor3 = if status.bought then Color3.fromRGB(120, 230, 120) else GOLD
		end
		local hitbox = m:FindFirstChild("Hitbox")
		local prompt = hitbox and hitbox:FindFirstChild("BuyPrompt") :: ProximityPrompt?
		if prompt then
			prompt.ActionText = if status.bought
				then "Yours today"
				elseif available then `Buy for {priceText}`
				elseif blocked then "Coins during the event"
				else "Coming soon"
			-- Studio keeps an unfinished product pressable, so the server's
			-- "Use the Test panel" notice can be checked there.
			-- Never before its odds have arrived, like every egg.
			prompt.Enabled = not status.bought
				and OddsView.ready(GiantEggRules.EGG_ID)
				and (available or (RunService:IsStudio() and not blocked))
			prompt.ObjectText = if duringEvent then "Event special: costs coins now" else "Giant Golden Egg"
		end
		cardEgg.Text =
			`The Giant Golden Egg in the middle of the map: Epic or better, {oddsLine()}. {if status.bought
				then "You have today's!"
				else "One per player each day, and during the event it costs coins instead of Robux!"}`
	end

	local function update()
		local b = EventClock.banner()
		local color = rgb(b.color)
		title.Text = b.title
		line.Text = b.line
		badge.BackgroundColor3 = color
		badgeText.Text = BADGES[b.kind] or "!"
		stroke.Color = color
		stroke.Transparency = if b.active then 0 else 0.55
		title.TextColor3 = if b.active then color:Lerp(Color3.new(1, 1, 1), 0.35) else Color3.new(1, 1, 1)
		cardTitle.Text = if b.active
			then `{config.kinds[b.kind].title}: now!`
			else `Next event: {config.kinds[b.kind].title}`
		cardTitle.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35)
		cardStroke.Color = color
		cardBlurb.Text = b.blurb
		cardWhen.Text = if b.active
			then `Ends in {Events.countdown(b.seconds)}.`
			else `Starts in {Events.countdown(b.seconds)}.`
		updateEgg(EventClock.now())
	end

	-- A gentle pulse on the banner while an event runs.
	local start = os.clock()
	RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if stroke.Transparency < 0.5 then
			stroke.Thickness = 2.5 + math.sin(t * 4)
		end
		-- The shell's wobble.
		if #shellParts > 0 then
			local cam = Workspace.CurrentCamera
			local near = cam == nil or (cam.CFrame.Position - pivot).Magnitude <= ROCK_RANGE
			local phase = t % ROCK_EVERY
			local angle = 0
			if near and phase < ROCK_SECONDS then
				local p = phase / ROCK_SECONDS
				angle = ROCK_ANGLE * math.sin(p * math.pi * 4) * (1 - p)
			end
			local axis = if math.floor(t / ROCK_EVERY) % 2 == 0 then Vector3.xAxis else Vector3.zAxis
			local turn = CFrame.new(pivot) * CFrame.fromAxisAngle(axis, angle) * CFrame.new(-pivot)
			for _, s in shellParts do
				s.part.CFrame = turn * s.base
			end
		end
	end)

	local cam = Workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(fit)
	fit()
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				update()
			end)
			if not ok then
				warn(`[EventView] {err}`)
			end
			task.wait(0.5)
		end
	end)
end

return EventView
