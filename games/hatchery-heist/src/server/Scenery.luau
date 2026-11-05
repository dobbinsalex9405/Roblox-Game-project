--!strict
-- Light, sky and scenery, from config/atmosphere.luau: a sunny meadow with a
-- sandy yard, the Golden Nest in the middle, low fences and flowers on every
-- base, a farmyard around the ring (Farm.luau), voxel trees between and around
-- the bases and a ring of terraced hills that hides the edge of the map. Decoration only: nothing here collides with players
-- (except the hills and tree trunks, which are outside the play area) or
-- changes gameplay, and everything sits on top of the ground.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Layout = require(ReplicatedStorage.Shared.Layout)

local Farm = require(script.Parent.Farm)

local Scenery = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

-- An upright cylinder (Roblox cylinders lie along X).
local function column(
	parent: Instance,
	name: string,
	at: Vector3,
	height: number,
	width: number,
	color: Color3,
	material: Enum.Material?
): Part
	return part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, width, width),
		CFrame = CFrame.new(at + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

-- A flat disc lying on the ground.
local function disc(
	parent: Instance,
	name: string,
	at: Vector3,
	diameter: number,
	thickness: number,
	color: Color3,
	material: Enum.Material
): Part
	return part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, diameter, diameter),
		CFrame = CFrame.new(at + Vector3.new(0, thickness / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
	})
end

-- An egg shape: a block drawn as a stretched sphere.
local function egg(
	parent: Instance,
	name: string,
	at: Vector3,
	width: number,
	height: number,
	color: Color3,
	material: Enum.Material?
): Part
	local p = part(parent, {
		Name = name,
		Size = Vector3.new(width, height, width),
		CFrame = CFrame.new(at + Vector3.new(0, height / 2, 0)),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function ball(
	parent: Instance,
	name: string,
	center: Vector3,
	size: number,
	color: Color3,
	material: Enum.Material?
): Part
	return part(parent, {
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size),
		CFrame = CFrame.new(center),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

local LEAF_COLORS = {
	Color3.fromRGB(76, 145, 65),
	Color3.fromRGB(92, 160, 70),
	Color3.fromRGB(64, 128, 72),
	Color3.fromRGB(110, 170, 80),
}
local FLOWER_COLORS = {
	Color3.fromRGB(255, 120, 150),
	Color3.fromRGB(255, 210, 80),
	Color3.fromRGB(170, 120, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 150, 70),
}

-- A voxel tree: a square trunk and a canopy of a few big leafy cubes,
-- turned a little so a wood of them does not look stamped out.
local function tree(parent: Instance, at: Vector3, scale: number, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local height = 8 * scale
	local turn = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi / 2), 0)
	local trunk = part(model, {
		Name = "Trunk",
		Size = Vector3.new(1.8, height, 1.8) * Vector3.new(scale, 1, scale),
		CFrame = turn * CFrame.new(0, height / 2, 0),
		Color = Color3.fromRGB(110, 78, 52),
		Material = Enum.Material.Wood,
	})
	trunk.CanCollide = true
	local leaves = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)]
	local cubes: { { at: Vector3, size: number } } = {
		{ at = Vector3.new(0, height + 2.5 * scale, 0), size = 8 },
		{ at = Vector3.new(2.6 * scale, height + 0.6 * scale, 1.4 * scale), size = 5.5 },
		{ at = Vector3.new(-2.4 * scale, height + 1 * scale, -1.8 * scale), size = 5.5 },
		{ at = Vector3.new(0.6 * scale, height + 6.2 * scale, -0.4 * scale), size = 4.5 },
	}
	for i, c in cubes do
		local size = c.size * scale
		local shade = if i == 4 then leaves:Lerp(Color3.fromRGB(170, 210, 110), 0.3) else leaves
		part(model, {
			Name = "Leaves",
			Size = Vector3.new(size, size * 0.85, size),
			CFrame = turn * CFrame.new(c.at),
			Color = shade,
			Material = Enum.Material.Grass,
		})
	end
	model.Parent = parent
end

local function flowers(parent: Instance, at: Vector3, rng: Random)
	for _ = 1, 5 do
		local offset = Vector3.new(rng:NextNumber(-1.8, 1.8), 0, rng:NextNumber(-1.8, 1.8))
		local stem = at + offset
		column(parent, "Stem", stem, 1, 0.2, Color3.fromRGB(70, 140, 60))
		ball(
			parent,
			"Flower",
			stem + Vector3.new(0, 1.1, 0),
			0.7,
			FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)]
		)
	end
end

