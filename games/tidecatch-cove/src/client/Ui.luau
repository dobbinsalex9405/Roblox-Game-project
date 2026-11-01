--!strict
-- Small builders for the grey-box interface. Phone first: big touch targets,
-- scaled text. Art comes after the gate.

local Ui = {}

Ui.PANEL = Color3.fromRGB(20, 30, 45)
Ui.BUTTON = Color3.fromRGB(40, 120, 190)
Ui.GOOD = Color3.fromRGB(60, 170, 90)
Ui.WARN = Color3.fromRGB(220, 90, 70)
Ui.GOLD = Color3.fromRGB(255, 215, 90)
Ui.MUTED = Color3.fromRGB(190, 200, 210)

function Ui.label(parent: Instance, name: string, size: UDim2, position: UDim2?): TextLabel
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

function Ui.corner(parent: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = parent
end

function Ui.panel(parent: Instance, name: string, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = position
	f.AnchorPoint = anchor
	f.BackgroundColor3 = Ui.PANEL
	f.BackgroundTransparency = 0.15
	Ui.corner(f)
	f.Parent = parent
	return f
end

function Ui.button(parent: Instance, name: string, text: string, size: UDim2, color: Color3?): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = size
	b.BackgroundColor3 = color or Ui.BUTTON
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	Ui.corner(b, 8)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = b
	b.Parent = parent
	return b
end

function Ui.list(parent: Instance, padding: number, direction: Enum.FillDirection?)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.FillDirection = direction or Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 4)
	layout.Parent = parent
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, padding)
	pad.PaddingBottom = UDim.new(0, padding)
	pad.PaddingLeft = UDim.new(0, padding)
	pad.PaddingRight = UDim.new(0, padding)
	pad.Parent = parent
end

-- Removes everything but layout objects.
function Ui.clear(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
			child:Destroy()
		end
	end
end

-- A row with text on the left and right.
function Ui.row(
	parent: Instance,
	order: number,
	left: string,
	right: string,
	color: Color3,
	bold: boolean
): Frame
	local frame = Instance.new("Frame")
	frame.Name = `Row{order}`
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, 18)
	local name = Ui.label(frame, "Left", UDim2.fromScale(0.68, 1))
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	name.TextColor3 = color
	name.Text = left
	local value = Ui.label(frame, "Right", UDim2.fromScale(0.32, 1), UDim2.fromScale(0.68, 0))
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.Text = right
	frame.Parent = parent
	return frame
end

return Ui
