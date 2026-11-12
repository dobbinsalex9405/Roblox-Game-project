--!strict
-- The Tower window (shared/Tower.luau): every floor with its theme and
-- bonus: build the next one, buy upgrades, and, standing on an elevator
-- stop, ride to a floor. Opened from the side menu or the elevator.
-- The Creatures window (place, stash, merge) is client/InventoryView,
-- started from here so it keeps its place in the side menu.
--
-- The client only asks; the server checks every move (Actions).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Layout)
local Tower = require(Shared.Tower)
local TowerDecor = require(Shared.TowerDecor)

local Context = require(script.Parent.Context)
local InventoryView = require(script.Parent.InventoryView)
local Sfx = require(script.Parent.Sfx)

local TowerView = {}

local PANEL = Color3.fromRGB(28, 30, 48)
local ROW = Color3.fromRGB(44, 47, 72)
local GOLD = Color3.fromRGB(255, 210, 63)
local GREEN = Color3.fromRGB(80, 200, 100)
local BLUE = Color3.fromRGB(70, 150, 230)
local GREY = Color3.fromRGB(110, 110, 125)
local SHADOW = Color3.fromRGB(16, 16, 26)
local FONT = Enum.Font.FredokaOne

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
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	local s = Instance.new("UIStroke")
	s.Thickness = 1.5
	s.Color = SHADOW
	s.Parent = l
	l.Parent = parent
	return l
end

