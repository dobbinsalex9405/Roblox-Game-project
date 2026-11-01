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
		Size = Vector3.new(Layout.PLOT_SIZE, 1, Layout.PLOT_SIZE),
		CFrame = at(Vector3.new(0, Layout.FLOOR_TOP - 0.5, 0)),
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
		billboard(p, Vector3.new(0, 4, 0), UDim2.fromOffset(120, 36), "")
		p.Parent = incubators
	end

	local pads = Instance.new("Folder")
	pads.Name = "Pads"
	pads.Parent = model
	for index_ = 1, 20 do
		local p = part({
			Name = `Pad{index_}`,
			Size = Vector3.new(6, 0.4, 6),
			CFrame = at(Layout.pad(index_)),
			Color = Color3.fromRGB(150, 140, 120),
		})
		p:SetAttribute("Pad", index_)
		p.Parent = pads
	end

	local collect = part({
		Name = "CollectPad",
		Size = Vector3.new(7, 0.4, 7),
		CFrame = at(Layout.COLLECT_PAD),
		Color = Color3.fromRGB(70, 200, 90),
		Material = Enum.Material.Neon,
	})
	billboard(collect, Vector3.new(0, 4, 0), UDim2.fromOffset(160, 40), "Collect")
	collect.Parent = model

	local rebirth = part({
		Name = "RebirthStand",
		Size = Vector3.new(4, 6, 4),
		CFrame = at(Layout.REBIRTH_STAND),
		Color = Color3.fromRGB(150, 80, 220),
		Material = Enum.Material.Neon,
	})
	billboard(rebirth, Vector3.new(0, 5, 0), UDim2.fromOffset(180, 40), "Rebirth")
	rebirth.Parent = model

	local board = part({
		Name = "OddsBoard",
		Size = Vector3.new(30, 8, 0.4),
		CFrame = at(Layout.ODDS_BOARD),
		Color = Color3.fromRGB(30, 30, 40),
	})
	board.Parent = model

	local post = part({
		Name = "Sign",
		Size = Vector3.new(1, 8, 1),
		CFrame = at(Layout.SIGN - Vector3.new(0, 4, 0)),
		Color = Color3.fromRGB(90, 70, 50),
	})
	billboard(post, Vector3.new(0, 6, 0), UDim2.fromOffset(240, 50), "Free base")
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
		billboard(p, Vector3.new(0, 3, 0), UDim2.fromOffset(120, 30), "")
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
	billboard(pylon, Vector3.new(0, 5, 0), UDim2.fromOffset(160, 36), "Shield")
	pylon.Parent = model

	local dome = part({
		Name = "ShieldDome",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(96, 96, 96),
		CFrame = at(Vector3.new(0, 0, 0)),
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
	for index = 1, 20 do
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
		if shown == nil or shown:GetAttribute("Uid") ~= c.uid then
			if shown then
				shown:Destroy()
			end
			local size = Layout.raritySize(species.rarity)
			local body = part({
				Name = "Creature",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size, size, size),
				CFrame = CFrame.new(pad.Position + Vector3.new(0, size / 2 + 0.2, 0)),
				Color = Layout.rarityColor(species.rarity),
				CanCollide = false,
			})
			body:SetAttribute("Uid", c.uid)
			local income = Hatchery.creatureIncome(c, config.creatures)
			billboard(
				body,
				Vector3.new(0, size / 2 + 1.5, 0),
				UDim2.fromOffset(140, 40),
				`{Layout.displayName(c.speciesId)}\n{Layout.shortNumber(income)}/s`
			)
			body.Parent = pad
			shown = body
		end
		-- Ridden, guarding (it patrols as its own model) or being carried off.
		(shown :: Part).Transparency = if isCarried then 1 elseif riding or guarding then 0.75 else 0
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
				CFrame = CFrame.new(p.Position + Vector3.new(0, size / 2 + 0.2, 0)),
				Color = Layout.rarityColor(species.rarity),
				CanCollide = false,
			})
			billboard(
				body,
				Vector3.new(0, size / 2 + 1.5, 0),
				UDim2.fromOffset(140, 40),
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
