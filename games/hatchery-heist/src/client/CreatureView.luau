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

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local CreatureLooks = require(Shared.CreatureLooks)
local Layout = require(Shared.Layout)
local VoxelArt = require(Shared.VoxelArt)

local CreatureView = {}

local ATTRIBUTE = "CreatureLook"
local ANIMATE_RANGE = 160 -- studs from the camera; further creatures hold still
local RING_TRANSPARENCY = 0.45

type Motor = { motor: Motor6D, anim: string }
type Glow = { part: Part, color: Color3 }
type Visual = {
	anchor: BasePart,
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
}

local visuals: { [BasePart]: Visual } = {}

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

local function build(anchor: BasePart, speciesId: string)
	local art = VoxelArt.species[speciesId]
	if art == nil then
		return -- no art: the ball stays as it is
	end
	local look = CreatureLooks[art.rarity] or CreatureLooks.Common
	-- Studs per voxel: the art's own size on a pad, scaled with the ball when
	-- the server draws it smaller (ridden or carried overhead).
	local s = VoxelArt.voxel * anchor.Size.Y / Layout.raritySize(art.rarity)
	local height = art.size[2] * s
	local feet = anchor.CFrame * CFrame.new(0, -anchor.Size.Y / 2, 0)

	local model = Instance.new("Model")
	model.Name = "Look"

	local v: Visual = {
		anchor = anchor,
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
	}

	local palette: { { color: Color3, glow: boolean } } = {}
	local glowColor: Color3? = nil
	for i, hex in art.palette do
		local color, glow = rgb(hex)
		palette[i] = { color = color, glow = glow }
		if glow and glowColor == nil then
			glowColor = color
		end
	end
	local rarityColor = Layout.rarityColor(art.rarity)

	-- One invisible root per part, at its pivot; the parts' boxes weld to it.
	local roots: { [string]: BasePart } = {}
	for _, part in art.parts do
		local pivot = feet * CFrame.new(part.pivot[1] * s, part.pivot[2] * s, part.pivot[3] * s)
		local root = visualPart(`Root_{part.name}`, Vector3.new(0.05, 0.05, 0.05), pivot)
		root.Transparency = 1
		root.Parent = model
		roots[part.name] = root
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
				table.insert(v.glow, { part = box, color = entry.color })
			end
			weld(root, box)
			box.Parent = model
			if part.anim == "blink" then
				table.insert(v.eyes, box)
			else
				table.insert(v.boxes, box)
			end
		end
	end
	-- Joints: the body hangs from the ball, everything else from its parent.
	for _, part in art.parts do
		local root = roots[part.name]
		local parent: BasePart = if part.parent then roots[part.parent] or anchor else anchor
		local motor = Instance.new("Motor6D")
		motor.Name = part.name
		motor.Part0 = parent
		motor.Part1 = root
		motor.C0 = parent.CFrame:ToObjectSpace(root.CFrame)
		motor.Parent = root
		local anim = if part.name == "body" then "body" else part.anim
		table.insert(v.motors, { motor = motor, anim = anim })
	end

	local width = math.max(art.size[1], art.size[3]) * s
	local centre = feet * CFrame.new(0, height / 2, 0)

	if look.ring then
		local ring = visualPart(
			"Ring",
			Vector3.new(0.12, width * 0.95, width * 0.95),
			feet * CFrame.Angles(0, 0, math.pi / 2)
		)
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.Neon
		ring.Color = rarityColor
		weld(anchor, ring)
		ring.Parent = model
		v.ring = ring
	end

	if look.light > 0 or look.particles > 0 then
		local aura = visualPart("Aura", Vector3.new(width, height, width), centre)
		aura.Transparency = 1
		weld(roots.body or anchor, aura)
		aura.Parent = model
		if look.light > 0 then
			local light = Instance.new("PointLight")
			light.Color = glowColor or rarityColor
			light.Range = look.light
			light.Brightness = 1.5
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

	if look.orbit > 0 then
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
			orb.Color = Color3.fromHSV(i / look.orbit, 0.7, 1)
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
local function animate(v: Visual, now: number)
	local look = v.look
	local t = now + v.phase
	local h = v.height
	for _, m in v.motors do
		local anim = m.anim
		local pose: CFrame
		if anim == "body" then
			local lift = h * (look.hover + look.bob * (0.5 + 0.5 * math.sin(t * look.bobSpeed * math.pi * 2)))
			local sway = if look.moves.head then math.sin(t * 0.4) * 0.05 else 0
			pose = CFrame.new(0, lift, 0) * CFrame.Angles(0, sway, 0)
		elseif anim == "head" and look.moves.head then
			pose = CFrame.Angles(math.sin(t * 1.1) * 0.07, math.sin(t * 0.5) * 0.2, 0)
		elseif anim == "ears" and look.moves.ears then
			local k = t % 3.3
			pose = if k < 0.3 then CFrame.Angles(math.sin(k / 0.3 * math.pi) * 0.3, 0, 0) else CFrame.identity
		elseif anim == "tail" and look.moves.tail then
			pose = CFrame.Angles(0, math.sin(t * 6) * 0.35, 0)
		elseif (anim == "wingL" or anim == "wingR") and look.moves.wings then
			local big = look.hover > 0
			local a = math.sin(t * (if big then 2.6 else 4.5)) * (if big then 0.45 else 0.25)
			pose = CFrame.Angles(0, 0, if anim == "wingL" then a else -a)
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
			g.part.Color = g.color:Lerp(Color3.new(1, 1, 1), 0.3 * k)
		end
		if v.light then
			v.light.Brightness = 1 + 1.5 * k
		end
	end
	if look.shimmer then
		local hue = (t * 0.12) % 1
		if v.ring then
			v.ring.Color = Color3.fromHSV(hue, 0.65, 1)
		end
		for i, orb in v.orbiters do
			orb.Color = Color3.fromHSV((hue + i / #v.orbiters) % 1, 0.7, 1)
		end
	end
	if v.orbit then
		v.orbit.Transform = CFrame.Angles(0, t * 1.1, 0)
	end
end

function CreatureView.start()
	for _, inst in Workspace:GetDescendants() do
		watch(inst)
	end
	Workspace.DescendantAdded:Connect(watch)

	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		local now = os.clock()
		for anchor, v in visuals do
			if anchor.Parent == nil then
				remove(anchor)
			elseif v.fade < 1 and (anchor.Position - eye).Magnitude <= ANIMATE_RANGE + v.height * 4 then
				animate(v, now)
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
