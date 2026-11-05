--!strict
-- Draws every creature as its voxel model (shared/VoxelArt, made by
-- tools/art). The server owns an invisible ball for each creature it shows:
-- on a pad, ridden, guarding, carried off by a raider, or a decoy. It marks
-- that ball with a `CreatureLook` attribute naming the species; this client
-- builds the model on it, standing where the ball stands and scaled with it,
-- so the server decides where a creature is and how big, and the client only
-- decides how it looks. (The ball is invisible on the server, not hidden
-- here: the camera rewrites LocalTransparencyModifier on character parts, so
-- a hidden mount would pop back into view.)
--
-- How a creature moves and shines grows with its rarity (shared/
-- CreatureLooks): Commons bob and blink; Uncommons turn their heads and wag;
-- Rares flick their ears and flap; Ultra Rares glow and sparkle; Epics stand
-- in a rarity ring; Legendaries hover in a bright aura; Godlies add orbiting
-- lights and a rainbow ring. The ball's `LookFade` attribute says when a
-- creature is a ghost (0.75: ridden or guarding) or gone (1: carried off).
--
-- Two ways to draw a creature, same parts, joints and animation either way:
-- its Blender meshes (shared/CreatureMeshes, loaded by the server into
-- ReplicatedStorage.CreatureMeshes) when they are there, otherwise its
-- VoxelArt boxes. Meshes that arrive after a creature is drawn swap it over.
--
-- The creature you ride yourself fills most of your camera, so it keeps its
-- colours but drops its glow: no neon, no light, no sparkles, ring or orbs.
-- Everyone else still sees it shine.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local ArtScale = require(Shared.ArtScale)
local CreatureLooks = require(Shared.CreatureLooks)
local CreatureMeshes = require(Shared.CreatureMeshes)
local Layout = require(Shared.Layout)
local VoxelArt = require(Shared.VoxelArt)
local Walk = require(Shared.Walk)

local GameConfig = ReplicatedStorage.GameConfig
local atmosphere = require(GameConfig.atmosphere) :: any
local wander = atmosphere.wander :: Walk.Config
local FAR_STUDS = atmosphere.creatureLod.farStuds :: number
local LOD_SLACK = 2 -- studs either side of FAR_STUDS, so it doesn't flicker
local slotsByRarity = (require(GameConfig.economy) :: any).tower.slotsByRarity :: { [string]: number }

local CreatureView = {}

local ATTRIBUTE = "CreatureLook"
local MESH_FOLDER = "CreatureMeshes" -- server/CreatureAssets fills it
local ANIMATE_RANGE = 160 -- studs from the camera; further creatures hold still
local RING_TRANSPARENCY = 0.45
local ORBIT_SECONDS = 9 -- an "orbit" part's turn (the Nebula Serpent's planets)
local LIGHT_BRIGHTNESS = 1 -- was 1.5 to 2.5 pulsing: a base of Legendaries washed out

-- A glow colour at `neon` of its full brightness (CreatureLooks.neon).
local function dim(color: Color3, neon: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), 1 - neon)
end

type Motor = { motor: Motor6D, anim: string }
type Glow = { part: BasePart, color: Color3 }
type Joint = { name: string, anim: string, parent: string? }
type Visual = {
	anchor: BasePart,
	species: string,
	meshed: boolean,
	model: Model,
	look: CreatureLooks.Look,
	height: number,
	phase: number,
	motors: { Motor },
	boxes: { BasePart },
	eyes: { BasePart },
	glow: { Glow },
	ring: BasePart?,
	orbit: Motor6D?,
	orbiters: { BasePart },
	light: PointLight?,
	emitter: ParticleEmitter?,
	fade: number,
	blinking: boolean,
	nextBlink: number,
	blinkUntil: number,
	connections: { RBXScriptConnection },
	-- Walking (shared/Walk): only creatures standing on a tower floor wander.
	gait: Walk.Gait,
	legged: boolean,
	roam: Roam?,
	moving: number,
	stepPhase: number,
	wingPhase: number,
	culled: boolean,
	-- Meshed creatures: the close-up pieces that have a far (LOD1) version,
	-- and those far pieces; one set is in the model at a time.
	near: { BasePart },
	far: { BasePart },
	showingFar: boolean,
}

