--!strict
-- A row of square rarity tabs (Alex, Nov 12): each shows a standout
-- creature, the tier's name on a band of its colour and a caption (a
-- chance, a count), with an optional line under it. As big as fit the
-- width, all seven in one row on a phone held sideways, wrapping evenly
-- when narrower (OddsTiers.grid). Used by the egg chances screen; meant to
-- be shared by any screen sorted by rarity.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Book = require(Shared.Book)
local Layout = require(Shared.Layout)
local OddsTiers = require(Shared.OddsTiers)

local CreatureView = require(script.Parent.CreatureView)

local RarityTabs = {}
RarityTabs.__index = RarityTabs

export type Tab = {
	rarity: string, -- also the tab's name (a tier from Eggs.RARITIES, or "All")
	face: string?, -- the creature drawn on it
	caption: string, -- the line under the tier's name, on the tab
	under: string?, -- a line below the tab (a count)
	locked: boolean?, -- drawn grey with the creature in shadow
	color: Color3?, -- for a tab that is not a tier; else Layout.rarityColor
}

export type Options = {
	tabs: { Tab },
	onPick: (rarity: string) -> (),
	-- Tile sides in px and the gap; config/atmosphere oddsScreen by default.
	tileMin: number?,
	tileMax: number?,
	tileGap: number?,
}

export type RarityTabs = typeof(setmetatable(
	{} :: {
		frame: Frame,
		options: Options,
		side: number,
		selected: string?,
	},
	RarityTabs
))

local look = (require(ReplicatedStorage.GameConfig.atmosphere) :: any).oddsScreen
local FONT = Enum.Font.GothamBold
local DARK_TEXT = Color3.fromRGB(20, 20, 28)
local LOCKED = Color3.fromRGB(90, 90, 105)
local UNDER_HEIGHT = 20
RarityTabs.UNDER_HEIGHT = UNDER_HEIGHT
RarityTabs.LOCKED = LOCKED

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, name: string, text: string, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextSize = size
	l.TextColor3 = color
	l.Text = text
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

-- A creature's picture filling `parent`: its Book picture (a render of its
-- meshes), else, where `live` allows, its model in a ViewportFrame. A list
-- of hundreds passes live = false: too many models for a phone. `shadow`
-- draws it black.
function RarityTabs.picture(parent: GuiObject, speciesId: string, live: boolean, shadow: boolean)
	local image = Book.picture(speciesId)
	if image then
		local l = Instance.new("ImageLabel")
		l.Name = "Picture"
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.ScaleType = Enum.ScaleType.Fit
		l.Image = image
		l.ImageColor3 = if shadow then Color3.new(0, 0, 0) else Color3.new(1, 1, 1)
		l.Parent = parent
		return
	end
	if not live then
		return
	end
	local model, size = CreatureView.staticModel(speciesId)
	if model == nil then
		return
	end
	local view = Instance.new("ViewportFrame")
	view.Name = "Picture"
	view.BackgroundTransparency = 1
	view.Size = UDim2.fromScale(1, 1)
	view.Ambient = Color3.fromRGB(170, 170, 185)
	view.LightDirection = Vector3.new(-0.6, -1, 0.5)
	if shadow then
		view.ImageColor3 = Color3.new(0, 0, 0)
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = view
	view.CurrentCamera = camera
	model.Parent = view
	local fitSize = math.max(size.X, size.Y, size.Z)
	local distance = (fitSize / 2) / math.tan(math.rad(15)) * 1.2
	local target = Vector3.new(0, size.Y / 2, 0)
	local offset = CFrame.Angles(0, math.rad(-28), 0) * CFrame.Angles(math.rad(-12), 0, 0)
	camera.CFrame = CFrame.lookAt(target + offset * Vector3.new(0, 0, -distance), target)
	view.Parent = parent
end

local function colorOf(tab: Tab): Color3
	if tab.locked then
		return LOCKED
	end
	return tab.color or Layout.rarityColor(tab.rarity)
end

-- Draws the tabs into a new frame in `parent` (put it in a layout; it is
-- as wide as its parent and as tall as its rows). `width` is the room in
-- px; call :resize when it changes.
function RarityTabs.new(parent: GuiObject, options: Options, width: number, order: number?): RarityTabs
	local frame = Instance.new("Frame")
	frame.Name = "RarityTabs"
	frame.LayoutOrder = order or 0
	frame.BackgroundTransparency = 1
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Size = UDim2.fromScale(1, 0)
	local cells = Instance.new("UIGridLayout")
	cells.SortOrder = Enum.SortOrder.LayoutOrder
	cells.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local gap = options.tileGap or look.tileGap
	cells.CellPadding = UDim2.fromOffset(gap, gap)
	cells.Parent = frame
	frame.Parent = parent
	local self =
		setmetatable({ frame = frame, options = options, side = 0, selected = nil :: string? }, RarityTabs)
	self:resize(width)
	return self
