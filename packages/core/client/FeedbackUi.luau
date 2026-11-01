--!strict
-- The Feedback button and form every game gets from CoreClient.start.
--
-- The button sits in the Roblox top bar, right-aligned in the free area
-- (GuiService.TopbarInset), so it never covers a game's own HUD. The left end
-- of that free area is left for the shop button. The form asks for a type
-- (Bug / Idea / Other), the text and an optional 1-5 fun rating, then shows
-- the server's answer. Rules (length, cooldown) come from Core.Feedback, the
-- same module the server checks with.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VRService = game:GetService("VRService")

local CoreRemotes = require(ReplicatedStorage.Core.CoreRemotes)
local Feedback = require(ReplicatedStorage.Core.Feedback)
local ClientNet = require(script.Parent.ClientNet)

local BUTTON_WIDTH = 112
local FORM_MAX_WIDTH = 400
local ANSWER_TIMEOUT = 15 -- seconds to wait for the server before saying so
local COOLDOWN = 60 -- matches the server's per-player cooldown
local CLOSE_AFTER_SENT = 2.5
local FPS_WINDOW = 5 -- seconds of frames averaged for the report

local PANEL = Color3.fromRGB(24, 28, 38)
local FIELD = Color3.fromRGB(40, 46, 60)
local CHIP = Color3.fromRGB(55, 62, 80)
local ACCENT = Color3.fromRGB(60, 140, 230)
local GOOD = Color3.fromRGB(80, 200, 120)
local WARN = Color3.fromRGB(240, 170, 70)
local MUTED = Color3.fromRGB(170, 178, 195)
local STAR_ON = Color3.fromRGB(255, 205, 70)
local WHITE = Color3.new(1, 1, 1)

local CATEGORY_LABELS: { [string]: string } = { bug = "Bug", idea = "Idea", other = "Other" }

local FeedbackUi = {}

