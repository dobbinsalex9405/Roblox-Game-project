--!strict
-- Where things are, in studs, shared by the server, the client and the tests.
-- The mine shaft is centered on the world origin with its top face at y = 0;
-- block (x, y, z) has x across, z along and y = depth row (1 = top row).
-- The surface camp surrounds the shaft at ground level (y = 0).

export type Point = { x: number, y: number, z: number }

local Layout = {}

-- Camp spots, relative to the shaft's south edge (-z).
Layout.CAMP_GAP = 26 -- studs from the shaft edge to the spawn
Layout.GROUND_SIZE = 260 -- camp ground square, studs

-- Center of block (x, y, z), in studs.
function Layout.blockCenter(mine: any, x: number, y: number, z: number): Point
	local b = mine.blockSize
	return {
		x = (x - (mine.width + 1) / 2) * b,
		y = -(y - 0.5) * b,
		z = (z - (mine.length + 1) / 2) * b,
	}
end

-- Half the shaft's width and length, in studs.
function Layout.halfSize(mine: any): (number, number)
	return mine.width * mine.blockSize / 2, mine.length * mine.blockSize / 2
end

-- Is a position over (or in) the shaft, seen from above?
function Layout.inFootprint(mine: any, p: Point): boolean
	local hx, hz = Layout.halfSize(mine)
	return math.abs(p.x) <= hx and math.abs(p.z) <= hz
end

-- Depth row at a height: 0 on or above the shaft's top face, 1 for the top
-- row of blocks, and so on. A player's root sits about 3 studs above their
-- feet, so a player standing on row 1's blocks reads as row 0.
function Layout.rowAt(mine: any, y: number): number
	if y >= 0 then
		return 0
	end
	return math.floor(-y / mine.blockSize) + 1
end

function Layout.totalRows(mine: any): number
	local rows = 0
	for _, layer in mine.layers do
		rows += layer.rows
	end
	return rows
end

-- Which layer (1, 2, ...) a row belongs to. Row 0 (the top face) counts as layer 1.
function Layout.layerOf(mine: any, row: number): number
	local bottom = 0
	for index, layer in mine.layers do
		bottom += layer.rows
		if row <= bottom then
			return index
		end
	end
	return #mine.layers
end

-- The first row of a layer.
function Layout.layerTop(mine: any, layerIndex: number): number
	local top = 1
	for index = 1, layerIndex - 1 do
		top += mine.layers[index].rows
	end
	return top
end

function Layout.distance(a: Point, b: Point): number
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Camp spawn, south of the shaft, standing height.
function Layout.campSpawn(mine: any): Point
	local _, hz = Layout.halfSize(mine)
	return { x = 0, y = 0, z = -(hz + Layout.CAMP_GAP) }
end

-- Camp stations, relative to the spawn.
function Layout.station(mine: any, name: string): Point
	local spawn = Layout.campSpawn(mine)
	local offsets: { [string]: Point } = {
		SellPad = { x = -18, y = 0, z = -6 },
		Pick = { x = 12, y = 0, z = -14 },
		Pack = { x = 20, y = 0, z = -6 },
		Lamp = { x = 28, y = 0, z = 2 },
		Guide = { x = -6, y = 0, z = -22 },
	}
	local o = offsets[name]
	assert(o, `unknown station {name}`)
	return { x = spawn.x + o.x, y = spawn.y + o.y, z = spawn.z + o.z }
end

function Layout.displayName(id: string): string
	return (string.gsub(id, "(%l)(%u)", "%1 %2"))
end

function Layout.shortNumber(n: number): string
	local units: { { size: number, suffix: string } } = {
		{ size = 1e12, suffix = "T" },
		{ size = 1e9, suffix = "B" },
		{ size = 1e6, suffix = "M" },
		{ size = 1e3, suffix = "K" },
	}
	for _, unit in units do
		if math.abs(n) >= unit.size then
			return string.format("%.2f%s", n / unit.size, unit.suffix)
		end
	end
	return tostring(math.floor(n))
end

return Layout
