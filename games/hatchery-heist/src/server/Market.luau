--!strict
-- The Egg Market's fixed parts (Alex's plan, Nov 5): the round belt's rails
-- in the voxel style (WorldArt BeltRail sections round both lanes), the dark
-- bed under the slats, one invisible stop facing each base, where the
-- guide's arrow points, and a small odds sign beside each stop (that each
-- player's client fills with their own odds). The Golden Nest in the middle
-- stays clear.
--
-- The moving parts (slats, pedestals and eggs) are the client's
-- (ConveyorView): they follow a schedule everyone shares (shared/Conveyor),
-- so nothing about them is ever sent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Geometry = require(Shared.Geometry)
local Layout = require(Shared.Layout)
local VoxelProp = require(Shared.VoxelProp)

local Market = {}

-- Rail sections a lane needs: 15 degrees each round lane 1 (radius 22, the
-- art's own); a wider lane takes more so each section keeps its length.
local SECTION_DEGREES = 15

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function rails(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Rails"
	folder.Parent = parent
	local anchor = VoxelProp.anchor("BeltRail")
	local base = Layout.MARKET_LANES[1]
	for lane, radius in Layout.MARKET_LANES do
		local count = math.max(8, math.floor(360 / SECTION_DEGREES * radius / base + 0.5))
		local section = Instance.new("Model")
		section.Name = `Lane{lane}`
		for k = 0, count - 1 do
			local a = k / count * 2 * math.pi
			local outward = Vector3.new(math.cos(a), 0, math.sin(a))
			local at = outward * radius + Vector3.new(0, Layout.MARKET_SLAT_Y, 0)
			-- The art's +X points away from the ring's centre, Z along it.
			local frame = CFrame.fromMatrix(at, outward, Vector3.yAxis) * CFrame.new(-anchor)
			local model = VoxelProp.build("BeltRail", frame)
			if model then
				for _, p in model:GetChildren() do
					p.Parent = section
				end
				model:Destroy()
			end
		end
		section.Parent = folder
		-- The bed under the slats: a dark ring of short boards.
		local bed = Instance.new("Model")
		bed.Name = `Bed{lane}`
		local boards = math.floor(2 * math.pi * radius / 2)
		for k = 0, boards - 1 do
			local a = (k + 0.5) / boards * 2 * math.pi
			local outward = Vector3.new(math.cos(a), 0, math.sin(a))
			local at = outward * radius + Vector3.new(0, Layout.MARKET_SLAT_Y - 0.15, 0)
			part(bed, {
				Name = "Bed",
				Size = Vector3.new(Layout.MARKET_WIDTH, 0.3, 2 * math.pi * radius / boards + 0.05),
				CFrame = CFrame.fromMatrix(at, outward, Vector3.yAxis),
				Color = Color3.fromRGB(70, 52, 40),
				Material = Enum.Material.WoodPlanks,
				CanCollide = false,
				CanQuery = false,
			})
		end
		bed.Parent = folder
	end
end

-- The odds signs, one beside each stop (Geometry.MARKET_SIGN): a dark face in
-- a wooden frame on two posts. Everyone sees the title; each client draws its
-- own odds over it (Hud).
local function signs(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Signs"
	folder.Parent = parent
	local wood = Color3.fromRGB(150, 108, 68)
	local sign = Geometry.MARKET_SIGN
	local size = Vector2.new(sign.width, sign.height)
	local rim = sign.frame
	for index = 1, Layout.PLOTS do
		local frame = Layout.marketSign(index)
		local face = part(folder, {
			Name = `Sign{index}`,
			Size = Vector3.new(size.X, size.Y, 0.3),
			CFrame = frame,
			Color = Color3.fromRGB(30, 30, 40),
		})
		local back = part(parent, {
			Name = "SignFrame",
			Size = Vector3.new(size.X + 2 * rim, size.Y + 2 * rim, 0.2),
			CFrame = frame * CFrame.new(0, 0, 0.25),
			Color = wood,
			Material = Enum.Material.Wood,
		})
		-- Its back, seen from across the ring: a painted egg and the
		-- market's name on the wood, not a blank slab (Studio gate).
		local backGui = Instance.new("SurfaceGui")
		backGui.Name = "Back"
		backGui.Face = Enum.NormalId.Back
		backGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		backGui.PixelsPerStud = 30
		backGui.LightInfluence = 0.5
		local painted = Instance.new("TextLabel")
		painted.Size = UDim2.fromScale(1, 1)
		painted.BackgroundTransparency = 1
		painted.Font = Enum.Font.FredokaOne
		painted.TextScaled = true
		painted.TextColor3 = Color3.fromRGB(255, 236, 190)
		painted.TextStrokeTransparency = 0.5
		painted.Text = "🥚 EGG MARKET"
		local backPad = Instance.new("UIPadding")
		backPad.PaddingTop = UDim.new(0.22, 0)
		backPad.PaddingBottom = UDim.new(0.22, 0)
		backPad.PaddingLeft = UDim.new(0.06, 0)
		backPad.PaddingRight = UDim.new(0.06, 0)
		backPad.Parent = painted
		painted.Parent = backGui
		backGui.Parent = back
		local bottom = sign.bottom
		for _, x in { -1, 1 } do
			part(parent, {
				Name = "SignLeg",
				Size = Vector3.new(0.5, bottom + 0.4, 0.5),
				CFrame = frame
					* CFrame.new(x * (size.X / 2 - 1), -size.Y / 2 - (bottom + 0.4) / 2 + 0.4, 0.4),
				Color = wood,
				Material = Enum.Material.Wood,
			})
		end
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Title"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.LightInfluence = 0
		local heading = Instance.new("TextLabel")
		heading.Size = UDim2.fromScale(1, 1)
		heading.BackgroundTransparency = 1
		heading.Font = Enum.Font.GothamBold
		heading.TextScaled = true
		heading.TextColor3 = Color3.fromRGB(255, 210, 63)
		heading.Text = "EGG ODDS"
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.3, 0)
		pad.PaddingBottom = UDim.new(0.3, 0)
		pad.Parent = heading
		heading.Parent = gui
		gui.Parent = face
	end
end

local function stops(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Stops"
	folder.Parent = parent
	for index = 1, Layout.PLOTS do
		part(folder, {
			Name = `Stop{index}`,
			Size = Vector3.new(4, 1, 4),
			CFrame = CFrame.new(Layout.marketStop(index)),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
	end
end

function Market.build(): Model
	local model = Instance.new("Model")
	model.Name = "EggMarket"
	rails(model)
	signs(model)
	stops(model)
	model.Parent = Workspace
	return model
end

-- Where market egg `index` stands at `progress` (for the server's reach check).
function Market.eggPosition(lane: number, progress: number): Vector3
	return Layout.marketFrame(lane, progress).Position
end

return Market
