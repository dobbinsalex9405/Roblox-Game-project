--!strict
-- Where everything sits in the grey-box map: 8 bases in a ring around a
-- shared yard. Positions inside a base are in the base's own space, where -Z
-- faces the yard. The server builds from these numbers and the client renders
-- the conveyor from them, so both always agree.

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
Layout.PAD_COLUMNS = 5

-- The belt runs along the front, from the left (-X) to the right (+X).
Layout.BELT_START = Vector3.new(-26, 2.5, -26)
Layout.BELT_END = Vector3.new(26, 2.5, -26)

Layout.COLLECT_PAD = Vector3.new(27, 1.2, -8)
Layout.REBIRTH_STAND = Vector3.new(27, 4, 8)
Layout.ODDS_BOARD = Vector3.new(0, 13, -19) -- centre of a 30 x 12 board
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

function Layout.pad(index: number): Vector3
	local column = (index - 1) % Layout.PAD_COLUMNS
	local row = (index - 1) // Layout.PAD_COLUMNS
	return Vector3.new(-20 + column * 10, 1.2, 0 + row * 7)
end

-- A point along the belt, `progress` from 0 (start) to 1 (end).
function Layout.beltPoint(progress: number): Vector3
	return Layout.BELT_START:Lerp(Layout.BELT_END, math.clamp(progress, 0, 1))
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

-- Rough height in studs, for things that need a size before the model loads
-- (labels, the ridden seat). The voxel model sets the real size.
local RARITY_SIZES: { [string]: number } = {
	Common = 2,
	Uncommon = 2.5,
	Rare = 3.2,
	["Ultra Rare"] = 4,
	Epic = 5,
	Legendary = 9,
	Godly = 11,
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
