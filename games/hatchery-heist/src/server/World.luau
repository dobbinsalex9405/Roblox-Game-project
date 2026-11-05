--!strict
-- The grey-box map, built from code: 8 bases around a shared yard. Each base
-- has a conveyor belt (the client draws the eggs on it), incubators, creature
-- pads, a collect pad, a rebirth stand and an odds board.
--
-- The server owns what everyone sees (eggs in incubators, creatures on pads,
-- the owner's name). It writes state as attributes; the owner's client adds
-- the prompts and countdown text. Nothing here decides gameplay: it only
-- draws saved data.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Creatures)
local Geometry = require(Shared.Geometry)
local Hatchery = require(Shared.Hatchery)
local Layout = require(Shared.Layout)
local Tower = require(Shared.Tower)

local World = {}

local plotsFolder: Folder
local plots: { Model } = {}
local owners: { [number]: Player? } = {}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

-- `size` is in studs (UDim2 scale), so labels shrink with distance and
-- neighbouring labels never pile on top of each other from across the yard.
local function billboard(parent: Instance, offset: Vector3, size: UDim2, text: string): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = size
	gui.StudsOffset = offset
	gui.MaxDistance = 80
	gui.AlwaysOnTop = false
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
	return label
end

-- Remembers how a tower part looks when its floor is built, so syncTower
-- can hide it, show it as a ghost (the next floor to buy) or show it.
local function towerPart(parent: Instance, floor: number, props: { [string]: any }): Part
	local p = part(props)
	p:SetAttribute("Floor", floor)
	p:SetAttribute("Shown", p.Transparency)
	p:SetAttribute("Solid", p.CanCollide)
	p.Transparency = 1
	p.CanCollide = false
	p.Parent = parent
	return p
end

-- Floors 2 to 10 over the back half of the base, an elevator stop on every
-- floor and a ladder up the right side. Everything starts hidden; syncTower
-- shows the floors the owner has built.
-- The ladder reaches this far above the top built floor (a TrussPart's height
-- is a whole number of 2-stud sections), and the stop round its top is this
-- tall.
local LADDER_ABOVE_TOP = 2
local LADDER_STOP_HEIGHT = 8
local LANDING_DEPTH = 1.6 -- of the top floor's 3-stud opening, from the tower side