-- A floor creature's cell: the middle of its wander area (home), where the
-- server stood it (stand), its schedule's seed and how far it may stray.
-- `plot` is the base the tower belongs to: your own tower is drawn and
-- animated further than other players' (Studio gate stress test, Nov 5).
type Roam = { home: CFrame, stand: CFrame, seed: number, rx: number, rz: number, plot: Model? }

local visuals: { [BasePart]: Visual } = {}
-- Where the server put each floor creature's stand-in, before this client
-- started walking it around (kept across redraws).
local homes: { [BasePart]: CFrame } = {}

local function rgb(hex: string): (Color3, boolean)
	local r = tonumber(string.sub(hex, 1, 2), 16) or 255
	local g = tonumber(string.sub(hex, 3, 4), 16) or 255
	local b = tonumber(string.sub(hex, 5, 6), 16) or 255
	return Color3.fromRGB(r, g, b), string.sub(hex, -1) == "*"
end

-- A part that is only looked at: no collisions, no touches, no raycasts (so
-- prompts behind a huge creature still work) and no weight on a rider.
local function visualPart(name: string, size: Vector3, cframe: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	return p
end

local function weld(part0: BasePart, part1: BasePart)
	local w = Instance.new("Weld")
	w.Part0 = part0
	w.Part1 = part1
	w.C0 = part0.CFrame:ToObjectSpace(part1.CFrame)
	w.Parent = part1
end

local function remove(anchor: BasePart)
	local v = visuals[anchor]
	if v == nil then
		return
	end
	visuals[anchor] = nil
	for _, c in v.connections do
		c:Disconnect()
	end
	v.model:Destroy()
	-- whichever mesh set was out of the model
	local outside: { BasePart } = if v.showingFar then v.near else v.far
	for _, p in outside do
		p:Destroy()
	end
	local home = homes[anchor]
	if home then
		anchor.CFrame = home
	end
end

local function applyFade(v: Visual)
	local raw = v.anchor:GetAttribute("LookFade")
	local fade = if type(raw) == "number" then math.clamp(raw, 0, 1) else 0
	v.fade = fade
	for _, p in v.boxes do
		p.Transparency = fade
	end
	for _, p in v.eyes do
		p.Transparency = if v.blinking then 1 else fade
	end
	for _, p in v.orbiters do
		p.Transparency = fade
	end
	if v.ring then
		v.ring.Transparency = RING_TRANSPARENCY + (1 - RING_TRANSPARENCY) * fade
	end
	local shown = fade < 0.5
	if v.light then
		v.light.Enabled = shown
	end
	if v.emitter then
		v.emitter.Enabled = shown
	end
end

-- Species whose meshes and texture this client has finished loading: until
-- then (or if any fails) the creature is drawn as voxel boxes, never as a
-- grey mesh that colours in later.
local loaded: { [Instance]: boolean } = {}

-- The loaded meshes for a species, when the server has them, every mesh the
-- creature needs is there, and their content has loaded on this client.
local function meshSource(speciesId: string): (CreatureMeshes.Creature?, Instance?)
	local entry = CreatureMeshes[speciesId]
	local folder = ReplicatedStorage:FindFirstChild(MESH_FOLDER)
	local source = if entry and folder then folder:FindFirstChild(speciesId) else nil
	if entry == nil or source == nil or loaded[source] ~= true then
		return nil, nil
	end
	for _, part in entry.parts do
		for _, mesh in part.meshes do
			-- a glow accent the server could not load is left out (CreatureAssets)
			if mesh.glow == nil and not source:FindFirstChild(mesh.name) then
				return nil, nil
			end
		end
	end
	return entry, source
end

-- The meshes are built at their own size in studs (tools/art/blender), so
-- they are scaled to the height of the voxel boxes the game draws for the
-- species: the pad, mount and carry sizes in Layout stay the one source of
-- how big a creature is, whichever way it is drawn.
local function fit(speciesId: string, mesh: CreatureMeshes.Creature): number
	local art = VoxelArt.species[speciesId]
	if art == nil or mesh.height <= 0 then
		return 1
	end
	return art.size[2] * VoxelArt.voxel / mesh.height
end

local function vec(t: { number }, k: number): Vector3
	return Vector3.new(t[1] * k, t[2] * k, t[3] * k)
end

-- A copy of one of a creature's MeshParts, sized for `k` (1 = its size on
-- a pad) and placed at `cframe`. Glowing meshes are plain Neon in their
-- colour, like the glowing boxes, so the pulse and shimmer work the same.
local function meshPiece(source: Instance, mesh: CreatureMeshes.Mesh, k: number, cframe: CFrame): MeshPart
	local template = source:FindFirstChild(mesh.name) :: MeshPart
	local p = template:Clone()
	p.Size = vec(mesh.size, k)
	p.CFrame = cframe
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	if mesh.glow then
		for _, child in p:GetChildren() do
			if child:IsA("SurfaceAppearance") then
				child:Destroy()
			end
		end
		p.TextureID = ""
		p.Material = Enum.Material.Neon
		p.Color = (rgb(mesh.glow))
	end
	return p
