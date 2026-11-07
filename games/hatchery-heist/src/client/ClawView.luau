--!strict
-- The Charm Claw's window, opened by the machine's Play prompt in the farm
-- hub: the exact odds of every pull (per tier, as a percentage and as
-- "1 in N", from the server's own tables), what the 10- and 100-pulls
-- promise, how close pity is, the coin pulls and the two Robux pulls. Players
-- PolicyService keeps from paid random items see the Charm Counter instead:
-- a chosen charm for a fixed price, nothing random.
--
-- Pulls are only sold once this player's odds have arrived. What comes out
-- (HH:ClawResult) plays a reveal: one capsule for a single pull, a grid that
-- turns over one card at a time for ten (best last), and the haul grouped
-- by charm for a hundred. A tap skips ahead.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ClientNet = require(ReplicatedStorage.CoreClient.ClientNet)
local CoreClient = require(ReplicatedStorage.CoreClient.CoreClient)
local Odds = require(ReplicatedStorage.Core.Odds)
local ShopRemotes = require(ReplicatedStorage.Core.ShopRemotes)
local Shared = ReplicatedStorage.Shared
local Charms = require(Shared.Charms)
local Claw = require(Shared.Claw)
local Layout = require(Shared.Layout)

local CharmUi = require(script.Parent.CharmUi)
local CharmsView = require(script.Parent.CharmsView)
local Context = require(script.Parent.Context)
local Sfx = require(script.Parent.Sfx)

local ClawView = {}

local PROMPT_NAME = "ClawPrompt"
local MODEL_NAME = "ClawMachine"
local MAX_W, MAX_H = 760, 500
local GAP = 8
local ROW = 24
local BIG_RANK = 4 -- Ultra Rare and up get the bigger sound
local LEGEND_RANK = 6 -- Legendary and up get the gold burst
local DIP_STUDS = 2.2 -- how far the claw in the machine dips on a pull
local DIP_SECONDS = 0.5
local TOP_BAR = 58 -- px of Roblox's top bar the reveal keeps clear of

type CatalogEntry = { key: string, kind: string, id: number, available: boolean, blocked: boolean }

-- The odds tables a pull can roll from, in the order the full list shows
-- them, with what each is for.
local function tableList(config: any): { { id: string, title: string } }
	local out = { { id = Claw.TABLE, title = "Every pull" } }
	for _, pull in config.claw.pulls do
		if pull.atLeast then
			table.insert(out, {
				id = Claw.floorTable(pull.atLeast),
				title = `The {pull.count}-pull's promised pull ({pull.atLeast} or better)`,
			})
		end
	end
	local pityTable = Claw.floorTable(config.claw.pityTier)
	local seen = false
	for _, t in out do
		seen = seen or t.id == pityTable
	end
	if not seen then
		table.insert(out, { id = pityTable, title = `The pity pull ({config.claw.pityTier} or better)` })
	end
	return out
end

-- One display's weight summed per tier, rarest last.
local function tierRows(config: any, display: any): { { tier: string, weight: number } }
	local sums: { [string]: number } = {}
	for _, row in display.rows do
		local def = Charms.def(config, row.id)
		if def then
			sums[def.tier] = (sums[def.tier] or 0) + row.weight
		end
	end
	local out = {}
	for _, tier in config.tiers do
		if sums[tier] then
			table.insert(out, { tier = tier, weight = sums[tier] })
		end
	end
	return out
end

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function list(parent: Instance, padding: number): UIListLayout
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

local function scroller(parent: Instance, name: string): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.Name = name
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.ScrollBarThickness = 6
	s.Parent = parent
	return s
end

-- A row of the odds card: the left text, a percentage and "1 in N".
local function oddsRow(
	parent: Instance,
	order: number,
	left: string,
	color: Color3,
	percent: string,
	oneIn: string
)
	local f = Instance.new("Frame")
	f.Name = `Row{order}`
	f.LayoutOrder = order
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, -8, 0, ROW)
	local a = CharmUi.text(f, "Name", left, 16, color)
	a.Size = UDim2.fromScale(0.5, 1)
	a.TextXAlignment = Enum.TextXAlignment.Left
	a.TextTruncate = Enum.TextTruncate.AtEnd
	local b = CharmUi.text(f, "Percent", percent, 16)
	b.Position = UDim2.fromScale(0.5, 0)
	b.Size = UDim2.fromScale(0.22, 1)
	b.TextXAlignment = Enum.TextXAlignment.Right
	local c = CharmUi.text(f, "OneIn", oneIn, 14, Color3.fromRGB(200, 205, 225))
	c.Position = UDim2.fromScale(0.72, 0)
	c.Size = UDim2.fromScale(0.28, 1)
	c.TextXAlignment = Enum.TextXAlignment.Right
	f.Parent = parent
