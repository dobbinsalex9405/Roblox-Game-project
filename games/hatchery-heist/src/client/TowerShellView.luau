--!strict
-- The apartment towers' outside, on this client only: each built storey's
-- shell (WorldArt TowerFloor/Back/Left/Right/Front n, made by
-- tools/art/world/tower.py) and the roof one storey above the top, drawn
-- over the server's grey-box tower, whose decks, railings, pillars and
-- plaques this client then hides (the decks still carry everyone).
--
-- Every storey is walled on all four sides. The front wall's window glass
-- is see-through, and while you are inside with the camera out in front, the
-- front walls of your storey and the one above fade so you stay in view.
--
-- A full tower is about 5,900 boxes, so only the nearest towers get a
-- shell: your own and the next nearest, up to `towers` within `drawStuds`
-- (config/atmosphere.luau `towerShells`); the rest keep the grey box. A
-- shell is built a few hundred boxes a frame, so nothing hitches.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Layout)
local Tower = require(Shared.Tower)
local TowerShell = require(Shared.TowerShell)
local VoxelProp = require(Shared.VoxelProp)

local TowerShellView = {}

type Shell = {
	plot: Model,
	floors: number, -- storeys drawn (0: none, the grey box shows)
	folder: Folder?,
	hidden: { BasePart },
	building: boolean,
	fronts: { [number]: { BasePart } }, -- each storey's front wall parts
	faded: { [number]: boolean },
}

local CHECK_SECONDS = 0.5
local DRAW_SLACK = 10 -- studs past drawStuds before a drawn shell goes

-- The server's grey-box parts a shell replaces on a built storey.
local function replaced(name: string): boolean
	return string.sub(name, 1, 4) == "Deck"
		or string.sub(name, 1, 4) == "Rail"
		or string.sub(name, 1, 6) == "Pillar"
		or name == "Plaque"
end

local function setHidden(shell: Shell, floors: number)
	for _, p in shell.hidden do
		p.LocalTransparencyModifier = 0
	end
	table.clear(shell.hidden)
	local tower = shell.plot:FindFirstChild("Tower")
	if tower == nil then
		return
	end
	for floor = 2, floors do
		local folder = tower:FindFirstChild(`Floor{floor}`)
		if folder then
			for _, p in folder:GetChildren() do
				if p:IsA("BasePart") and replaced(p.Name) then
					p.LocalTransparencyModifier = 1
					table.insert(shell.hidden, p)
				end
			end
		end
	end
end

-- Builds `floors` storeys and the roof for one plot, a slice a frame.
-- `look` is atmosphere.towerShells (paneTransparency, frontFade).
local function build(shell: Shell, floors: number, perFrame: number, look: any)
	if shell.folder then
		shell.folder:Destroy()
		shell.folder = nil
	end
	setHidden(shell, 0)
	shell.floors = floors
	shell.fronts = {}
	shell.faded = {}
	if floors == 0 then
		return
	end
	local index = shell.plot:GetAttribute("PlotIndex")
	if type(index) ~= "number" then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = `TowerShell{index}`
	folder.Parent = Workspace
	shell.folder = folder
	shell.building = true
	local base = Layout.plotCFrame(index)
	task.spawn(function()
		local made = 0
		for _, piece in TowerShell.pieces(floors) do
			local boxes = VoxelProp.boxes(piece.prop)
			if boxes == nil then
				continue
			end
			local local0 = CFrame.new(0, piece.lift, 0) * CFrame.new(-VoxelProp.anchor(piece.prop))
			local origin = base * CFrame.new(0, Layout.floorTop(piece.storey), 0) * local0
			for _, box in boxes do
				if shell.folder ~= folder then
					return -- rebuilt or dropped meanwhile
				end
				if not TowerShell.drawn(piece.storey, (local0 * box.offset).Position.Y + box.size.Y / 2) then
					continue
				end
				local p = VoxelProp.part(box, origin)
				if box.part == "pane" then
					p.Transparency = look.paneTransparency -- window glass: the room shows through
				end
				if string.sub(piece.prop, 1, 10) == "TowerFront" then
					local list = shell.fronts[piece.storey] or {}
					shell.fronts[piece.storey] = list
					table.insert(list, p)
					if shell.faded[piece.storey] then
						p.LocalTransparencyModifier = look.frontFade
					end
				end
				p.Parent = folder
				made += 1
				if made % perFrame == 0 then
					RunService.Heartbeat:Wait()
				end
			end
		end
		if shell.folder == folder then
			shell.building = false
			setHidden(shell, floors)
		end
	end)
end

function TowerShellView.start()
	local config = (require(ReplicatedStorage.GameConfig.atmosphere) :: any).towerShells
	local shells: { [Model]: Shell } = {}
	local player = Players.LocalPlayer

	task.spawn(function()
		while true do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local camera = Workspace.CurrentCamera
			local from = if root then root.Position elseif camera then camera.CFrame.Position else nil
			if from then
				-- Every plot, nearest first; your own always counts first.
				local plots: { { plot: Model, distance: number, own: boolean } } = {}
				local folder = Workspace:FindFirstChild("Plots")
				for _, child in if folder then folder:GetChildren() else {} do
					if child:IsA("Model") and type(child:GetAttribute("PlotIndex")) == "number" then
						local floor = child.PrimaryPart
						if floor then
							table.insert(plots, {
								plot = child,
								distance = (floor.Position - from).Magnitude,
								own = child:GetAttribute("OwnerUserId") == player.UserId,
							})
						end
					end
				end
				table.sort(plots, function(a, b)
					if a.own ~= b.own then
						return a.own
					end
					return a.distance < b.distance
				end)
				for rank, entry in plots do
					local shell = shells[entry.plot]
					if shell == nil then
						shell = {
							plot = entry.plot,
							floors = 0,
							folder = nil,
							hidden = {},
							building = false,
							fronts = {},
							faded = {},
						}
						shells[entry.plot] = shell
					end
					local s = shell :: Shell
					local reach = config.drawStuds + (if s.floors > 0 then DRAW_SLACK else 0)
					local near = entry.own or entry.distance <= reach
					local built = TowerShell.storeys(entry.plot:GetAttribute("TowerFloors"), Tower.FLOORS)
					local want = if near and rank <= config.towers then built else 0
					if want ~= s.floors then
						build(s, want, config.boxesPerFrame, config)
					end
				end
			end
			task.wait(CHECK_SECONDS)
		end
	end)

	-- Every frame: fade the front walls between the camera and the player
	-- inside a tower (TowerShell.fadedFronts), and bring them back after.
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local camera = Workspace.CurrentCamera
		for _, shell in shells do
			local want: { [number]: boolean } = {}
			local index = shell.plot:GetAttribute("PlotIndex")
			if root and camera and shell.floors > 0 and type(index) == "number" then
				local base = Layout.plotCFrame(index)
				local at = base:PointToObjectSpace(root.Position)
				local cam = base:PointToObjectSpace(camera.CFrame.Position)
				want = TowerShell.fadedFronts(at.X, at.Y, at.Z, cam.Z, shell.floors, Layout.floorTop)
			end
			for storey, parts in shell.fronts do
				local fade = want[storey] == true
				if fade ~= (shell.faded[storey] == true) then
					shell.faded[storey] = fade
					for _, p in parts do
						p.LocalTransparencyModifier = if fade then config.frontFade else 0
					end
				end
			end
		end
	end)
end

return TowerShellView