end

local function build(anchor: BasePart, speciesId: string)
	local mesh, source = meshSource(speciesId)
	local art = VoxelArt.species[speciesId]
	if art == nil and mesh == nil then
		return -- no art: the ball stays as it is
	end
	local rarity = if mesh then mesh.rarity else (art :: VoxelArt.Art).rarity
	local look = CreatureLooks[rarity] or CreatureLooks.Common
	-- k: scales the art so all of it, crest and all, stands as tall as the
	-- server's ball (its size on a pad, ridden or carried). s: studs per voxel.
	-- Meshes are drawn at their boxes' height (fit), so both paths fit the
	-- same art height into the ball.
	local meshFit = if mesh then fit(speciesId, mesh) else 1
	local artHeight = if mesh then mesh.size[2] * meshFit else (art :: VoxelArt.Art).size[2] * VoxelArt.voxel
	local k = ArtScale.drawScale(anchor.Size.Y, artHeight)
	local s = VoxelArt.voxel * k
	k *= meshFit
	local size = if mesh then vec(mesh.size, k) else vec((art :: VoxelArt.Art).size, s)
	local height = size.Y
	local feet = anchor.CFrame * CFrame.new(0, -anchor.Size.Y / 2, 0)

	local model = Instance.new("Model")
	model.Name = "Look"

	-- Gait from the meshes' data, else from the parts' names.
	local anims: { [string]: boolean } = {}
	for _, part in (if mesh then mesh.parts else (art :: VoxelArt.Art).parts) :: { any } do
		anims[part.anim] = true
	end
	local legged = false
	for anim in anims do
		if Walk.isLeg(anim) then
			legged = true
		end
	end
	local gait: Walk.Gait = Walk.gaitOf(if mesh then (mesh :: any).gait else nil, anims, look.hover > 0)

	-- Only a creature standing on a floor pad wanders, around its cell.
	local roam: Roam? = nil
	local pad = anchor.Parent
	local uid = anchor:GetAttribute("Uid")
	if anchor.Name == "Creature" and pad and string.match(pad.Name, "^Pad%d+$") and type(uid) == "string" then
		local home = homes[anchor] or anchor.CFrame
		homes[anchor] = home
		local index = pad:GetAttribute("Pad")
		local cx, cz, rx, rz = Walk.cell(
			if type(index) == "number" then index else 1,
			slotsByRarity[rarity] or 1,
			math.max(size.X, size.Z),
			wander.margin
		)
		roam = {
			home = home * CFrame.new(cx, 0, cz),
			stand = home,
			seed = Walk.seed(uid),
			rx = rx,
			rz = rz,
			plot = pad:FindFirstAncestorWhichIsA("Model"),
		}
	end

	local v: Visual = {
		anchor = anchor,
		species = speciesId,
		meshed = mesh ~= nil,
		model = model,
		look = look,
		height = height,
		phase = math.random() * 100,
		motors = {},
		boxes = {},
		eyes = {},
		glow = {},
		ring = nil,
		orbit = nil,
		orbiters = {},
		light = nil,
		emitter = nil,
		fade = 0,
		blinking = false,
		nextBlink = os.clock() + 1 + math.random() * 3,
		blinkUntil = 0,
		connections = {},
		gait = gait,
		legged = legged,
		roam = roam,
		moving = 0,
		stepPhase = 0,
		wingPhase = 0,
		culled = false,
		near = {},
		far = {},
		showingFar = false,
	}

	local glowColor: Color3? = nil
	local rarityColor = Layout.rarityColor(rarity)

	-- One invisible root per part, at its pivot; the part's meshes or boxes
	-- weld to it.
	local roots: { [string]: BasePart } = {}
	local joints: { Joint } = {}
	local function addRoot(name: string, pivot: CFrame)
		local root = visualPart(`Root_{name}`, Vector3.new(0.05, 0.05, 0.05), pivot)
		root.Transparency = 1
		root.Parent = model
		roots[name] = root
		return root
	end
	-- Your own mount fills your camera: no glow on it for you.
	local character = Players.LocalPlayer.Character
	local ownMount = character ~= nil and anchor.Name == "Mount" and anchor:IsDescendantOf(character)
	local function keep(piece: BasePart, anim: string, glow: Color3?)
		piece.Parent = model
		if glow and ownMount then
			piece.Material = Enum.Material.SmoothPlastic
		elseif glow then
			piece.Color = dim(glow, look.neon)
			table.insert(v.glow, { part = piece, color = piece.Color })
			if glowColor == nil then
				glowColor = glow
			end
		end
		if anim == "blink" then
			table.insert(v.eyes, piece)
		else
			table.insert(v.boxes, piece)
		end
	end

	if mesh and source then
		for _, part in mesh.parts do
			local root = addRoot(part.name, feet * CFrame.new(vec(part.pivot, k)))
			local lod = part.lod1
			local farReady = lod ~= nil and source:FindFirstChild(lod.name) ~= nil
			for _, m in part.meshes do
				if not source:FindFirstChild(m.name) then
					continue -- a glow accent left out by the server
				end
				local piece = meshPiece(source, m, k, feet * CFrame.new(vec(m.center, k)))
				weld(root, piece)
				keep(piece, part.anim, if m.glow then (rgb(m.glow)) else nil)
				if farReady then
					table.insert(v.near, piece)
				end
			end
			if lod and farReady then
				local piece = meshPiece(source, lod, k, feet * CFrame.new(vec(lod.center, k)))
				weld(root, piece)
				keep(piece, part.anim, if lod.glow then (rgb(lod.glow)) else nil)
				piece.Parent = nil
				table.insert(v.far, piece)
			end
			table.insert(
				joints,
				{ name = part.name, anim = Walk.role(part.name, part.anim), parent = part.parent }
			)
		end
	else
		local voxel = art :: VoxelArt.Art
		local palette: { { color: Color3, glow: boolean } } = {}
		for i, hex in voxel.palette do
			local color, glow = rgb(hex)
			palette[i] = { color = color, glow = glow }
		end
		for _, part in voxel.parts do
			local root = addRoot(part.name, feet * CFrame.new(vec(part.pivot, s)))
			local boxes = part.boxes
			for i = 1, #boxes, 7 do
				local x, y, z = boxes[i], boxes[i + 1], boxes[i + 2]
				local sx, sy, sz = boxes[i + 3], boxes[i + 4], boxes[i + 5]
				local entry = palette[boxes[i + 6]]
				local box = visualPart(
					part.name,
					Vector3.new(sx * s, sy * s, sz * s),
					feet * CFrame.new((x + sx / 2) * s, (y + sy / 2) * s, (z + sz / 2) * s)
				)
				box.Color = entry.color
				if entry.glow then
					box.Material = Enum.Material.Neon
				end
				weld(root, box)
				keep(box, part.anim, if entry.glow then entry.color else nil)
			end
			table.insert(
				joints,
				{ name = part.name, anim = Walk.role(part.name, part.anim), parent = part.parent }
			)
		end
	end
	-- Joints: the body hangs from the ball, everything else from its parent.
	for _, joint in joints do
		local root = roots[joint.name]
		local parent: BasePart = if joint.parent then roots[joint.parent] or anchor else anchor
		local motor = Instance.new("Motor6D")
		motor.Name = joint.name
		motor.Part0 = parent
		motor.Part1 = root
		motor.C0 = parent.CFrame:ToObjectSpace(root.CFrame)
		motor.Parent = root
		table.insert(v.motors, { motor = motor, anim = joint.anim })
	end

	local width = math.max(size.X, size.Z)
	local centre = feet * CFrame.new(0, height / 2, 0)

	if look.ring and not ownMount then
		local ring = visualPart(
			"Ring",
			Vector3.new(0.12, width * 0.95, width * 0.95),
			feet * CFrame.Angles(0, 0, math.pi / 2)
		)
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.Neon
		ring.Color = dim(rarityColor, look.neon)
		weld(anchor, ring)
		ring.Parent = model
		v.ring = ring
	end

	if (look.light > 0 or look.particles > 0) and not ownMount then
		local aura = visualPart("Aura", Vector3.new(width, height, width), centre)
		aura.Transparency = 1
		weld(roots.body or anchor, aura)
		aura.Parent = model
		if look.light > 0 then
			local light = Instance.new("PointLight")
			light.Color = glowColor or rarityColor
			light.Range = look.light
			light.Brightness = LIGHT_BRIGHTNESS
			light.Shadows = false
			light.Parent = aura
			v.light = light
		end
		if look.particles > 0 then
			local e = Instance.new("ParticleEmitter")
			e.Rate = look.particles
			e.Lifetime = NumberRange.new(1.2, 2.2)
			e.Speed = NumberRange.new(0.3, 1.2)
			e.SpreadAngle = Vector2.new(180, 180)
			e.Acceleration = Vector3.new(0, 0.6, 0)
			e.LightEmission = 1
			e.Color = ColorSequence.new(glowColor or rarityColor, Color3.new(1, 1, 1))
			local size = math.clamp(height * 0.05, 0.12, 0.6)
			e.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.2, size),
				NumberSequenceKeypoint.new(1, 0),
			})
			e.Transparency = NumberSequence.new(0.1)
			e.Parent = aura
			v.emitter = e
		end
	end

	-- A creature with its own "orbit" part (the Nebula Serpent's planets)
	-- skips the generic rainbow cubes.
	local ownOrbit = false
	for _, joint in joints do
		if joint.anim == "orbit" then
			ownOrbit = true
		end
	end
	if look.orbit > 0 and not ownMount and not ownOrbit then
		local hub = visualPart("Orbit", Vector3.new(0.05, 0.05, 0.05), feet * CFrame.new(0, height * 0.55, 0))
		hub.Transparency = 1
		hub.Parent = model
		local motor = Instance.new("Motor6D")
		motor.Part0 = anchor
		motor.Part1 = hub
		motor.C0 = anchor.CFrame:ToObjectSpace(hub.CFrame)
		motor.Parent = hub
		v.orbit = motor
		local radius = width * 0.62
		local cube = math.max(s * 2, 0.3)
		for i = 1, look.orbit do
			local a = (i / look.orbit) * math.pi * 2
			local y = math.sin(a * 2) * height * 0.12
			local orb = visualPart(
				"Orb",
				Vector3.new(cube, cube, cube),
				hub.CFrame
					* CFrame.new(math.cos(a) * radius, y, math.sin(a) * radius)
					* CFrame.Angles(a, a, 0)
			)
			orb.Material = Enum.Material.Neon
			orb.Color = Color3.fromHSV(i / look.orbit, 0.7, look.neon)
			weld(hub, orb)
			orb.Parent = model
			table.insert(v.orbiters, orb)
		end
	end

	model.Parent = anchor
	visuals[anchor] = v
	applyFade(v)
	table.insert(
		v.connections,
		anchor:GetAttributeChangedSignal("LookFade"):Connect(function()
			applyFade(v)
		end)
	)
end

-- A still copy of a creature for a picture (the hatch reveal, the Hatchery
-- Book): its meshes, or anchored boxes, with its feet at the origin, facing
-- -Z like on a pad. Returns the model and its size in studs, or nil for a
-- species without art.
function CreatureView.staticModel(speciesId: string, studsPerVoxel: number?): (Model?, Vector3)
	local s = studsPerVoxel or VoxelArt.voxel
	local mesh, source = meshSource(speciesId)
	if mesh and source then
		local k = s / VoxelArt.voxel * fit(speciesId, mesh)
		local model = Instance.new("Model")
		model.Name = speciesId
		for _, part in mesh.parts do
			for _, m in part.meshes do
				if not source:FindFirstChild(m.name) then
					continue -- a glow accent left out by the server
				end
				local piece = meshPiece(source, m, k, CFrame.new(vec(m.center, k)))
				piece.Anchored = true
				piece.Parent = model
			end
		end
		return model, vec(mesh.size, k)
	end
	local art = VoxelArt.species[speciesId]
	if art == nil then
		return nil, Vector3.zero
	end
	local model = Instance.new("Model")
	model.Name = speciesId
	local colors: { Color3 } = {}
	local glows: { boolean } = {}
	for i, hex in art.palette do
		colors[i], glows[i] = rgb(hex)
	end
	for _, part in art.parts do
		local boxes = part.boxes
		for i = 1, #boxes, 7 do
			local x, y, z = boxes[i], boxes[i + 1], boxes[i + 2]
			local sx, sy, sz = boxes[i + 3], boxes[i + 4], boxes[i + 5]
			local box = visualPart(
				part.name,
				Vector3.new(sx * s, sy * s, sz * s),
				CFrame.new((x + sx / 2) * s, (y + sy / 2) * s, (z + sz / 2) * s)
			)
			box.Anchored = true
			box.Color = colors[boxes[i + 6]]
			if glows[boxes[i + 6]] then
				box.Material = Enum.Material.Neon
			end
			box.Parent = model
		end
	end
	return model, Vector3.new(art.size[1], art.size[2], art.size[3]) * s
end

local function watch(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local speciesId = inst:GetAttribute(ATTRIBUTE)
	if type(speciesId) ~= "string" or visuals[inst] then
		return
	end
	local anchor = inst :: BasePart
	build(anchor, speciesId)
	local v = visuals[anchor]
	if v == nil then
		return
	end
	table.insert(
		v.connections,
		anchor.AncestryChanged:Connect(function()
			if not anchor:IsDescendantOf(Workspace) then
				remove(anchor)
			end
		end)
	)
	table.insert(
		v.connections,
		anchor:GetAttributeChangedSignal(ATTRIBUTE):Connect(function()
			remove(anchor)
			watch(anchor)
		end)
	)
end

-- One pose per frame for every creature near the camera.
local function walkPose(v: Visual, anim: string): CFrame
	local p = Walk.pose(v.gait, anim, v.stepPhase, v.moving, v.height, v.legged)
	return CFrame.new(p.dx, p.dy, 0) * CFrame.Angles(p.rx, p.ry, p.rz)
end

local function animate(v: Visual, now: number, dt: number)
	local look = v.look
	local t = now + v.phase
	local h = v.height
	local walking = v.moving > 0
	-- Wings keep their own phase so a faster beat while moving never jumps.
	local big = look.hover > 0
	v.wingPhase += dt * (if big then 2.6 else 4.5) * Walk.wingRate(v.gait, v.moving)
	for _, m in v.motors do
		local anim = m.anim
		local pose: CFrame
		if anim == "body" then
			-- Standing still it breathes (bobs) less as it walks.
			local still = 1 - v.moving
			local lift = h
				* (look.hover + still * look.bob * (0.5 + 0.5 * math.sin(t * look.bobSpeed * math.pi * 2)))
			local sway = if look.moves.head then still * math.sin(t * 0.4) * 0.05 else 0
			pose = CFrame.new(0, lift, 0) * CFrame.Angles(0, sway, 0)
			if walking then
				pose *= walkPose(v, anim)
			end
		elseif anim == "head" and (look.moves.head or walking) then
			local still = if look.moves.head then 1 - v.moving else 0
			pose = CFrame.Angles(still * math.sin(t * 1.1) * 0.07, still * math.sin(t * 0.5) * 0.2, 0)
			if walking then
				pose *= walkPose(v, anim)
			end
		elseif anim == "ears" and (look.moves.ears or walking) then
			local k = t % 3.3
			local flick = look.moves.ears and not walking and k < 0.3
			pose = if flick then CFrame.Angles(math.sin(k / 0.3 * math.pi) * 0.3, 0, 0) else CFrame.identity
			if walking then
				pose *= walkPose(v, anim)
			end
		elseif anim == "tail" and (look.moves.tail or walking) then
			local wag = if look.moves.tail then math.sin(t * 6) * 0.35 * (1 - v.moving) else 0
			pose = CFrame.Angles(0, wag, 0)
			if walking then
				pose *= walkPose(v, anim)
			end
		elseif anim == "wingL" or anim == "wingR" then
			if look.moves.wings or v.gait == "hover" then
				local a = math.sin(v.wingPhase) * (if big then 0.45 else 0.25)
				pose = CFrame.Angles(0, 0, if anim == "wingL" then a else -a)
			elseif walking then
				-- Tiers that don't flap still move their wings with the gait.
				pose = walkPose(v, anim)
			else
				continue
			end
		elseif anim == "orbit" then
			-- Turns about its pivot's vertical axis (the Nebula Serpent's
			-- planets), one turn every ORBIT_SECONDS.
			pose = CFrame.Angles(0, t / ORBIT_SECONDS * 2 * math.pi, 0)
		elseif Walk.isLeg(anim) or anim == "finL" or anim == "finR" then
			pose = walkPose(v, anim)
		else
			continue
		end
		m.motor.Transform = pose
	end

	if look.moves.blink and #v.eyes > 0 then
		local blinking = now < v.blinkUntil
		if not blinking and now >= v.nextBlink then
			v.blinkUntil = now + 0.13
			v.nextBlink = now + 2.5 + math.random() * 3
			blinking = true
		end
		if blinking ~= v.blinking then
			v.blinking = blinking
			for _, p in v.eyes do
				p.Transparency = if blinking then 1 else v.fade
			end
		end
	end

	if look.pulse then
		local k = 0.5 + 0.5 * math.sin(t * 2.2)
		for _, g in v.glow do
			g.part.Color = g.color:Lerp(Color3.new(1, 1, 1), 0.3 * k * look.neon)
		end
		if v.light then
			v.light.Brightness = LIGHT_BRIGHTNESS * (0.8 + 0.6 * k)
		end
	end
	if look.shimmer then
		local hue = (t * 0.12) % 1
		if v.ring then
			v.ring.Color = Color3.fromHSV(hue, 0.65, look.neon)
		end
		for i, orb in v.orbiters do
			orb.Color = Color3.fromHSV((hue + i / #v.orbiters) % 1, 0.7, look.neon)
		end
	end
	if v.orbit then
		v.orbit.Transform = CFrame.Angles(0, t * 1.1, 0)
	end
end

-- Swap a meshed creature between its close-up and far meshes.
local function setFar(v: Visual, far: boolean)
	if far == v.showingFar or #v.far == 0 then
		return
	end
	v.showingFar = far
	for _, p in v.near do
		p.Parent = if far then nil else v.model
	end
	for _, p in v.far do
		p.Parent = if far then v.model else nil
	end
end

-- Hide or show a floor creature (its model and its name label).
local function setCulled(v: Visual, culled: boolean)
	if culled == v.culled then
		return
	end
	v.culled = culled
	v.model.Parent = if culled then nil else v.anchor
	local label = v.anchor:FindFirstChildOfClass("BillboardGui")
	if label then
		label.Enabled = not culled
	end
end

-- Walk a floor creature to where its schedule has it now. Ridden, guarding
-- or carried creatures (faded) stand at home.
local function stroll(v: Visual, roam: Roam, serverNow: number)
	if v.fade > 0 then
		v.moving = 0
		v.anchor.CFrame = roam.stand
		return
	end
	local at = Walk.at(roam.seed, roam.rx, roam.rz, serverNow, wander)
	v.anchor.CFrame = roam.home * CFrame.new(at.x, 0, at.z) * CFrame.Angles(0, at.yaw, 0)
	v.moving = at.moving
	v.stepPhase = Walk.phase(v.gait, at.travelled, v.height)
end

-- Meshes for a species just arrived: load their geometry and texture, then
-- redraw its creatures with them.
local function meshesArrived(model: Instance)
	if loaded[model] ~= nil then
		return
	end
	loaded[model] = false
	local ok = pcall(function()
		local failed = false
		ContentProvider:PreloadAsync({ model }, function(_: string, status: Enum.AssetFetchStatus)
			if status ~= Enum.AssetFetchStatus.Success then
				failed = true
			end
		end)
		if failed then
			error("asset failed")
		end
	end)
	if not ok then
		return -- stays on the boxes
	end
	loaded[model] = true
	-- Collected first: redrawing removes and re-adds keys of `visuals`, which
	-- must not happen while iterating it.
	local redraw: { BasePart } = {}
	for anchor, v in visuals do
		if v.species == model.Name and not v.meshed then
			table.insert(redraw, anchor)
		end
	end
	for _, anchor in redraw do
		remove(anchor)
		watch(anchor)
	end
end

local function watchMeshFolder(folder: Instance)
	if folder.Name ~= MESH_FOLDER or not folder:IsA("Folder") then
		return
	end
	folder.ChildAdded:Connect(function(model)
		task.spawn(meshesArrived, model)
	end)
	for _, model in folder:GetChildren() do
		task.spawn(meshesArrived, model)
	end
end

function CreatureView.start()
	for _, inst in Workspace:GetDescendants() do
		watch(inst)
	end
	Workspace.DescendantAdded:Connect(watch)
	local folder = ReplicatedStorage:FindFirstChild(MESH_FOLDER)
	if folder then
		watchMeshFolder(folder)
	end
	ReplicatedStorage.ChildAdded:Connect(watchMeshFolder)

	RunService.RenderStepped:Connect(function(dt: number)
		local camera = Workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		local now = os.clock()
		local serverNow = Workspace:GetServerTimeNow()
		-- Tower creatures are culled by distance only, so every floor shows:
		-- your own tower out to `cullStuds`, other players' (the costly part
		-- of a full server) out to `cullOtherStuds`, and theirs only move
		-- within `animateOtherStuds` (Studio gates).
		local userId = Players.LocalPlayer.UserId
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		for anchor, v in visuals do
			if anchor.Parent == nil then
				remove(anchor)
				continue
			end
			local roam = v.roam
			local own = true
			if roam then
				local plot = roam.plot
				own = plot == nil or plot:GetAttribute("OwnerUserId") == userId
				local away = if root then (roam.home.Position - root.Position).Magnitude else 0
				setCulled(v, Walk.culled(away, own, wander))
				if v.culled then
					continue
				end
			end
			local distance = (anchor.Position - eye).Magnitude
			if #v.far > 0 then
				local limit = FAR_STUDS + (if v.showingFar then -LOD_SLACK else LOD_SLACK)
				setFar(v, distance > limit)
			end
			local range = if own then ANIMATE_RANGE else wander.animateOtherStuds
			if v.fade < 1 and distance <= range + v.height * 4 then
				if roam then
					stroll(v, roam, serverNow)
				end
				animate(v, now, dt)
			end
		end
	end)
end

-- For tests and the boot check: how many creatures are drawn right now.
function CreatureView.count(): number
	local n = 0
	for _ in visuals do
		n += 1
	end
	return n
end

return CreatureView