local started = false
local openForm: ((category: string?) -> ())? = nil

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function text(parent: Instance, name: string, height: number, size: number, bold: boolean?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = UDim2.new(1, 0, 0, height)
	l.BackgroundTransparency = 1
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	l.TextSize = size
	l.TextColor3 = WHITE
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = ""
	l.Parent = parent
	return l
end

local function button(parent: Instance, name: string, label: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.BackgroundColor3 = color
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamBold
	b.TextSize = 18
	b.TextColor3 = WHITE
	b.Text = label
	corner(b, 8)
	b.Parent = parent
	return b
end

local function row(parent: Instance, name: string, height: number, padding: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = UDim2.new(1, 0, 0, height)
	f.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, padding)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = f
	f.Parent = parent
	return f
end

-- Average frames per second over the last few seconds, for performance reports.
local function startFpsMeter(): () -> number
	local frames: { number } = {}
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		table.insert(frames, now)
		while #frames > 0 and now - frames[1] > FPS_WINDOW do
			table.remove(frames, 1)
		end
	end)
	return function(): number
		if #frames < 2 then
			return 0
		end
		local span = frames[#frames] - frames[1]
		return if span > 0 then math.clamp((#frames - 1) / span, 0, 1000) else 0
	end
end

local function clientInfo(fps: () -> number): Feedback.ClientInfo
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.zero
	return {
		platform = Feedback.platformFrom({
			touch = UserInputService.TouchEnabled,
			keyboard = UserInputService.KeyboardEnabled,
			gamepad = UserInputService.GamepadEnabled,
			vr = VRService.VREnabled,
		}),
		screen = Feedback.screenString(viewport.X, viewport.Y),
		fps = math.floor(fps()),
	}
end

function FeedbackUi.start()
	assert(not started, "FeedbackUi.start called twice")
	started = true

	local fps = startFpsMeter()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "CoreFeedback"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.None -- positions are in full-screen pixels, top bar included
	gui.DisplayOrder = 20
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- The top-bar button.
	local open = button(gui, "FeedbackButton", "Feedback", Color3.fromRGB(18, 20, 26))
	open.BackgroundTransparency = 0.3
	open.AnchorPoint = Vector2.new(0, 0.5)
	open.TextSize = 16
	corner(open, 22)

	local function placeButton()
		local inset = GuiService.TopbarInset
		if inset.Width >= BUTTON_WIDTH + 16 and inset.Height > 0 then
			local height = math.clamp(inset.Height - 14, 32, 44)
			open.Size = UDim2.fromOffset(BUTTON_WIDTH, height)
			open.Position = UDim2.fromOffset(inset.Max.X - 8 - BUTTON_WIDTH, inset.Min.Y + inset.Height / 2)
		else
			-- No top bar room (or no top bar): top-left of the safe area.
			local top = GuiService:GetGuiInset()
			open.Size = UDim2.fromOffset(BUTTON_WIDTH, 40)
			open.Position = UDim2.fromOffset(12, top.Y + 8 + 20)
		end
	end
	placeButton()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeButton)

	-- The form, over a dimmed screen that closes it when tapped.
	local formGui = Instance.new("ScreenGui")
	formGui.Name = "CoreFeedbackForm"
	formGui.ResetOnSpawn = false
	formGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets -- below the top bar
	formGui.DisplayOrder = 40
	formGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	formGui.Enabled = false

	local dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.AutoButtonColor = false
	dim.Text = ""
	dim.Selectable = false
	dim.Parent = formGui

	local form = Instance.new("ScrollingFrame")
	form.Name = "Form"
	form.AnchorPoint = Vector2.new(0.5, 0)
	form.Position = UDim2.new(0.5, 0, 0, 8)
	form.Size = UDim2.new(0.94, 0, 0, 400)
	form.BackgroundColor3 = PANEL
	form.BorderSizePixel = 0
	form.ScrollBarThickness = 6
	form.ScrollingDirection = Enum.ScrollingDirection.Y
	form.AutomaticCanvasSize = Enum.AutomaticSize.Y
	form.CanvasSize = UDim2.new()
	form.Active = true -- swallows taps so they never reach the dim layer behind
	form.ZIndex = 2
	corner(form, 14)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(FORM_MAX_WIDTH, math.huge)
	limit.Parent = form
	local pad = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(pad :: any)[side] = UDim.new(0, 14)
	end
	pad.Parent = form
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = form
	form.Parent = formGui

	local order = 0
	local function nextOrder(item: GuiObject)
		order += 1
		item.LayoutOrder = order
	end

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 36)
	header.BackgroundTransparency = 1
	header.Parent = form
	nextOrder(header)
	local title = text(header, "Title", 36, 22, true)
	title.Size = UDim2.new(1, -48, 1, 0)
	title.Text = "Send feedback"
	local close = button(header, "Close", "X", CHIP)
	close.Size = UDim2.fromOffset(40, 36)
	close.Position = UDim2.new(1, -40, 0, 0)

	local hint = text(form, "Hint", 36, 14)
	hint.TextColor3 = MUTED
	hint.Text = "Found a bug or have an idea? Tell us! Please don't share personal info."
	nextOrder(hint)

	local categoryRow = row(form, "Category", 44, 8)
	nextOrder(categoryRow)
	local categoryButtons: { [string]: TextButton } = {}
	for index, category in Feedback.CATEGORIES do
		local b = button(categoryRow, CATEGORY_LABELS[category], CATEGORY_LABELS[category], CHIP)
		b.Size = UDim2.new(1 / 3, -6, 1, 0)
		b.LayoutOrder = index
		categoryButtons[category] = b
	end

	local ratingTitle = text(form, "RatingTitle", 18, 14)
	ratingTitle.TextColor3 = MUTED
	ratingTitle.Text = "How fun is the game? (optional)"
	nextOrder(ratingTitle)
	local ratingRow = row(form, "Rating", 40, 6)
	nextOrder(ratingRow)
	local stars: { TextButton } = {}
	for i = 1, 5 do
		local star = button(ratingRow, `Star{i}`, "★", CHIP)
		star.Size = UDim2.fromOffset(44, 40)
		star.TextSize = 24
		star.LayoutOrder = i
		stars[i] = star
	end

	local box = Instance.new("TextBox")
	box.Name = "Text"
	box.Size = UDim2.new(1, 0, 0, 100)
	box.BackgroundColor3 = FIELD
	box.ClearTextOnFocus = false
	box.MultiLine = true
	box.TextWrapped = true
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Top
	box.Font = Enum.Font.Gotham
	box.TextSize = 16
	box.TextColor3 = WHITE
	box.PlaceholderColor3 = MUTED
	box.Text = ""
	corner(box, 8)
	local boxPad = Instance.new("UIPadding")
	boxPad.PaddingTop = UDim.new(0, 8)
	boxPad.PaddingLeft = UDim.new(0, 8)
	boxPad.PaddingRight = UDim.new(0, 8)
	boxPad.Parent = box
	box.Parent = form
	nextOrder(box)

	local counter = text(form, "Counter", 16, 13)
	counter.TextColor3 = MUTED
	counter.TextXAlignment = Enum.TextXAlignment.Right
	nextOrder(counter)

	local status = text(form, "Status", 0, 15, true)
	status.AutomaticSize = Enum.AutomaticSize.Y
	nextOrder(status)

	local send = button(form, "Send", "Send", ACCENT)
	send.Size = UDim2.new(1, 0, 0, 48)
	send.TextSize = 20
	nextOrder(send)

	formGui.Parent = playerGui
	gui.Parent = playerGui

	-- State.
	local category: string? = nil
	local rating = 0
	local sending = false
	local sendToken = 0
	local cooldownUntil = 0

	local function refresh()
		for key, b in categoryButtons do
			b.BackgroundColor3 = if key == category then ACCENT else CHIP
		end
		for i, star in stars do
			star.TextColor3 = if i <= rating then STAR_ON else MUTED
		end
		box.PlaceholderText = Feedback.PLACEHOLDERS[category or "none"]
		counter.Text = `{utf8.len(box.Text) or 0} / {Feedback.MAX_LENGTH}`
		local blocker =
			Feedback.sendBlocker(category, box.Text, sending, math.max(0, cooldownUntil - os.clock()))
		send.Text = blocker or "Send"
		send.Active = blocker == nil
		send.AutoButtonColor = blocker == nil
		send.BackgroundColor3 = if blocker == nil then ACCENT else CHIP
	end

	local function setStatus(message: string, color: Color3)
		status.Text = message
		status.TextColor3 = color
	end

	local function fitForm()
		local camera = workspace.CurrentCamera
		local available = if camera then camera.ViewportSize.Y - GuiService:GetGuiInset().Y - 16 else 400
		local wanted = layout.AbsoluteContentSize.Y + 28
		form.Size = UDim2.new(0.94, 0, 0, math.max(160, math.min(wanted, available)))
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitForm)

	local function show(chosen: string?)
		if chosen and table.find(Feedback.CATEGORIES, chosen :: any) then
			category = chosen
		end
		if not sending then
			setStatus("", WHITE)
		end
		formGui.Enabled = true
		fitForm()
		refresh()
		if UserInputService.GamepadEnabled and not UserInputService.TouchEnabled then
			GuiService.SelectedObject = categoryButtons[category or "bug"]
		end
	end

	local function hide()
		formGui.Enabled = false
		box:ReleaseFocus()
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(formGui) then
			GuiService.SelectedObject = nil
		end
	end
	openForm = show

	open.Activated:Connect(function()
		if formGui.Enabled then
			hide()
		else
			show(nil)
		end
	end)
	close.Activated:Connect(hide)
	dim.Activated:Connect(hide)

	for key, b in categoryButtons do
		b.Activated:Connect(function()
			category = key
			refresh()
		end)
	end
	for i, star in stars do
		star.Activated:Connect(function()
			rating = if rating == i then 0 else i -- tap the same star again to clear
			refresh()
		end)
	end

	box:GetPropertyChangedSignal("Text"):Connect(function()
		-- Keep it within the limit as the player types (and pastes).
		if (utf8.len(box.Text) or 0) > Feedback.MAX_LENGTH then
			box.Text = Feedback.clip(box.Text, Feedback.MAX_LENGTH)
			return -- the change fires this again
		end
		refresh()
	end)

	send.Activated:Connect(function()
		if Feedback.sendBlocker(category, box.Text, sending, math.max(0, cooldownUntil - os.clock())) then
			return
		end
		sending = true
		sendToken += 1
		local token = sendToken
		setStatus("Sending...", MUTED)
		refresh()
		ClientNet.fire(
			CoreRemotes["Core:Feedback"],
			category,
			string.sub(box.Text, 1, 2000),
			rating,
			clientInfo(fps)
		)
		task.delay(ANSWER_TIMEOUT, function()
			if sending and token == sendToken then
				sending = false
				setStatus("No answer from the server. Please try again in a minute.", WARN)
				refresh()
			end
		end)
	end)

	ClientNet.on(CoreRemotes["Core:FeedbackResult"], function(sent: boolean, message: string)
		sending = false
		sendToken += 1
		local token = sendToken
		if sent then
			cooldownUntil = os.clock() + COOLDOWN
			box.Text = ""
			rating = 0
			category = nil
			setStatus(message, GOOD)
			task.delay(CLOSE_AFTER_SENT, function()
				if token == sendToken and formGui.Enabled then
					hide()
				end
			end)
		else
			setStatus(message, WARN)
		end
		refresh()
	end)

	-- Count the cooldown down on the button while the form is open.
	task.spawn(function()
		while true do
			task.wait(1)
			if formGui.Enabled and cooldownUntil > os.clock() - 1 then
				refresh()
			end
		end
	end)

	refresh()
end

-- Opens the form from a game's own menu, optionally with a type picked.
function FeedbackUi.open(category: string?)
	if openForm then
		openForm(category)
	end
end

return FeedbackUi
