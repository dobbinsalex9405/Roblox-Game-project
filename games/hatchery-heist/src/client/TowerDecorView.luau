--!strict
-- Furnishes the towers: each floor shows the decor of the upgrades its owner
-- bought (config/towerDecor.luau, built from shared/WorldArt boxes by
-- shared/VoxelProp). The server only says how far each tower got (plot
-- attributes TowerFloors and TowerUpgrades, server/World syncTower); this
-- client builds the rooms itself, so the server and other players carry
-- none of it.
--
-- A fully furnished floor is about 1,500 boxes, so only the floors nearest
-- the camera are furnished (at most MAX_FLOORS, built a few hundred boxes a
-- frame), and a floor's decor goes again once the camera is far away. When
-- an owner buys an upgrade while the floor is furnished, the new pieces grow
-- in with a sparkle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Layout)
local TowerDecor = require(Shared.TowerDecor)
local VoxelProp = require(Shared.VoxelProp)
local WorldArt = require(Shared.WorldArt)

local Sfx = require(script.Parent.Sfx)

local TowerDecorView = {}

local MAX_FLOORS = 6 -- floors furnished at once, nearest the camera first
local NEAR, FAR = 80, 100 -- studs from the camera to a floor's middle: furnish, unfurnish
local BOXES_PER_FRAME = 400
local CHECK_EVERY = 0.25 -- seconds
local GROW_TIME = 0.45
local LIGHT_COLOR = Color3.fromRGB(255, 214, 160)

type Group = { model: Model, boxes: number }

local function plotOf(model: Instance): (number?, number, { number })
	local index = model:GetAttribute("PlotIndex")
	local floors = model:GetAttribute("TowerFloors")
	if type(index) ~= "number" or type(floors) ~= "number" or floors < 1 then
		return nil, 0, {}
	end
	return index, floors, TowerDecor.parseUpgrades(model:GetAttribute("TowerUpgrades"))
end

-- A floor's middle in the world, for distances.
local function floorCentre(index: number, floor: number): Vector3
	return (Layout.plotCFrame(index) * CFrame.new(0, Layout.floorTop(floor) + 4, 10)).Position
end

-- Ceiling lights light the room: a warm point light in the first glowing box.
local function addLight(model: Model)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p.Material == Enum.Material.Neon then
			local light = Instance.new("PointLight")
			light.Color = LIGHT_COLOR
			light.Range = 16
			light.Brightness = 0.9
			light.Shadows = false
			light.Parent = p
			return
		end
	end
end

local function build(config: TowerDecor.Config, index: number, floor: number, group: number): Group
	local model = Instance.new("Model")
	model.Name = `Floor{floor}Upgrade{group}`
	local frame = Layout.plotCFrame(index)
	local top = Layout.floorTop(floor)
	local boxes = 0
	local entry = config.floors[floor]
	for _, item in entry.upgrades[group] do
		local x, y, z, yaw = TowerDecor.place(item, top)
		local origin = frame * CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
		local prop = VoxelProp.build(item.prop, origin, item.scale)
		if prop then
			prop.WorldPivot = origin
			local art = WorldArt.props[item.prop]
			if art and art.zone == "ceiling" then
				addLight(prop)
			end
			boxes += #prop:GetChildren()
			prop.Parent = model
		end
	end
	return { model = model, boxes = boxes }
end

-- The new pieces of an upgrade grow from small, each about its own base,
-- with a burst of sparkles over the room.
local function grow(model: Model, at: Vector3)
	local props = {}
	for _, prop in model:GetChildren() do
		if prop:IsA("Model") and pcall(function()
			prop:ScaleTo(0.05)
		end) then
			table.insert(props, prop)
		end
	end
	local start = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - start) / GROW_TIME, 0, 1)
		-- ease out with a little overshoot: 0 -> 1.08 -> 1
		local s = if t >= 1 then 1 else math.max(1 + 2.2 * (t - 1) ^ 3 + 1.2 * (t - 1) ^ 2, 0.05)
		for _, prop in props do
			if prop.Parent then
				pcall(function()
					prop:ScaleTo(s)
				end)
			end
		end
		if t >= 1 and connection then
			connection:Disconnect()
		end
	end)
	local spark = Instance.new("Part")
	spark.Name = "UpgradeSparkle"
	spark.Anchored = true
	spark.CanCollide = false
	spark.CanQuery = false
	spark.CanTouch = false
	spark.Transparency = 1
	spark.Size = Vector3.new(40, 1, 20)
	spark.CFrame = CFrame.new(at)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 230, 140), Color3.fromRGB(255, 255, 255))
	emitter.Size = NumberSequence.new(0.8, 0)
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(4, 9)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.LightEmission = 1
	emitter.Enabled = false
	emitter.Parent = spark
	spark.Parent = model.Parent
	emitter:Emit(60)
	task.delay(2, function()
		spark:Destroy()
	end)
end

-- Grey pads hide under the beds once a floor has them (upgrade 1).
local function padsHidden(plot: Model, floor: number, hidden: boolean)
	local pads = plot:FindFirstChild("Pads")
	if pads == nil then
		return
	end
	for _, pad in pads:GetChildren() do
		if pad:IsA("BasePart") and pad:GetAttribute("Floor") == floor then
			pad.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

