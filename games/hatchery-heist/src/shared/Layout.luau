--!strict
-- Where everything sits in the grey-box map: 8 bases in a ring around a
-- shared yard with the Egg Market in the middle. Positions inside a base are
-- in the base's own space, where -Z faces the yard. The server builds from
-- these numbers and the client renders the market's eggs from them, so both
-- always agree.

local Geometry = require("./Geometry")

local Layout = {}

Layout.PLOTS = 8 -- one per player; servers hold 8 (ops/SETUP.md)
Layout.RING_RADIUS = 110
Layout.PLOT_SIZE = 64
Layout.FLOOR_TOP = 1 -- the floor's top surface, in the base's own space
-- Each base's own space sits this far below the ground, so the floor shows
-- only a low lip above the grass (0.3 studs; the plaza is at 0.2). The
-- numbers inside a base stay as they were and everything moves together.
Layout.PLOT_Y = -0.7
Layout.FLOOR_THICKNESS = 0.4 -- thin enough that the floor's centre stays above the ground
Layout.FLOOR_WORLD_TOP = Layout.FLOOR_TOP + Layout.PLOT_Y -- the floor's top in the world

Layout.INCUBATOR_COLUMNS = 7
Layout.INCUBATOR_POSITIONS = 14 -- economy.incubators.maxSlots + passBonusSlots

Layout.COLLECT_PAD = Vector3.new(27, 1.2, -8)
Layout.REBIRTH_STAND = Vector3.new(27, 4, 8)
Layout.SIGN = Vector3.new(0, 9, 30)
Layout.SPAWN = Vector3.new(0, 4, 24)

-- The base's frame in the world: on the ring, facing the yard.
function Layout.plotCFrame(index: number): CFrame
	local angle = (index - 1) / Layout.PLOTS * 2 * math.pi
	local position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * Layout.RING_RADIUS
	local drop = Vector3.new(0, Layout.PLOT_Y, 0)
	return CFrame.lookAt(position + drop, drop)
end

function Layout.incubator(slot: number): Vector3
	local column = (slot - 1) % Layout.INCUBATOR_COLUMNS
	local row = (slot - 1) // Layout.INCUBATOR_COLUMNS
	return Vector3.new(-18 + column * 6, 1.5, -15 + row * 6)
end

-- Pad `index` across the whole tower (Geometry.pad): 1 to 8 on the ground
-- floor, 9 to 16 on floor 2, and so on.
function Layout.pad(index: number): Vector3
	local x, z, height = Geometry.pad(index)
	return Vector3.new(x, 1.2 + height, z)
end

-- Tower floor looks, floor 1 to 10 (themes in economy.tower.themes): the
-- deck and the trim (railings, pillars) of the cozy apartment tower.
-- Placeholder colours until the world thread's apartment art lands.
Layout.FLOOR_LOOKS = {
	{ deck = Color3.fromRGB(176, 128, 88), trim = Color3.fromRGB(214, 110, 80) }, -- Cozy Studio
	{ deck = Color3.fromRGB(150, 105, 70), trim = Color3.fromRGB(120, 150, 110) }, -- Book Nook
	{ deck = Color3.fromRGB(190, 160, 115), trim = Color3.fromRGB(90, 165, 95) }, -- Plant Sunroom
	{ deck = Color3.fromRGB(215, 190, 160), trim = Color3.fromRGB(230, 140, 90) }, -- Bakery Kitchen
	{ deck = Color3.fromRGB(120, 90, 70), trim = Color3.fromRGB(80, 140, 220) }, -- Games Lounge
	{ deck = Color3.fromRGB(140, 100, 70), trim = Color3.fromRGB(235, 240, 250) }, -- Winter Cabin
	{ deck = Color3.fromRGB(205, 180, 145), trim = Color3.fromRGB(230, 120, 150) }, -- Art Studio
	{ deck = Color3.fromRGB(150, 170, 110), trim = Color3.fromRGB(110, 190, 140) }, -- Rooftop Garden
	{ deck = Color3.fromRGB(50, 55, 95), trim = Color3.fromRGB(190, 180, 255) }, -- Starlit Observatory
	{ deck = Color3.fromRGB(235, 215, 170), trim = Color3.fromRGB(255, 200, 90) }, -- Golden Sky Penthouse
}

-- Where each floor's elevator stop is, and the ladder up the right side,
-- in the base's own space (y = 0: add the floor's top).
Layout.ELEVATOR = Vector3.new(-20.5, 0, 20.5)
Layout.LADDER = Vector3.new(25.2, 0, 14.5)

-- The top of floor `floor`'s deck, in the base's own space.
function Layout.floorTop(floor: number): number
	return Layout.FLOOR_TOP + (floor - 1) * Geometry.FLOOR_HEIGHT
end