local function button(parent: Instance, name: string, label: string, color: Color3, width: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.fromOffset(width, 40) -- 40 px: the phone tap minimum
	b.BackgroundColor3 = color
	b.Font = FONT
	b.TextSize = 15
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = label
	corner(b, 8)
	stroke(b, SHADOW, 1.5)
	b.Parent = parent
	return b
end

-- A window with a title, an X and a scrolling list; `fit` sizes it to the
-- screen.
local function window(
	name: string,
	title: string,
	order: number
): (ScreenGui, Frame, ScrollingFrame, () -> ())
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.DisplayOrder = order
	gui.Enabled = false
	local frame = Instance.new("Frame")
	frame.Name = "Window"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.BackgroundColor3 = PANEL
	corner(frame, 16)
	stroke(frame, GOLD, 3)
	frame.Parent = gui
	local heading = text(frame, "Title", title, 28, GOLD)
	heading.Position = UDim2.fromOffset(16, 8)
	heading.Size = UDim2.new(1, -80, 0, 36)
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
	close.Parent = frame
	close.Activated:Connect(function()
		Sfx.play("click")
		gui.Enabled = false
	end)
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(10, 96)
	list.Size = UDim2.new(1, -20, 1, -104)
	list.CanvasSize = UDim2.fromScale(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = list
	list.Parent = frame
	local function fit()
		local cam = Workspace.CurrentCamera
		local screen = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		frame.Size = UDim2.fromOffset(math.min(600, screen.X - 24), math.min(520, screen.Y - 40))
	end
	return gui, frame, list, fit
end

local function clear(list: ScrollingFrame)
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function row(list: ScrollingFrame, order: number, height: number, color: Color3?): Frame
	local f = Instance.new("Frame")
	f.Name = `Row{order}`
	f.LayoutOrder = order
	f.Size = UDim2.new(1, 0, 0, height)
	f.BackgroundColor3 = color or ROW
	corner(f, 10)
	f.Parent = list
	return f
end

local function coins(n: number): string
	return `{Layout.shortNumber(n)} coins`
end

local function times(m: number): string
	return `x{string.format("%.2f", m)}`
end

-- Opens the Tower window; set by start.
local openTower: (atElevator: boolean) -> () = function() end

-- The elevator stop's prompt (BaseView) opens the Tower window with the
-- floor buttons.
function TowerView.elevator()
	openTower(true)
end

function TowerView.start(ctx: Context.Context, menu: Menu)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local economy = ctx.config.economy
	local themes = economy.tower.themes
	local decor: TowerDecor.Config = require(ReplicatedStorage.GameConfig.towerDecor) :: any

	------------------------------------------------------------------ Tower
	local towerGui, towerFrame, floorList, fitTower = window("TowerMenu", "Your Tower", 22)
	towerGui.Parent = playerGui
	local towerInfo = text(towerFrame, "Info", "", 15)
	towerInfo.Position = UDim2.fromOffset(16, 46)
	towerInfo.Size = UDim2.new(1, -32, 0, 40)
	towerInfo.TextWrapped = true
	towerInfo.TextYAlignment = Enum.TextYAlignment.Top
	local elevatorMode = false
	local menus = (require(ReplicatedStorage.GameConfig.atmosphere) :: any).menus
	-- A floor whose row shows a word in place of its button for a moment:
	-- "Building..." after a tap, "Built!" once done, "Need ... more".
	local held: { [number]: { text: string, color: Color3, untilAt: number } } = {}
	local drawTower: () -> ()
	local function hold(floor: number, words: string, color: Color3, seconds: number)
		local entry = { text = words, color = color, untilAt = os.clock() + seconds }
		held[floor] = entry
		drawTower()
		task.delay(seconds, function()
			if held[floor] == entry then
				held[floor] = nil
				if towerGui.Enabled then
					drawTower()
				end
			end
		end)
	end

	drawTower = function()
		local d = ctx.data()
		if d == nil then
			return
		end
		clear(floorList)
		local owned = Tower.owned(d)
		towerInfo.Text = if elevatorMode
			then "Elevator: tap Go to ride to a floor."
			else "Higher floors earn more. Upgrades make a floor cosier and raise its bonus."
		for floor = 1, Tower.FLOORS do
			local built = floor <= owned
			local isNext = floor == owned + 1
			local r = row(floorList, floor, 58, if built then ROW else ROW:Lerp(SHADOW, 0.5))
			local look = Layout.FLOOR_LOOKS[floor]
			local swatch = Instance.new("Frame")
			swatch.Name = "Swatch"
			swatch.Position = UDim2.fromOffset(8, 8)
			swatch.Size = UDim2.fromOffset(10, 42)
			swatch.BackgroundColor3 = if built then look.trim else GREY
			corner(swatch, 4)
			swatch.Parent = r
			local name = text(r, "Name", `{floor}. {themes[floor]}`, 17, if built then nil else GREY)
			name.Position = UDim2.fromOffset(26, 6)
			name.Size = UDim2.new(1, -262, 0, 22)
			local detail = ""
			if built then
				local m = Tower.multiplier(d, floor, economy)
				local ups = Tower.upgrades(d, floor)
				local nextName = TowerDecor.nextName(decor, floor, ups)
				detail = if floor == 1
					then "Ground floor  x1.00"
					elseif
						nextName
					then `{times(m)} of {times(Tower.fullMultiplier(floor, economy))}  ·  Next: {nextName} ({ups}/{#economy.tower.upgradeShares})`
					else `{times(m)}  ·  Fully furnished`
			else
				detail =
					`{times(Tower.multiplier({ floorUpgrades = {} }, floor, economy))} when built, up to {times(
						Tower.fullMultiplier(floor, economy)
					)}`
			end
			local info = text(r, "Detail", detail, 14, Color3.fromRGB(210, 210, 225))
			info.Position = UDim2.fromOffset(26, 30)
			info.Size = UDim2.new(1, -262, 0, 20)
			local buttons = Instance.new("Frame")
			buttons.Name = "Buttons"
			buttons.BackgroundTransparency = 1
			buttons.AnchorPoint = Vector2.new(1, 0.5)
			buttons.Position = UDim2.new(1, -8, 0.5, 0)
			buttons.Size = UDim2.fromOffset(232, 40)
			local bl = Instance.new("UIListLayout")
			bl.FillDirection = Enum.FillDirection.Horizontal
			bl.HorizontalAlignment = Enum.HorizontalAlignment.Right
			bl.Padding = UDim.new(0, 6)
			bl.Parent = buttons
			buttons.Parent = r
			if built and elevatorMode then
				local go = button(buttons, "Go", "Go", BLUE, 56)
				go.Activated:Connect(function()
					Sfx.play("click")
					ctx.fire(ctx.remotes["HH:GoFloor"], floor)
					towerGui.Enabled = false
				end)
			end
			local hasHold = held[floor]
			if hasHold and os.clock() < hasHold.untilAt then
				local word = text(buttons, "Held", hasHold.text, 17, hasHold.color)
				word.Size = UDim2.fromOffset(168, 40)
				word.TextXAlignment = Enum.TextXAlignment.Center
			elseif built then
				local price = Tower.nextUpgradePrice(d, floor, economy)
				if price then
					local up = button(
						buttons,
						"Upgrade",
						`Upgrade {coins(price)}`,
						if d.coins >= price then GREEN else GREY,
						168
					)
					up.Activated:Connect(function()
						Sfx.play("click")
						local now = ctx.data()
						if now and now.coins < price then
							hold(
								floor,
								`Need {Layout.shortNumber(price - now.coins)} more`,
								GREY:Lerp(Color3.new(1, 1, 1), 0.5),
								menus.holdSeconds
							)
							return
						end
						hold(floor, "Upgrading...", GOLD, menus.waitSeconds)
						ctx.fire(ctx.remotes["HH:UpgradeFloor"], floor)
					end)
				end
			elseif isNext then
				local price = Tower.nextFloorPrice(d, economy) :: number
				local build = button(
					buttons,
					"Build",
					`Build {coins(price)}`,
					if d.coins >= price then GREEN else GREY,
					168
				)
				build.Activated:Connect(function()
					Sfx.play("click")
					local now = ctx.data()
					if now and now.coins < price then
						hold(
							floor,
							`Need {Layout.shortNumber(price - now.coins)} more`,
							GREY:Lerp(Color3.new(1, 1, 1), 0.5),
							menus.holdSeconds
						)
						return
					end
					hold(floor, "Building...", GOLD, menus.waitSeconds)
					ctx.fire(ctx.remotes["HH:BuyFloor"])
				end)
			else
				local lock = text(buttons, "Price", coins(economy.tower.floorPrices[floor - 1]), 15, GREY)
				lock.Size = UDim2.fromOffset(168, 40)
				lock.TextXAlignment = Enum.TextXAlignment.Right
			end
		end
	end

	openTower = function(atElevator: boolean)
		elevatorMode = atElevator
		fitTower()
		drawTower()
		towerGui.Enabled = true
	end
	menu.add("Tower", "🏰 Tower", function()
		Sfx.play("click")
		if towerGui.Enabled then
			towerGui.Enabled = false
		else
			openTower(false)
		end
	end)

	-------------------------------------------------------------- Creatures
	-- The Creatures window (stash, place, merge) lives in InventoryView.
	InventoryView.start(ctx, menu)

	-- Redraw an open window when the save changes (a purchase, a move, a
	-- new hatch, a button turning green).
	local lastTower = ""
	local seenOwned: number? = nil
	local seenUpgrades: { [number]: number } = {}
	ctx.onData(function(d: { [string]: any })
		-- A floor just built or upgraded: "Built!" in its row for a moment,
		-- with a sound, before its next button shows.
		local owned = Tower.owned(d)
		local before = seenOwned
		if before and owned > before then
			Sfx.play("reward")
			for floor = before + 1, owned do
				hold(floor, "Built!", GOLD, menus.holdSeconds)
			end
		end
		for floor = 2, owned do
			local n = Tower.upgrades(d, floor)
			local was = seenUpgrades[floor]
			if before and floor <= before and was and n > was then
				Sfx.play("reward")
				hold(floor, "Upgraded!", GOLD, menus.holdSeconds)
			end
			seenUpgrades[floor] = n
		end
		seenOwned = owned
		if towerGui.Enabled then
			-- only when a button changes, never on every coin (a rebuilt
			-- button loses the click being made on it)
			local key = `{Tower.menuKey(d, economy)}|{tostring(elevatorMode)}`
			if key ~= lastTower then
				lastTower = key
				drawTower()
			end
		end
	end)
end

return TowerView
