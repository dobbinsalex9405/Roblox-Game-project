--!strict
-- Small helpers shared by the core's built-in screens (shop, test panel):
-- plain Roblox UI built from code, readable on a phone.

local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local UiKit = {}

UiKit.BACKGROUND = Color3.fromRGB(25, 25, 35)
UiKit.ROW = Color3.fromRGB(40, 40, 55)
UiKit.ACCENT = Color3.fromRGB(70, 160, 90)
UiKit.MUTED = Color3.fromRGB(110, 110, 125)
UiKit.WARN = Color3.fromRGB(200, 80, 70)

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

function UiKit.label(parent: Instance, text: string, height: number, bold: boolean?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, height)
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	l.TextSize = if bold then 17 else 14
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = text
	l.Parent = parent
	return l
end

function UiKit.button(
	parent: Instance,
	text: string,
	width: number,
	height: number,
	color: Color3?
): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(width, height)
	b.BackgroundColor3 = color or UiKit.ACCENT
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	corner(b, 8)
	b.Parent = parent
	return b
end

-- A vertical list that grows with its content.
function UiKit.list(parent: Instance, padding: number): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromScale(1, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, padding)
	layout.Parent = f
	f.Parent = parent
	return f
end

-- A horizontal row of buttons.
function UiKit.row(parent: Instance, height: number): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, height)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = f
	f.Parent = parent
	return f
end

function UiKit.card(parent: Instance): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = UiKit.ROW
	f.Size = UDim2.fromScale(1, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	corner(f, 8)
	local pad = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(pad :: any)[side] = UDim.new(0, 8)
	end
	pad.Parent = f
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = f
	f.Parent = parent
	return f
end

-- A centered window with a title, a close button and a scrolling body.
-- Returns the window and the body to fill.
function UiKit.window(gui: ScreenGui, title: string, onClose: () -> ()): (Frame, ScrollingFrame)
	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.BackgroundColor3 = UiKit.BACKGROUND
	window.BackgroundTransparency = 0.05
	window.Visible = false
	corner(window, 12)
	local function fit()
		local view = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
		window.Size = UDim2.fromOffset(math.min(420, view.X - 32), math.min(520, view.Y - 80))
	end
	fit()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	local heading = UiKit.label(window, title, 40, true)
	heading.Position = UDim2.fromOffset(14, 4)
	heading.Size = UDim2.new(1, -70, 0, 40)
	local close = UiKit.button(window, "X", 36, 32, UiKit.WARN)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 8)
	close.Activated:Connect(onClose)

	local body = Instance.new("ScrollingFrame")
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(10, 48)
	body.Size = UDim2.new(1, -20, 1, -58)
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollBarThickness = 6
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = body
	body.Parent = window
	window.Parent = gui
	return window, body
end

-- Places a button in Roblox's top bar, `slot` buttons from the left of the
-- free area (the feedback button sits at the right end), or at the top left
-- of the screen when there is no top bar inset.
function UiKit.topbarButton(gui: ScreenGui, text: string, slot: number, width: number): TextButton
	gui.ScreenInsets = Enum.ScreenInsets.None
	local button = UiKit.button(gui, text, width, 32, UiKit.BACKGROUND)
	button.BackgroundTransparency = 0.25
	local function place()
		local inset = GuiService.TopbarInset
		local height = inset.Height
		if inset.Width > 0 and height > 8 then
			button.Size = UDim2.fromOffset(width, height - 8)
			button.Position = UDim2.fromOffset(inset.Min.X + 8 + slot * (width + 8), inset.Min.Y + 4)
		else
			button.Size = UDim2.fromOffset(width, 36)
			button.Position = UDim2.fromOffset(12 + slot * (width + 8), 8)
		end
	end
	place()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)
	return button
end

function UiKit.clear(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

return UiKit