end

local function note(parent: Instance, order: number, text: string, size: number, color: Color3?): TextLabel
	local l = CharmUi.text(parent, `Note{order}`, text, size, color)
	l.LayoutOrder = order
	l.Size = UDim2.new(1, -8, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	return l
end

function ClawView.start(ctx: Context.Context)
	local config = ctx.config.charms
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local gui, window = CharmUi.window(playerGui, "ClawWindow", 23)

	local displays: { [string]: any } = {}
	local catalog: { [string]: CatalogEntry } = {}
	local fullList = false
	local robuxPrices: { [number]: string } = {}
	local busyUntil = 0 -- no second pull while one is on its way

	-- Header.
	local title = CharmUi.text(window, "Title", "Charm Claw", 30, CharmUi.GOLD)
	title.Position = UDim2.fromOffset(16, 6)
	title.Size = UDim2.fromOffset(200, 40)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local close = CharmUi.close(window)
	local bagButton = CharmUi.button(window, "Bag", "", CharmUi.TILE, 150)
	bagButton.AnchorPoint = Vector2.new(1, 0)
	bagButton.Position = UDim2.new(1, -62, 0, 8)

	-- Left: the odds (or the Charm Counter).
	local left = scroller(window, "Odds")
	left.Position = UDim2.fromOffset(14, 58)
	local leftPad = Instance.new("UIPadding")
	leftPad.PaddingTop = UDim.new(0, 2)
	leftPad.PaddingBottom = UDim.new(0, 8)
	leftPad.Parent = left
	list(left, 4)

	-- Right: the pulls.
	local right = scroller(window, "Pulls")
	local rightPad = Instance.new("UIPadding")
	rightPad.PaddingTop = UDim.new(0, 2)
	rightPad.PaddingBottom = UDim.new(0, 8)
	rightPad.Parent = right
	list(right, GAP)

	local function fit()
		local size = CharmUi.fit(window, MAX_W, MAX_H)
		-- Side by side when there's room, else the odds above the pulls.
		local wide = size.X >= 560
		if wide then
			local leftW = math.floor((size.X - 28 - 12) * 0.52)
			left.Size = UDim2.fromOffset(leftW, size.Y - 68)
			right.Position = UDim2.fromOffset(14 + leftW + 12, 58)
			right.Size = UDim2.fromOffset(size.X - 28 - leftW - 12, size.Y - 68)
		else
			local half = math.floor((size.Y - 68 - GAP) / 2)
			left.Size = UDim2.fromOffset(size.X - 24, half)
			right.Position = UDim2.fromOffset(14, 58 + half + GAP)
			right.Size = UDim2.fromOffset(size.X - 24, half)
		end
	end

	local function data(): { [string]: any }?
		return ctx.data()
	end

	local function ready(): boolean
		return displays[Claw.TABLE] ~= nil
	end

	local function requestOdds()
		for _, t in tableList(config) do
			CoreClient.requestOdds(t.id)
		end
	end

	-- The odds card.
	local function drawOdds()
		clear(left)
		local d = data()
		if ctx.restricted() then
			note(left, 1, "Charm Counter", 22, CharmUi.GOLD)
			note(
				left,
				2,
				"Pick the charm you want: no chance involved. Charms above Rare only come from the claw.",
				15,
				Color3.fromRGB(215, 225, 245)
			)
			local peak = if d then d.incomePeak or 0 else 0
			local order = 3
			for _, kindId in Charms.activeKinds(config) do
				local kind = Charms.kind(config, kindId)
				for rank = 1, #config.tiers do
					local def = Charms.at(config, kindId, rank)
					local price = def and Claw.counterPrice(peak, config, def.tier)
					if def and price then
						order += 1
						local f = Instance.new("Frame")
						f.Name = `Counter{def.id}`
						f.LayoutOrder = order
						f.BackgroundColor3 = CharmUi.TILE
						f.Size = UDim2.new(1, -8, 0, CharmUi.BUTTON + 8)
						CharmUi.corner(f, 10)
						CharmUi.stroke(f, Layout.rarityColor(def.tier), 2)
						local name =
							CharmUi.text(f, "Name", `{if kind then kind.icon else ""} {def.name}`, 15)
						name.Position = UDim2.fromOffset(8, 2)
						name.Size = UDim2.new(1, -150, 0, 22)
						name.TextXAlignment = Enum.TextXAlignment.Left
						name.TextTruncate = Enum.TextTruncate.AtEnd
						local effect = CharmUi.text(
							f,
							"Effect",
							Charms.effectText(config, def),
							13,
							Layout.rarityColor(def.tier):Lerp(Color3.new(1, 1, 1), 0.4)
						)
						effect.Position = UDim2.fromOffset(8, 26)
						effect.Size = UDim2.new(1, -150, 0, 20)
						effect.TextXAlignment = Enum.TextXAlignment.Left
						local afford = d ~= nil and (d.coins or 0) >= price
						local buy = CharmUi.button(
							f,
							"Buy",
							`{Layout.shortNumber(price)}`,
							if afford then CharmUi.GREEN else CharmUi.GREY,
							130
						)
						buy.AnchorPoint = Vector2.new(1, 0.5)
						buy.Position = UDim2.new(1, -6, 0.5, 0)
						buy.TextSize = 17
						buy.Activated:Connect(function()
							Sfx.play("click")
							ctx.fire(ctx.remotes["HH:CharmCounter"], def.id)
						end)
						f.Parent = left
					end
				end
			end
			return
		end

		local display = displays[Claw.TABLE]
		note(left, 1, "Odds of every pull", 22, CharmUi.GOLD)
		if display == nil then
			note(left, 2, "Loading the odds...", 16)
			return
		end
		for i, r in tierRows(config, display) do
			oddsRow(
				left,
				1 + i,
				r.tier,
				Layout.rarityColor(r.tier),
				Odds.formatPercent(r.weight, display.total),
				Odds.formatOneIn(r.weight, display.total)
			)
		end
		local kinds = Charms.activeKinds(config)
		local names = {}
		for _, kindId in kinds do
			local kind = Charms.kind(config, kindId)
			table.insert(names, if kind then kind.label else kindId)
		end
		note(
			left,
			20,
			`Each tier is split evenly between the {#kinds} kinds: {table.concat(names, ", ")}.`,
			14,
			Color3.fromRGB(200, 205, 225)
		)
		local order = 21
		for _, pull in config.claw.pulls do
			if pull.atLeast then
				order += 1
				note(
					left,
					order,
					`{pull.count} pulls: at least one {pull.atLeast} or better. If none came, the last pull is rolled from {pull.atLeast} and up.`,
					15,
					Color3.fromRGB(215, 225, 245)
				)
			end
		end
		local left_ = if d then Claw.pityLeft(d, config) else config.claw.pityAt
		order += 1
		note(
			left,
			order,
			`Pity: a {config.claw.pityTier} or better within {left_} {if left_ == 1 then "pull" else "pulls"}.`,
			16,
			CharmUi.AMBER
		)
		order += 1
		local seeAll = CharmUi.button(
			left,
			"SeeAll",
			if fullList then "Hide the full list" else "See every charm",
			CharmUi.BLUE,
			200
		)
		seeAll.LayoutOrder = order
		seeAll.Activated:Connect(function()
			Sfx.play("click")
			fullList = not fullList
			drawOdds()
		end)
		if not fullList then
			return
		end
		for _, t in tableList(config) do
			local shown = displays[t.id]
			order += 1
			note(left, order, t.title, 17, CharmUi.GOLD)
			if shown == nil then
				order += 1
				note(left, order, "Loading...", 15)
			else
				local rows = table.clone(shown.rows)
				-- Rarest last, then by kind, like the tiers above.
				table.sort(rows, function(a, b)
					local da, db = Charms.def(config, a.id), Charms.def(config, b.id)
					local ra, rb = da and da.rank or 0, db and db.rank or 0
					if ra ~= rb then
						return ra < rb
					end
					return a.id < b.id
				end)
				for _, r in rows do
					local def = Charms.def(config, r.id)
					order += 1
					oddsRow(
						left,
						order,
						if def then def.name else r.id,
						if def then Layout.rarityColor(def.tier) else Color3.new(1, 1, 1),
						Odds.formatPercent(r.weight, shown.total),
						Odds.formatOneIn(r.weight, shown.total)
					)
				end
			end
		end
	end

	-- The pulls.
	local function drawPulls()
		clear(right)
		local d = data()
		local coins = if d then d.coins or 0 else 0
		local peak = if d then d.incomePeak or 0 else 0
		local count = if d then Charms.bagCount(d) else 0
		bagButton.Text = `Bag {count} / {config.bagSlots}`
		bagButton.TextColor3 = if count >= config.bagWarnAt then CharmUi.AMBER else Color3.new(1, 1, 1)

		local balance = note(right, 1, `You have {Layout.shortNumber(coins)} coins`, 18, CharmUi.GOLD)
		balance.TextXAlignment = Enum.TextXAlignment.Left
		if ctx.restricted() then
			note(
				right,
				2,
				"The claw isn't available in your region. The Charm Counter sells charms for coins instead.",
				16,
				Color3.fromRGB(215, 225, 245)
			)
			return
		end
		local open = ready() and os.clock() >= busyUntil
		local order = 2
		for _, pull in config.claw.pulls do
			order += 1
			local price = Claw.price(peak, config, pull.count)
			local room = Charms.hasRoom(d or {}, config, pull.count)
			local can = open and room and coins >= price
			local label = if pull.count == 1 then "Pull x1" else `Pull x{pull.count}`
			local b = CharmUi.button(
				right,
				`Pull{pull.count}`,
				`{label}: {Layout.shortNumber(price)} coins`,
				if can then CharmUi.GREEN else CharmUi.GREY,
				240
			)
			b.Size = UDim2.new(1, -8, 0, CharmUi.BUTTON)
			b.LayoutOrder = order
			b.AutoButtonColor = can
			b.Activated:Connect(function()
				if not ready() then
					Sfx.play("click")
					requestOdds()
					return
				end
				if os.clock() < busyUntil then
					return
				end
				Sfx.play("click")
				busyUntil = os.clock() + 1.5
				ctx.fire(ctx.remotes["HH:ClawPull"], pull.count)
				drawPulls()
			end)
		end
		if not ready() then
			order += 1
			note(right, order, "The odds load first: pulls open once they're on screen.", 14, CharmUi.AMBER)
		end
		if count >= config.bagWarnAt then
			order += 1
			note(
				right,
				order,
				"Your charm bag is nearly full. Fuse charms in the Charms window to make room.",
				14,
				CharmUi.AMBER
			)
		end

		-- The Robux pulls, shown with "Coming soon" until they're on Roblox.
		order += 1
		note(right, order, "Robux pulls", 18, CharmUi.GOLD)
		for _, pull in config.claw.pulls do
			if pull.product then
				local entry = catalog[pull.product]
				local live = entry ~= nil and entry.available and not entry.blocked
				local robux = if entry then robuxPrices[entry.id] else nil
				order += 1
				local text = if live
					then `{pull.count} pulls{if robux and robux ~= "" then `: {robux}` else ""}`
					else `{pull.count} pulls: coming soon`
				local b = CharmUi.button(
					right,
					`Buy{pull.product}`,
					text,
					if live and ready() then CharmUi.BLUE else CharmUi.GREY,
					240
				)
				b.Size = UDim2.new(1, -8, 0, CharmUi.BUTTON)
				b.LayoutOrder = order
				b.AutoButtonColor = live
				b.Activated:Connect(function()
					if live and ready() then
						Sfx.play("click")
						ClientNet.fire(ShopRemotes["Shop:Buy"], "product", pull.product, "ClawMachine")
					end
				end)
			end
		end
		order += 1
		note(
			right,
			order,
			"Robux pulls use the same odds and promises as coin pulls. Charms only add small bonuses.",
			13,
			Color3.fromRGB(200, 205, 225)
		)
	end

	local function render()
		if gui.Enabled then
			drawOdds()
			drawPulls()
		end
	end

	local function open()
		if gui.Enabled then
			return
		end
		gui.Enabled = true
		fit()
		requestOdds()
		ClientNet.fire(ShopRemotes["Shop:RequestCatalog"])
		render()
	end

	local function shut()
		gui.Enabled = false
		fullList = false
	end

	close.Activated:Connect(function()
		Sfx.play("click")
		shut()
	end)
	bagButton.Activated:Connect(function()
		Sfx.play("click")
		shut()
		CharmsView.open()
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		if who == player and prompt.Name == PROMPT_NAME then
			Sfx.play("click")
			open()
		end
	end)

	CoreClient.onOdds(function(display: any)
		if type(display) ~= "table" or type(display.tableId) ~= "string" or type(display.rows) ~= "table" then
			return
		end
		for _, t in tableList(config) do
			if t.id == display.tableId then
				displays[t.id] = display
				render()
				return
			end
		end
	end)
	ClientNet.on(ShopRemotes["Shop:Catalog"], function(entries: { CatalogEntry })
		table.clear(catalog)
		for _, entry in entries do
			if entry.kind == "product" and Claw.productPulls(config, entry.key) then
				catalog[entry.key] = entry
				-- The Robux price, from Roblox (what the purchase prompt shows).
				if entry.available and robuxPrices[entry.id] == nil then
					robuxPrices[entry.id] = ""
					task.spawn(function()
						local ok, info = pcall(function()
							return MarketplaceService:GetProductInfo(entry.id, Enum.InfoType.Product)
						end)
						local price = ok and type(info) == "table" and info.PriceInRobux
						robuxPrices[entry.id] = if type(price) == "number" then `R$ {price}` else ""
						render()
					end)
				end
			end
		end
		render()
	end)
	ctx.onData(function()
		render()
	end)
	-- The screen's size can arrive (or change, turning a phone) after the
	-- window opened.
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if gui.Enabled then
			fit()
		end
	end)

	-- Walking away closes the window (the server only sells at the machine).
	task.spawn(function()
		while true do
			task.wait(0.5)
			if gui.Enabled then
				local machine = Workspace:FindFirstChild(MODEL_NAME)
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if machine and machine:IsA("Model") and root then
					local at = machine:GetPivot().Position
					local flat = Vector3.new(root.Position.X - at.X, 0, root.Position.Z - at.Z)
					if flat.Magnitude > config.claw.reach then
						shut()
					end
				end
				fit()
				if os.clock() >= busyUntil and busyUntil > 0 then
					busyUntil = 0
					render()
				end
			end
		end
	end)

	----------------------------------------------------------------------
	-- The reveal.
	----------------------------------------------------------------------
	local revealGui = Instance.new("ScreenGui")
	revealGui.Name = "ClawReveal"
	revealGui.ResetOnSpawn = false
	revealGui.IgnoreGuiInset = true
	revealGui.DisplayOrder = 40
	revealGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	revealGui.Enabled = false
	revealGui.Parent = playerGui
	local shade = Instance.new("TextButton")
	shade.Name = "Shade"
	shade.Text = ""
	shade.AutoButtonColor = false
	shade.BackgroundColor3 = Color3.fromRGB(8, 8, 16)
	shade.BackgroundTransparency = 0.12
	shade.Size = UDim2.fromScale(1, 1)
	shade.Parent = revealGui
	local burst = Instance.new("Frame")
	burst.Name = "Burst"
	burst.AnchorPoint = Vector2.new(0.5, 0.5)
	burst.Position = UDim2.fromScale(0.5, 0.45)
	burst.BackgroundColor3 = CharmUi.GOLD
	burst.BackgroundTransparency = 1
	burst.Size = UDim2.fromOffset(10, 10)
	CharmUi.corner(burst, 999)
	burst.Parent = revealGui
	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.new(0.5, 0, 0.5, TOP_BAR / 2)
	stage.BackgroundTransparency = 1
	stage.Parent = revealGui
	local heading = CharmUi.text(stage, "Heading", "", 28, CharmUi.GOLD)
	heading.Size = UDim2.new(1, 0, 0, 36)
	local tray = Instance.new("Frame")
	tray.Name = "Tray"
	tray.BackgroundTransparency = 1
	tray.Position = UDim2.fromOffset(0, 44)
	tray.Parent = stage
	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.BackgroundTransparency = 1
	footer.AnchorPoint = Vector2.new(0.5, 1)
	footer.Position = UDim2.fromScale(0.5, 1)
	footer.Size = UDim2.new(1, 0, 0, CharmUi.BUTTON)
	footer.Parent = stage
	local footerRow = Instance.new("UIListLayout")
	footerRow.FillDirection = Enum.FillDirection.Horizontal
	footerRow.HorizontalAlignment = Enum.HorizontalAlignment.Center
	footerRow.Padding = UDim.new(0, 12)
	footerRow.SortOrder = Enum.SortOrder.LayoutOrder
	footerRow.Parent = footer
	local skip = CharmUi.button(footer, "Skip", "Skip", CharmUi.GREY, 120)
	skip.LayoutOrder = 1
	local toCharms = CharmUi.button(footer, "OpenCharms", "Open Charms", CharmUi.BLUE, 160)
	toCharms.LayoutOrder = 2
	local done = CharmUi.button(footer, "Done", "Done", CharmUi.GREEN, 120)
	done.LayoutOrder = 3

	local queue: { { ids: { string }, source: string } } = {}
	local showing = false
	local skipNow: (() -> ())? = nil
	local finish: (() -> ())? = nil

	-- The room the reveal has: the screen below Roblox's top bar.
	local function screenSize(): Vector2
		local s = revealGui.AbsoluteSize
		if s.X <= 0 or s.Y <= 0 then
			local camera = Workspace.CurrentCamera
			s = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		end
		return Vector2.new(s.X, s.Y - TOP_BAR - 16)
	end
	-- Heading, gap, footer: what a stage needs besides its tray.
	local CHROME = 44 + 12 + CharmUi.BUTTON

	local function flash(rank: number)
		if rank >= LEGEND_RANK then
			Sfx.play("revealLegend")
			local s = screenSize()
			local size = math.max(s.X, s.Y) * 1.4
			burst.Size = UDim2.fromOffset(40, 40)
			burst.BackgroundTransparency = 0.15
			TweenService:Create(
				burst,
				TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 }
			):Play()
		elseif rank >= BIG_RANK then
			Sfx.play("revealBig")
		else
			Sfx.play("reward")
		end
	end

	-- A card that pops in from nothing.
	local function pop(card: CharmUi.Card, size: Vector2)
		local b = card.button
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		local home = b.Position
		b.Size = UDim2.fromOffset(0, 0)
		TweenService:Create(
			b,
			TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = UDim2.fromOffset(size.X, size.Y), Position = home }
		):Play()
	end

	-- The world claw dips into the capsules (this client only).
	local function dip()
		local machine = Workspace:FindFirstChild(MODEL_NAME)
		local clawModel = machine and machine:FindFirstChild("Claw")
		if clawModel == nil or not clawModel:IsA("Model") then
			return
		end
		local model = clawModel :: Model
		local home = model:GetAttribute("Home")
		if typeof(home) ~= "CFrame" then
			home = model:GetPivot()
			model:SetAttribute("Home", home)
		end
		local start = os.clock()
		local conn: RBXScriptConnection? = nil
		conn = RunService.RenderStepped:Connect(function()
			local t = (os.clock() - start) / (DIP_SECONDS * 2)
			if t >= 1 or model.Parent == nil then
				model:PivotTo(home :: CFrame)
				if conn then
					conn:Disconnect()
				end
				return
			end
			local depth = math.sin(t * math.pi) * DIP_STUDS
			model:PivotTo((home :: CFrame) * CFrame.new(0, -depth, 0))
		end)
	end

	local playNext: () -> ()

	local token = 0 -- which reveal is on screen, so an old timer can't close a newer one

	local function endReveal()
		token += 1
		clear(tray)
		revealGui.Enabled = false
		skipNow = nil
		finish = nil
		showing = false
		if #queue > 0 then
			playNext()
		elseif not gui.Enabled then
			-- Back to the machine's window if the player is still there.
			local machine = Workspace:FindFirstChild(MODEL_NAME)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if machine and machine:IsA("Model") and root then
				local at = machine:GetPivot().Position
				if
					(Vector3.new(root.Position.X - at.X, 0, root.Position.Z - at.Z)).Magnitude
					<= config.claw.reach
				then
					open()
				end
			end
		end
	end

	-- One charm: a big card with its turning model.
	local function showOne(id: string)
		local def = Charms.def(config, id)
		if def == nil then
			endReveal()
			return
		end
		local s = screenSize()
		local w = math.min(300, s.X - 40)
		local h = math.min(360, s.Y - CHROME)
		stage.Size = UDim2.fromOffset(w, h + CHROME)
		tray.Size = UDim2.fromOffset(w, h)
		heading.Text = "You got"
		local card = CharmUi.card(tray, config, def, 1)
		card.button.Position = UDim2.fromOffset(w / 2, h / 2)
		card.button.Active = false
		card.name.TextSize = 22
		card.name.Size = UDim2.new(1, -8, 0, 30)
		card.name.Position = UDim2.new(0, 4, 1, -88)
		card.effect.TextSize = 16
		card.effect.Size = UDim2.new(1, -8, 0, 24)
		card.effect.Position = UDim2.new(0, 4, 1, -54)
		card.icon.Visible = false
		local tier = CharmUi.text(card.button, "Tier", def.tier, 18, Layout.rarityColor(def.tier))
		tier.Size = UDim2.new(1, -8, 0, 22)
		tier.Position = UDim2.new(0, 4, 1, -28)
		local box = Instance.new("Frame")
		box.Name = "PreviewBox"
		box.BackgroundTransparency = 1
		box.Position = UDim2.fromOffset(10, 10)
		box.Size = UDim2.new(1, -20, 1, -104)
		box.Parent = card.button
		local show = CharmUi.preview(box, config)
		show(id)
		pop(card, Vector2.new(w, h))
		flash(def.rank)
		skip.Visible = false
		done.Visible = true
		toCharms.Visible = true
		finish = endReveal
		local mine = token
		task.delay(config.claw.revealSeconds.single + 2, function()
			if token == mine and revealGui.Enabled then
				endReveal()
			end
		end)
	end

	-- Ten (or any few): a grid that turns over one card at a time, best last.
	local function showFew(ids: { string })
		local defs = {}
		for _, id in ids do
			local def = Charms.def(config, id)
			if def then
				table.insert(defs, def)
			end
		end
		table.sort(defs, function(a, b)
			return a.rank < b.rank
		end)
		local s = screenSize()
		local cols = if s.X >= 620 then 5 else 4
		local rows = math.ceil(#defs / cols)
		local cellW = math.min(118, math.floor((s.X - 40 - (cols - 1) * GAP) / cols))
		local cellH = math.min(126, math.floor((s.Y - CHROME - (rows - 1) * GAP) / rows))
		cellH = math.max(cellH, 84)
		local w = cols * cellW + (cols - 1) * GAP
		local h = rows * cellH + (rows - 1) * GAP
		stage.Size = UDim2.fromOffset(w, h + CHROME)
		tray.Size = UDim2.fromOffset(w, h)
		heading.Text = `{#defs} charms!`
		local step = config.claw.revealSeconds.ten / math.max(1, #defs)
		local shown = 0
		local cards: { CharmUi.Card } = {}
		local backs: { Frame } = {}
		for i, def in defs do
			local col = (i - 1) % cols
			local row = math.floor((i - 1) / cols)
			local card = CharmUi.card(tray, config, def, i)
			card.button.Active = false
			card.button.Size = UDim2.fromOffset(cellW, cellH)
			card.button.Position = UDim2.fromOffset(col * (cellW + GAP), row * (cellH + GAP))
			card.button.Visible = false
			local back = Instance.new("Frame")
			back.Name = `Back{i}`
			back.BackgroundColor3 = CharmUi.TILE
			back.Size = card.button.Size
			back.Position = card.button.Position
			CharmUi.corner(back, 12)
			CharmUi.stroke(back, CharmUi.GOLD, 2)
			local q = CharmUi.text(back, "Mark", "?", 40, CharmUi.GOLD)
			q.Size = UDim2.fromScale(1, 1)
			back.Parent = tray
			cards[i] = card
			backs[i] = back
		end
		local function turn(i: number)
			local card = cards[i]
			if card == nil or card.button.Visible then
				return
			end
			backs[i].Visible = false
			card.button.Position += UDim2.fromOffset(cellW / 2, cellH / 2)
			card.button.Visible = true
			pop(card, Vector2.new(cellW, cellH))
			shown += 1
		end
		local function all()
			for i in cards do
				turn(i)
			end
			skip.Visible = false
			done.Visible = true
			toCharms.Visible = true
		end
		skip.Visible = true
		done.Visible = false
		toCharms.Visible = false
		skipNow = function()
			all()
			local best = defs[#defs]
			if best then
				flash(best.rank)
			end
			skipNow = nil
		end
		finish = endReveal
		task.spawn(function()
			for i, def in defs do
				if skipNow == nil or not revealGui.Enabled then
					return
				end
				task.wait(if i == #defs then step * 2 else step)
				if skipNow == nil or not revealGui.Enabled then
					return
				end
				turn(i)
				if i == #defs then
					flash(def.rank)
				else
					Sfx.play("click", 1 + i * 0.03)
				end
			end
			if skipNow then
				skipNow = nil
				all()
			end
		end)
	end

	-- A hundred: the haul grouped by charm, best first, with counts.
	local function showMany(ids: { string })
		local counts: { [string]: number } = {}
		local best = 0
		for _, id in ids do
			counts[id] = (counts[id] or 0) + 1
			local def = Charms.def(config, id)
			if def then
				best = math.max(best, def.rank)
			end
		end
		local defs = {}
		for id in counts do
			local def = Charms.def(config, id)
			if def then
				table.insert(defs, def)
			end
		end
		table.sort(defs, function(a, b)
			if a.rank ~= b.rank then
				return a.rank > b.rank
			end
			return a.id < b.id
		end)
		local s = screenSize()
		local w = math.min(720, s.X - 40)
		local h = math.min(420, s.Y - CHROME)
		stage.Size = UDim2.fromOffset(w, h + CHROME)
		tray.Size = UDim2.fromOffset(w, h)
		heading.Text = `{#ids} charms!`
		local grid = scroller(tray, "Haul")
		grid.Size = UDim2.fromScale(1, 1)
		local layout = Instance.new("UIGridLayout")
		local cols = math.clamp(math.floor((w - 10 + GAP) / (104 + GAP)), 3, 6)
		local cellW = math.floor((w - 10 - (cols - 1) * GAP) / cols)
		layout.CellSize = UDim2.fromOffset(cellW, 112)
		layout.CellPadding = UDim2.fromOffset(GAP, GAP)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		for i, def in defs do
			local card = CharmUi.card(grid, config, def, i)
			card.button.Active = false
			card.count.Text = `x{counts[def.id]}`
		end
		skip.Visible = false
		done.Visible = true
		toCharms.Visible = true
		finish = endReveal
		flash(best)
	end

	playNext = function()
		local next_ = table.remove(queue, 1)
		if next_ == nil then
			return
		end
		showing = true
		clear(tray)
		revealGui.Enabled = true
		if #next_.ids == 1 then
			showOne(next_.ids[1])
		elseif #next_.ids <= 20 then
			showFew(next_.ids)
		else
			showMany(next_.ids)
		end
	end

	shade.Activated:Connect(function()
		if skipNow then
			skipNow()
		elseif finish then
			finish()
		end
	end)
	skip.Activated:Connect(function()
		Sfx.play("click")
		if skipNow then
			skipNow()
		end
	end)
	done.Activated:Connect(function()
		Sfx.play("click")
		endReveal()
	end)
	toCharms.Activated:Connect(function()
		Sfx.play("click")
		table.clear(queue)
		endReveal()
		shut()
		CharmsView.open()
	end)

	ctx.on(ctx.remotes["HH:ClawResult"], function(ids: { string }, source: string)
		busyUntil = 0
		if #ids == 0 then
			render()
			return
		end
		-- The window steps aside for the reveal and comes back after.
		shut()
		dip()
		table.insert(queue, { ids = ids, source = source })
		if not showing then
			showing = true
			task.delay(if source == "Coins" then DIP_SECONDS else 0, playNext)
		end
	end)
end

return ClawView