local function buildTower(model: Model, at: (Vector3) -> CFrame)
	local tower = Instance.new("Folder")
	tower.Name = "Tower"
	tower.Parent = model
	local lo, hi = Geometry.TOWER_MIN, Geometry.TOWER_MAX
	local gapLo, gapHi = Layout.LADDER.Z - 2.5, Layout.LADDER.Z + 2.5
	for floor = 1, Tower.FLOORS do
		local folder = Instance.new("Folder")
		folder.Name = `Floor{floor}`
		folder.Parent = tower
		local top = Layout.floorTop(floor)
		local look = Layout.FLOOR_LOOKS[floor]
		if floor > 1 then
			-- The deck, with an opening beside the ladder (Geometry.LADDER_HOLE)
			-- so a climber rises through it and steps back onto the floor:
			-- the main deck up to the opening, and a strip either side of it.
			local holeLo, holeHi = Geometry.LADDER_HOLE_MIN, Geometry.LADDER_HOLE_MAX
			local function deck(name: string, x0: number, x1: number, z0: number, z1: number)
				towerPart(folder, floor, {
					Name = name,
					Size = Vector3.new(x1 - x0, 1, z1 - z0),
					CFrame = at(Vector3.new((x0 + x1) / 2, top - 0.5, (z0 + z1) / 2)),
					Color = look.deck,
					Material = Enum.Material.WoodPlanks,
				})
			end
			deck("Deck", lo[1], holeLo[1], lo[2], hi[2])
			deck("DeckFront", holeLo[1], hi[1], lo[2], holeLo[2])
			deck("DeckBack", holeLo[1], hi[1], holeHi[2], hi[2])
			-- Railings round the edge, open where the ladder arrives.
			local rail = 2.5
			local function railing(name: string, from: Vector3, to: Vector3)
				local mid = (from + to) / 2
				local size = Vector3.new(
					math.max(math.abs(to.X - from.X), 0.4),
					rail,
					math.max(math.abs(to.Z - from.Z), 0.4)
				)
				towerPart(folder, floor, {
					Name = name,
					Size = size,
					CFrame = at(Vector3.new(mid.X, top + rail / 2, mid.Z)),
					Color = look.trim,
					Material = Enum.Material.Wood,
				})
			end
			railing("RailFront", Vector3.new(lo[1], 0, lo[2] + 0.2), Vector3.new(hi[1], 0, lo[2] + 0.2))
			railing("RailBack", Vector3.new(lo[1], 0, hi[2] - 0.2), Vector3.new(hi[1], 0, hi[2] - 0.2))
			railing("RailLeft", Vector3.new(lo[1] + 0.2, 0, lo[2]), Vector3.new(lo[1] + 0.2, 0, hi[2]))
			railing("RailRightA", Vector3.new(hi[1] - 0.2, 0, lo[2]), Vector3.new(hi[1] - 0.2, 0, gapLo))
			railing("RailRightB", Vector3.new(hi[1] - 0.2, 0, gapHi), Vector3.new(hi[1] - 0.2, 0, hi[2]))
			-- Corner pillars holding this floor up.
			local below = Layout.floorTop(floor - 1)
			local height = top - 1 - below
			for i, corner in
				{
					{ lo[1] + 0.6, lo[2] + 0.6 },
					{ hi[1] - 0.6, lo[2] + 0.6 },
					{ lo[1] + 0.6, hi[2] - 0.6 },
					{ hi[1] - 0.6, hi[2] - 0.6 },
				}
			do
				towerPart(folder, floor, {
					Name = `Pillar{i}`,
					Size = Vector3.new(1.2, height, 1.2),
					CFrame = at(Vector3.new(corner[1], below + height / 2, corner[2])),
					Color = look.trim,
					Material = Enum.Material.Wood,
				})
			end
			-- The floor's name over the front rail.
			local plaque = towerPart(folder, floor, {
				Name = "Plaque",
				Size = Vector3.new(8, 1.6, 0.3),
				CFrame = at(Vector3.new(0, top + 3.4, lo[2] + 0.2)),
				Color = look.trim,
				Material = Enum.Material.Wood,
				CanCollide = false,
			})
			local plaqueLabel = billboard(plaque, Vector3.new(0, 1.6, 0), UDim2.fromScale(12, 1.8), "")
			local plaqueGui = plaqueLabel.Parent :: BillboardGui
			plaqueGui.Enabled = false
		end
		-- Upgrades build things on the floor, one group per upgrade, round the
		-- edges so the middle stays clear: cozy spots, toys, lights, food and
		-- water. Grey-box shapes until the world art lands.
		if floor > 1 then
			local props = {
				{
					name = "Cozy",
					at = Vector3.new(-21, 0, 1),
					size = Vector3.new(4, 0.8, 3),
					color = Color3.fromRGB(220, 190, 120),
				},
				{
					name = "Toy",
					at = Vector3.new(21, 0, 1),
					size = Vector3.new(1.6, 1.6, 1.6),
					color = Color3.fromRGB(230, 80, 80),
					ball = true,
				},
				{
					name = "Light",
					at = Vector3.new(-21, 0, 10),
					size = Vector3.new(0.6, 4, 0.6),
					color = Color3.fromRGB(255, 220, 140),
					glow = true,
				},
				{
					name = "Food",
					at = Vector3.new(0, 0, 21.5),
					size = Vector3.new(5, 0.8, 1.6),
					color = Color3.fromRGB(120, 180, 230),
				},
			}
			for n, prop in props do
				local p = towerPart(folder, floor, {
					Name = `Upgrade{n}{prop.name}`,
					Shape = if prop.ball then Enum.PartType.Ball else Enum.PartType.Block,
					Size = prop.size,
					CFrame = at(Vector3.new(prop.at.X, top + prop.size.Y / 2, prop.at.Z)),
					Color = prop.color,
					Material = if prop.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic,
					CanCollide = false,
				})
				p:SetAttribute("Upgrade", n)
			end
		end
		-- The elevator stop: the owner stands on it and picks a floor.
		local stop = towerPart(folder, floor, {
			Name = "Elevator",
			Size = Vector3.new(4, 0.4, 4),
			CFrame = at(Vector3.new(Layout.ELEVATOR.X, top + 0.2, Layout.ELEVATOR.Z)),
			Color = Color3.fromRGB(90, 200, 255),
			Material = Enum.Material.Neon,
			Transparency = 0.2,
		})
		local stopLabel = billboard(stop, Vector3.new(0, 3, 0), UDim2.fromScale(5, 1.2), "Elevator")
		local stopGui = stopLabel.Parent :: BillboardGui
		stopGui.Enabled = false
	end
	-- One ladder up the right side, as tall as the built tower (syncTower).
	local ladder = Instance.new("TrussPart")
	ladder.Name = "Ladder"
	ladder.Anchored = true
	ladder.Size = Vector3.new(2, 2, 2)
	ladder.CFrame = at(Vector3.new(Layout.LADDER.X, Layout.FLOOR_TOP + 1, Layout.LADDER.Z))
	ladder.Color = Color3.fromRGB(140, 100, 60)
	ladder.Transparency = 1
	ladder.CanCollide = false
	ladder.Parent = tower
	-- The ladder's top (Studio gate: holding W carried players past the top
	-- floor and off onto the grass). Invisible walls on its three outer
	-- sides, and a landing over the inner part of the top floor's opening so
	-- the step back onto the floor is short; the climber, hugging the
	-- ladder, rises past the landing's edge. Parked at floor 2's height
	-- (the lowest top a ladder has); syncTower moves it to the top floor.
	local stop = Instance.new("Model")
	stop.Name = "LadderStop"
	local lx, lz = Layout.LADDER.X, Layout.LADDER.Z
	local holeLo, holeHi = Geometry.LADDER_HOLE_MIN, Geometry.LADDER_HOLE_MAX
	local h = LADDER_STOP_HEIGHT
	local parked = Layout.floorTop(2)
	local edge = hi[1] -- the decks' right edge
	local far = lx + 1.4
	local pieces = {
		{ name = "WallFar", x0 = far, x1 = far + 0.4, z0 = lz - 2.5, z1 = lz + 2.5, y0 = 0, y1 = h },
		{ name = "WallFront", x0 = edge, x1 = far, z0 = lz - 2.9, z1 = lz - 2.5, y0 = 0, y1 = h },
		{ name = "WallBack", x0 = edge, x1 = far, z0 = lz + 2.5, z1 = lz + 2.9, y0 = 0, y1 = h },
		{
			name = "Landing",
			x0 = holeLo[1],
			x1 = holeLo[1] + LANDING_DEPTH,
			z0 = holeLo[2],
			z1 = holeHi[2],
			y0 = -1,
			y1 = 0,
		},
	}
	for _, w in pieces do
		local piece = part({
			Name = w.name,
			Size = Vector3.new(w.x1 - w.x0, w.y1 - w.y0, w.z1 - w.z0),
			CFrame = at(Vector3.new((w.x0 + w.x1) / 2, parked + (w.y0 + w.y1) / 2, (w.z0 + w.z1) / 2)),
			Transparency = 1,
			CanCollide = false,
		})
		piece.Parent = stop
	end
	stop.WorldPivot = at(Vector3.new(0, parked, 0))
	stop.Parent = tower
