--!strict
-- The grey-box surface camp, built from code around the shaft opening: the
-- ground, the shaft walls and floor, the spawn, the sell pad, one upgrade
-- stand each for pick, pack and lamp, and the layer guide board. The camp
-- streams persistently so prompts and the guide are always there.
--
-- Selling and upgrading are server-side ProximityPrompts: Roblox checks the
-- distance and the server runs the action, so they need no remote. The
-- client only rewrites the prompt text to show its own prices.

local StarterPack = game:GetService("StarterPack")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Gear = require(Shared.Gear)
local Layout = require(Shared.Layout)

local Camp = {}

local WALL = 6 -- shaft wall thickness, studs
local GROUND_DEPTH = 4

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function vec(p: Layout.Point, dy: number?): Vector3
	return Vector3.new(p.x, p.y + (dy or 0), p.z)
end

local function billboard(parent: Instance, offset: Vector3, text: string)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(180, 40)
	gui.StudsOffset = offset
	gui.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui
	gui.Parent = parent
end

local function prompt(parent: Instance, action: string, object: string): ProximityPrompt
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 12
	pp.RequiresLineOfSight = false
	pp.Parent = parent
	return pp
end

export type Handlers = {
	sell: (player: Player) -> (),
	upgrade: (player: Player, kind: Gear.Kind) -> (),
}

function Camp.build(mine: any, handlers: Handlers): Model
	local model = Instance.new("Model")
	model.Name = "Camp"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local hx, hz = Layout.halfSize(mine)
	local half = Layout.GROUND_SIZE / 2
	local depth = Layout.totalRows(mine) * mine.blockSize
	local groundY = -GROUND_DEPTH / 2
	local grass = Color3.fromRGB(95, 120, 70)

	-- Ground: four slabs around the shaft opening.
	part(model, {
		Name = "GroundNorth",
		Size = Vector3.new(Layout.GROUND_SIZE, GROUND_DEPTH, half - hz),
		Position = Vector3.new(0, groundY, (half + hz) / 2),
		Color = grass,
		Material = Enum.Material.Grass,
	})
	part(model, {
		Name = "GroundSouth",
		Size = Vector3.new(Layout.GROUND_SIZE, GROUND_DEPTH, half - hz),
		Position = Vector3.new(0, groundY, -(half + hz) / 2),
		Color = grass,
		Material = Enum.Material.Grass,
	})
	part(model, {
		Name = "GroundEast",
		Size = Vector3.new(half - hx, GROUND_DEPTH, hz * 2),
		Position = Vector3.new((half + hx) / 2, groundY, 0),
		Color = grass,
		Material = Enum.Material.Grass,
	})
	part(model, {
		Name = "GroundWest",
		Size = Vector3.new(half - hx, GROUND_DEPTH, hz * 2),
		Position = Vector3.new(-(half + hx) / 2, groundY, 0),
		Color = grass,
		Material = Enum.Material.Grass,
	})

	-- Shaft walls and floor: unbreakable, outside the grid.
	local rock = Color3.fromRGB(35, 30, 30)
	local wallY = -depth / 2 - GROUND_DEPTH / 2
	local wallHeight = depth + WALL - GROUND_DEPTH
	for _, side in { 1, -1 } do
		part(model, {
			Name = "WallX",
			Size = Vector3.new(WALL, wallHeight, hz * 2 + WALL * 2),
			Position = Vector3.new(side * (hx + WALL / 2), wallY - WALL / 2, 0),
			Color = rock,
			Material = Enum.Material.Rock,
		})
		part(model, {
			Name = "WallZ",
			Size = Vector3.new(hx * 2, wallHeight, WALL),
			Position = Vector3.new(0, wallY - WALL / 2, side * (hz + WALL / 2)),
			Color = rock,
			Material = Enum.Material.Rock,
		})
	end
	part(model, {
		Name = "Bedrock",
		Size = Vector3.new(hx * 2, WALL, hz * 2),
		Position = Vector3.new(0, -depth - WALL / 2, 0),
		Color = Color3.fromRGB(15, 12, 12),
		Material = Enum.Material.Rock,
	})

	local spawnAt = Layout.campSpawn(mine)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CampSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = vec(spawnAt, 0.5)
	spawn.Color = Color3.fromRGB(200, 170, 110)
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Parent = model

	local stations = Instance.new("Folder")
	stations.Name = "Stations"
	stations.Parent = model

	local sell = part(stations, {
		Name = "SellPad",
		Size = Vector3.new(8, 1, 8),
		Position = vec(Layout.station(mine, "SellPad"), 0.5),
		Color = Color3.fromRGB(240, 200, 60),
		Material = Enum.Material.Neon,
	})
	billboard(sell, Vector3.new(0, 5, 0), "Sell ore")
	prompt(sell, "Sell", "Ore buyer").Triggered:Connect(function(player: Player)
		handlers.sell(player)
	end)

	for _, kind in Gear.KINDS do
		local stand = part(stations, {
			Name = kind,
			Size = Vector3.new(5, 6, 5),
			Position = vec(Layout.station(mine, kind), 3),
			Color = Color3.fromRGB(110, 150, 220),
		})
		stand:SetAttribute("Kind", kind)
		billboard(stand, Vector3.new(0, 5, 0), `Upgrade {string.lower(kind)}`)
		prompt(stand, "Upgrade", kind).Triggered:Connect(function(player: Player)
			handlers.upgrade(player, kind)
		end)
	end

	local guide = part(stations, {
		Name = "LayerGuide",
		Size = Vector3.new(26, 16, 1),
		Position = vec(Layout.station(mine, "Guide"), 8),
		Color = Color3.fromRGB(40, 35, 30),
		Material = Enum.Material.WoodPlanks,
	})
	-- The board faces the spawn (+z).
	guide.CFrame = CFrame.lookAt(guide.Position, guide.Position + Vector3.new(0, 0, 1))
	billboard(guide, Vector3.new(0, 10, 0), "Layer guide")

	model.Parent = Workspace
	return model
end

-- Every player gets a pickaxe (grey box: a stick and a head).
function Camp.pickaxe()
	local tool = Instance.new("Tool")
	tool.Name = "Pickaxe"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Hold to mine"
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 4, 0.4)
	handle.Color = Color3.fromRGB(120, 85, 50)
	handle.Massless = true
	handle.CanCollide = false
	handle.Parent = tool
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2.6, 0.5, 0.5)
	head.Color = Color3.fromRGB(150, 150, 160)
	head.Material = Enum.Material.Metal
	head.Massless = true
	head.CanCollide = false
	head.CFrame = handle.CFrame * CFrame.new(0, 1.8, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = head
	head.Parent = tool
	tool.Grip = CFrame.new(0, -1.2, 0)
	tool.Parent = StarterPack
end

return Camp
