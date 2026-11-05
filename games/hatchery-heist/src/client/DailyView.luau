--!strict
-- Daily Rewards window: seven days in a row, today's ready to claim, a
-- countdown to the next one. The side-menu button shows a "!" when a reward
-- is waiting, and the window opens by itself once per session for returning
-- players with one waiting. Amounts come from shared/Daily (so many seconds
-- of the player's income, at least a floor); the server pays and checks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Daily = require(Shared.Daily)
local Hatchery = require(Shared.Hatchery)
local Layout = require(Shared.Layout)

local Context = require(script.Parent.Context)
local Sfx = require(script.Parent.Sfx)

local DailyView = {}

local PANEL = Color3.fromRGB(28, 30, 48)
local TILE = Color3.fromRGB(44, 47, 72)
local GOLD = Color3.fromRGB(255, 210, 63)
local GREEN = Color3.fromRGB(80, 200, 100)
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

local function stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
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

local function clock(seconds: number): string
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = math.floor(seconds % 60)
	return string.format("%d:%02d:%02d", h, m, s)
end

type Tile = { frame: Frame, stroke: UIStroke, amount: TextLabel, state: TextLabel }

function DailyView.start(ctx: Context.Context, menu: Menu)
	local config = ctx.config.economy.daily
	local days = #config.rewards
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "DailyRewards"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 21
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromOffset(520, 322)
	window.BackgroundColor3 = PANEL
	corner(window, 16)
	stroke(window, GOLD, 3)
	window.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = window

	local title = text(window, "Title", "Daily Rewards", 30, GOLD)
	title.Position = UDim2.fromOffset(16, 8)
	title.Size = UDim2.new(1, -80, 0, 36)
	title.TextXAlignment = Enum.TextXAlignment.Left
	-- Fixed text sizes, wrapped rather than scaled: scaled text shrank to 10 or
	-- 11 px on phones (audit, Nov 5); nothing here goes under 13 px.
	local about =
		text(window, "About", "Come back every day for a bigger reward. Miss a day and it starts over.", 15)
	about.Position = UDim2.fromOffset(16, 44)
	about.Size = UDim2.new(1, -76, 0, 38)
	about.TextXAlignment = Enum.TextXAlignment.Left
	about.TextYAlignment = Enum.TextYAlignment.Top
	about.TextWrapped = true

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

	-- Days 1 to 6 in a row of small tiles, the last day as one big tile.
	local tiles: { Tile } = {}
	local small = days - 1
	local gap = 8
	local tileW = math.floor((520 - 32 - gap * (small - 1)) / small)
	for day = 1, days do
		local big = day == days
		local f = Instance.new("Frame")
		f.Name = `Day{day}`
		f.BackgroundColor3 = TILE
		if big then
			f.Position = UDim2.fromOffset(16, 204)
			f.Size = UDim2.fromOffset(520 - 32 - 170, 70)
		else
			f.Position = UDim2.fromOffset(16 + (day - 1) * (tileW + gap), 94)
			f.Size = UDim2.fromOffset(tileW, 100)
		end
		corner(f, 12)
		local s = stroke(f, GREY, 2)
		f.Parent = window
		local label = text(f, "Day", `Day {day}`, if big then 22 else 16, if big then GOLD else nil)
		label.Size = UDim2.new(1, 0, 0, if big then 28 else 22)
		label.Position = UDim2.fromOffset(0, 4)
		-- Small tiles show the number, with "coins" under it; the big tile
		-- has room for both on one line.
		local amount = text(f, "Amount", "", if big then 24 else 18, GOLD)
		amount.Size = UDim2.new(1, -4, 0, 24)
		amount.Position = UDim2.fromOffset(2, if big then 34 else 28)
		if not big then
			local unit = text(f, "Unit", "coins", 13, GOLD)
			unit.Size = UDim2.new(1, 0, 0, 16)
			unit.Position = UDim2.fromOffset(0, 52)
		end
		local state = text(f, "State", "", 14, Color3.fromRGB(220, 220, 235))
		state.Size = UDim2.new(1, 0, 0, 20)
		state.Position = UDim2.new(0, 0, 1, -26)
		if big then
			state.Visible = false
		end
		tiles[day] = { frame = f, stroke = s, amount = amount, state = state }
	end

	local claim = Instance.new("TextButton")
	claim.Name = "Claim"
	claim.AnchorPoint = Vector2.new(1, 0)
	claim.Position = UDim2.fromOffset(520 - 16, 204)
	claim.Size = UDim2.fromOffset(160, 70)
	claim.Font = FONT
	claim.TextSize = 24
	claim.TextColor3 = Color3.new(1, 1, 1)
	corner(claim, 12)
	stroke(claim, SHADOW, 2)
	claim.Parent = window

	local footer = text(window, "Footer", "", 16)
	footer.Position = UDim2.fromOffset(16, 288)
	footer.Size = UDim2.new(1, -32, 0, 22)

	local function fit()
		local cam = Workspace.CurrentCamera
		local screen = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		scale.Scale = math.min(1, (screen.X - 24) / 520, (screen.Y - 40) / 322)
	end

	-- The badge on the side-menu button.
	local button = menu.add("Daily", "🎁 Daily", function()
		Sfx.play("click")
		fit()
		gui.Enabled = not gui.Enabled
	end)
	local badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromOffset(4, 4)
	badge.Size = UDim2.fromOffset(22, 22)
	badge.BackgroundColor3 = Color3.fromRGB(230, 60, 60)
	badge.Font = FONT
	badge.TextSize = 16
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.Text = "!"
	badge.Visible = false
	corner(badge, 11)
	badge.Parent = button

	local waiting = false -- a claim is on its way to the server
	local claiming: number? = nil -- coins the claim on its way pays

	-- "+600 coins" rising from the Claim button once the coins land: the
	-- window covers the coin counter, so this is where a player sees it.
	local function pop(amount: number)
		local l = text(window, "Gained", `+{Layout.shortNumber(amount)} coins`, 30, GOLD)
		l.AnchorPoint = Vector2.new(0.5, 1)
		l.Position = UDim2.fromOffset(520 - 16 - 80, 204)
		l.Size = UDim2.fromOffset(240, 40)
		l.TextXAlignment = Enum.TextXAlignment.Center
		l.ZIndex = 5
		local rise =
			TweenService:Create(l, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.fromOffset(520 - 16 - 80, 150),
				TextTransparency = 1,
			})
		rise:Play()
		task.delay(1.7, function()
			l:Destroy()
		end)
	end
	local function refresh()
		local d = ctx.data()
		if d == nil then
			return
		end
		local now = ctx.serverNow()
		local status = Daily.status(d, now, days)
		local perSecond = Hatchery.incomePerSecond(d, ctx.config, ctx.perks())
		-- Days already claimed in this run of the streak.
		local claimedUpTo = if status.claimedToday and status.day == 1 then days else status.day - 1
		for day, tile in tiles do
			local coins = Layout.shortNumber(Daily.amount(day, perSecond, config))
			tile.amount.Text = if day == days then `{coins} coins` else coins
			local claimed = day <= claimedUpTo
			local today = status.ready and day == status.day
			local tomorrow = status.claimedToday and day == status.day and claimedUpTo < days
			tile.frame.BackgroundColor3 = if claimed
				then TILE:Lerp(GREEN, 0.25)
				elseif today then TILE:Lerp(GOLD, 0.2)
				else TILE
			tile.stroke.Color = if today then GOLD elseif claimed then GREEN else GREY
			tile.stroke.Thickness = if today then 3 else 2
			tile.state.Text = if claimed
				then "Claimed"
				elseif today then "Today!"
				elseif tomorrow then "Tomorrow"
				else ""
			tile.state.TextColor3 = if claimed
				then GREEN
				elseif today then GOLD
				else Color3.fromRGB(220, 220, 235)
		end
		local ready = status.ready and not waiting
		claim.Text = if ready then "Claim!" elseif waiting then "..." else clock(status.secondsLeft)
		claim.BackgroundColor3 = if ready then GREEN else GREY
		claim.AutoButtonColor = ready
		footer.Text = if status.ready
			then `Day {status.day} reward is ready.`
			else `Next reward in {clock(status.secondsLeft)}.`
		badge.Visible = status.ready
	end

	claim.Activated:Connect(function()
		local d = ctx.data()
		if d == nil or waiting then
			return
		end
		if not Daily.status(d, ctx.serverNow(), days).ready then
			return
		end
		waiting = true
		local status = Daily.status(d, ctx.serverNow(), days)
		claiming = Daily.amount(status.day, Hatchery.incomePerSecond(d, ctx.config, ctx.perks()), config)
		ctx.fire(ctx.remotes["HH:ClaimDaily"])
		refresh()
		-- The new data clears `waiting`; if the server refused, try again soon.
		task.delay(3, function()
			waiting = false
			claiming = nil
			refresh()
		end)
	end)
	close.Activated:Connect(function()
		Sfx.play("click")
		gui.Enabled = false
	end)

	local autoOpened = false
	ctx.onData(function(d: { [string]: any })
		waiting = false
		local paid = claiming
		if paid and Daily.status(d, ctx.serverNow(), days).claimedToday then
			claiming = nil
			Sfx.play("reward")
			if gui.Enabled then
				pop(paid)
			end
		end
		refresh()
		-- Returning players with a reward waiting see the window once.
		if not autoOpened then
			autoOpened = true
			local sessions = if type(d.meta) == "table" then d.meta.sessions or 0 else 0
			if sessions > 1 and Daily.status(d, ctx.serverNow(), days).ready then
				fit()
				gui.Enabled = true
			end
		end
	end)

	task.spawn(function()
		while true do
			if gui.Enabled then
				fit()
			end
			refresh()
			task.wait(1)
		end
	end)
end

return DailyView
