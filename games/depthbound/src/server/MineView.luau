--!strict
-- Draws the mine: one anchored Part per exposed block, nothing else. A fresh
-- mine is just its top face; every break removes one Part and adds the
-- newly exposed neighbours. With StreamingEnabled, each client only receives
-- the Parts near its player, which keeps phones fast at any depth.
--
-- Parts carry X, Y, Z and Block attributes so the client knows what it is
-- aiming at. The server never trusts them back: hits are re-checked against
-- the grid.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Layout)
local MineGrid = require(Shared.MineGrid)

local MineView = {}

local folder: Folder
local parts: { [number]: BasePart } = {}
local grid: MineGrid.Grid
local blocks: { [string]: any }

local function draw(key: number)
	if parts[key] then
		parts[key]:Destroy()
	end
	local x, y, z = grid:position(key)
	local blockId = grid:blockAt(x, y, z)
	local block = blocks[blockId]
	local center = Layout.blockCenter(grid.mine, x, y, z)
	local size = grid.mine.blockSize
	local p = Instance.new("Part")
	p.Name = blockId
	p.Anchored = true
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = Vector3.new(size, size, size)
	p.CFrame = CFrame.new(center.x, center.y, center.z)
	p.Color = Color3.fromRGB(block.color[1], block.color[2], block.color[3])
	p.Material = (Enum.Material :: any)[block.material]
	p:SetAttribute("X", x)
	p:SetAttribute("Y", y)
	p:SetAttribute("Z", z)
	p:SetAttribute("Block", blockId)
	p.Parent = folder
	parts[key] = p
end

function MineView.start(g: MineGrid.Grid, blockConfig: { [string]: any })
	grid = g
	blocks = blockConfig
	folder = Instance.new("Folder")
	folder.Name = "Mine"
	for _, key in grid:exposedKeys() do
		draw(key)
	end
	folder.Parent = Workspace
end

function MineView.apply(changes: MineGrid.Changes)
	for _, key in changes.hidden do
		local p = parts[key]
		if p then
			p:Destroy()
			parts[key] = nil
		end
	end
	for _, key in changes.shown do
		draw(key)
	end
end

-- Cracks show as fading: a block at 0.75 damage is mostly see-through.
function MineView.damaged(key: number, fraction: number)
	local p = parts[key]
	if p then
		p.Transparency = math.clamp(fraction, 0, 1) * 0.6
	end
end

function MineView.count(): number
	local n = 0
	for _ in parts do
		n += 1
	end
	return n
end

return MineView