-- The Egg Market in the middle of the map (world space, around the Golden
-- Nest at the origin): a round belt of two lanes, lane 1 inside and lane 2
-- outside, turning opposite ways so every base sees eggs coming both ways.
-- Eggs appear at MARKET_START, between bases 1 and 2, and ride once round.
Layout.MARKET_LANES = { 22, 27.5 } -- each lane's centreline radius
Layout.MARKET_SLAT_Y = 0.9 -- the slats' underside (the rails' anchor height)
Layout.MARKET_SLAT_TOP = 1.3 -- where pedestals stand
Layout.MARKET_START = math.pi / 8
Layout.MARKET_WIDTH = 3.2 -- a lane's slats, across

-- The angle round the market of a lane at `progress` (0 to 1).
function Layout.marketAngle(lane: number, progress: number): number
	local turn = math.clamp(progress, 0, 1) * 2 * math.pi
	return Layout.MARKET_START + (if lane == 1 then -turn else turn)
end

-- Where on the market an egg at `progress` along `lane` stands (the slats'
-- top), facing the way it travels.
function Layout.marketFrame(lane: number, progress: number): CFrame
	local radius = Layout.MARKET_LANES[lane] or Layout.MARKET_LANES[1]
	local a = Layout.marketAngle(lane, progress)
	local outward = Vector3.new(math.cos(a), 0, math.sin(a))
	local position = outward * radius + Vector3.new(0, Layout.MARKET_SLAT_TOP, 0)
	-- Travel direction: lane 1's angle falls, lane 2's rises.
	local along = if lane == 1
		then Vector3.new(math.sin(a), 0, -math.cos(a))
		else Vector3.new(-math.sin(a), 0, math.cos(a))
	return CFrame.lookAt(position, position + along)
end

-- The point of the market's outer edge that faces base `index`: where the
-- guide's arrow leads a new player.
function Layout.marketStop(index: number): Vector3
	local angle = (index - 1) / Layout.PLOTS * 2 * math.pi
	local radius = Layout.MARKET_LANES[#Layout.MARKET_LANES] + Layout.MARKET_WIDTH / 2 + 1.5
	return Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius + Vector3.new(0, 1.5, 0)
end

-- The seven tiers, lowest first, and the studio's rarity colours (the voxel
-- style guide: cards, rings, hatch flashes and name banners).
Layout.RARITIES = { "Common", "Uncommon", "Rare", "Ultra Rare", "Epic", "Legendary", "Godly" }

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(174, 184, 196),
	Uncommon = Color3.fromRGB(95, 208, 104),
	Rare = Color3.fromRGB(63, 169, 245),
	["Ultra Rare"] = Color3.fromRGB(0, 214, 201),
	Epic = Color3.fromRGB(177, 92, 255),
	Legendary = Color3.fromRGB(255, 194, 26),
	Godly = Color3.fromRGB(255, 77, 94),
}

-- A creature's height in studs on a pad: the server's stand-in ball is this
-- size and the client draws the whole art exactly this tall. Rarer creatures
-- are only a little bigger (Alex, Nov 5): they take more room on a floor
-- instead, so a floor never gets crowded by one giant.
local RARITY_SIZES: { [string]: number } = {
	Common = 2,
	Uncommon = 2.2,
	Rare = 2.4,
	["Ultra Rare"] = 2.7,
	Epic = 3,
	Legendary = 3.4,
	Godly = 3.8,
}

-- 1 for Common up to 7 for Godly.
function Layout.rarityRank(rarity: string): number
	return table.find(Layout.RARITIES, rarity) or 1
end

function Layout.rarityColor(rarity: string): Color3
	return RARITY_COLORS[rarity] or RARITY_COLORS.Common
end

function Layout.raritySize(rarity: string): number
	return RARITY_SIZES[rarity] or RARITY_SIZES.Common
end

-- A ridden creature is one stud taller than on its pad, up to 6 studs, so a
-- Legendary still fits through the yard and its rider stays on screen.
Layout.MOUNT_MAX = 6
function Layout.mountSize(rarity: string): number
	return math.min(Layout.raritySize(rarity) + 1, Layout.MOUNT_MAX)
end

-- A creature carried overhead by a raider, up to 4 studs.
Layout.CARRY_MAX = 4
function Layout.carrySize(rarity: string): number
	return math.min(Layout.raritySize(rarity), Layout.CARRY_MAX)
end

local EGG_COLORS: { [string]: Color3 } = {
	BasicEgg = Color3.fromRGB(245, 235, 210),
	MeadowEgg = Color3.fromRGB(150, 210, 110),
	MoonlitEgg = Color3.fromRGB(90, 80, 200),
	PremiumEgg = Color3.fromRGB(255, 200, 60),
}

function Layout.eggColor(eggId: string): Color3
	return EGG_COLORS[eggId] or Color3.fromRGB(230, 230, 230)
end

-- "BasicEgg" -> "Basic Egg"
function Layout.displayName(id: string): string
	return (string.gsub(id, "(%l)(%u)", "%1 %2"))
end

-- 1234567 -> "1.23M"
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
