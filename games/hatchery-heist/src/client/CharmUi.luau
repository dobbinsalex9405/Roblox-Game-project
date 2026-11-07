--!strict
-- The look shared by the Charms window (client/CharmsView) and the claw
-- machine (client/ClawView): the game's chunky style (FredokaOne, dark navy
-- panels, gold edges), buttons at least 44 px tall, charm cards in their
-- tier colour, and a slowly turning 3D preview of one charm.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Charms = require(Shared.Charms)
local Layout = require(Shared.Layout)

local CharmView = require(script.Parent.CharmView)

local CharmUi = {}

CharmUi.PANEL = Color3.fromRGB(28, 30, 48)
CharmUi.TILE = Color3.fromRGB(44, 47, 72)
CharmUi.GOLD = Color3.fromRGB(255, 210, 63)
CharmUi.GREEN = Color3.fromRGB(80, 200, 100)
CharmUi.BLUE = Color3.fromRGB(63, 140, 230)
CharmUi.GREY = Color3.fromRGB(110, 110, 125)
CharmUi.RED = Color3.fromRGB(215, 70, 70)
CharmUi.AMBER = Color3.fromRGB(255, 170, 40)
CharmUi.SHADOW = Color3.fromRGB(16, 16, 26)
CharmUi.FONT = Enum.Font.FredokaOne
CharmUi.BUTTON = 44 -- px, every button's height (phones need at least 40)
local TOP_BAR = 58 -- px, Roblox's top bar (GuiService:GetGuiInset)

function CharmUi.corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

function CharmUi.stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- A label in the game's font with a dark outline. Fixed sizes, never under
-- 13 px (scaled text shrank to 10 px on phones: audit, Nov 5).
function CharmUi.text(parent: Instance, name: string, value: string, size: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = CharmUi.FONT
	l.TextSize = math.max(13, size)
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Text = value
	local s = Instance.new("UIStroke")
	s.Thickness = 1.5
	s.Color = CharmUi.SHADOW
	s.Parent = l
	l.Parent = parent
	return l
end

function CharmUi.button(
	parent: Instance,
	name: string,
	label: string,
	color: Color3,
	width: number
): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.fromOffset(width, CharmUi.BUTTON)
	b.BackgroundColor3 = color
	b.Font = CharmUi.FONT
	b.TextSize = 18
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = label
	b.TextWrapped = true
	CharmUi.corner(b, 10)
	CharmUi.stroke(b, CharmUi.SHADOW, 2)
	local s = Instance.new("UIStroke")
	s.Thickness = 1.2
	s.Color = CharmUi.SHADOW
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = b
	b.Parent = parent
	return b
end

-- A window's close X.
function CharmUi.close(parent: Instance): TextButton
	local close = CharmUi.button(parent, "Close", "X", CharmUi.RED, 44)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 8)
	close.TextSize = 24
	return close
end

