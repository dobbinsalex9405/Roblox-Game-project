--!strict
-- Draws customers on this client only: the server keeps them as numbers
-- (Wave 1 plan), so the street stays light with 8 busy restaurants. Each plot
-- shows its counter queue (the owner's own from their data, other plots from
-- the server's Queue attribute) and one walk-up customer at every station
-- that has a working cook. Grey-box figures until the gate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Layout)
local Restaurant = require(Shared.Restaurant)

local Context = require(script.Parent.Context)

local CrowdView = {}

local SHIRTS = {
	Color3.fromRGB(220, 90, 90),
	Color3.fromRGB(90, 150, 230),
	Color3.fromRGB(100, 190, 120),
	Color3.fromRGB(240, 200, 90),
	Color3.fromRGB(170, 110, 210),
	Color3.fromRGB(240, 150, 80),
}

local function figure(parent: Instance, name: string, shirt: Color3): Model
	local model = Instance.new("Model")
	model.Name = name
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CastShadow = false
	body.Size = Vector3.new(1.6, 2.6, 1)
	body.Color = shirt
	body.Material = Enum.Material.SmoothPlastic
	body.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Anchored = true
	head.CanCollide = false
	head.CanQuery = false
	head.CastShadow = false
	head.Size = Vector3.new(1.3, 1.3, 1.3)
	head.Color = Color3.fromRGB(240, 200, 160)
	head.Material = Enum.Material.SmoothPlastic
	head.Parent = model
	model.PrimaryPart = body
	model.Parent = parent
	return model
end

local function place(model: Model, cframe: CFrame)
	local body = model:FindFirstChild("Body") :: Part
	local head = model:FindFirstChild("Head") :: Part
	body.CFrame = cframe
	head.CFrame = cframe * CFrame.new(0, 2, 0)
end

-- Shows exactly `count` figures named `prefix1..N` in `folder`, at `point(i)`.
local function show(folder: Folder, prefix: string, count: number, frame: CFrame, point: (number) -> Vector3)
	for i = 1, count do
		local name = `{prefix}{i}`
		local model = folder:FindFirstChild(name) :: Model?
		if model == nil then
			model = figure(folder, name, SHIRTS[(i - 1) % #SHIRTS + 1])
		end
		local at = frame * point(i)
		-- Everyone faces the plot (toward local +Z).
		place(model :: Model, CFrame.lookAt(at, at + frame.LookVector * -1))
	end
	-- Figures are always numbered 1..N, so the extras run on from count + 1.
	local extra = count + 1
	local child = folder:FindFirstChild(`{prefix}{extra}`)
	while child do
		child:Destroy()
		extra += 1
		child = folder:FindFirstChild(`{prefix}{extra}`)
	end
end

function CrowdView.start(ctx: Context.Context)
	local plots = Workspace:WaitForChild("Plots")
	local root = Instance.new("Folder")
	root.Name = "Crowd"
	root.Parent = Workspace
	local queueMax = ctx.config.economy.customers.queueMax

	task.spawn(function()
		while true do
			local now = ctx.serverNow()
			local own = ctx.plot()
			local d = ctx.data()
			for _, model in plots:GetChildren() do
				local index = model:GetAttribute("PlotIndex")
				if not model:IsA("Model") or type(index) ~= "number" then
					continue
				end
				local folder = root:FindFirstChild(model.Name) :: Folder?
				if folder == nil then
					local f = Instance.new("Folder")
					f.Name = model.Name
					f.Parent = root
					folder = f
				end
				local frame = Layout.plotCFrame(index)

				local waiting = model:GetAttribute("Queue")
				local queue = if type(waiting) == "number" then waiting else 0
				if model == own and d then
					local _, live = Restaurant.preview(d, ctx.config, ctx.perks(), now)
					queue = Restaurant.waiting(live)
				end
				show(folder :: Folder, "Queue", math.clamp(queue, 0, queueMax), frame, Layout.queuePoint)

				-- One walk-up customer at each station with a working cook.
				local spots: { number } = {}
				local tiles = model:FindFirstChild("Spots")
				if tiles then
					for _, tile in tiles:GetChildren() do
						local readyAt = tile:GetAttribute("ReadyAt")
						local level = tile:GetAttribute("Level")
						local working = type(readyAt) == "number"
							and type(level) == "number"
							and (now >= readyAt or level > 1)
						if type(tile:GetAttribute("Cook")) == "string" and working then
							table.insert(spots, tile:GetAttribute("Spot") :: number)
						end
					end
				end
				table.sort(spots)
				show(folder :: Folder, "WalkUp", #spots, frame, function(i: number): Vector3
					return Layout.walkUpPoint(spots[i])
				end)
			end
			task.wait(0.25)
		end
	end)
end

return CrowdView