function TowerDecorView.start(config: TowerDecor.Config?)
	local decor: TowerDecor.Config = config or require(ReplicatedStorage.GameConfig.towerDecor) :: any
	local plots = Workspace:WaitForChild("Plots")
	local folder = Instance.new("Folder")
	folder.Name = "TowerDecor"
	folder.Parent = Workspace

	local built: { [string]: Group } = {} -- "plot:floor:group" -> its model
	local shown: { [string]: boolean } = {} -- "plot:floor" furnished now
	local seen: { [string]: number } = {} -- "plot:floor" -> upgrades last seen
	local queue: { { key: string, index: number, floor: number, group: number, grow: boolean } } = {}
	local queued: { [string]: boolean } = {}
	local plotModels: { [number]: Model } = {}

	local function drop(key: string)
		local g = built[key]
		if g then
			g.model:Destroy()
			built[key] = nil
		end
	end

	local function check()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		local eye = camera.CFrame.Position
		local want: { { index: number, floor: number, upgrades: number, dist: number } } = {}
		local owners: { [string]: number } = {}
		for _, model in plots:GetChildren() do
			if not model:IsA("Model") then
				continue
			end
			local index, floors, ups = plotOf(model)
			if index == nil then
				continue
			end
			plotModels[index] = model
			for floor = 1, math.min(floors, 10) do
				local key = `{index}:{floor}`
				owners[key] = 1
				local upgrades = ups[floor] or 0
				local dist = (floorCentre(index, floor) - eye).Magnitude
				if dist < (if shown[key] then FAR else NEAR) then
					table.insert(want, { index = index, floor = floor, upgrades = upgrades, dist = dist })
				end
			end
		end
		table.sort(want, function(a, b)
			return a.dist < b.dist
		end)
		local keep: { [string]: number } = {}
		for i = 1, math.min(#want, MAX_FLOORS) do
			local w = want[i]
			keep[`{w.index}:{w.floor}`] = w.upgrades
		end
		-- unfurnish what is no longer kept, or no longer owned
		for key in built do
			local index, floor, group = string.match(key, "^(%d+):(%d+):(%d+)$")
			local fk = `{index}:{floor}`
			local upgrades = keep[fk]
			local groupN = tonumber(group) :: number
			if upgrades == nil or (groupN > 0 and groupN > upgrades) then
				drop(key)
				if groupN == 1 then
					local plot = plotModels[tonumber(index) :: number]
					if plot then
						padsHidden(plot, tonumber(floor) :: number, false)
					end
				end
			end
		end
		for fk in shown do
			if keep[fk] == nil then
				shown[fk] = nil
			end
		end
		-- furnish what is kept
		for fk, upgrades in keep do
			local index, floor = string.match(fk, "^(%d+):(%d+)$")
			local i, f = tonumber(index) :: number, tonumber(floor) :: number
			local before = seen[fk]
			for _, group in TowerDecor.groups(decor, f, upgrades) do
				local key = `{fk}:{group}`
				if built[key] == nil and not queued[key] then
					queued[key] = true
					table.insert(queue, {
						key = key,
						index = i,
						floor = f,
						group = group,
						grow = shown[fk] == true and before ~= nil and group > before,
					})
				end
			end
			shown[fk] = true
		end
		-- remember every floor's upgrades, furnished or not, so a later
		-- purchase is noticed; forget bases that changed hands
		for _, model in plots:GetChildren() do
			local index, floors, ups = plotOf(model)
			if index then
				for floor = 1, math.min(floors, 10) do
					seen[`{index}:{floor}`] = ups[floor] or 0
				end
			end
		end
		for fk in seen do
			if owners[fk] == nil then
				seen[fk] = nil
			end
		end
	end

	local function work()
		local budget = BOXES_PER_FRAME
		while budget > 0 and #queue > 0 do
			local job = table.remove(queue, 1) :: any
			queued[job.key] = nil
			local fk = `{job.index}:{job.floor}`
			if not shown[fk] or built[job.key] then
				continue
			end
			local g = build(decor, job.index, job.floor, job.group)
			g.model.Parent = folder
			built[job.key] = g
			budget -= math.max(g.boxes, 1)
			if job.group == 1 then
				local plot = plotModels[job.index]
				if plot then
					padsHidden(plot, job.floor, true)
				end
			end
			if job.grow then
				grow(g.model, floorCentre(job.index, job.floor) - Vector3.new(0, 4, 0))
				local plot = plotModels[job.index]
				local me = game:GetService("Players").LocalPlayer
				if plot and me and plot:GetAttribute("OwnerUserId") == me.UserId then
					Sfx.play("reward", 1.15)
				end
			end
		end
	end

	local last = -math.huge
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - last >= CHECK_EVERY then
			last = now
			check()
		end
		if #queue > 0 then
			work()
		end
	end)
	return {
		-- for tests and the Studio panel: how many groups are furnished now
		count = function(): number
			local n = 0
			for _ in built do
				n += 1
			end
			return n
		end,
		check = check,
		work = work,
	}
end

return TowerDecorView
