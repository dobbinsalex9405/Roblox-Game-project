--!strict
-- The hatch reveal: when an egg hatches, a voxel egg wobbles on screen, cracks
-- in a flash and the new creature turns in the light under its rarity banner,
-- its name, its income and how rare it was ("1 in 50,000"). The ceremony grows
-- with rarity (shared/CreatureLooks): a Common pops out in about two seconds;
-- from Rare up light rays turn behind it; Ultra Rares glow; Epics add
-- confetti; Legendaries and Godlies shake the screen and linger.
--
-- A tap skips ahead: during the wobble it cracks the egg at once, and once the
-- creature is out it closes the reveal. Holding the screen skips every reveal
-- still waiting (a notice lists what hatched). Hatches that arrive meanwhile
-- queue up and play in turn; waiting Commons and Uncommons that are already
-- in the book share one reveal ("+3 more: Chick x2, Bunny"), so a player with
-- a dozen incubators is not held up by a dozen Chick reveals.
--
-- The "1 in N" shown is the player's own odds from the server (OddsView, the
-- same numbers as the odds card, boosts included), falling back to the egg's
-- base odds only if those have not arrived.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Odds = require(ReplicatedStorage.Core.Odds)
local Shared = ReplicatedStorage.Shared
local CreatureLooks = require(Shared.CreatureLooks)
local Layout = require(Shared.Layout)

local Context = require(script.Parent.Context)
local CreatureView = require(script.Parent.CreatureView)
local OddsView = require(script.Parent.OddsView)
local Sfx = require(script.Parent.Sfx)

local HatchReveal = {}

local QUEUE_MAX = 8 -- more waiting than this and the rest just get a notice
local EGG_HEIGHT = 2.6 -- studs, in the reveal's own little world
local EGG_VOXEL = 0.14
local MIN_FRAME = 3.4 -- studs: the least the creature view shows, so Commons look small
local HOLD_TO_SKIP = 0.6 -- seconds the screen is held to skip every reveal
local GROUP_RANK = 2 -- waiting hatches up to Uncommon share one reveal
local TAP_GRACE = 0.35 -- seconds after the creature appears before a tap closes it
local FONT = Enum.Font.FredokaOne

export type Reveal = {
	-- Queues a reveal; false when the queue is full (the caller says it instead).
	show: (speciesId: string, eggId: string, isNew: boolean?) -> boolean,
	-- True while a reveal is on screen.
	busy: () -> boolean,
}

type Piece = { part: BasePart, velocity: Vector3, spin: Vector3, home: CFrame }
type Confetti = { frame: Frame, x: number, y: number, vx: number, vy: number, spin: number, born: number }

-- A voxel egg: a solid of little cubes, wider low down, with a zigzag band
-- and a few spots, merged into runs along X (one part per run) so the shell
-- can burst apart in pieces when it cracks.
local function buildEgg(color: Color3): (Model, { BasePart })
	local model = Instance.new("Model")
	model.Name = "Egg"
	local parts: { BasePart } = {}
	local h, s, v = color:ToHSV()
	local band = Color3.fromHSV(h, math.min(1, s + 0.25), v * 0.72)
	local spot = color:Lerp(Color3.new(1, 1, 1), 0.6)
	local shades = { color, band, spot }
	local layers = math.floor(EGG_HEIGHT / EGG_VOXEL + 0.5)
	local widest = 0
	local radii: { number } = {}
	for layer = 0, layers - 1 do
		local t = (layer + 0.5) / layers
		-- An egg, not a ball: fuller below the middle, narrower on top.
		local r = 0.98 * math.sin(math.pi * t) ^ 0.6 * (1.1 - 0.3 * t) / EGG_VOXEL
		radii[layer] = r
		widest = math.max(widest, math.ceil(r))
	end
	local bandAt = layers * 0.5
	for layer = 0, layers - 1 do
		local r = radii[layer]
		for z = -widest, widest do
			local runStart: number? = nil
			local runShade = 0
			local function flush(x: number)
				if runStart then
					local size = Vector3.new((x - runStart) * EGG_VOXEL, EGG_VOXEL, EGG_VOXEL)
					local centre = Vector3.new(
						(runStart + x - 1) / 2 * EGG_VOXEL,
						(layer + 0.5) * EGG_VOXEL,
						z * EGG_VOXEL
					)
					local p = Instance.new("Part")
					p.Anchored = true
					p.CanCollide = false
					p.CanQuery = false
					p.CanTouch = false
					p.CastShadow = false
					p.Material = Enum.Material.SmoothPlastic
					p.TopSurface = Enum.SurfaceType.Smooth
					p.BottomSurface = Enum.SurfaceType.Smooth
					p.Size = size
					p.CFrame = CFrame.new(centre)
					p.Color = shades[runShade]
					p.Parent = model
					table.insert(parts, p)
				end
				runStart = nil
			end
			for x = -widest, widest + 1 do
				local cx, cz = x, z
				local inside = x <= widest and cx * cx + cz * cz <= r * r
				local shade = 0
				if inside then
					shade = 1
					local angle = math.atan2(cz, cx)
					local zig = bandAt + math.abs(((angle / math.pi * 4) % 2) - 1) * 2 - 1
					if layer >= zig - 0.5 and layer < zig + 1.5 then
						shade = 2
					elseif
						(x * 7 + layer * 5 + z * 3) % 13 == 0
						and math.abs(layer - bandAt) > 2.5
						and cx * cx + cz * cz > (r - 1.5) * (r - 1.5)
					then
						shade = 3
					end
				end
				if shade ~= runShade then
					flush(x)
					if shade > 0 then
						runStart = x
					end
					runShade = shade
				end
			end
		end
	end
	return model, parts