end

-- Redraws the tabs for `width` px of room.
function RarityTabs.resize(self: RarityTabs, width: number)
	local options = self.options
	local gap = options.tileGap or look.tileGap
	local minSide = options.tileMin or look.tileMin
	local _, side =
		OddsTiers.grid(math.max(minSide, width), #options.tabs, gap, minSide, options.tileMax or look.tileMax)
	if side == self.side then
		return
	end
	self.side = side
	for _, child in self.frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local cells = self.frame:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
	local hasUnder = false
	for _, tab in options.tabs do
		hasUnder = hasUnder or tab.under ~= nil
	end
	cells.CellSize = UDim2.fromOffset(side, side + (if hasUnder then UNDER_HEIGHT else 0))
	for i, tab in options.tabs do
		local color = colorOf(tab)
		local cell = Instance.new("Frame")
		cell.Name = tab.rarity
		cell.LayoutOrder = i
		cell.BackgroundTransparency = 1
		local face = Instance.new("TextButton")
		face.Name = "Tab"
		face.Text = ""
		face.Size = UDim2.fromOffset(side, side)
		face.BackgroundColor3 = color:Lerp(Color3.fromRGB(25, 25, 35), 0.72)
		face.AutoButtonColor = true
		corner(face, 10)
		local stroke = Instance.new("UIStroke")
		stroke.Name = "Edge"
		stroke.Color = color
		stroke.Thickness = 3
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = face
		local pictureSide = math.floor(side * 0.6)
		local well = Instance.new("Frame")
		well.Name = "Well"
		well.BackgroundTransparency = 1
		well.AnchorPoint = Vector2.new(0.5, 0)
		well.Position = UDim2.new(0.5, 0, 0, 3)
		well.Size = UDim2.fromOffset(pictureSide, pictureSide)
		well.Parent = face
		if tab.face then
			RarityTabs.picture(well, tab.face, true, tab.locked == true)
		end
		-- 13 px or more: readable on a phone (the floor is 11).
		local textSize = math.clamp(math.floor(side * 0.13), 13, 17)
		local band = label(face, "Name", tab.rarity, textSize, DARK_TEXT)
		band.BackgroundTransparency = 0
		band.BackgroundColor3 = color
		band.BorderSizePixel = 0
		band.Position = UDim2.fromOffset(0, pictureSide + 4)
		band.Size = UDim2.new(1, 0, 0, textSize + 6)
		if tab.locked then
			band.TextColor3 = Color3.new(1, 1, 1)
		end
		local captionTop = pictureSide + 4 + textSize + 6
		local caption = label(face, "Caption", tab.caption, textSize - 1, Color3.new(1, 1, 1))
		caption.Position = UDim2.fromOffset(2, captionTop)
		caption.Size = UDim2.new(1, -4, 1, -captionTop)
		face.Activated:Connect(function()
			options.onPick(tab.rarity)
		end)
		face.Parent = cell
		if tab.under then
			local under = label(cell, "Under", tab.under, 13, color)
			under.Position = UDim2.fromOffset(0, side)
			under.Size = UDim2.new(1, 0, 0, UNDER_HEIGHT)
		end
		cell.Parent = self.frame
	end
	self:select(self.selected)
end

-- Marks one tab as the open one (a white edge), or none.
function RarityTabs.select(self: RarityTabs, rarity: string?)
	self.selected = rarity
	for _, tab in self.options.tabs do
		local cell = self.frame:FindFirstChild(tab.rarity)
		local face = cell and cell:FindFirstChild("Tab")
		local edge = face and face:FindFirstChild("Edge") :: UIStroke?
		if edge then
			local on = tab.rarity == rarity
			edge.Color = if on then Color3.new(1, 1, 1) else colorOf(tab)
			edge.Thickness = if on then 4 else 3
		end
	end
end

-- Changes the line on one tab (a chance, a count).
function RarityTabs.setCaption(self: RarityTabs, rarity: string, text: string)
	for _, tab in self.options.tabs do
		if tab.rarity == rarity then
			tab.caption = text
		end
	end
	local cell = self.frame:FindFirstChild(rarity)
	local face = cell and cell:FindFirstChild("Tab")
	local caption = face and face:FindFirstChild("Caption") :: TextLabel?
	if caption then
		caption.Text = text
	end
end

function RarityTabs.destroy(self: RarityTabs)
	self.frame:Destroy()
end

return RarityTabs
