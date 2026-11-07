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

-- Base-local heights: the floor's top surface, and the top of the 8-stud
-- post that carries the base's sign (Layout.SIGN).
Geometry.FLOOR_TOP = 1
Geometry.SIGN_TOP = 9

-- The tower: floor 1 is the base's ground, and each floor above stands
-- FLOOR_HEIGHT studs higher, over the back half of the base.
Geometry.FLOORS = 10
Geometry.FLOOR_HEIGHT = 12
Geometry.SPOTS_PER_FLOOR = 8 -- 4 across, 2 deep
Geometry.SPOT_COLUMNS = 4
-- The tower's footprint in base-local x, z (floors 2 and up).
Geometry.TOWER_MIN = { -24, -3 }
Geometry.TOWER_MAX = { 24, 23 }
-- The ladder (a 2-stud truss) up the right side, just outside the decks,
-- and the opening cut in every upper deck beside it, so a climber on the
-- tower side of the ladder rises through each floor and steps back onto
-- the deck there instead of hitting its underside. Base-local x, z.
Geometry.LADDER = { 25.2, 14.5 }
Geometry.LADDER_HOLE_MIN = { 21, 12.5 }
Geometry.LADDER_HOLE_MAX = { 24, 16.5 }

-- The label floating over the next floor to buy ("Floor 10: 165M coins"),
-- in studs: wide enough for the longest one at full text height, with room
-- to spare (Studio gate, #84: the text was filling its box edge to edge).
-- `above`: its centre over the deck's centre.
Geometry.FLOOR_LABEL = { width = 32, height = 2.2, above = 2 }

-- The "YOUR HATCHERY" banner over your own base sign (client/GuideView), in
-- studs; `above` is its centre over the sign post's centre. It floats clear
-- above the next-floor label behind it, so from spawn the two never read as
-- one crowded line (Studio gate, Nov 5).
Geometry.YOUR_BASE_LABEL = { width = 20, height = 4, above = 14.5 }

-- Base-local positions of things raids care about. Layout uses the same
-- numbers for the parts. Pad `index` counts across the whole tower: pads 1
-- to 8 are on floor 1, 9 to 16 on floor 2, and so on. Returns x, z and the
-- height above floor 1.
function Geometry.pad(index: number): (number, number, number)
	local floor = (index - 1) // Geometry.SPOTS_PER_FLOOR
	local spot = (index - 1) % Geometry.SPOTS_PER_FLOOR
	local column = spot % Geometry.SPOT_COLUMNS
	local row = spot // Geometry.SPOT_COLUMNS
	return -15 + column * 10, 5 + row * 10, floor * Geometry.FLOOR_HEIGHT
end

-- Where a creature taking `span` side-by-side pads from pad `index` stands:
-- the middle of its pads (x, z, height), which is also where its prompts
-- sit and what a raider's reach is measured from.
function Geometry.padCentre(index: number, span: number): (number, number, number)
	local x, z, height = Geometry.pad(index)
	return x + (span - 1) * 5, z, height
end

-- Whether a character whose root is `rootAbove` studs above the ground
-- floor's top stands on the floor of pad `index` (not under it or above it).
-- A standing R15 root is about 3 studs above the deck it stands on; raiders
-- reach upper floors by the ladder, so a steal needs this to be true.
function Geometry.onFloorOfPad(index: number, rootAbove: number): boolean
	local _, _, height = Geometry.pad(index)
	local above = rootAbove - height
	return above >= -2 and above <= Geometry.FLOOR_HEIGHT - 2
end

Geometry.TRAP_SPOTS = { { -10, -22 }, { 10, -22 }, { -27, 10 }, { 17, 27 } }
Geometry.DECOY_SPOTS = { { -27, -4 }, { -27, 4 }, { -27, 22 } }
Geometry.SHIELD_PYLON = { 27, 20 }

-- The odds sign at each Egg Market stop (Studio gates, Nov 5): just outside
-- the belt, its inner end beside the left post of the stop's arch (left for
-- a player walking in), turned `turn` degrees from facing straight out so it
-- faces the path a player walks in on. Its face is raised (about 4 to 7 studs)
-- so the follow camera sees it over the character, in three big lines.
-- Layout.marketSign places it; the farm hub keeps its pieces clear of it
-- (tests/HubLayout.spec).
Geometry.MARKET_SIGN = table.freeze({
	width = 10, -- the face, studs
	height = 3.3,
	bottom = 3.6, -- the face's lower edge above the ground (clear of the phone's GOAL line)
	frame = 0.3, -- the wooden frame round the face
	depth = 1, -- face, frame and legs, front to back
	innerOut = 30, -- the frame's inner end: studs from the centre...
	innerLeft = 7.3, -- ...and studs left of the stop's path, walking in
	turn = 20,
})

-- Sign `index`'s centre (x, z), the way its face looks (x, z, unit) and the
-- way across it, from the inner end to the outer (x, z, unit).
function Geometry.marketSign(index: number): (number, number, number, number, number, number)
	local sign = Geometry.MARKET_SIGN
	local a = angle(index)
	local ox, oz = math.cos(a), math.sin(a) -- out from the centre
	local lx, lz = -math.sin(a), math.cos(a) -- left, for a player walking in
	local t = math.rad(sign.turn)
	local ax, az = ox * math.sin(t) + lx * math.cos(t), oz * math.sin(t) + lz * math.cos(t)
	local fx, fz = ox * math.cos(t) - lx * math.sin(t), oz * math.cos(t) - lz * math.sin(t)
	local half = sign.width / 2 + sign.frame
	local cx = ox * sign.innerOut + lx * sign.innerLeft + ax * half
	local cz = oz * sign.innerOut + lz * sign.innerLeft + az * half
	return cx, cz, fx, fz, ax, az
end

return Geometry