end

local function buildPlot(index: number): Model
	local frame = Layout.plotCFrame(index)
	local model = Instance.new("Model")
	model.Name = `Plot{index}`
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)

	local function at(local_: Vector3): CFrame
		return frame * CFrame.new(local_)
	end

	local floor = part({
		Name = "Floor",
		Size = Vector3.new(Layout.PLOT_SIZE, Layout.FLOOR_THICKNESS, Layout.PLOT_SIZE),
		CFrame = at(Vector3.new(0, Layout.FLOOR_TOP - Layout.FLOOR_THICKNESS / 2, 0)),
		Color = Color3.fromRGB(120, 110, 95),
		Material = Enum.Material.WoodPlanks,
	})
	floor.Parent = model
	model.PrimaryPart = floor

	local belt = part({
		Name = "Belt",
		Size = Vector3.new((Layout.BELT_END - Layout.BELT_START).Magnitude + 4, 1, 6),
		CFrame = at((Layout.BELT_START + Layout.BELT_END) / 2 - Vector3.new(0, 1.5, 0)),
		Color = Color3.fromRGB(45, 45, 50),
		Material = Enum.Material.DiamondPlate,
	})
	belt.Parent = model

	local incubators = Instance.new("Folder")
	incubators.Name = "Incubators"
	incubators.Parent = model
	for slot = 1, Layout.INCUBATOR_POSITIONS do
		local p = part({
			Name = `Incubator{slot}`,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 4, 4),
			CFrame = at(Layout.incubator(slot)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(80, 80, 90),
		})
		p:SetAttribute("Slot", slot)
		p:SetAttribute("State", "Locked")
		billboard(p, Vector3.new(0, 4, 0), UDim2.fromScale(4.6, 1.3), "")
		p.Parent = incubators
	end

	-- Pads across the whole tower: 8 per floor (Geometry.pad). Pads on
	-- floors the owner has not built stay hidden (syncTower).
	local pads = Instance.new("Folder")
	pads.Name = "Pads"
	pads.Parent = model
	for index_ = 1, Tower.FLOORS * Tower.SPOTS do
		local p = part({
			Name = `Pad{index_}`,
			Size = Vector3.new(6, 0.4, 6),
			CFrame = at(Layout.pad(index_)),
			Color = Color3.fromRGB(150, 140, 120),
		})
		p:SetAttribute("Pad", index_)
		p:SetAttribute("Floor", Tower.floorOf(index_))
		if index_ > Tower.SPOTS then
			-- Upper floors' pads stay hidden until the owner builds the floor.
			p.Transparency = 1
			p.CanCollide = false
		end
		p.Parent = pads
	end

	buildTower(model, at)

	local collect = part({
		Name = "CollectPad",
		Size = Vector3.new(7, 0.4, 7),
		CFrame = at(Layout.COLLECT_PAD),
		Color = Color3.fromRGB(70, 200, 90),
		Material = Enum.Material.Neon,
	})
	billboard(collect, Vector3.new(0, 3.5, 0), UDim2.fromScale(6, 1.6), "Collect")
	collect.Parent = model

	local rebirth = part({
		Name = "RebirthStand",
		Size = Vector3.new(4, 6, 4),
		CFrame = at(Layout.REBIRTH_STAND),
		Color = Color3.fromRGB(150, 80, 220),
		Material = Enum.Material.Neon,
	})
	billboard(rebirth, Vector3.new(0, 4.5, 0), UDim2.fromScale(8, 1.6), "Rebirth")
	rebirth.Parent = model

	local board = part({
		Name = "OddsBoard",
		Size = Vector3.new(30, 12, 0.4),
		CFrame = at(Layout.ODDS_BOARD),
		Color = Color3.fromRGB(30, 30, 40),
	})
	board.Parent = model
	-- Two legs and a wooden frame, so the board stands on the floor.
	local boardBottom = Layout.ODDS_BOARD.Y - 6
	for _, x in { -14, 14 } do
		local legHeight = boardBottom - Layout.FLOOR_TOP
		part({
			Name = "OddsBoardLeg",
			Size = Vector3.new(0.8, legHeight, 0.8),
			CFrame = at(Vector3.new(x, Layout.FLOOR_TOP + legHeight / 2, Layout.ODDS_BOARD.Z + 0.6)),
			Color = Color3.fromRGB(120, 85, 55),
			Material = Enum.Material.Wood,
		}).Parent =
			model
	end
	part({
		Name = "OddsBoardFrame",
		Size = Vector3.new(31, 13, 0.3),
		CFrame = at(Layout.ODDS_BOARD + Vector3.new(0, 0, 0.35)),
		Color = Color3.fromRGB(120, 85, 55),
		Material = Enum.Material.Wood,
	}).Parent =
		model
	-- What everyone sees on the board: its title. The owner's client hides
	-- this and draws the real odds of their own belt over it (Hud).
	local face = Instance.new("SurfaceGui")
	face.Name = "Title"
	face.Face = Enum.NormalId.Front
	face.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	face.PixelsPerStud = 25
	face.LightInfluence = 0
	local heading = Instance.new("TextLabel")
	heading.Size = UDim2.fromScale(1, 1)
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.GothamBold
	heading.TextScaled = true
	heading.TextColor3 = Color3.fromRGB(255, 210, 63)
	heading.Text = "🥚 EGG ODDS 🥚"
	local headingPad = Instance.new("UIPadding")
	headingPad.PaddingTop = UDim.new(0.25, 0)
	headingPad.PaddingBottom = UDim.new(0.25, 0)
	headingPad.Parent = heading
	heading.Parent = face
	face.Parent = board

	local post = part({
		Name = "Sign",
		Size = Vector3.new(1, 8, 1),
		CFrame = at(Layout.SIGN - Vector3.new(0, 4, 0)),
		Color = Color3.fromRGB(90, 70, 50),
	})
	billboard(post, Vector3.new(0, 6, 0), UDim2.fromScale(16, 3), "Free base")
	post.Parent = model

	local traps = Instance.new("Folder")
	traps.Name = "Traps"
	traps.Parent = model
	for spot, xz in Geometry.TRAP_SPOTS do
		local p = part({
			Name = `Trap{spot}`,
			Size = Vector3.new(5, 0.3, 5),
			CFrame = at(Vector3.new(xz[1], 1.15, xz[2])),
			Color = Color3.fromRGB(90, 90, 90),
			Transparency = 0.5,
			CanCollide = false,
		})
		p:SetAttribute("Spot", spot)
		billboard(p, Vector3.new(0, 3, 0), UDim2.fromScale(4.4, 1.1), "")
		p.Parent = traps
	end

	local decoys = Instance.new("Folder")
	decoys.Name = "Decoys"
	decoys.Parent = model
	for spot, xz in Geometry.DECOY_SPOTS do
		local p = part({
			Name = `Decoy{spot}`,
			Size = Vector3.new(5, 0.4, 5),
			CFrame = at(Vector3.new(xz[1], 1.2, xz[2])),
			Color = Color3.fromRGB(150, 140, 120),
		})
		p:SetAttribute("Spot", spot)
		p.Parent = decoys
	end

	local pylon = part({
		Name = "ShieldPylon",
		Size = Vector3.new(3, 7, 3),
		CFrame = at(Vector3.new(Geometry.SHIELD_PYLON[1], 4.5, Geometry.SHIELD_PYLON[2])),
		Color = Color3.fromRGB(60, 160, 255),
		Material = Enum.Material.Neon,
	})
	billboard(pylon, Vector3.new(0, 5, 0), UDim2.fromScale(5, 1.4), "Shield")
	pylon.Parent = model

	local dome = part({
		Name = "ShieldDome",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(96, 96, 96),
		CFrame = at(Vector3.new(0, -Layout.PLOT_Y, 0)), -- centred on the ground, as before
		Color = Color3.fromRGB(80, 170, 255),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	dome.Parent = model

	model.Parent = plotsFolder
	return model
end

function World.build()
	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = Workspace
	for index = 1, Layout.PLOTS do
		plots[index] = buildPlot(index)
	end
end

function World.plotOf(player: Player): number?
	for index, owner in owners do
		if owner == player then
			return index
		end
	end
	return nil
end

-- Gives the player the first free base. Returns its index, or nil when every
-- base is taken (more players than bases: the server's max players is wrong).
function World.claim(player: Player): number?
	local existing = World.plotOf(player)
	if existing then
		return existing
	end
	for index = 1, Layout.PLOTS do
		if owners[index] == nil then
			owners[index] = player
			plots[index]:SetAttribute("OwnerUserId", player.UserId)
			local sign = plots[index]:FindFirstChild("Sign") :: Part
			local label = (sign:FindFirstChild("Label") :: BillboardGui):FindFirstChild("Text") :: TextLabel
			label.Text = `{player.DisplayName}'s Hatchery`
			return index
		end
	end
	return nil
end

function World.release(player: Player)
	local index = World.plotOf(player)
	if index == nil then
		return
	end
	owners[index] = nil
	local model = plots[index]
	model:SetAttribute("OwnerUserId", 0)
	local sign = model:FindFirstChild("Sign") :: Part
	local label = (sign:FindFirstChild("Label") :: BillboardGui):FindFirstChild("Text") :: TextLabel
	label.Text = "Free base"
	World.sync(index, nil, nil, 0)
end

function World.spawnCFrame(index: number): CFrame
	return Layout.plotCFrame(index) * CFrame.new(Layout.SPAWN)
end

function World.model(index: number): Model?
	return plots[index]
end

-- The elevator: whether the player stands at one of their own tower's
-- elevator stops, and where floor `floor`'s stop is.
local function stopOf(index: number, floor: number): BasePart?
	local model = plots[index]
	local tower = model and model:FindFirstChild("Tower")
	local folder = tower and tower:FindFirstChild(`Floor{floor}`)
	return folder and folder:FindFirstChild("Elevator") :: BasePart?
end

function World.atElevator(player: Player, floors: number): boolean
	local index = World.plotOf(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if index == nil or root == nil then
		return false
	end
	for floor = 1, floors do
		local stop = stopOf(index, floor)
		if stop and (stop.Position - root.Position).Magnitude <= 8 then
			return true
		end
	end
	return false
end

function World.elevatorTo(player: Player, floor: number)
	local index = World.plotOf(player)
	local stop = index and stopOf(index, floor)
	if stop then
		World.teleport(player, stop.CFrame * CFrame.new(0, 3.2, 0))
	end
end

function World.ownerOfIndex(index: number): Player?
	return owners[index]
end

-- Server-made moves go through here so the movement check can restart.
local teleportListeners: { (player: Player) -> () } = {}

function World.onTeleport(listener: (player: Player) -> ())
	table.insert(teleportListeners, listener)
end

function World.teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if character == nil then
		return
	end
	character:PivotTo(cframe)
	for _, listener in teleportListeners do
		listener(player)
	end
end

-- Puts the player's character at their base.
function World.sendHome(player: Player)
	local index = World.plotOf(player)
	if index then
		World.teleport(player, World.spawnCFrame(index))
	end
end

-- Puts the player in the yard just outside base `index`, facing away from it.
function World.pushOut(player: Player, index: number)
	local x, z = Geometry.outsideFront(index)
	local cx, cz = Geometry.center(index)
	local position = Vector3.new(x, 4, z)
	World.teleport(player, CFrame.lookAt(position, position + Vector3.new(x - cx, 0, z - cz)))
end

local function setLabel(p: Instance, text: string)
	local gui = p:FindFirstChild("Label")
	local label = gui and gui:FindFirstChild("Text")
	if label then
		(label :: TextLabel).Text = text
	end
end

local function syncIncubators(model: Model, d: { [string]: any }?, config: any?, slotCount: number)
	local folder = model:FindFirstChild("Incubators") :: Folder
	local nextCost = if d and config then Hatchery.nextSlotCost(d, config.economy) else nil
	for slot = 1, Layout.INCUBATOR_POSITIONS do
		local p = folder:FindFirstChild(`Incubator{slot}`) :: Part
		local incubator = if d then Hatchery.incubatorAt(d, slot) else nil
		local state = "Locked"
		if incubator then
			state = "Busy"
		elseif slot <= slotCount then
			state = "Empty"
		elseif slot == slotCount + 1 and nextCost then
			state = "Buyable"
		end
		p:SetAttribute("State", state)
		p:SetAttribute("EggId", if incubator then incubator.eggId else nil)
		p:SetAttribute("ReadyAt", if incubator then incubator.readyAt else nil)
		p:SetAttribute("Cost", if state == "Buyable" then nextCost else nil)
		p.Color = if state == "Locked"
			then Color3.fromRGB(60, 60, 65)
			elseif state == "Buyable" then Color3.fromRGB(200, 170, 60)
			else Color3.fromRGB(110, 180, 220)
		p.Transparency = if state == "Locked" then 0.6 else 0

		local egg = p:FindFirstChild("Egg") :: Part?
		if incubator then
			if egg == nil or egg:GetAttribute("EggId") ~= incubator.eggId then
				if egg then
					egg:Destroy()
				end
				local newEgg = part({
					Name = "Egg",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(2.6, 2.6, 2.6),
					CFrame = CFrame.new(p.Position + Vector3.new(0, 1.8, 0)),
					Color = Layout.eggColor(incubator.eggId),
					CanCollide = false,
				})
				newEgg:SetAttribute("EggId", incubator.eggId)
				newEgg.Parent = p
			end
		elseif egg then
			egg:Destroy()
		end
		if state == "Locked" or state == "Empty" then
			setLabel(p, "")
		end
	end
end

local function syncPads(model: Model, d: { [string]: any }?, config: any?, carried: { [string]: boolean })
	local folder = model:FindFirstChild("Pads") :: Folder
	local onPad: { [number]: any } = {}
	if d then
		for _, c in d.creatures do
			if c.slot then
				onPad[c.slot] = c
			end
		end
	end
	for index = 1, Tower.FLOORS * Tower.SPOTS do
		local pad = folder:FindFirstChild(`Pad{index}`) :: Part
		local c = onPad[index]
		local shown = pad:FindFirstChild("Creature") :: Part?
		if c == nil or config == nil then
			if shown then
				shown:Destroy()
			end
			pad:SetAttribute("CreatureUid", nil)
			pad:SetAttribute("SpeciesId", nil)
			pad:SetAttribute("Riding", nil)
			pad:SetAttribute("Guard", nil)
			pad:SetAttribute("Carried", nil)
			pad:SetAttribute("Span", nil)
			continue
		end
		local species = config.creatures.species[c.speciesId]
		local riding = d ~= nil and d.mountUid == c.uid
		pad:SetAttribute("CreatureUid", c.uid)
		pad:SetAttribute("SpeciesId", c.speciesId)
		local guarding = d ~= nil and d.guardUid == c.uid
		local isCarried = carried[c.uid] == true
		pad:SetAttribute("Riding", riding)
		pad:SetAttribute("Guard", guarding)
		pad:SetAttribute("Carried", isCarried)
		-- How many pads it takes: the client centres its prompts on them.
		pad:SetAttribute("Span", Tower.size(c, config.creatures, config.economy))
		if shown == nil or shown:GetAttribute("Uid") ~= c.uid then
			if shown then
				shown:Destroy()
			end
			local size = Layout.raritySize(species.rarity)
			local body = part({
				Name = "Creature",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size, size, size),
				-- Facing the way the base faces: toward the yard. A creature
				-- taking 2 or 3 pads stands in the middle of them.
				CFrame = pad.CFrame
					* CFrame.new((Tower.size(c, config.creatures, config.economy) - 1) * 5, size / 2 + 0.2, 0),
				Color = Layout.rarityColor(species.rarity),
				Transparency = 1,
				CanCollide = false,
			})
			body:SetAttribute("Uid", c.uid)
			-- An invisible stand-in: the client draws the voxel creature here
			-- (CreatureView), sized and placed by this part.
			body:SetAttribute("CreatureLook", c.speciesId)
			local income = Hatchery.creatureIncome(c, config.creatures)
			billboard(
				body,
				Vector3.new(0, size / 2 + 1.5, 0),
				UDim2.fromScale(5, 1.5),
				`{Layout.displayName(c.speciesId)}\n{Layout.shortNumber(income)}/s`
			)
			body.Parent = pad
			shown = body
		end
		-- Ridden, guarding (it patrols as its own model) or being carried off:
		-- the client draws it faded, or not at all.
		(shown :: Part):SetAttribute(
			"LookFade",
			if isCarried then 1 elseif riding or guarding then 0.75 else 0
		)
	end
end

local function shortCoins(n: number): string
	return `{Layout.shortNumber(n)} coins`
end

-- Shows the floors the owner has built, the next one as a ghost with its
-- price, each floor's upgrades, and the ladder up to the top floor.
local function syncTower(model: Model, d: { [string]: any }?, config: any?)
	local owned = if d then Tower.owned(d) else 1
	local tower = model:FindFirstChild("Tower") :: Folder
	local claimed = d ~= nil and config ~= nil
	for _, p in tower:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("Floor") then
			local floor = p:GetAttribute("Floor") :: number
			local upgrade = p:GetAttribute("Upgrade") :: number?
			local built = claimed and floor <= owned
			local ghost = claimed and floor == owned + 1 and string.sub(p.Name, 1, 4) == "Deck"
			local show = built and (upgrade == nil or Tower.upgrades(d :: any, floor) >= upgrade)
			local transparency = if show then p:GetAttribute("Shown") :: number elseif ghost then 0.85 else 1
			local solid = show and p:GetAttribute("Solid") == true
			-- Synced every tick: write only what changed.
			if p.Transparency ~= transparency then
				p.Transparency = transparency
			end
			if p.CanCollide ~= solid then
				p.CanCollide = solid
			end
			-- A label shows even on an invisible part: hide it with its part.
			local label = p:FindFirstChild("Label")
			if label and label:IsA("BillboardGui") and p.Name ~= "Deck" and label.Enabled ~= show then
				label.Enabled = show
			end
		end
	end
	for floor = 2, Tower.FLOORS do
		local folder = tower:FindFirstChild(`Floor{floor}`) :: Folder
		local plaque = folder:FindFirstChild("Plaque") :: Part
		local text = ""
		if claimed and floor <= owned then
			local m = Tower.multiplier(d :: any, floor, (config :: any).economy)
			text = `{floor}. {(config :: any).economy.tower.themes[floor]}  x{string.format("%.2f", m)}`
		end
		setLabel(plaque, text)
		local deck = folder:FindFirstChild("Deck") :: Part
		local nextPrice = if claimed then Tower.nextFloorPrice(d :: any, (config :: any).economy) else nil
		local label = deck:FindFirstChild("Label")
		if floor == owned + 1 and claimed and nextPrice then
			if label == nil then
				-- Wider than the text needs ("Floor 10: 165M"), so it never fills
				-- the box and shrinks (Studio gate).
				billboard(deck, Vector3.new(0, 2, 0), UDim2.fromScale(20, 2.4), "")
			end
			setLabel(deck, `Floor {floor}: {shortCoins(nextPrice)}`)
		elseif label then
			label:Destroy()
		end
	end
	-- The pads of unbuilt floors go too.
	for _, pad in (model:FindFirstChild("Pads") :: Folder):GetChildren() do
		local floor = pad:GetAttribute("Floor") :: number
		local built = floor <= owned and (claimed or floor == 1)
		local transparency = if built then 0 else 1
		if (pad :: Part).Transparency ~= transparency then
			(pad :: Part).Transparency = transparency;
			(pad :: Part).CanCollide = built
		end
	end
	-- What every client furnishes (client/TowerDecorView): floors built and
	-- each floor's upgrades, "0,2,4,..." (floor 1 first). 0 floors: nobody
	-- owns the base.
	local floorsAttr = if claimed then owned else 0
	local upgradesAttr = ""
	if claimed then
		local list = table.create(owned, "0")
		for floor = 1, owned do
			list[floor] = tostring(Tower.upgrades(d :: any, floor))
		end
		upgradesAttr = table.concat(list, ",")
	end
	if model:GetAttribute("TowerFloors") ~= floorsAttr then
		model:SetAttribute("TowerFloors", floorsAttr)
	end
	if model:GetAttribute("TowerUpgrades") ~= upgradesAttr then
		model:SetAttribute("TowerUpgrades", upgradesAttr)
	end
	local ladder = tower:FindFirstChild("Ladder") :: TrussPart
	local stop = tower:FindFirstChild("LadderStop") :: Model
	if claimed and owned > 1 then
		local height = Layout.floorTop(owned) - Layout.FLOOR_TOP + LADDER_ABOVE_TOP
		local base = (model.PrimaryPart :: BasePart).CFrame * CFrame.new(0, Layout.FLOOR_THICKNESS / 2, 0)
		if ladder.Size.Y ~= height or ladder.Transparency ~= 0 then
			ladder.Size = Vector3.new(2, height, 2)
			ladder.CFrame = base * CFrame.new(Layout.LADDER.X, height / 2, Layout.LADDER.Z)
			ladder.Transparency = 0
			ladder.CanCollide = true
			-- The stop rides at the top floor, so a climber who keeps going
			-- steps onto that floor, not off the ladder's far side.
			stop:PivotTo(base * CFrame.new(0, Layout.floorTop(owned) - Layout.FLOOR_TOP, 0))
			for _, wall in stop:GetChildren() do
				(wall :: BasePart).CanCollide = true
			end
		end
	else
		if ladder.Transparency ~= 1 then
			ladder.Transparency = 1
			ladder.CanCollide = false
			for _, wall in stop:GetChildren() do
				(wall :: BasePart).CanCollide = false
			end
		end
	end
end

local DECOY_LOOK = "Duckling" -- what a decoy egg pretends to be

local function syncDefenses(model: Model, d: { [string]: any }?, config: any?, now: number)
	local traps = model:FindFirstChild("Traps") :: Folder
	for spot = 1, #Geometry.TRAP_SPOTS do
		local p = traps:FindFirstChild(`Trap{spot}`) :: Part
		local kind: string? = nil
		if d then
			for _, trap in d.traps do
				if trap.spot == spot then
					kind = trap.kind
				end
			end
		end
		-- Every trap spot looks the same to raiders. Only the owner's client
		-- colors and labels its own traps (BaseView), from this attribute.
		p:SetAttribute("Kind", kind)
	end

	local decoys = model:FindFirstChild("Decoys") :: Folder
	for spot = 1, #Geometry.DECOY_SPOTS do
		local p = decoys:FindFirstChild(`Decoy{spot}`) :: Part
		local placed = false
		if d then
			for _, decoy in d.decoys do
				if decoy.spot == spot then
					placed = true
				end
			end
		end
		p:SetAttribute("Placed", placed)
		local shown = p:FindFirstChild("Creature")
		if placed and shown == nil and config then
			local species = config.creatures.species[DECOY_LOOK]
			local size = Layout.raritySize(species.rarity)
			local body = part({
				Name = "Creature",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size, size, size),
				CFrame = CFrame.new(p.Position + Vector3.new(0, size / 2 + 0.2, 0)) * p.CFrame.Rotation,
				Color = Layout.rarityColor(species.rarity),
				Transparency = 1,
				CanCollide = false,
			})
			body:SetAttribute("CreatureLook", DECOY_LOOK)
			billboard(
				body,
				Vector3.new(0, size / 2 + 1.5, 0),
				UDim2.fromScale(5, 1.5),
				`{Layout.displayName(DECOY_LOOK)}\n{Layout.shortNumber(species.coinsPerSecond)}/s`
			)
			body.Parent = p
		elseif not placed and shown then
			shown:Destroy()
		end
	end

	local shieldUntil = if d then d.shieldUntil else 0
	local pylon = model:FindFirstChild("ShieldPylon") :: Part
	pylon:SetAttribute("ShieldUntil", shieldUntil)
	pylon:SetAttribute("ReadyAt", if d then d.shieldReadyAt else 0)
	local dome = model:FindFirstChild("ShieldDome") :: Part
	dome.Transparency = if shieldUntil > now then 0.6 else 1
	model:SetAttribute("ShieldUntil", shieldUntil)
end

-- Draws a base from saved data (nil data = an empty base). `carried` lists
-- the uids raiders are carrying off right now.
function World.sync(
	index: number,
	d: { [string]: any }?,
	config: any?,
	slotCount: number,
	carried: { [string]: boolean }?,
	now: number?
)
	local model: Model? = plots[index]
	if model == nil then
		return
	end
	syncIncubators(model, d, config, slotCount)
	syncTower(model, d, config)
	syncPads(model, d, config, carried or {})
	syncDefenses(model, d, config, now or os.time())
	local rebirth = model:FindFirstChild("RebirthStand") :: Part
	if d and config then
		local cost = Creatures.rebirthCost(d.rebirths, config.economy)
		rebirth:SetAttribute("Cost", cost)
		setLabel(rebirth, `Rebirth: {Layout.shortNumber(cost)} coins`)
	else
		rebirth:SetAttribute("Cost", nil)
		setLabel(rebirth, "Rebirth")
	end
end

return World
