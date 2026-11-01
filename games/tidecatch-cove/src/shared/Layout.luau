--!strict
-- Where everything sits in the grey-box map: a lagoon in the middle with a
-- small island (spawn and the bait shop) and four fishing docks, and a ring
-- of 8 coves around it, one per player, each with its tide pools.
--
-- The water is a see-through slab players wade through (flat water until the
-- gate, per the build plan). Positions inside a cove are in the cove's own
-- space, where -Z faces the lagoon. The server builds from these numbers and
-- the client draws prompts and boards from them, so both always agree.

local Catch = require("./Catch")

local Layout = {}

Layout.COVES = 8 -- one per player; servers hold 8 (ops/SETUP.md)
Layout.COVE_RING_RADIUS = 160
Layout.COVE_SIZE = 56
Layout.COVE_FLOOR_TOP = 0.5

Layout.LAGOON_RADIUS = 100
Layout.WATER_DEPTH = 2.4
Layout.ISLAND_RADIUS = 18
Layout.ISLAND_TOP = 0.8
Layout.SHOP = Vector3.new(0, 3.8, -8)

-- Docks, one per fishing spot (config/fishing.spots, in order).
Layout.DOCK_RADIUS = 58
Layout.DOCK_SIZE = 14
Layout.DOCK_TOP = 0.6
Layout.FLOAT_OFFSET = 14 -- how far past the dock the fishing float sits

-- Pools: 5 columns, 2 rows.
Layout.POOL_POSITIONS = 10 -- pools.maxSlots + pools.passBonusSlots
Layout.POOL_COLUMNS = 5
Layout.POOL_RADIUS = 3.5

Layout.SIGN = Vector3.new(0, 9, 24)
Layout.SPAWN = Vector3.new(0, 4, 16)

-- The cove's frame in the world: on the ring, facing the lagoon.
function Layout.coveCFrame(index: number): CFrame
	local angle = (index - 1) / Layout.COVES * 2 * math.pi
	local position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * Layout.COVE_RING_RADIUS
	return CFrame.lookAt(position, Vector3.zero)
end

-- A pool's centre in cove space (slot 1 is front left).
function Layout.pool(slot: number): Vector3
	local column = (slot - 1) % Layout.POOL_COLUMNS
	local row = (slot - 1) // Layout.POOL_COLUMNS
	return Vector3.new(-20 + column * 10, Layout.COVE_FLOOR_TOP, -8 + row * 12)
end

-- A dock's frame: its centre at the water line, looking out to sea. Docks sit
-- between the coves' directions so no cove is right behind one.
function Layout.dockCFrame(spotIndex: number): CFrame
	local angle = (spotIndex - 0.5) / 4 * 2 * math.pi + math.pi / 8
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local position = direction * Layout.DOCK_RADIUS + Vector3.new(0, Layout.DOCK_TOP, 0)
	return CFrame.lookAt(position, position + direction)
end

function Layout.dockPosition(spotIndex: number): Vector3
	return Layout.dockCFrame(spotIndex).Position
end

-- Where the float lands in the water when casting from a dock.
function Layout.floatPosition(spotIndex: number): Vector3
	local frame = Layout.dockCFrame(spotIndex)
	return (frame * CFrame.new(0, 0, -Layout.FLOAT_OFFSET)).Position
		+ Vector3.new(0, Layout.WATER_DEPTH - Layout.DOCK_TOP, 0)
end

-- Horizontal distance, so jumping does not change who can cast.
function Layout.flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(90, 200, 90),
	Rare = Color3.fromRGB(70, 140, 255),
	Epic = Color3.fromRGB(170, 85, 255),
	Legendary = Color3.fromRGB(255, 170, 40),
}

local RARITY_SIZES: { [string]: number } = {
	Common = 1.2,
	Uncommon = 1.4,
	Rare = 1.6,
	Epic = 1.8,
	Legendary = 2,
}

function Layout.rarityColor(rarity: string): Color3
	return RARITY_COLORS[rarity] or RARITY_COLORS.Common
end

-- A creature's drawn size in a pool: bigger by rarity and by growth stage.
function Layout.creatureSize(rarity: string, stage: number): number
	return (RARITY_SIZES[rarity] or RARITY_SIZES.Common) * (0.6 + 0.25 * stage)
end

-- "SandShrimp" -> "Sand Shrimp" (the same names the server's notices use)
Layout.displayName = Catch.displayName

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

-- 75 -> "1:15"
function Layout.formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, (seconds // 60) % 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Layout