function Scenery.light(config: any)
	local l = config.lighting
	Lighting.ClockTime = l.clockTime
	Lighting.GeographicLatitude = l.geographicLatitude
	Lighting.Brightness = l.brightness
	Lighting.Ambient = rgb(l.ambient)
	Lighting.OutdoorAmbient = rgb(l.outdoorAmbient)
	Lighting.EnvironmentDiffuseScale = l.environmentDiffuseScale
	Lighting.EnvironmentSpecularScale = l.environmentSpecularScale
	Lighting.ExposureCompensation = l.exposureCompensation
	Lighting.ShadowSoftness = l.shadowSoftness
	Lighting.GlobalShadows = true

	for _, child in Lighting:GetChildren() do
		if
			child:IsA("Atmosphere")
			or child:IsA("Sky")
			or child:IsA("BloomEffect")
			or child:IsA("SunRaysEffect")
			or child:IsA("ColorCorrectionEffect")
		then
			child:Destroy()
		end
	end

	local a = config.atmosphere
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = a.density
	atmosphere.Offset = a.offset
	atmosphere.Color = rgb(a.color)
	atmosphere.Decay = rgb(a.decay)
	atmosphere.Glare = a.glare
	atmosphere.Haze = a.haze
	atmosphere.Parent = Lighting

	-- Roblox's built-in sky textures; no uploaded assets.
	local sky = Instance.new("Sky")
	sky.SunAngularSize = config.sky.sunAngularSize
	sky.MoonAngularSize = config.sky.moonAngularSize
	sky.StarCount = config.sky.starCount
	sky.Parent = Lighting

	local e = config.effects
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = e.bloomIntensity
	bloom.Size = e.bloomSize
	bloom.Threshold = e.bloomThreshold
	bloom.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = e.sunRaysIntensity
	rays.Spread = e.sunRaysSpread
	rays.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Saturation = e.saturation
	grade.Contrast = e.contrast
	grade.TintColor = rgb(e.tint)
	grade.Parent = Lighting

	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
		clouds.Cover = config.clouds.cover
		clouds.Density = config.clouds.density
		clouds.Color = rgb(config.clouds.color)
		clouds.Parent = terrain
	end
end

-- The middle of the yard: a sandy plaza with the Golden Nest.
local function yard(parent: Instance)
	local yardRadius = Layout.RING_RADIUS - Layout.PLOT_SIZE / 2 + 2
	disc(
		parent,
		"Plaza",
		Vector3.zero,
		yardRadius * 2,
		0.2,
		Color3.fromRGB(222, 196, 150),
		Enum.Material.Sand
	)
	disc(
		parent,
		"NestGround",
		Vector3.new(0, 0.2, 0),
		30,
		0.2,
		Color3.fromRGB(150, 175, 90),
		Enum.Material.Grass
	)
	local nest = Instance.new("Model")
	nest.Name = "GoldenNest"
	-- A ring of straw bundles.
	local straw = Color3.fromRGB(196, 160, 82)
	for i = 1, 14 do
		local angle = i / 14 * math.pi * 2
		local at = Vector3.new(math.cos(angle) * 8, 0.4, math.sin(angle) * 8)
		part(nest, {
			Name = "Straw",
			Size = Vector3.new(5, 2.4, 2.6),
			CFrame = CFrame.lookAt(at + Vector3.new(0, 1.2, 0), Vector3.new(0, 1.6, 0))
				* CFrame.Angles(0, math.rad(90), math.rad(i % 2 == 0 and 8 or -8)),
			Color = straw,
			Material = Enum.Material.Fabric,
			CanCollide = true,
		})
	end
	disc(nest, "NestBed", Vector3.new(0, 0.4, 0), 15, 1, Color3.fromRGB(170, 132, 70), Enum.Material.Fabric)
	local golden = egg(
		nest,
		"GoldenEgg",
		Vector3.new(0, 1.4, 0),
		6,
		8.2,
		Color3.fromRGB(255, 200, 60),
		Enum.Material.Foil
	)
	golden.CanCollide = true
	golden.Reflectance = 0.15
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.fromRGB(255, 230, 140)
	sparkles.Parent = golden
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 210, 120)
	glow.Range = 16
	glow.Brightness = 1.5
	glow.Parent = golden
	egg(nest, "BlueEgg", Vector3.new(3.8, 1.4, 2.4), 3.2, 4.2, Color3.fromRGB(120, 190, 255))
	egg(nest, "PinkEgg", Vector3.new(-3.6, 1.4, 2.8), 3, 4, Color3.fromRGB(255, 150, 190))
	egg(nest, "GreenEgg", Vector3.new(0.6, 1.4, -4.2), 3.4, 4.4, Color3.fromRGB(150, 220, 110))
	nest.Parent = parent
end

