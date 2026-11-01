--!strict
-- Where everything sits in the grey-box map: 8 bases in a ring around a
-- shared yard. Positions inside a base are in the base's own space, where -Z
-- faces the yard. The server builds from these numbers and the client renders
-- the conveyor from them, so both always agree.

local Layout = {}

Layout.PLOTS = 8 -- one per player; servers hold 8 (ops/SETUP.md)
Layout.RING_RADIUS = 110
Layout.PLOT_SIZE = 64
Layout.FLOOR_TOP = 1 -- the floor's top surface, in studs above the baseplate

Layout.INCUBATOR_COLUMNS = 7
Layout.INCUBATOR_POSITIONS = 14 -- economy.incubators.maxSlots + passBonusSlots
Layout.PAD_COLUMNS = 5

-- The belt runs along the front, from the left (-X) to the right (+X).
Layout.BELT_START = Vector3.new(-26, 2.5, -26)
Layout.BELT_END = Vector3.new(26, 2.5, -26)

Layout.COLLECT_PAD = Vector3.new(27, 1.2, -8)
Layout.REBIRTH_STAND = Vector3.new(27, 4, 8)
Layout.ODDS_BOARD = Vector3.new(0, 11, -19)
Layout.SIGN = Vector3.new(0, 9, 30)
Layout.SPAWN = Vector3.new(0, 4, 24)

-- The base's frame in the world: on the ring, facing the yard.
function Layout.plotCFrame(index: number): CFrame
	local angle = (index - 1) / Layout.PLOTS * 2 * math.pi
	local position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * Layout.RING_RADIUS
	return CFrame.lookAt(position, Vector3.zero)
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

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(90, 200, 90),
	Rare = Color3.fromRGB(70, 140, 255),
	Epic = Color3.fromRGB(170, 85, 255),
	Legendary = Color3.fromRGB(255, 170, 40),
}

local RARITY_SIZES: { [string]: number } = {
	Common = 2,
	Uncommon = 2.4,
	Rare = 2.8,
	Epic = 3.2,
	Legendary = 3.6,
}

function Layout.rarityColor(rarity: string): Color3
	return RARITY_COLORS[rarity] or RARITY_COLORS.Common
end

function Layout.raritySize(rarity: string): number
	return RARITY_SIZES[rarity] or RARITY_SIZES.Common
end

local EGG_COLORS: { [string]: Color3 } = {
	BasicEgg = Color3.fromRGB(245, 235, 210),
	MeadowEgg = Color3.fromRGB(150, 210, 110),
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
	local units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, unit in units do
		if math.abs(n) >= unit[1] then
			return string.format("%.2f%s", n / unit[1], unit[2])
		end
	end
	return tostring(math.floor(n))
end

return Layout
