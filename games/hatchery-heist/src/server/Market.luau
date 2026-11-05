--!strict
-- The Egg Market's fixed parts (Alex's plan, Nov 5): the round belt's rails
-- in the voxel style (WorldArt BeltRail sections round both lanes), the dark
-- bed under the slats, the odds boards round the Golden Nest (one per egg,
-- that each player's client fills with their own odds) and one invisible
-- stop facing each base, where the guide's arrow points.
--
-- The moving parts (slats, pedestals and eggs) are the client's
-- (ConveyorView): they follow a schedule everyone shares (shared/Conveyor),
-- so nothing about them is ever sent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Layout)
local VoxelProp = require(Shared.VoxelProp)
local economy = require(ReplicatedStorage.GameConfig.economy) :: any

local Market = {}

-- Rail sections a lane needs: 15 degrees each round lane 1 (radius 22, the
-- art's own); a wider lane takes more so each section keeps its length.
local SECTION_DEGREES = 15
-- Readable from the walk path (about 34 studs) on a phone: one egg a board,
-- its tiers in two columns of 1.3-stud lines, top at 8 studs so the HUD at
-- the top of a phone screen does not cover it (Studio gates).
local BOARD_SIZE = Vector2.new(26, 7)
local BOARD_BOTTOM = 1 -- studs above the ground, on two legs
local BOARD_RADIUS = 15 -- from the centre: clear of the nest, corners inside the lanes

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

-- The odds boards: one per egg, standing round the Golden Nest at eye level
-- and facing out, each a wide board with its tiers in two columns. On a
-- phone the HUD covers whatever stands 8 to 15 studs up from the walk path,
-- so the boards stay below that (Studio gates). Everyone sees the title;
-- each client draws its own odds over it (Hud).
local function boards(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Boards"
	folder.Parent = parent
	local wood = Color3.fromRGB(120, 85, 55)
	local count = 0
	for _ in economy.conveyor.weights do
		count += 1
	end
	local centreY = BOARD_BOTTOM + BOARD_SIZE.Y / 2
	for side = 1, count do
		-- Turned so no board stands across base 1's path (angle 0).
		local yaw = (side - 0.5) / count * 2 * math.pi
		local frame = CFrame.Angles(0, yaw, 0) * CFrame.new(0, centreY, -BOARD_RADIUS)
		-- The board's front (-Z) faces outward, away from the nest.
		local board = part(folder, {
			Name = `Board{side}`,
			Size = Vector3.new(BOARD_SIZE.X, BOARD_SIZE.Y, 0.3),
			CFrame = frame,
			Color = Color3.fromRGB(30, 30, 40),
		})
		part(parent, {
			Name = "BoardFrame",
			Size = Vector3.new(BOARD_SIZE.X + 0.6, BOARD_SIZE.Y + 0.6, 0.2),
			CFrame = frame * CFrame.new(0, 0, 0.25),
			Color = wood,
			Material = Enum.Material.Wood,
		})
		for _, x in { -1, 1 } do
			part(parent, {
				Name = "BoardLeg",
				Size = Vector3.new(0.6, BOARD_BOTTOM + 0.3, 0.6),
				CFrame = frame
					* CFrame.new(x * (BOARD_SIZE.X / 2 - 1), -BOARD_SIZE.Y / 2 - BOARD_BOTTOM / 2 + 0.15, 0.4),
				Color = wood,
				Material = Enum.Material.Wood,
			})
		end
		local face = Instance.new("SurfaceGui")
		face.Name = "Title"
		face.Face = Enum.NormalId.Front
		face.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		face.PixelsPerStud = 50
		face.LightInfluence = 0
		local heading = Instance.new("TextLabel")
		heading.Size = UDim2.fromScale(1, 1)
		heading.BackgroundTransparency = 1
		heading.Font = Enum.Font.GothamBold
		heading.TextScaled = true
		heading.TextColor3 = Color3.fromRGB(255, 210, 63)
		heading.Text = "🥚 EGG MARKET 🥚"
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.3, 0)
		pad.PaddingBottom = UDim.new(0.3, 0)
		pad.Parent = heading
		heading.Parent = face
		face.Parent = board
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
	boards(model)
	stops(model)
	model.Parent = Workspace
	return model
end

-- Where market egg `index` stands at `progress` (for the server's reach check).
function Market.eggPosition(lane: number, progress: number): Vector3
	return Layout.marketFrame(lane, progress).Position
end

return Market