-- A window: a ScreenGui with a "Window" frame (GuideView hides the side
-- menu while it shows). The window takes the screen up to `maxW` x `maxH`.
function CharmUi.window(parentGui: Instance, name: string, order: number): (ScreenGui, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = order
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = parentGui
	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.BackgroundColor3 = CharmUi.PANEL
	CharmUi.corner(window, 16)
	CharmUi.stroke(window, CharmUi.GOLD, 3)
	window.Parent = gui
	return gui, window
end

-- The window's size for a screen: as big as fits, up to the maximum.
function CharmUi.fit(window: Frame, maxW: number, maxH: number): Vector2
	local screen = (window.Parent :: ScreenGui).AbsoluteSize
	if screen.X <= 0 or screen.Y <= 0 then
		-- A ScreenGui that was just enabled may not have its size yet: the
		-- camera's view less Roblox's top bar.
		local camera = Workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		screen = Vector2.new(view.X, view.Y - TOP_BAR)
	end
	local w = math.floor(math.min(maxW, screen.X - 24))
	local h = math.floor(math.min(maxH, screen.Y - 24))
	window.Size = UDim2.fromOffset(w, h)
	return Vector2.new(w, h)
end

-- A charm's card: tier-colour border, the kind's icon, name, effect and a
-- count badge. Returns the card (a button) and its parts.
export type Card = {
	button: TextButton,
	icon: TextLabel,
	name: TextLabel,
	effect: TextLabel,
	count: TextLabel,
	ribbon: TextLabel,
	stroke: UIStroke,
}

function CharmUi.card(parent: Instance, config: any, def: Charms.Def, order: number): Card
	local color = Layout.rarityColor(def.tier)
	local b = Instance.new("TextButton")
	b.Name = def.id
	b.LayoutOrder = order
	b.Text = ""
	b.AutoButtonColor = true
	b.BackgroundColor3 = CharmUi.TILE:Lerp(color, 0.18)
	CharmUi.corner(b, 12)
	local s = CharmUi.stroke(b, color, 3)
	local kind = Charms.kind(config, def.kind)
	local icon = CharmUi.text(b, "Icon", if kind then kind.icon else "?", 30)
	icon.Size = UDim2.new(1, 0, 0, 36)
	icon.Position = UDim2.fromOffset(0, 4)
	local name = CharmUi.text(b, "CharmName", def.name, 14)
	name.Size = UDim2.new(1, -8, 0, 32)
	name.Position = UDim2.fromOffset(4, 40)
	name.TextWrapped = true
	name.TextYAlignment = Enum.TextYAlignment.Top
	local effect =
		CharmUi.text(b, "Effect", Charms.effectText(config, def), 13, color:Lerp(Color3.new(1, 1, 1), 0.45))
	effect.Size = UDim2.new(1, -8, 0, 32)
	effect.Position = UDim2.new(0, 4, 1, -34)
	effect.TextWrapped = true
	local count = CharmUi.text(b, "Count", "", 15, CharmUi.GOLD)
	count.AnchorPoint = Vector2.new(1, 0)
	count.Position = UDim2.new(1, -6, 0, 4)
	count.Size = UDim2.fromOffset(40, 18)
	count.TextXAlignment = Enum.TextXAlignment.Right
	-- A small "On" badge in the corner, clear of the icon even on the
	-- narrowest card (108 px).
	local ribbon = CharmUi.text(b, "Ribbon", "On", 13, CharmUi.SHADOW)
	ribbon.BackgroundTransparency = 0
	ribbon.BackgroundColor3 = CharmUi.GOLD
	ribbon.Position = UDim2.fromOffset(4, 4)
	ribbon.Size = UDim2.fromOffset(30, 18)
	ribbon.Visible = false
	CharmUi.corner(ribbon, 6)
	local ribbonStroke = ribbon:FindFirstChildOfClass("UIStroke")
	if ribbonStroke then
		ribbonStroke:Destroy()
	end
	b.Parent = parent
	return {
		button = b,
		icon = icon,
		name = name,
		effect = effect,
		count = count,
		ribbon = ribbon,
		stroke = s,
	}
end

-- A 3D preview of one charm, turning slowly, inside `frame`. Returns a
-- function that swaps the charm shown (nil = empty).
function CharmUi.preview(frame: GuiObject, config: any): (string?) -> ()
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Preview"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(170, 170, 185)
	viewport.LightColor = Color3.fromRGB(255, 245, 230)
	viewport.LightDirection = Vector3.new(-0.5, -1, -0.6)
	viewport.Parent = frame
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.2, 6.2), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local current: Model? = nil
	local root: BasePart? = nil
	local spin: RBXScriptConnection? = nil
	return function(id: string?)
		if current then
			current:Destroy()
			current = nil
		end
		if spin then
			spin:Disconnect()
			spin = nil
		end
		if id == nil then
			return
		end
		local model, r = CharmView.build(config, id, 2.4, CFrame.new())
		if model == nil or r == nil then
			return
		end
		-- Parts in a ViewportFrame don't simulate: keep them all anchored and
		-- turn the whole model.
		for _, child in model:GetDescendants() do
			if child:IsA("BasePart") then
				child.Anchored = true
			elseif child:IsA("WeldConstraint") or child:IsA("ParticleEmitter") or child:IsA("PointLight") then
				child:Destroy()
			end
		end
		model.Parent = viewport
		current = model
		root = r
		local start = os.clock()
		spin = RunService.RenderStepped:Connect(function()
			if current and root and viewport.Parent and viewport.Visible then
				current:PivotTo(CFrame.Angles(0, math.pi + (os.clock() - start) * 0.8, 0))
			end
		end)
	end
end

return CharmUi
