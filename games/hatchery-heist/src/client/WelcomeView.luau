--!strict
-- The welcome back card: what the creatures earned while the player was
-- away, with Double Offline Earnings (25 Robux) beside it. This card is the
-- only place that item is sold (Robux list, approved Nov 12). The card shows
-- only when the item is on sale and the coins are worth doubling; otherwise
-- the welcome back stays a notice line (Hud).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modal = require(ReplicatedStorage.CoreClient.Modal)
local Layout = require(ReplicatedStorage.Shared.Layout)

local Context = require(script.Parent.Context)
local Offers = require(script.Parent.Offers)
local Sfx = require(script.Parent.Sfx)

local WelcomeView = {}

local PANEL = Color3.fromRGB(28, 30, 48)
local GOLD = Color3.fromRGB(255, 210, 63)
local GREEN = Color3.fromRGB(80, 200, 100)
local GREY = Color3.fromRGB(110, 110, 125)
local SHADOW = Color3.fromRGB(16, 16, 26)
local FONT = Enum.Font.FredokaOne
local WIDTH, HEIGHT = 380, 214

export type View = {
	-- Shows the card for `earned` coins and `readyEggs` finished eggs.
	-- Returns false (nothing shown) when Double Offline is not on sale. May
	-- wait a few seconds for the shop's catalog.
	show: (earned: number, readyEggs: number) -> boolean,
}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color
	s.Thickness = thickness
	s.Parent = parent
end

local function label(parent: Instance, name: string, size: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextSize = size
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local function button(parent: Instance, name: string, text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.fromOffset(166, 48)
	b.BackgroundColor3 = color
	b.Font = FONT
	b.TextSize = 22
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	corner(b, 12)
	stroke(b, SHADOW, 2)
	b.Parent = parent
	return b
end

function WelcomeView.start(_ctx: Context.Context): View
	local gui = Instance.new("ScreenGui")
	gui.Name = "WelcomeBack"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 22
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	window.BackgroundColor3 = PANEL
	corner(window, 16)
	stroke(window, GOLD, 3)
	window.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = window

	local title = label(window, "Title", 28, GOLD)
	title.Text = "Welcome back!"
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -32, 0, 34)

	local body = label(window, "Body", 18)
	body.Position = UDim2.fromOffset(16, 48)
	body.Size = UDim2.new(1, -32, 0, 84)
	body.TextYAlignment = Enum.TextYAlignment.Top

	local double = button(window, "Double", "Double it!", GREEN)
	double.Position = UDim2.fromOffset(16, HEIGHT - 64)
	local keep = button(window, "Keep", "Nice!", GREY)
	keep.AnchorPoint = Vector2.new(1, 0)
	keep.Position = UDim2.new(1, -16, 0, HEIGHT - 64)

	local closesAt = 0
	local function close()
		gui.Enabled = false
	end
	double.Activated:Connect(function()
		Sfx.play("click")
		Offers.buy("DoubleOffline", "WelcomeBack")
		close()
	end)
	keep.Activated:Connect(function()
		Sfx.play("click")
		close()
	end)
	Modal.attach(gui, window, close)

	local function fit()
		local cam = Workspace.CurrentCamera
		local screen = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		scale.Scale = math.min(1, (screen.X - 24) / WIDTH, (screen.Y - 40) / HEIGHT)
	end

	-- The offer lasts as long as the server will sell it.
	local offerSeconds = (require(ReplicatedStorage.GameConfig.monetization) :: any).perks.doubleOfflineSeconds
	task.spawn(function()
		while true do
			task.wait(1)
			if gui.Enabled and os.clock() >= closesAt then
				close()
			end
		end
	end)

	local view = {}
	function view.show(earned: number, readyEggs: number): boolean
		-- The welcome back arrives as the player joins, often before the
		-- shop's catalog: wait a moment for it.
		if earned < 1 or not Offers.await(5) or not Offers.sold("DoubleOffline") then
			return false
		end
		local text = `Your creatures earned {Layout.shortNumber(earned)} coins while you were away.`
		if readyEggs > 0 then
			text ..= ` {readyEggs} egg{if readyEggs == 1 then "" else "s"} finished hatching.`
		end
		body.Text = text .. " Double them?"
		closesAt = os.clock() + offerSeconds
		fit()
		gui.Enabled = true
		return true
	end
	return view
end

return WelcomeView
