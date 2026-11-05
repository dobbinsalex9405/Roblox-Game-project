--!strict
-- Light, sky and scenery, from config/atmosphere.luau: a sunny meadow with a
-- sandy yard, the Golden Nest in the middle, low fences and flowers on every
-- base, a farmyard around the ring (Farm.luau), a wood of voxel trees between
-- and around the bases with bushes, rocks and flowers (shared/NaturePlan, the
-- meshes from EnvAssets) and a ring of terraced hills that hides the edge of
-- the map. Until a tree's meshes load it is drawn as boxes. The uploaded
-- skybox and grass tile arrive the same way (`skybox`, `grass`). Decoration
-- only: nothing here collides with players (except the hills and tree
-- trunks, which are outside the play area) or changes gameplay, and
-- everything sits on top of the ground.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EnvArt = require(ReplicatedStorage.Shared.EnvArt)
local Layout = require(ReplicatedStorage.Shared.Layout)
local NaturePlan = require(ReplicatedStorage.Shared.NaturePlan)

local EnvAssets = require(script.Parent.EnvAssets)
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
local function tree(parent: Instance, at: Vector3, scale: number, rng: Random): Model
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
	return model
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

	-- Roblox's built-in sky until the uploaded skybox loads (`skybox`).
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
-- right and a back fence, leaving the front (the belt side) open.
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

-- The uploaded grass tile, laid over the ground and the hill tops.
function Scenery.grass(url: string, config: any)
	local studs = config.ground.grassTileStuds
	local function lay(p: BasePart)
		local texture = Instance.new("Texture")
		texture.Name = "GrassTile"
		texture.Face = Enum.NormalId.Top
		texture.Texture = url
		texture.StudsPerTileU = studs
		texture.StudsPerTileV = studs
		texture.Parent = p
	end
	local ground = Workspace:FindFirstChild("Baseplate")
	if ground and ground:IsA("BasePart") then
		lay(ground)
	end
	local scenery = Workspace:FindFirstChild("Scenery")
	local hills = scenery and scenery:FindFirstChild("Hills")
	if hills then
		for _, hill in hills:GetChildren() do
			if hill:IsA("BasePart") then
				lay(hill)
			end
		end
	end
end

-- Once the uploaded skybox is on: its painted clouds and mountains show
-- through thinner moving clouds and haze.
function Scenery.skybox(config: any)
	local k = config.skybox
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = k.atmosphereDensity
		atmosphere.Haze = k.haze
	end
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	local clouds = terrain and terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds.Cover = k.cloudCover
	end
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
	Farm.build(folder, s.farm)
	-- Trees and props keep clear of each piece of the farm.
	local farmSpots: { Vector3 } = {}
	local function farmSpot(degrees: number, radius: number)
		local a = math.rad(degrees)
		table.insert(farmSpots, Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius))
	end
	for _, key in { "barn", "windmill", "pond", "pen" } do
		local spot = (s.farm :: any)[key]
		farmSpot(spot.angle, spot.radius)
	end
	for _, degrees in s.farm.fields do
		farmSpot(degrees, s.farm.fieldRadius)
	end
	local function clear(x: number, z: number): boolean
		for _, at in farmSpots do
			if (at - Vector3.new(x, 0, z)).Magnitude < s.farm.clearRadius then
				return false
			end
		end
		return true
	end

	-- Rolling hills hide the edge of the world. Their centres stay above
	-- the ground so nothing is ever built inside it.
	local hills = Instance.new("Folder")
	hills.Name = "Hills"
	hills.Parent = folder
	local tops: { NaturePlan.Hill } = {}
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
		table.insert(
			tops,
			{ x = math.cos(angle) * r, z = math.sin(angle) * r, top = y, width = size * 0.44 * 0.7 }
		)
	end

	-- Trees, bushes, rocks and flowers (shared/NaturePlan). A tree is drawn
	-- as boxes until its meshes load; the small things wait for theirs.
	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	trees.Parent = folder
	local spots = NaturePlan.plan(s.nature, Layout.PLOTS, clear, tops)
	for _, spot in spots do
		local frame = CFrame.new(spot.x, spot.y, spot.z) * CFrame.Angles(0, spot.yaw, 0)
		local placeholder: Model? = nil
		if spot.tree then
			-- the box tree is about 16.5 studs tall at scale 1
			local height = EnvArt.models[spot.model].size[2] * spot.scale
			placeholder = tree(trees, frame.Position, math.clamp(height / 16.5, 0.6, 1.8), rng)
		end
		EnvAssets.when(spot.model, function(template: Model)
			if placeholder then
				placeholder:Destroy()
			end
			local placed = EnvAssets.place(template, frame, spot.scale, trees)
			if spot.tree then
				-- a solid trunk so nobody walks through a tree
				local size = EnvArt.models[spot.model].size
				local width = math.min(size[1], size[3]) * spot.scale * 0.14
				local trunk = part(placed, {
					Name = "Trunk",
					Size = Vector3.new(width, size[2] * spot.scale * 0.45, width),
					CFrame = frame * CFrame.new(0, size[2] * spot.scale * 0.225, 0),
					Transparency = 1,
					CastShadow = false,
				})
				trunk.CanCollide = true
			end
		end)
	end

	folder.Parent = Workspace
end

return Scenery