-- Low fences and flower beds on each base: a side fence on the left and
-- right and a back fence, leaving the front (the yard side) open.
local function dressPlot(parent: Instance, index: number, rng: Random)
	local frame = Layout.plotCFrame(index)
	local model = Instance.new("Model")
	model.Name = `PlotDecor{index}`
	local half = Layout.PLOT_SIZE / 2 - 0.6
	local top = Layout.FLOOR_TOP
	local wood = Color3.fromRGB(235, 225, 205)
	local function fence(from: Vector3, to: Vector3)
		local length = (to - from).Magnitude
		local steps = math.max(1, math.floor(length / 8))
		for i = 0, steps do
			local at = from:Lerp(to, i / steps)
			part(model, {
				Name = "Post",
				Size = Vector3.new(0.6, 3, 0.6),
				CFrame = frame * CFrame.new(at + Vector3.new(0, top + 1.5, 0)),
				Color = wood,
				Material = Enum.Material.WoodPlanks,
			})
		end
		local middle = (from + to) / 2
		for _, height in { 1.2, 2.4 } do
			part(model, {
				Name = "Rail",
				Size = Vector3.new(0.3, 0.4, length),
				CFrame = frame * CFrame.lookAt(
					middle + Vector3.new(0, top + height, 0),
					to + Vector3.new(0, top + height, 0)
				),
				Color = wood,
				Material = Enum.Material.WoodPlanks,
			})
		end
	end
	fence(Vector3.new(-half, 0, -half + 10), Vector3.new(-half, 0, half))
	fence(Vector3.new(half, 0, -half + 10), Vector3.new(half, 0, half))
	fence(Vector3.new(-half, 0, half), Vector3.new(half, 0, half))
	for _, corner in { Vector3.new(-28, 0, 28), Vector3.new(28, 0, 28) } do
		local at = frame * (corner + Vector3.new(0, top, 0))
		disc(model, "Bed", at, 5, 0.3, Color3.fromRGB(105, 75, 50), Enum.Material.Ground)
		flowers(model, at + Vector3.new(0, 0.3, 0), rng)
	end
	model.Parent = parent
end

function Scenery.build(config: any)
	Scenery.light(config)

	local folder = Instance.new("Folder")
	folder.Name = "Scenery"
	local s = config.scenery
	local rng = Random.new(s.seed)

	yard(folder)
	for index = 1, Layout.PLOTS do
		dressPlot(folder, index, rng)
	end
	local farmAngles = Farm.build(folder, s.farm)
	-- Trees keep clear of the farm.
	local function clear(angle: number): boolean
		local degrees = math.deg(angle) % 360
		for _, taken in farmAngles do
			local gap = math.abs((degrees - taken + 180) % 360 - 180)
			if gap < s.farm.clearAngle then
				return false
			end
		end
		return true
	end

	-- One tree in each gap between neighbouring bases...
	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	trees.Parent = folder
	for index = 1, Layout.PLOTS do
		local angle = (index - 0.5) / Layout.PLOTS * math.pi * 2
		local r = Layout.RING_RADIUS + 40
		if not clear(angle) then
			continue
		end
		tree(trees, Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r), 1.3, rng)
	end
	-- ...and a wood all around the outside of the ring.
	for i = 1, s.treeCount do
		local angle = (i + rng:NextNumber(-0.35, 0.35)) / s.treeCount * math.pi * 2
		local r = rng:NextNumber(s.treeRadiusMin, s.treeRadiusMax)
		local scale = rng:NextNumber(0.9, 1.6)
		local bloom = rng:NextNumber()
		if not clear(angle) then
			continue
		end
		tree(trees, Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r), scale, rng)
		if bloom < 0.5 then
			flowers(trees, Vector3.new(math.cos(angle) * (r - 8), 0, math.sin(angle) * (r - 8)), rng)
		end
	end

	-- Rolling hills hide the edge of the world. Their centres stay above
	-- the ground so nothing is ever built inside it.
	local hills = Instance.new("Folder")
	hills.Name = "Hills"
	hills.Parent = folder
	for i = 1, s.hillCount do
		local angle = (i + rng:NextNumber(-0.3, 0.3)) / s.hillCount * math.pi * 2
		local r = s.hillRadius + rng:NextNumber(-15, 25)
		local size = rng:NextNumber(110, 170)
		local color = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)]:Lerp(Color3.fromRGB(120, 160, 90), 0.4)
		local base = CFrame.new(math.cos(angle) * r, 0, math.sin(angle) * r) * CFrame.Angles(0, -angle, 0)
		-- Voxel hills: three stacked terraces, each smaller than the last.
		local y = 0
		for step, k in { 1, 0.72, 0.44 } do
			local height = size * 0.16
			local hill = part(hills, {
				Name = "Hill",
				Size = Vector3.new(size * k * 0.7, height, size * k),
				CFrame = base * CFrame.new(0, y + height / 2, 0),
				Color = color:Lerp(Color3.fromRGB(150, 190, 100), (step - 1) * 0.15),
				Material = Enum.Material.Grass,
			})
			hill.CanCollide = true
			hill.CastShadow = false
			y += height
		end
	end

	folder.Parent = Workspace
end

return Scenery
