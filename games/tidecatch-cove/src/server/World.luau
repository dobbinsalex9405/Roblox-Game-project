--!strict
-- The grey-box map, built from code: a lagoon with an island (spawn and the
-- bait shop), four fishing docks with their floats and odds boards, and 8
-- coves around it, each with its tide pools and a sign.
--
-- The server owns what everyone sees (creatures in pools, the owner's name).
-- It writes state as attributes; the owner's client adds the prompts and the
-- growth countdowns. Nothing here decides gameplay: it only draws saved data.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Catch = require(Shared.Catch)
local Cove = require(Shared.Cove)
local Creatures = require(Shared.Creatures)
local Layout = require(Shared.Layout)

local World = {}

local mapFolder: Folder
local coves: { Model } = {}
local owners: { [number]: Player? } = {}

local SAND = Color3.fromRGB(226, 205, 150)
local WOOD = Color3.fromRGB(140, 105, 70)
local WATER = Color3.fromRGB(60, 150, 210)

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
	gui.MaxDistance = 90
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

-- A flat disc: Roblox cylinders lie along X, so turn them upright.
local function disc(props: { [string]: any }, center: Vector3, radius: number, height: number): Part
	local p = part(props)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, radius * 2, radius * 2)
	p.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	return p
end

local function buildLagoon(fishing: any)
	local water = disc({
		Name = "Water",
		Color = WATER,
		Material = Enum.Material.Glass,
		Transparency = 0.45,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, Vector3.new(0, Layout.WATER_DEPTH / 2, 0), Layout.LAGOON_RADIUS, Layout.WATER_DEPTH)
	water.Parent = mapFolder

	local island = disc(
		{ Name = "Island", Color = SAND, Material = Enum.Material.Sand },
		Vector3.new(0, Layout.ISLAND_TOP / 2, 0),
		Layout.ISLAND_RADIUS,
		Layout.ISLAND_TOP
	)
	island.Parent = mapFolder

	local shop = part({
		Name = "BaitShop",
		Size = Vector3.new(10, 6, 4),
		CFrame = CFrame.new(Layout.SHOP),
		Color = Color3.fromRGB(230, 120, 60),
	})
	billboard(shop, Vector3.new(0, 5, 0), UDim2.fromOffset(220, 50), "Bait & Tackle")
	shop.Parent = mapFolder

	local docks = Instance.new("Folder")
	docks.Name = "Docks"
	docks.Parent = mapFolder
	for index, spot in fishing.spots do
		local frame = Layout.dockCFrame(index)
		local dock = part({
			Name = spot.id,
			Size = Vector3.new(Layout.DOCK_SIZE, 0.6, Layout.DOCK_SIZE),
			CFrame = frame * CFrame.new(0, -0.3, 0),
			Color = WOOD,
			Material = Enum.Material.WoodPlanks,
		})
		dock:SetAttribute("SpotId", spot.id)
		dock:SetAttribute("SpotIndex", index)
		dock:SetAttribute("MinRod", spot.minRod)
		dock:SetAttribute("LowTideOnly", spot.lowTideOnly)
		local rodName = Layout.displayName(Catch.rod(fishing, spot.minRod).id)
		local subtitle = if spot.lowTideOnly
			then "Opens at low tide"
			elseif spot.minRod > 1 then `Needs a {rodName}`
			else "Any rod"
		billboard(
			dock,
			Vector3.new(0, 7, 0),
			UDim2.fromOffset(240, 60),
			`{Layout.displayName(spot.id)}\n{subtitle}`
		)

		local float = part({
			Name = "Float",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.2, 1.2, 1.2),
			CFrame = CFrame.new(Layout.floatPosition(index)),
			Color = Color3.fromRGB(240, 60, 60),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		float.Parent = dock

		-- The odds board stands at the back of the dock, facing the player
		-- who walks on from the shore. The client fills it in.
		local board = part({
			Name = "OddsBoard",
			Size = Vector3.new(10, 7, 0.4),
			CFrame = frame * CFrame.new(0, 4.4, Layout.DOCK_SIZE / 2) * CFrame.Angles(0, math.pi, 0),
			Color = Color3.fromRGB(30, 30, 40),
		})
		board.Parent = dock
		dock.Parent = docks
	end
end

local function buildCove(index: number): Model
	local frame = Layout.coveCFrame(index)
	local model = Instance.new("Model")
	model.Name = `Cove{index}`
	model:SetAttribute("CoveIndex", index)
	model:SetAttribute("OwnerUserId", 0)

	local function at(local_: Vector3): CFrame
		return frame * CFrame.new(local_)
	end

	local floor = part({
		Name = "Floor",
		Size = Vector3.new(Layout.COVE_SIZE, 1, Layout.COVE_SIZE),
		CFrame = at(Vector3.new(0, Layout.COVE_FLOOR_TOP - 0.5, 0)),
		Color = SAND,
		Material = Enum.Material.Sand,
	})
	floor.Parent = model
	model.PrimaryPart = floor

	local pools = Instance.new("Folder")
	pools.Name = "Pools"
	pools.Parent = model
	for slot = 1, Layout.POOL_POSITIONS do
		local center = (frame * CFrame.new(Layout.pool(slot))).Position
		local rim = disc({
			Name = `Pool{slot}`,
			Color = Color3.fromRGB(120, 120, 125),
			Material = Enum.Material.Slate,
		}, center + Vector3.new(0, 0.2, 0), Layout.POOL_RADIUS + 0.6, 0.6)
		rim:SetAttribute("Slot", slot)
		rim:SetAttribute("State", "Locked")
		local water = disc({
			Name = "Water",
			Color = WATER,
			Material = Enum.Material.Glass,
			Transparency = 0.3,
			CanCollide = false,
		}, center + Vector3.new(0, 0.55, 0), Layout.POOL_RADIUS, 0.1)
		water.Parent = rim
		billboard(rim, Vector3.new(0, 4.5, 0), UDim2.fromOffset(150, 46), "")
		rim.Parent = pools
	end

	local post = part({
		Name = "Sign",
		Size = Vector3.new(1, 8, 1),
		CFrame = at(Layout.SIGN - Vector3.new(0, 4, 0)),
		Color = WOOD,
	})
	billboard(post, Vector3.new(0, 6, 0), UDim2.fromOffset(240, 50), "Free cove")
	post.Parent = model

	model.Parent = mapFolder
	return model
end

function World.build(fishing: any)
	mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	mapFolder.Parent = Workspace
	buildLagoon(fishing)
	local covesFolder = Instance.new("Folder")
	covesFolder.Name = "Coves"
	covesFolder.Parent = mapFolder
	for index = 1, Layout.COVES do
		coves[index] = buildCove(index)
		coves[index].Parent = covesFolder
	end
end

function World.coveOf(player: Player): number?
	for index, owner in owners do
		if owner == player then
			return index
		end
	end
	return nil
end

local function setLabel(p: Instance, text: string)
	local gui = p:FindFirstChild("Label")
	local label = gui and gui:FindFirstChild("Text")
	if label and (label :: TextLabel).Text ~= text then
		(label :: TextLabel).Text = text
	end
end

-- Gives the player the first free cove. Returns its index, or nil when every
-- cove is taken (more players than coves: the server's max players is wrong).
function World.claim(player: Player): number?
	local existing = World.coveOf(player)
	if existing then
		return existing
	end
	for index = 1, Layout.COVES do
		if owners[index] == nil then
			owners[index] = player
			coves[index]:SetAttribute("OwnerUserId", player.UserId)
			setLabel(coves[index]:FindFirstChild("Sign") :: Part, `{player.DisplayName}'s Cove`)
			return index
		end
	end
	return nil
end

function World.release(player: Player)
	local index = World.coveOf(player)
	if index == nil then
		return
	end
	owners[index] = nil
	local model = coves[index]
	model:SetAttribute("OwnerUserId", 0)
	setLabel(model:FindFirstChild("Sign") :: Part, "Free cove")
	World.sync(index, nil, nil, 0, 0)
end

-- Puts the player's character at their cove.
function World.sendHome(player: Player)
	local index = World.coveOf(player)
	local character = player.Character
	if index and character then
		character:PivotTo(Layout.coveCFrame(index) * CFrame.new(Layout.SPAWN))
	end
end

-- Whether the player stands close enough to a spot's dock to cast.
function World.canReach(player: Player, spotIndex: number, reach: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return false
	end
	return Layout.flatDistance(root.Position, Layout.dockPosition(spotIndex)) <= reach
end

-- Draws a cove's pools from saved data (nil data = an empty cove).
function World.sync(
	index: number,
	d: { [string]: any }?,
	config: Cove.Config?,
	poolCount: number,
	now: number
)
	local model: Model? = coves[index]
	if model == nil then
		return
	end
	local folder = model:FindFirstChild("Pools") :: Folder
	local nextCost = if d and config then Cove.nextPoolCost(d, config.pools) else nil
	for slot = 1, Layout.POOL_POSITIONS do
		local rim = folder:FindFirstChild(`Pool{slot}`) :: Part
		local pooled = if d then Cove.poolAt(d, slot) else nil
		local state = "Locked"
		if pooled then
			state = "Full"
		elseif slot <= poolCount then
			state = "Empty"
		elseif slot == poolCount + 1 and nextCost then
			state = "Buyable"
		end
		rim:SetAttribute("State", state)
		rim:SetAttribute("Cost", if state == "Buyable" then nextCost else nil)
		rim.Transparency = if state == "Locked" then 0.7 else 0
		rim.Color = if state == "Buyable" then Color3.fromRGB(200, 170, 60) else Color3.fromRGB(120, 120, 125)
		local water = rim:FindFirstChild("Water") :: Part
		water.Transparency = if state == "Locked" or state == "Buyable" then 1 else 0.3

		local shown = rim:FindFirstChild("Creature") :: Part?
		if pooled == nil or config == nil then
			if shown then
				shown:Destroy()
			end
			for _, key in { "Uid", "SpeciesId", "Kg", "Mutation", "PlacedAt", "Fed", "LastFedAt" } do
				rim:SetAttribute(key, nil)
			end
			if state ~= "Buyable" then
				setLabel(rim, if state == "Empty" then "Empty pool" else "")
			end
			continue
		end
		-- The owner's client computes the stage and countdown from these.
		rim:SetAttribute("Uid", pooled.uid)
		rim:SetAttribute("SpeciesId", pooled.speciesId)
		rim:SetAttribute("Kg", pooled.kg)
		rim:SetAttribute("Mutation", pooled.mutation)
		rim:SetAttribute("PlacedAt", pooled.placedAt)
		rim:SetAttribute("Fed", pooled.fed)
		rim:SetAttribute("LastFedAt", pooled.lastFedAt)

		local def = config.species.species[pooled.speciesId]
		local rarity = if def then def.rarity else "Common"
		local stage = Creatures.stage(pooled, now, config.species, config.pools)
		local size = Layout.creatureSize(rarity, stage)
		if shown == nil or shown:GetAttribute("Uid") ~= pooled.uid then
			if shown then
				shown:Destroy()
			end
			local body = part({
				Name = "Creature",
				Shape = Enum.PartType.Ball,
				Color = Layout.rarityColor(rarity),
				CanCollide = false,
				CanQuery = false,
			})
			body:SetAttribute("Uid", pooled.uid)
			body.Parent = rim
			shown = body
		end
		local body = shown :: Part
		if body:GetAttribute("Stage") ~= stage then
			body:SetAttribute("Stage", stage)
			body.Size = Vector3.new(size, size, size)
			body.CFrame = CFrame.new(rim.Position + Vector3.new(0, 0.3 + size * 0.3, 0))
		end
		body.Material = if pooled.mutation ~= "None" then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
end

return World
