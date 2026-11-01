--!strict
-- The grey-box map, built from code: one street with 8 restaurant plots, four
-- on each side. Each plot has a counter (customers queue in front of it), a
-- register, 12 station spots in three district zones, gates for the locked
-- districts, a rebirth stand and a sign with the owner's name.
--
-- The server owns what everyone sees (stations, cooks, locked zones, the
-- owner's name, how many customers are waiting). It writes state as
-- attributes; clients add the prompts, labels, countdowns and customer
-- figures. Nothing here decides gameplay: it only draws saved data.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Layout)
local Restaurant = require(Shared.Restaurant)

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

local function setLabel(p: Instance, text: string)
	local gui = p:FindFirstChild("Label")
	local label = gui and gui:FindFirstChild("Text")
	if label and (label :: TextLabel).Text ~= text then
		(label :: TextLabel).Text = text
	end
end

local function buildPlot(index: number): Model
	local frame = Layout.plotCFrame(index)
	local model = Instance.new("Model")
	model.Name = `Plot{index}`
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("Queue", 0)
	model:SetAttribute("Districts", 0)

	local function at(local_: Vector3): CFrame
		return frame * CFrame.new(local_)
	end

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = model
	for district = 1, Layout.ZONES do
		local center = Layout.zoneCenter(district)
		local zone = part({
			Name = `Zone{district}`,
			Size = Vector3.new(Layout.PLOT_WIDTH, 1, Layout.ZONE_DEPTH),
			CFrame = at(Vector3.new(0, Layout.FLOOR_TOP - 0.5, center.Z)),
			Color = Layout.districtColor(district),
			Material = Enum.Material.Concrete,
		})
		zone:SetAttribute("District", district)
		zone.Parent = zones
		if district == 1 then
			model.PrimaryPart = zone
		end
	end

	local counter = part({
		Name = "Counter",
		Size = Layout.COUNTER_SIZE,
		CFrame = at(Layout.COUNTER),
		Color = Color3.fromRGB(230, 225, 210),
		Material = Enum.Material.Wood,
	})
	billboard(counter, Vector3.new(0, 4, 0), UDim2.fromOffset(220, 44), "Counter")
	counter.Parent = model

	local register = part({
		Name = "Register",
		Size = Vector3.new(6, 0.4, 6),
		CFrame = at(Layout.REGISTER),
		Color = Color3.fromRGB(70, 200, 90),
		Material = Enum.Material.Neon,
	})
	billboard(register, Vector3.new(0, 4, 0), UDim2.fromOffset(160, 40), "Register")
	register.Parent = model

	local spots = Instance.new("Folder")
	spots.Name = "Spots"
	spots.Parent = model
	for spot = 1, Layout.ZONES * Layout.SPOTS_PER_ZONE do
		local tile = part({
			Name = `Spot{spot}`,
			Size = Vector3.new(10, 0.4, 7),
			CFrame = at(Layout.spot(spot)),
			Color = Color3.fromRGB(235, 235, 235),
			Transparency = 0.5,
		})
		tile:SetAttribute("Spot", spot)
		tile:SetAttribute("District", (spot - 1) // Layout.SPOTS_PER_ZONE + 1)
		tile:SetAttribute("State", "Locked")
		tile.Parent = spots
	end

	local gates = Instance.new("Folder")
	gates.Name = "Gates"
	gates.Parent = model
	for district = 2, Layout.ZONES do
		local z = -Layout.PLOT_DEPTH / 2 + Layout.ZONE_DEPTH * (district - 1)
		local gate = part({
			Name = `Gate{district}`,
			Size = Vector3.new(Layout.PLOT_WIDTH, 7, 1),
			CFrame = at(Vector3.new(0, Layout.FLOOR_TOP + 3.5, z)),
			Color = Color3.fromRGB(240, 200, 60),
			Material = Enum.Material.ForceField,
			Transparency = 0.3,
		})
		gate:SetAttribute("District", district)
		gate:SetAttribute("Unlocked", false)
		billboard(gate, Vector3.new(0, 5, 0), UDim2.fromOffset(260, 50), "")
		gate.Parent = gates
	end

	local rebirth = part({
		Name = "RebirthStand",
		Size = Vector3.new(4, 6, 4),
		CFrame = at(Layout.REBIRTH_STAND),
		Color = Color3.fromRGB(150, 80, 220),
		Material = Enum.Material.Neon,
	})
	billboard(rebirth, Vector3.new(0, 5, 0), UDim2.fromOffset(200, 44), "Rebirth")
	rebirth.Parent = model

	local post = part({
		Name = "Sign",
		Size = Vector3.new(1, 8, 1),
		CFrame = at(Layout.SIGN - Vector3.new(0, 4, 0)),
		Color = Color3.fromRGB(90, 70, 50),
	})
	billboard(post, Vector3.new(0, 6, 0), UDim2.fromOffset(260, 50), "Empty lot")
	post.Parent = model

	model.Parent = plotsFolder
	return model
end

function World.build()
	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = Workspace

	local length = Layout.PLOTS_PER_SIDE * Layout.PLOT_SPACING + 40
	local street = part({
		Name = "Street",
		Size = Vector3.new(length, 1, Layout.STREET_WIDTH),
		CFrame = CFrame.new(0, 0.05, 0),
		Color = Color3.fromRGB(55, 55, 60),
		Material = Enum.Material.Asphalt,
	})
	street.Parent = Workspace
	local line = part({
		Name = "CentreLine",
		Size = Vector3.new(length, 0.1, 0.4),
		CFrame = CFrame.new(0, 0.6, 0),
		Color = Color3.fromRGB(240, 210, 80),
		CanCollide = false,
	})
	line.Parent = street

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

local function setSign(model: Model, text: string)
	setLabel(model:FindFirstChild("Sign") :: Part, text)
end

-- Gives the player the first free plot. Returns its index, or nil when every
-- plot is taken (more players than plots: the server's max players is wrong).
function World.claim(player: Player): number?
	local existing = World.plotOf(player)
	if existing then
		return existing
	end
	for index = 1, Layout.PLOTS do
		if owners[index] == nil then
			owners[index] = player
			plots[index]:SetAttribute("OwnerUserId", player.UserId)
			setSign(plots[index], `{player.DisplayName}'s Street Food`)
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
	setSign(model, "Empty lot")
	World.sync(index, nil, nil)
end

function World.spawnCFrame(index: number): CFrame
	return Layout.plotCFrame(index) * CFrame.new(Layout.SPAWN)
end

-- Puts the player's character at their plot.
function World.sendHome(player: Player)
	local index = World.plotOf(player)
	local character = player.Character
	if index and character then
		character:PivotTo(World.spawnCFrame(index))
	end
end

local function syncStation(tile: Part, station: Restaurant.Station?, cook: Restaurant.Cook?)
	local shown = tile:FindFirstChild("Station") :: Part?
	if station == nil then
		if shown then
			shown:Destroy()
		end
		return
	end
	if shown == nil or shown:GetAttribute("StationId") ~= station.stationId then
		if shown then
			shown:Destroy()
		end
		local body = part({
			Name = "Station",
			Size = Vector3.new(9, 5, 5),
			CFrame = tile.CFrame * CFrame.new(0, 2.7, 0),
			Color = Layout.stationColor(station.stationId),
			CanCollide = true,
		})
		body:SetAttribute("StationId", station.stationId)
		billboard(
			body,
			Vector3.new(0, 5, 0),
			UDim2.fromOffset(200, 56),
			Layout.displayName(station.stationId)
		)
		body.Parent = tile
		shown = body
	end
	local body = shown :: Part
	local figure = body:FindFirstChild("Cook") :: Part?
	if cook == nil then
		if figure then
			figure:Destroy()
		end
	else
		if figure == nil then
			local f = part({
				Name = "Cook",
				Size = Vector3.new(1.6, 3.6, 1.2),
				CFrame = body.CFrame * CFrame.new(0, 0.3, 3.3),
				CanCollide = false,
			})
			f.Parent = body
			figure = f
		end
		(figure :: Part).Color = Layout.cookColor(cook.tier)
	end
end

-- Draws a plot from saved data (nil data = an empty lot).
function World.sync(index: number, d: Restaurant.Data?, config: Restaurant.Config?)
	local model: Model? = plots[index]
	if model == nil then
		return
	end
	local districts = if d then d.districts else 0
	model:SetAttribute("Districts", districts)
	model:SetAttribute("Queue", if d and config then Restaurant.waiting(d.queue) else 0)

	for _, zone in (model:FindFirstChild("Zones") :: Folder):GetChildren() do
		local district = zone:GetAttribute("District") :: number
		local open = district <= districts
		local p = zone :: Part
		p.Transparency = if open then 0 else 0.35
		p.Material = if open then Enum.Material.Concrete else Enum.Material.Slate
	end

	for _, gate in (model:FindFirstChild("Gates") :: Folder):GetChildren() do
		local district = gate:GetAttribute("District") :: number
		local unlocked = d == nil or district <= districts
		local p = gate :: Part
		local nextUp = d ~= nil and config ~= nil and district == districts + 1
		p:SetAttribute("Unlocked", unlocked)
		p:SetAttribute("Next", nextUp)
		p:SetAttribute(
			"Cost",
			if nextUp and d and config then Restaurant.nextDistrictCost(d, config) else nil
		)
		p.Transparency = if unlocked then 1 else 0.3
		p.CanCollide = not unlocked
		if config and not unlocked then
			local info = config.districts[district]
			local name = if info then Layout.displayName(info.id) else `District {district}`
			setLabel(p, if nextUp and info then `{name}: {Layout.cash(info.cost)}` else `{name} (locked)`)
		else
			setLabel(p, "")
		end
	end

	local spotsOpen = if d and config then Restaurant.spotCount(d.districts, config) else 0
	for _, tile in (model:FindFirstChild("Spots") :: Folder):GetChildren() do
		local p = tile :: Part
		local spot = p:GetAttribute("Spot") :: number
		local station = if d then Restaurant.stationAt(d, spot) else nil
		local cook = if d and station then Restaurant.cookAt(d, station.stationId) else nil
		local state = if station then "Built" elseif spot <= spotsOpen then "Empty" else "Locked"
		p:SetAttribute("State", state)
		p:SetAttribute("StationId", if station then station.stationId else nil)
		p:SetAttribute("Level", if station then station.level else nil)
		p:SetAttribute("ReadyAt", if station then station.readyAt else nil)
		p:SetAttribute("Cook", if cook then cook.tier else nil)
		p:SetAttribute(
			"UpgradeCost",
			if station and config then Restaurant.upgradeCost(station, config) else nil
		)
		p.Transparency = if state == "Locked" then 1 else 0.5
		syncStation(p, station, cook)
	end

	local rebirth = model:FindFirstChild("RebirthStand") :: Part
	if d and config then
		local cost = config.economy.rebirth.cost
		rebirth:SetAttribute("Cost", cost)
		rebirth:SetAttribute("Available", d.rebirths < config.economy.rebirth.maxRebirths)
		setLabel(
			rebirth,
			if d.rebirths < config.economy.rebirth.maxRebirths
				then `Rebirth: {Layout.cash(cost)}`
				else "Rebirth (done)"
		)
	else
		rebirth:SetAttribute("Cost", nil)
		rebirth:SetAttribute("Available", false)
		setLabel(rebirth, "Rebirth")
	end
end

return World
