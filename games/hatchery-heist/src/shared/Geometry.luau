--!strict
-- Base geometry as plain numbers, so raid rules (who is in which base, how far
-- from a pad) run in Lune tests as well as on the server. It matches
-- Layout.plotCFrame exactly: base i sits on a ring facing the yard, local -Z
-- toward the centre and local +X to the right; the server checks the two
-- agree at start-up.

local Geometry = {}

Geometry.PLOTS = 8
Geometry.RING_RADIUS = 110
Geometry.HALF_SIZE = 32 -- half of Layout.PLOT_SIZE

local function angle(index: number): number
	return (index - 1) / Geometry.PLOTS * 2 * math.pi
end

function Geometry.center(index: number): (number, number)
	local a = angle(index)
	return math.cos(a) * Geometry.RING_RADIUS, math.sin(a) * Geometry.RING_RADIUS
end

-- World x, z to base-local x, z.
function Geometry.toLocal(index: number, x: number, z: number): (number, number)
	local a = angle(index)
	local cx, cz = Geometry.center(index)
	local dx, dz = x - cx, z - cz
	return dx * math.sin(a) - dz * math.cos(a), dx * math.cos(a) + dz * math.sin(a)
end

-- Base-local x, z to world x, z.
function Geometry.toWorld(index: number, lx: number, lz: number): (number, number)
	local a = angle(index)
	local cx, cz = Geometry.center(index)
	return cx + lx * math.sin(a) + lz * math.cos(a), cz - lx * math.cos(a) + lz * math.sin(a)
end

-- Whether world x, z is on base `index` (shrunk by `margin` studs).
function Geometry.inside(index: number, x: number, z: number, margin: number?): boolean
	local lx, lz = Geometry.toLocal(index, x, z)
	local limit = Geometry.HALF_SIZE - (margin or 0)
	return math.abs(lx) <= limit and math.abs(lz) <= limit
end

-- The base world x, z is on, if any.
function Geometry.plotAt(x: number, z: number): number?
	for index = 1, Geometry.PLOTS do
		if Geometry.inside(index, x, z) then
			return index
		end
	end
	return nil
end

-- A spot just outside a base's front edge, in the yard, as world x, z.
function Geometry.outsideFront(index: number): (number, number)
	return Geometry.toWorld(index, 0, -(Geometry.HALF_SIZE + 6))
end

function Geometry.distance(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

-- Base-local positions (x, z) of things raids care about. Layout uses the
-- same numbers for the parts.
function Geometry.pad(index: number): (number, number)
	local column = (index - 1) % 5
	local row = (index - 1) // 5
	return -20 + column * 10, row * 7
end

Geometry.TRAP_SPOTS = { { -10, -22 }, { 10, -22 }, { -27, 10 }, { 17, 27 } }
Geometry.DECOY_SPOTS = { { -27, -4 }, { -27, 4 }, { -27, 22 } }
Geometry.SHIELD_PYLON = { 27, 20 }

return Geometry
