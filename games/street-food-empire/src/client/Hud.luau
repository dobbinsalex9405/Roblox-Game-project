--!strict
-- The minimal M2 interface, phone first: cash, what the cooks earn, the
-- register, customers waiting, rebirths, short notices, the welcome-back
-- message, and a pick-one menu (what to build, which cook to hire) that the
-- plot view opens. Built from code; art comes after the gate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Layout)
local Restaurant = require(Shared.Restaurant)

local Context = require(script.Parent.Context)

export type Option = {
	title: string,
	detail: string,
	enabled: boolean,
	pick: () -> (),
}

export type Hud = {
	notice: (text: string, seconds: number?) -> (),
	openMenu: (title: string, options: { Option }) -> (),
	closeMenu: () -> (),
	showBanner: (text: string, onCancel: () -> ()) -> (),
	hideBanner: () -> (),
}

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

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function panel(parent: Instance, name: string, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = position
	f.AnchorPoint = anchor
	f.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	f.BackgroundTransparency = 0.2
	corner(f, 10)
	f.Parent = parent
	return f
end

local function button(parent: Instance, name: string, text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	corner(b, 8)
	b.Parent = parent
	return b
end

function Hud.start(ctx: Context.Context): Hud
	local gui = Instance.new("ScreenGui")
	gui.Name = "StreetFoodHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = ctx.player:WaitForChild("PlayerGui")

	-- Top bar: cash and cook income; the register and the queue under them.
	local bar = panel(gui, "Bar", UDim2.fromOffset(360, 64), UDim2.new(0.5, 0, 0, 8), Vector2.new(0.5, 0))
	local cash = label(bar, "Cash", UDim2.new(0.55, -8, 0.6, 0), UDim2.fromOffset(8, 2))
	cash.TextXAlignment = Enum.TextXAlignment.Left
	cash.TextColor3 = Color3.fromRGB(130, 230, 120)
	local income = label(bar, "Income", UDim2.new(0.45, -8, 0.6, 0), UDim2.new(0.55, 0, 0, 2))
	income.TextXAlignment = Enum.TextXAlignment.Right
	local register = label(bar, "Register", UDim2.new(0.6, -8, 0.38, 0), UDim2.new(0, 8, 0.6, 0))
	register.TextXAlignment = Enum.TextXAlignment.Left
	register.Font = Enum.Font.Gotham
	local waiting = label(bar, "Waiting", UDim2.new(0.4, -8, 0.38, 0), UDim2.fromScale(0.6, 0.6))
	waiting.TextXAlignment = Enum.TextXAlignment.Right
	waiting.Font = Enum.Font.Gotham

	local rebirths = label(gui, "Rebirths", UDim2.fromOffset(160, 20), UDim2.new(0.5, 0, 0, 74))
	rebirths.AnchorPoint = Vector2.new(0.5, 0)
	rebirths.Font = Enum.Font.Gotham
	rebirths.Visible = false

	-- Notices: one line at a time under the bar.
	local notice =
		panel(gui, "Notice", UDim2.fromOffset(360, 36), UDim2.new(0.5, 0, 0, 100), Vector2.new(0.5, 0))
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

	ctx.on(ctx.remotes["SFE:Notice"], function(text: string)
		show(text)
	end)
	ctx.on(ctx.remotes["SFE:Served"], function(earned: number)
		show(`Served! +{Layout.cash(earned)}`, 1.2)
	end)
	ctx.on(ctx.remotes["SFE:WelcomeBack"], function(earned: number, customers: number)
		local parts = {}
		if earned > 0 then
			table.insert(parts, `your cooks earned {Layout.cash(earned)} (it's in the register)`)
		end
		if customers > 0 then
			table.insert(parts, `{customers} customer{if customers == 1 then " is" else "s are"} waiting`)
		end
		show(`Welcome back! {table.concat(parts, ", and ")}.`, 8)
	end)

	-- Banner with a Cancel button (used while moving a station).
	local banner =
		panel(gui, "Banner", UDim2.fromOffset(360, 44), UDim2.new(0.5, 0, 1, -150), Vector2.new(0.5, 1))
	banner.Visible = false
	local bannerText = label(banner, "Text", UDim2.new(1, -110, 1, -12), UDim2.fromOffset(10, 6))
	bannerText.TextXAlignment = Enum.TextXAlignment.Left
	local cancel = button(banner, "Cancel", "Cancel", Color3.fromRGB(200, 80, 70))
	cancel.Size = UDim2.new(0, 90, 1, -12)
	cancel.Position = UDim2.new(1, -96, 0, 6)
	local onCancel: (() -> ())? = nil
	cancel.Activated:Connect(function()
		banner.Visible = false
		if onCancel then
			onCancel()
		end
	end)

	-- Pick-one menu, centred, sized for phones.
	local menu =
		panel(gui, "Menu", UDim2.fromScale(0.92, 0), UDim2.fromScale(0.5, 0.55), Vector2.new(0.5, 0.5))
	menu.AutomaticSize = Enum.AutomaticSize.Y
	menu.Visible = false
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(380, math.huge)
	limit.Parent = menu
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = menu
	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(padding :: any)[side] = UDim.new(0, 10)
	end
	padding.Parent = menu

	local function closeMenu()
		menu.Visible = false
		for _, child in menu:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function openMenu(title: string, options: { Option })
		closeMenu()
		local heading = label(menu, "Title", UDim2.new(1, 0, 0, 28))
		heading.LayoutOrder = 0
		heading.Text = title
		for index, option in options do
			local row = button(
				menu,
				`Option{index}`,
				"",
				if option.enabled then Color3.fromRGB(60, 140, 90) else Color3.fromRGB(70, 70, 80)
			)
			row.LayoutOrder = index
			row.Size = UDim2.new(1, 0, 0, 52)
			row.RichText = true
			row.TextScaled = false
			row.TextSize = 16
			row.TextWrapped = true
			row.Text = `<b>{option.title}</b>\n<font size="13">{option.detail}</font>`
			row.AutoButtonColor = option.enabled
			row.Activated:Connect(function()
				if option.enabled then
					closeMenu()
					option.pick()
				end
			end)
		end
		local close = button(menu, "Close", "Close", Color3.fromRGB(150, 60, 60))
		close.LayoutOrder = #options + 1
		close.Size = UDim2.new(1, 0, 0, 36)
		close.Activated:Connect(function()
			closeMenu()
		end)
		menu.Visible = true
	end

	ctx.onData(function(d: { [string]: any })
		rebirths.Visible = d.rebirths > 0
		rebirths.Text = `Rebirths: {d.rebirths}`
	end)

	-- Numbers that move every frame: cash, income, the register and the queue.
	task.spawn(function()
		while true do
			local d = ctx.data()
			if d then
				local now = ctx.serverNow()
				local perks = ctx.perks()
				local rates = Restaurant.rates(d, ctx.config, perks, now)
				local pending, queue = Restaurant.preview(d, ctx.config, perks, now)
				cash.Text = Layout.cash(d.cash)
				income.Text = `+{Layout.cash(rates.registerPerSecond)}/s`
				register.Text = if ctx.autoCollect()
					then `Auto-collecting {Layout.cash(pending)}`
					else `Register: {Layout.cash(pending)}`
				local people = Restaurant.waiting(queue)
				waiting.Text = `{people} waiting`
				waiting.TextColor3 = if people >= ctx.config.economy.customers.queueMax
					then Color3.fromRGB(255, 140, 90)
					else Color3.new(1, 1, 1)
			end
			task.wait(0.2)
		end
	end)

	return {
		notice = show,
		openMenu = openMenu,
		closeMenu = closeMenu,
		showBanner = function(text: string, cancelled: () -> ())
			bannerText.Text = text
			onCancel = cancelled
			banner.Visible = true
		end,
		hideBanner = function()
			onCancel = nil
			banner.Visible = false
		end,
	}
end

return Hud