end

local function textLabel(parent: Instance, name: string, height: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, height)
	l.Font = FONT
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = ""
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = math.max(2, height / 14)
	stroke.Color = Color3.fromRGB(20, 16, 30)
	stroke.Parent = l
	l.Parent = parent
	return l
end

-- `notify` shows a short message (the HUD's notice), for skipped reveals.
function HatchReveal.start(ctx: Context.Context, notify: (text: string) -> ()): Reveal
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "HatchReveal"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50 -- above the HUD and menus
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- The dim backdrop doubles as the tap target.
	local dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.fromRGB(10, 8, 20)
	dim.BackgroundTransparency = 1
	dim.Parent = gui

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui

	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.BackgroundTransparency = 1
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.42)
	stage.Parent = root

	-- Light rays: bars through the centre, faded at both ends, turning.
	local rays = Instance.new("Frame")
	rays.Name = "Rays"
	rays.BackgroundTransparency = 1
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromScale(1.7, 1.7)
	rays.Parent = stage
	local rayBars: { Frame } = {}

	-- A soft glow behind Ultra Rares and up: rings of light, faint outside.
	local halo: { Frame } = {}
	for i, scale in { 1.15, 1.03, 0.92, 0.81, 0.7, 0.59, 0.48 } do
		local ring = Instance.new("Frame")
		ring.Name = `Halo{i}`
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromScale(scale, scale)
		ring.BackgroundTransparency = 1
		ring.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = ring
		ring.Parent = stage
		table.insert(halo, ring)
	end
	local HALO_STEP = 0.95 -- each ring's transparency; they add up toward the middle

	local view = Instance.new("ViewportFrame")
	view.Name = "View"
	view.BackgroundTransparency = 1
	view.Size = UDim2.fromScale(1, 1)
	view.Ambient = Color3.fromRGB(170, 170, 185)
	view.LightColor = Color3.fromRGB(255, 248, 235)
	view.LightDirection = Vector3.new(-0.6, -1, 0.5)
	view.Parent = stage
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = view
	view.CurrentCamera = camera

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.Parent = root

	local words = Instance.new("Frame")
	words.Name = "Words"
	words.BackgroundTransparency = 1
	words.AnchorPoint = Vector2.new(0.5, 0)
	words.Parent = root
	local wordsScale = Instance.new("UIScale")
	wordsScale.Parent = words
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = words
	local newText = textLabel(words, "New", 24, Color3.fromRGB(120, 255, 140))
	newText.LayoutOrder = 0
	newText.Text = "NEW! Added to your Hatchery Book"
	local rarityText = textLabel(words, "Rarity", 44, Color3.new(1, 1, 1))
	rarityText.LayoutOrder = 1
	local nameText = textLabel(words, "Species", 30, Color3.new(1, 1, 1))
	nameText.LayoutOrder = 2
	local infoText = textLabel(words, "Info", 22, Color3.fromRGB(255, 226, 120))
	infoText.LayoutOrder = 3
	local moreText = textLabel(words, "More", 20, Color3.fromRGB(225, 225, 240))
	moreText.LayoutOrder = 4

	-- The hint is the last line of the words, so nothing above can ever
	-- run into it; its text sits at the bottom of a taller line (a gap).
	local hint = textLabel(words, "Hint", 18, Color3.fromRGB(230, 230, 240))
	hint.LayoutOrder = 5
	hint.TextYAlignment = Enum.TextYAlignment.Bottom
	hint.Text = "Tap to continue"
	hint.TextTransparency = 1

	-- Stage size and centre in pixels, and the text size, set by layout().
	local side = 400
	local centre = Vector2.new(640, 300)
	local textScale = 1

	-- Fits the stage and words to the screen: square, as big as fits.
	local function layout()
		local cam = Workspace.CurrentCamera
		local screen = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		side = math.floor(math.min(screen.Y * 0.56, screen.X * 0.86))
		centre = Vector2.new(screen.X * 0.5, screen.Y * 0.42)
		-- Smaller words on short screens (a phone held sideways) so they
		-- fit under the creature; the hint stays at least 14 px tall.
		textScale = math.clamp(screen.Y / 720, 0.6, 1)
		local hintText = 18 * math.max(textScale, 0.8) / textScale
		hint.Size = UDim2.new(1, 0, 0, math.floor(hintText + 10 / textScale))
		hint.TextScaled = false
		hint.TextSize = math.floor(hintText)
		stage.Size = UDim2.fromOffset(side, side)
		local wordsWidth = math.min(screen.X - 32, 520)
		-- Every line at its tallest: new, rarity, name, info, more, hint.
		local tallest = 24 + 44 + 30 + 22 + 20 + hintText + 10 / textScale
		words.Size = UDim2.fromOffset(wordsWidth / textScale, tallest)
		-- Under the stage, but pulled up if it would run off the bottom.
		local top = math.min(screen.Y * 0.42 + side / 2 - side * 0.02, screen.Y - 6 - tallest * textScale)
		words.Position = UDim2.fromOffset(screen.X / 2, top)
	end

	type Hatch = { speciesId: string, eggId: string, isNew: boolean, more: { string }? }
	local queue: { Hatch } = {}
	local running = false

	-- State of the reveal on screen.
	local phase: "idle" | "wobble" | "shown" | "closing" = "idle"
	local look: CreatureLooks.Look = CreatureLooks.Common
	local rarity = "Common"
	local rank = 1
	local startedAt = 0
	local shownAt = 0
	local eggModel: Model? = nil
	local eggParts: { BasePart } = {}
	local eggColors: { [BasePart]: Color3 } = {}
	local pieces: { Piece } = {}
	local creature: Model? = nil
	local creatureSize = Vector3.one
	local confetti: { Confetti } = {}
	local shakeUntil = 0
	local nextShakeSound = 0
	local current: Hatch? = nil
	local playNext: () -> ()

	local function aim(target: Vector3, size: number, yaw: number, pitch: number)
		local distance = (size / 2) / math.tan(math.rad(camera.FieldOfView / 2)) * 1.35
		local offset = CFrame.Angles(0, yaw, 0) * CFrame.Angles(-pitch, 0, 0) * Vector3.new(0, 0, -distance)
		camera.CFrame = CFrame.lookAt(target + offset, target)
	end

	local function clearRays()
		for _, bar in rayBars do
			bar:Destroy()
		end
		table.clear(rayBars)
	end

	local function makeRays(count: number, color: Color3)
		clearRays()
		for i = 1, count do
			local bar = Instance.new("Frame")
			bar.Name = "Ray"
			bar.AnchorPoint = Vector2.new(0.5, 0.5)
			bar.Position = UDim2.fromScale(0.5, 0.5)
			bar.Size = UDim2.fromScale(1, if i % 2 == 0 then 0.06 else 0.1)
			bar.BorderSizePixel = 0
			bar.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35)
			bar.Rotation = (i - 1) * 180 / count
			local gradient = Instance.new("UIGradient")
			gradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.1, 0.55),
				NumberSequenceKeypoint.new(0.3, 0.25),
				NumberSequenceKeypoint.new(0.5, 0.1),
				NumberSequenceKeypoint.new(0.7, 0.25),
				NumberSequenceKeypoint.new(0.9, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			})
			gradient.Parent = bar
			bar.Parent = rays
			table.insert(rayBars, bar)
		end
	end

	local function clearConfetti()
		for _, c in confetti do
			c.frame:Destroy()
		end
		table.clear(confetti)
	end

	local function burstConfetti(count: number, now: number)
		local size = side
		for _ = 1, count do
			local f = Instance.new("Frame")
			f.Name = "Confetti"
			f.BorderSizePixel = 0
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			local w = 6 + math.random() * 8
			f.Size = UDim2.fromOffset(w, w * (0.5 + math.random() * 0.6))
			f.BackgroundColor3 = Color3.fromHSV(math.random(), 0.75, 1)
			f.Parent = root
			local angle = math.random() * math.pi * 2
			local speed = size * (0.9 + math.random() * 1.2)
			table.insert(confetti, {
				frame = f,
				x = centre.X,
				y = centre.Y,
				vx = math.cos(angle) * speed,
				vy = math.sin(angle) * speed * 0.6 - size * 1.1,
				spin = (math.random() - 0.5) * 900,
				born = now,
			})
		end
	end

	local function clearScene()
		view:ClearAllChildren()
		camera = Instance.new("Camera")
		camera.FieldOfView = 30
		camera.Parent = view
		view.CurrentCamera = camera
		eggModel = nil
		table.clear(eggParts)
		table.clear(pieces)
		creature = nil
	end

	-- The egg cracks: a flash, the shell bursts, the creature and its words appear.
	local function crack(now: number)
		if phase ~= "wobble" or current == nil then
			return
		end
		phase = "shown"
		shownAt = now
		local speciesId = current.speciesId
		Sfx.play("eggCrack")
		Sfx.play(if rank >= 6 then "revealLegend" elseif rank >= 4 then "revealBig" else "reveal")
		if current.isNew then
			Sfx.play("newEntry")
		end

		flash.BackgroundTransparency = if rank >= 4 then 0 else 0.25
		TweenService
			:Create(flash, TweenInfo.new(if rank >= 6 then 0.8 else 0.4), { BackgroundTransparency = 1 })
			:Play()

		for _, p in eggParts do
			local from = p.Position - Vector3.new(0, EGG_HEIGHT * 0.45, 0)
			local out = if from.Magnitude > 0.01 then from.Unit else Vector3.yAxis
			table.insert(pieces, {
				part = p,
				velocity = (out + Vector3.new(0, 0.6, 0)) * (4 + math.random() * 5),
				spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 12,
				home = p.CFrame,
			})
		end

		local model, size = CreatureView.staticModel(speciesId)
		if model then
			model.Parent = view
			creature = model
			creatureSize = size
		end

		local color = Layout.rarityColor(rarity)
		rarityText.TextColor3 = color
		if look.rays > 0 then
			makeRays(look.rays, color)
		end
		-- Every creature gets a soft light behind it so it stands out from
		-- the yard; from Ultra Rare up it glows brighter.
		for _, ring in halo do
			ring.BackgroundColor3 = color
			ring.BackgroundTransparency = HALO_STEP + (if rank >= 4 then 0 else 0.02)
		end
		if look.confetti > 0 then
			burstConfetti(look.confetti, now)
		end
		shakeUntil = now + (if look.shake > 0 then 0.7 else 0)

		words.Visible = true
		wordsScale.Scale = 0.35 * textScale
		TweenService:Create(
			wordsScale,
			TweenInfo.new(if rank >= 5 then 0.6 else 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = textScale }
		):Play()
		hint.Text = if #queue > 0 then "Tap to continue  ·  hold to skip all" else "Tap to continue"
		hint.TextTransparency = 1
		TweenService
			:Create(hint, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.8), {
				TextTransparency = 0.15,
			})
			:Play()
	end

	local function close()
		if phase ~= "shown" then
			return
		end
		phase = "closing"
		local fade = TweenInfo.new(0.22)
		TweenService:Create(dim, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(wordsScale, fade, { Scale = 0.8 * textScale }):Play()
		task.delay(0.22, function()
			clearScene()
			clearRays()
			clearConfetti()
			for _, ring in halo do
				ring.BackgroundTransparency = 1
			end
			words.Visible = false
			hint.TextTransparency = 1
			root.Position = UDim2.fromScale(0, 0)
			phase = "idle"
			current = nil
			playNext()
		end)
	end

	local function rankOf(speciesId: string): number
		local species = ctx.config.creatures.species[speciesId]
		return Layout.rarityRank(if species then species.rarity else "Common")
	end

	-- A list like "Chick x2, Bunny" for a notice or the "+N more" line.
	local function tally(ids: { string }): string
		local counts: { [string]: number } = {}
		local order: { string } = {}
		for _, id in ids do
			if counts[id] == nil then
				counts[id] = 0
				table.insert(order, id)
			end
			counts[id] += 1
		end
		local parts = {}
		for _, id in order do
			local name = Layout.displayName(id)
			table.insert(parts, if counts[id] > 1 then `{name} x{counts[id]}` else name)
		end
		return table.concat(parts, ", ")
	end

	-- The player's own chance from the server's odds, else the egg's base odds.
	local function chance(eggId: string, speciesId: string): string?
		local shown = OddsView.oneIn(eggId, speciesId)
		if shown then
			return shown
		end
		for _, egg in ctx.config.eggs do
			if egg.id == eggId then
				for _, o in egg.outcomes do
					if o.id == speciesId then
						return Odds.formatOneIn(o.weight, egg.total)
					end
				end
			end
		end
		return nil
	end

	function playNext()
		local nextOne = table.remove(queue, 1)
		if nextOne == nil then
			running = false
			gui.Enabled = false
			return
		end
		-- Small hatches already in the book share this reveal.
		if not nextOne.isNew and rankOf(nextOne.speciesId) <= GROUP_RANK then
			local more: { string } = {}
			local i = 1
			while i <= #queue do
				local q = queue[i]
				if not q.isNew and rankOf(q.speciesId) <= GROUP_RANK then
					table.insert(more, q.speciesId)
					table.remove(queue, i)
				else
					i += 1
				end
			end
			nextOne.more = more
		end
		running = true
		current = nextOne
		local species = ctx.config.creatures.species[nextOne.speciesId]
		rarity = if species then species.rarity else "Common"
		look = CreatureLooks[rarity] or CreatureLooks.Common
		rank = Layout.rarityRank(rarity)

		layout()
		clearScene()
		-- The Giant Legendary Egg (timed events) cracks in its own gold.
		local model, parts = buildEgg(
			if nextOne.eggId == "GiantEgg"
				then Color3.fromRGB(255, 178, 46)
				else Layout.eggColor(nextOne.eggId)
		)
		model.Parent = view
		eggModel = model
		eggParts = parts
		table.clear(eggColors)
		for _, p in parts do
			eggColors[p] = p.Color
		end
		aim(Vector3.new(0, EGG_HEIGHT / 2, 0), EGG_HEIGHT * 1.7, math.rad(20), math.rad(8))

		rarityText.Text = string.upper(rarity)
		nameText.Text = Layout.displayName(nextOne.speciesId)
		local info = {}
		if species then
			table.insert(info, `+{Layout.shortNumber(species.coinsPerSecond)} coins/s`)
		end
		if not ctx.restricted() then
			local oneIn = chance(nextOne.eggId, nextOne.speciesId)
			if oneIn then
				table.insert(info, oneIn)
			end
		end
		infoText.Text = table.concat(info, "  ·  ")
		newText.Visible = nextOne.isNew
		local more = nextOne.more
		moreText.Visible = more ~= nil and #more > 0
		moreText.Text = if more and #more > 0 then `+{#more} more: {tally(more)}` else ""
		words.Visible = false

		gui.Enabled = true
		dim.BackgroundTransparency = 1
		TweenService:Create(dim, TweenInfo.new(0.25), { BackgroundTransparency = 0.25 }):Play()
		phase = "wobble"
		startedAt = os.clock()
		nextShakeSound = startedAt
	end

	-- Holding the screen skips everything still waiting.
	local holdingSince: number? = nil
	dim.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			holdingSince = os.clock()
		end
	end)
	dim.InputEnded:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			holdingSince = nil
		end
	end)

	local function skipAll()
		holdingSince = nil
		local skipped: { string } = {}
		for _, q in queue do
			table.insert(skipped, q.speciesId)
			local extra: { string } = q.more or {}
			for _, id in extra do
				table.insert(skipped, id)
			end
		end
		table.clear(queue)
		if #skipped > 0 then
			notify(`Also hatched: {tally(skipped)}`)
		end
		if phase == "wobble" then
			crack(os.clock())
		end
		close()
	end

	-- Re-fit when the screen turns or resizes mid-reveal, so the words never
	-- cover the hint.
	local function watchCamera()
		local cam = Workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				if running then
					layout()
				end
			end)
		end
	end
	watchCamera()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)

	dim.Activated:Connect(function()
		local now = os.clock()
		if phase == "wobble" and now - startedAt > 0.15 then
			crack(now)
		elseif phase == "shown" and now - shownAt > TAP_GRACE then
			close()
		end
	end)

	RunService.RenderStepped:Connect(function(dt: number)
		if phase == "idle" then
			return
		end
		local now = os.clock()
		if holdingSince and now - holdingSince >= HOLD_TO_SKIP then
			skipAll()
			return
		end
		if phase == "wobble" then
			local t = now - startedAt
			local k = math.clamp(t / look.wobble, 0, 1)
			if now >= nextShakeSound then
				Sfx.play("eggShake", 0.9 + 0.3 * k)
				nextShakeSound = now + math.max(0.35, 0.9 - 0.5 * k)
			end
			-- Shakes harder and faster as it nears cracking, with little hops.
			local amp = 0.06 + 0.3 * k * k
			local tilt = math.sin(t * (12 + 14 * k)) * amp
			local hop = math.max(0, math.sin(t * 7)) * 0.12 * k
			local egg = eggModel
			if egg then
				egg:PivotTo(CFrame.new(0, hop, 0) * CFrame.Angles(0, t * 0.6, tilt))
				-- Rarer eggs give a hint: they flush toward their rarity colour.
				if rank >= 4 then
					local glow = math.clamp((k - 0.55) / 0.45, 0, 1)
					local target = Layout.rarityColor(rarity)
					for _, p in eggParts do
						p.Color = eggColors[p]:Lerp(target, glow * 0.75)
					end
				end
			end
			if t >= look.wobble then
				crack(now)
			end
			return
		end

		-- Shown (or closing): the creature turns, rays spin, bits fly.
		local t = now - shownAt
		if creature then
			-- Small creatures are framed small and big ones fill the frame,
			-- so a Legendary looks as huge here as it does on its pad.
			local size = math.max(creatureSize.X, creatureSize.Y, creatureSize.Z, MIN_FRAME)
			local intro = math.clamp(t / 0.5, 0, 1)
			local zoom = 1.6 - 0.6 * (1 - (1 - intro) ^ 3)
			-- Turns slowly from a little left of front, through the front.
			local yaw = math.rad(-20) + t * 0.35
			aim(Vector3.new(0, size * 0.5, 0), size * zoom, yaw, math.rad(10))
		end
		for _, piece in pieces do
			piece.velocity -= Vector3.new(0, 18 * dt, 0)
			local p = piece.part
			p.CFrame = (p.CFrame + piece.velocity * dt)
				* CFrame.Angles(piece.spin.X * dt, piece.spin.Y * dt, piece.spin.Z * dt)
			p.Transparency = math.clamp(t / 0.45, 0, 1)
		end
		rays.Rotation = t * 18
		for _, c in confetti do
			local age = now - c.born
			c.vy += side * 2.4 * dt
			c.vx *= (1 - 1.2 * dt)
			c.x += c.vx * dt
			c.y += c.vy * dt
			c.frame.Position = UDim2.fromOffset(c.x, c.y)
			c.frame.Rotation += c.spin * dt
			c.frame.BackgroundTransparency = math.clamp((age - 1.6) / 0.8, 0, 1)
		end
		if now < shakeUntil then
			local left = (shakeUntil - now) / 0.7
			local px = look.shake * left
			root.Position = UDim2.fromOffset((math.random() - 0.5) * 2 * px, (math.random() - 0.5) * 2 * px)
		elseif root.Position ~= UDim2.new() then
			root.Position = UDim2.fromScale(0, 0)
		end
		if phase == "shown" and t >= look.hold then
			close()
		end
	end)

	return {
		show = function(speciesId: string, eggId: string, isNew: boolean?): boolean
			if #queue >= QUEUE_MAX then
				return false
			end
			table.insert(queue, { speciesId = speciesId, eggId = eggId, isNew = isNew == true })
			if not running then
				playNext()
			end
			return true
		end,
		busy = function(): boolean
			return running
		end,
	}
end

return HatchReveal
