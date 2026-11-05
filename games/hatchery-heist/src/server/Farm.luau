--!strict
-- The farmyard around the ring of bases, in the voxel style: a red barn
-- with a silo, a windmill (its sails turn on each client, SceneryView), a
-- duck pond, an animal pen and fields of crops, all outside the play area
-- between and behind the bases (config/atmosphere.luau `scenery.farm`).
-- Farm animals are the game's own voxel creatures: invisible stand-ins
-- marked with `CreatureLook`, drawn and animated by the client's
-- CreatureView, like the creatures on the pads. Decoration only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout)

local Farm = {}

local RED = Color3.fromRGB(184, 52, 46)
local DARK_RED = Color3.fromRGB(128, 36, 34)
local WHITE = Color3.fromRGB(242, 236, 224)
local ROOF = Color3.fromRGB(86, 70, 76)
local WOOD = Color3.fromRGB(150, 104, 64)
local DIRT = Color3.fromRGB(120, 86, 58)
local STONE = Color3.fromRGB(170, 172, 180)
local WATER = Color3.fromRGB(70, 150, 220)
local SAND = Color3.fromRGB(222, 200, 150)

-- A box in a local frame: `at` is the centre of its bottom face.
local function box(
	parent: Instance,
	name: string,
	frame: CFrame,
	at: Vector3,
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	collide: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = material or Enum.Material.SmoothPlastic
	p.Size = size
	p.CFrame = frame * CFrame.new(at + Vector3.new(0, size.Y / 2, 0))
	p.Color = color
	p.Parent = parent
	return p
end

-- A spot on the map: `angle` degrees round the ring, `radius` studs out,
-- facing the middle (its -Z points at the yard).
local function spot(angle: number, radius: number): CFrame
	local a = math.rad(angle)
	local at = Vector3.new(math.cos(a), 0, math.sin(a)) * radius
	return CFrame.lookAt(at, Vector3.zero)
end

-- An invisible stand-in the client draws as a voxel creature.
local function animal(parent: Instance, speciesId: string, rarity: string, at: Vector3, facing: number)
	local size = Layout.raritySize(rarity)
	local p = Instance.new("Part")
	p.Name = "FarmAnimal"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(size, size, size)
	p.CFrame = CFrame.new(at + Vector3.new(0, size / 2, 0)) * CFrame.Angles(0, math.rad(facing), 0)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Transparency = 1
	p:SetAttribute("CreatureLook", speciesId)
	p.Parent = parent
end

local function barn(parent: Instance, frame: CFrame)
	local m = Instance.new("Model")
	m.Name = "Barn"
	local w, d, h = 28, 20, 14
	box(m, "Walls", frame, Vector3.zero, Vector3.new(w, h, d), RED, Enum.Material.WoodPlanks, true)
	for _, x in { -w / 2, w / 2 } do
		for _, z in { -d / 2, d / 2 } do
			box(m, "Corner", frame, Vector3.new(x, 0, z), Vector3.new(1.2, h, 1.2), WHITE)
		end
	end
	-- A stepped voxel roof, overhanging a little.
	local layers = 5
	for i = 0, layers - 1 do
		local width = (w + 3) * (1 - i / layers)
		box(
			m,
			"Roof",
			frame,
			Vector3.new(0, h + i * 2, 0),
			Vector3.new(width, 2, d + 2),
			ROOF,
			Enum.Material.Slate
		)
	end
	-- Big front doors facing the yard with white X braces, and a hay loft.
	local front = -d / 2 - 0.2
	box(
		m,
		"Doors",
		frame,
		Vector3.new(0, 0, front),
		Vector3.new(11, 10, 0.4),
		DARK_RED,
		Enum.Material.WoodPlanks
	)
	for _, side in { -1, 1 } do
		local cx = side * 2.75
		local p = box(m, "Brace", frame, Vector3.new(cx, 0, front - 0.25), Vector3.new(0.6, 6.8, 0.2), WHITE)
		p.CFrame = frame * CFrame.new(cx, 5, front - 0.25) * CFrame.Angles(0, 0, math.rad(side * 38))
		local q = box(m, "Brace", frame, Vector3.new(cx, 0, front - 0.25), Vector3.new(0.6, 6.8, 0.2), WHITE)
		q.CFrame = frame * CFrame.new(cx, 5, front - 0.25) * CFrame.Angles(0, 0, math.rad(-side * 38))
	end
	box(m, "DoorFrame", frame, Vector3.new(0, 10, front - 0.1), Vector3.new(12, 0.8, 0.4), WHITE)
	box(m, "Loft", frame, Vector3.new(0, 11.2, front - 0.1), Vector3.new(4.4, 2.6, 0.4), WHITE)
	box(
		m,
		"LoftDark",
		frame,
		Vector3.new(0, 11.6, front - 0.2),
		Vector3.new(3.4, 1.8, 0.3),
		Color3.fromRGB(40, 30, 30)
	)
	box(
		m,
		"LoftHay",
		frame,
		Vector3.new(0, 11.6, front - 0.3),
		Vector3.new(3, 0.8, 0.3),
		Color3.fromRGB(230, 190, 90)
	)
	-- A silo beside it: an octagon of two crossed blocks with a dome.
	local silo = Vector3.new(w / 2 + 6, 0, 2)
	box(m, "Silo", frame, silo, Vector3.new(8, 26, 5), STONE, Enum.Material.Metal, true)
	box(m, "Silo", frame, silo, Vector3.new(5, 26, 8), STONE, Enum.Material.Metal, true)
	for i = 0, 2 do
		box(m, "SiloBand", frame, silo + Vector3.new(0, 6 + i * 7, 0), Vector3.new(8.3, 0.6, 5.3), RED)
		box(m, "SiloBand", frame, silo + Vector3.new(0, 6 + i * 7, 0), Vector3.new(5.3, 0.6, 8.3), RED)
	end
	box(m, "SiloTop", frame, silo + Vector3.new(0, 26, 0), Vector3.new(6, 2, 6), RED)
	box(m, "SiloTop", frame, silo + Vector3.new(0, 28, 0), Vector3.new(3.6, 1.4, 3.6), RED)
	-- Hay bales stacked by the door.
	local hay = Color3.fromRGB(226, 186, 92)
	for i, at in { Vector3.new(-10, 0, -14), Vector3.new(-7, 0, -14.5), Vector3.new(-8.5, 2, -14.2) } do
		box(m, `Hay{i}`, frame, at, Vector3.new(3, 2, 2), hay, Enum.Material.Fabric, true)
	end
	m.Parent = parent
end

-- Returns the sails model so the client can turn it.
local function windmill(parent: Instance, frame: CFrame)
	local m = Instance.new("Model")
	m.Name = "Windmill"
	local sections = { { 10, 9 }, { 8, 9 }, { 6.4, 8 } } -- width, height
	local y = 0
	for i, s in sections do
		box(
			m,
			`Tower{i}`,
			frame,
			Vector3.new(0, y, 0),
			Vector3.new(s[1], s[2], s[1]),
			WHITE,
			Enum.Material.Brick,
			true
		)
		y += s[2]
	end
	box(m, "Cap", frame, Vector3.new(0, y, 0), Vector3.new(7.6, 2, 7.6), DARK_RED)
	box(m, "Cap", frame, Vector3.new(0, y + 2, 0), Vector3.new(5, 2, 5), DARK_RED)
	box(m, "Door", frame, Vector3.new(0, 0, -5.1), Vector3.new(3, 5, 0.4), WOOD, Enum.Material.WoodPlanks)
	box(m, "Window", frame, Vector3.new(0, 12, -4.1), Vector3.new(2, 2, 0.3), Color3.fromRGB(60, 90, 140))

	local sails = Instance.new("Model")
	sails.Name = "Sails"
	local hubAt = Vector3.new(0, y - 1.5, -4.4)
	local hub = box(sails, "Hub", frame, hubAt, Vector3.new(2, 2, 1.6), WOOD)
	hub.Name = "Hub"
	sails.PrimaryPart = hub
	local hubCentre = frame * CFrame.new(hubAt + Vector3.new(0, 1, 0))
	for i = 0, 3 do
		local turn = hubCentre * CFrame.Angles(0, 0, i * math.pi / 2)
		local arm = Instance.new("Part")
		arm.Name = "Arm"
		arm.Anchored = true
		arm.CanCollide = false
		arm.CanTouch = false
		arm.Size = Vector3.new(0.8, 13, 0.5)
		arm.CFrame = turn * CFrame.new(0, 7, -0.5)
		arm.Color = WOOD
		arm.Material = Enum.Material.WoodPlanks
		arm.Parent = sails
		local sail = arm:Clone()
		sail.Name = "Sail"
		sail.Size = Vector3.new(3.6, 10, 0.25)
		sail.CFrame = turn * CFrame.new(2.2, 8.2, -0.5)
		sail.Color = WHITE
		sail.Material = Enum.Material.Fabric
		sail.Parent = sails
	end
	sails.Parent = m
	m.Parent = parent
end

local function pond(parent: Instance, frame: CFrame)
	local m = Instance.new("Model")
	m.Name = "Pond"
	-- Stepped voxel edges: sand, then two layers of water.
	box(m, "Shore", frame, Vector3.zero, Vector3.new(34, 0.3, 24), SAND, Enum.Material.Sand)
	box(m, "Shore", frame, Vector3.zero, Vector3.new(26, 0.3, 30), SAND, Enum.Material.Sand)
	box(m, "Water", frame, Vector3.new(0, 0.3, 0), Vector3.new(30, 0.2, 18), WATER, Enum.Material.Glass)
	box(m, "Water", frame, Vector3.new(0, 0.3, 0), Vector3.new(20, 0.2, 26), WATER, Enum.Material.Glass)
	for _, p in m:GetChildren() do
		if p.Name == "Water" then
			(p :: Part).Transparency = 0.15
		end
	end
	for i, at in { Vector3.new(-8, 0.5, 3), Vector3.new(6, 0.5, -6), Vector3.new(9, 0.5, 5) } do
		box(m, `LilyPad{i}`, frame, at, Vector3.new(2.2, 0.15, 2.2), Color3.fromRGB(80, 170, 80))
	end
	for i, at in { Vector3.new(-14, 0, -9), Vector3.new(14, 0, 9), Vector3.new(-12, 0, 11) } do
		box(m, `Reed{i}`, frame, at, Vector3.new(0.4, 3, 0.4), Color3.fromRGB(90, 140, 60))
		box(
			m,
			`Reed{i}`,
			frame,
			at + Vector3.new(0.7, 0, 0.3),
			Vector3.new(0.4, 2.2, 0.4),
			Color3.fromRGB(90, 140, 60)
		)
		box(
			m,
			`ReedTop{i}`,
			frame,
			at + Vector3.new(0, 3, 0),
			Vector3.new(0.6, 1, 0.6),
			Color3.fromRGB(120, 80, 50)
		)
	end
	m.Parent = parent
	local animals = Instance.new("Folder")
	animals.Name = "PondAnimals"
	for i, at in { Vector3.new(-4, 0.5, -2), Vector3.new(-1, 0.5, 1), Vector3.new(4, 0.5, 2) } do
		animal(animals, "Duckling", "Common", (frame * CFrame.new(at)).Position, i * 70)
	end
	animals.Parent = parent
end

local function pen(parent: Instance, frame: CFrame)
	local m = Instance.new("Model")
	m.Name = "Pen"
	local half = 10
	box(
		m,
		"Grass",
		frame,
		Vector3.zero,
		Vector3.new(half * 2, 0.2, half * 2),
		Color3.fromRGB(120, 180, 80),
		Enum.Material.Grass
	)
	box(m, "Mud", frame, Vector3.new(4, 0.2, 3), Vector3.new(7, 0.15, 5), DIRT, Enum.Material.Mud)
	for _, side in
		{
			{ Vector3.new(0, 0, -half), Vector3.new(half * 2, 0, 0) },
			{ Vector3.new(0, 0, half), Vector3.new(half * 2, 0, 0) },
			{ Vector3.new(-half, 0, 0), Vector3.new(0, 0, half * 2) },
			{ Vector3.new(half, 0, 0), Vector3.new(0, 0, half * 2) },
		}
	do
		local centre, span = side[1], side[2]
		local length = math.max(span.X, span.Z)
		local size = if span.X > 0 then Vector3.new(length, 0.5, 0.4) else Vector3.new(0.4, 0.5, length)
		box(m, "Rail", frame, centre + Vector3.new(0, 1, 0), size, WHITE, Enum.Material.WoodPlanks)
		box(m, "Rail", frame, centre + Vector3.new(0, 2.2, 0), size, WHITE, Enum.Material.WoodPlanks)
		for k = -2, 2 do
			local along = span.Unit * (k * length / 4)
			box(m, "Post", frame, centre + along, Vector3.new(0.7, 3, 0.7), WHITE, Enum.Material.WoodPlanks)
		end
	end
	box(m, "Trough", frame, Vector3.new(-5, 0.2, -6), Vector3.new(6, 1.2, 2), WOOD, Enum.Material.WoodPlanks)
	box(m, "TroughWater", frame, Vector3.new(-5, 1.25, -6), Vector3.new(5.4, 0.2, 1.4), WATER)
	m.Parent = parent
	local animals = Instance.new("Folder")
	animals.Name = "PenAnimals"
	animal(animals, "Lamb", "Common", (frame * CFrame.new(-4, 0.2, 2)).Position, 30)
	animal(animals, "Lamb", "Common", (frame * CFrame.new(-1, 0.2, 5)).Position, 200)
	animal(animals, "Piglet", "Common", (frame * CFrame.new(4, 0.35, 3)).Position, 120)
	animal(animals, "Piglet", "Common", (frame * CFrame.new(6, 0.35, 1)).Position, 300)
	animals.Parent = parent
end

-- Rows of crops on dark soil, with a scarecrow in the first field.
local function field(parent: Instance, frame: CFrame, kind: number, scarecrow: boolean)
	local m = Instance.new("Model")
	m.Name = "Field"
	local rows, length = 6, 34
	local crops = {
		{ size = Vector3.new(1.1, 2.4, 1.1), color = Color3.fromRGB(232, 196, 84), step = 2.5 }, -- wheat
		{ size = Vector3.new(1.6, 1.3, 1.6), color = Color3.fromRGB(110, 180, 70), step = 3.4 }, -- cabbages
		{ size = Vector3.new(1.8, 1.5, 1.8), color = Color3.fromRGB(240, 140, 40), step = 4.2 }, -- pumpkins
	}
	local crop = crops[(kind - 1) % #crops + 1]
	for r = 1, rows do
		local z = (r - (rows + 1) / 2) * 4
		box(
			m,
			"Soil",
			frame,
			Vector3.new(0, 0, z),
			Vector3.new(length, 0.35, 2.4),
			DIRT,
			Enum.Material.Ground
		)
		local count = math.floor(length / crop.step)
		for c = 1, count do
			local x = (c - (count + 1) / 2) * crop.step
			box(m, "Crop", frame, Vector3.new(x, 0.35, z), crop.size, crop.color, Enum.Material.SmoothPlastic)
		end
	end
	if scarecrow then
		box(m, "Pole", frame, Vector3.new(0, 0, -14), Vector3.new(0.6, 7, 0.6), WOOD)
		box(m, "Arms", frame, Vector3.new(0, 4.6, -14), Vector3.new(6, 0.5, 0.5), WOOD)
		box(
			m,
			"Shirt",
			frame,
			Vector3.new(0, 3.4, -14),
			Vector3.new(2.6, 2.6, 1.2),
			Color3.fromRGB(70, 110, 190),
			Enum.Material.Fabric
		)
		box(
			m,
			"Head",
			frame,
			Vector3.new(0, 6, -14),
			Vector3.new(1.8, 1.8, 1.8),
			Color3.fromRGB(230, 200, 140),
			Enum.Material.Fabric
		)
		box(m, "Hat", frame, Vector3.new(0, 7.8, -14), Vector3.new(3, 0.3, 3), Color3.fromRGB(200, 160, 80))
		box(m, "Hat", frame, Vector3.new(0, 8.1, -14), Vector3.new(1.8, 1, 1.8), Color3.fromRGB(200, 160, 80))
	end
	m.Parent = parent
end

-- Chicks pecking around the barnyard.
local function barnyardChicks(parent: Instance, frame: CFrame)
	local folder = Instance.new("Folder")
	folder.Name = "BarnAnimals"
	for i, at in
		{ Vector3.new(-4, 0, -16), Vector3.new(2, 0, -18), Vector3.new(6, 0, -15), Vector3.new(-1, 0, -21) }
	do
		animal(folder, "Chick", "Common", (frame * CFrame.new(at)).Position, i * 95)
	end
	folder.Parent = parent
end

-- Builds the farm into `parent`. Returns the angles (degrees) it took, so
-- trees can keep clear of them.
function Farm.build(parent: Instance, config: any): { number }
	local folder = Instance.new("Folder")
	folder.Name = "Farm"
	local taken = {}
	local function at(s: { angle: number, radius: number }): CFrame
		table.insert(taken, s.angle)
		return spot(s.angle, s.radius)
	end
	local barnFrame = at(config.barn)
	barn(folder, barnFrame)
	barnyardChicks(folder, barnFrame)
	windmill(folder, at(config.windmill))
	pond(folder, at(config.pond))
	pen(folder, at(config.pen))
	for i, angle in config.fields do
		field(folder, at({ angle = angle, radius = config.fieldRadius }), i, i == 1)
	end
	folder.Parent = parent
	return taken
end

return Farm
