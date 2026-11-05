--!strict
-- Builds a world prop (shared/WorldArt, made by tools/art/world) out of
-- plain anchored boxes: the server for scenery that stands still, the
-- client for things it moves itself (the Egg Market's eggs).
--
-- Each box comes back with its place relative to the prop's origin (the
-- middle of its base, front -Z), so a caller can place the whole prop with
-- one CFrame, or move many props in one workspace:BulkMoveTo.

local WorldArt = require("./WorldArt")

local VoxelProp = {}

export type Box = {
	part: string, -- the WorldArt part it belongs to
	size: Vector3,
	offset: CFrame, -- from the prop's origin
	color: Color3,
	glow: boolean,
}

local cache: { [string]: { Box } } = {}
-- More props to look up after WorldArt's (another generated module in the
-- same format, such as the shop's).
local extra: { { [string]: WorldArt.Prop } } = {}

function VoxelProp.register(props: { [string]: WorldArt.Prop })
	table.insert(extra, props)
end

local function lookup(name: string): WorldArt.Prop?
	local prop = WorldArt.props[name]
	if prop then
		return prop
	end
	for _, props in extra do
		if props[name] then
			return props[name]
		end
	end
	return nil
end

local function rgb(hex: string): (Color3, boolean)
	local r = tonumber(string.sub(hex, 1, 2), 16) or 255
	local g = tonumber(string.sub(hex, 3, 4), 16) or 255
	local b = tonumber(string.sub(hex, 5, 6), 16) or 255
	return Color3.fromRGB(r, g, b), string.sub(hex, -1) == "*"
end

-- The boxes of prop `name` at `scale` (1 = as drawn), or nil if there is no
-- such prop.
function VoxelProp.boxes(name: string, scale: number?): { Box }?
	local k = scale or 1
	local key = `{name}@{k}`
	local hit = cache[key]
	if hit then
		return hit
	end
	local prop = lookup(name)
	if prop == nil then
		return nil
	end
	local s = prop.voxel * k
	local palette: { { color: Color3, glow: boolean } } = {}
	for i, hex in prop.palette do
		local color, glow = rgb(hex)
		palette[i] = { color = color, glow = glow }
	end
	local out: { Box } = {}
	for _, part in prop.parts do
		local b = part.boxes
		for i = 1, #b, 7 do
			local entry = palette[b[i + 6]]
			table.insert(out, {
				part = part.name,
				size = Vector3.new(b[i + 3] * s, b[i + 4] * s, b[i + 5] * s),
				offset = CFrame.new(
					(b[i] + b[i + 3] / 2) * s,
					(b[i + 1] + b[i + 4] / 2) * s,
					(b[i + 2] + b[i + 5] / 2) * s
				),
				color = entry.color,
				glow = entry.glow,
			})
		end
	end
	cache[key] = out
	return out
end

-- A prop's anchor point (studs from its origin at `scale`), or its origin.
function VoxelProp.anchor(name: string, scale: number?): Vector3
	local prop = lookup(name)
	if prop == nil or prop.anchor == nil then
		return Vector3.zero
	end
	local s = prop.voxel * (scale or 1)
	local a = prop.anchor :: { number }
	return Vector3.new(a[1] * s, a[2] * s, a[3] * s)
end

-- One Part for a box, placed at `origin`.
function VoxelProp.part(box: Box, origin: CFrame): Part
	local p = Instance.new("Part")
	p.Name = box.part
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = if box.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Color = box.color
	p.Size = box.size
	p.CFrame = origin * box.offset
	return p
end

-- The whole prop as a Model at `origin`. `recolor` repaints a part's boxes
-- (the egg pedestal's "trim" in the egg's colour).
function VoxelProp.build(name: string, origin: CFrame, scale: number?, recolor: { [string]: Color3 }?): Model?
	local boxes = VoxelProp.boxes(name, scale)
	if boxes == nil then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = name
	for _, box in boxes do
		local p = VoxelProp.part(box, origin)
		if recolor and recolor[box.part] then
			p.Color = recolor[box.part]
		end
		p.Parent = model
	end
	return model
end

return VoxelProp
