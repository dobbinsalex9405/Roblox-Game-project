--!strict
-- The Egg Market's fixed parts (Alex's plan, Nov 5): the round belt's rails
-- in the voxel style (WorldArt BeltRail sections round both lanes), the dark
-- bed under the slats, the odds kiosk over the Golden Nest (four boards,
-- one per side, one egg each, that each player's client fills with their
-- own odds) and
-- one invisible stop facing each base, where the guide's arrow points.
--
-- The moving parts (slats, pedestals and eggs) are the client's
-- (ConveyorView): they follow a schedule everyone shares (shared/Conveyor),
-- so nothing about them is ever sent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Layout)
local VoxelProp = require(Shared.VoxelProp)

local Market = {}

-- Rail sections a lane needs: 15 degrees each round lane 1 (radius 22, the
-- art's own); a wider lane takes more so each section keeps its length.
local SECTION_DEGREES = 15
-- Big enough to read from the walk path (about 34 studs) on a phone: one egg
-- a board, one tier a line, each line about 1.7 studs tall (Studio gate).
local KIOSK_HEIGHT = 14.5 -- the boards' middle; their bottom clears the Golden Egg
local BOARD_SIZE = Vector2.new(16, 16)

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

-- Four boards under a roof over the Golden Nest. Everyone sees the title;
-- each client draws its own odds over it (Hud).
local function kiosk(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Boards"
	folder.Parent = parent
	local wood = Color3.fromRGB(120, 85, 55)
	local roofY = KIOSK_HEIGHT + BOARD_SIZE.Y / 2 + 0.8
	-- Four posts just outside the nest hold a roof; the boards hang under it.
	local corner = BOARD_SIZE.X / 2 + 0.6
	for _, xz in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		part(parent, {
			Name = "KioskPost",
			Size = Vector3.new(1, roofY, 1),
			CFrame = CFrame.new(xz[1] * corner, roofY / 2, xz[2] * corner),
			Color = wood,
			Material = Enum.Material.Wood,
		})
	end
	part(parent, {
		Name = "KioskRoof",
		Size = Vector3.new(BOARD_SIZE.X + 3, 0.8, BOARD_SIZE.X + 3),
		CFrame = CFrame.new(0, roofY + 0.4, 0),
		Color = Color3.fromRGB(196, 72, 60),
	})
	local half = BOARD_SIZE.X / 2 + 0.2
	for side = 0, 3 do
		local yaw = side * math.pi / 2
		local frame = CFrame.Angles(0, yaw, 0) * CFrame.new(0, KIOSK_HEIGHT, -half)
		-- The board's front (-Z) faces outward, away from the nest.
		local board = part(folder, {
			Name = `Board{side + 1}`,
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
	kiosk(model)
	stops(model)
	model.Parent = Workspace
	return model
end

-- Where market egg `index` stands at `progress` (for the server's reach check).
function Market.eggPosition(lane: number, progress: number): Vector3
	return Layout.marketFrame(lane, progress).Position
end

return Market
