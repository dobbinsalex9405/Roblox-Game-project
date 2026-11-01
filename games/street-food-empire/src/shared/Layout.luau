--!strict
-- Where everything sits in the grey-box map: 8 restaurant plots along one
-- street, four on each side, all facing it. Positions inside a plot are in the
-- plot's own space, where -Z faces the street. Each plot has three zones,
-- one per district, from the street back: Cart Corner, Market Row, Downtown.
-- The server builds from these numbers and the client draws customers from
-- them, so both always agree.

local Layout = {}

Layout.PLOTS = 8 -- one per player; servers hold 8 (ops/SETUP.md)
Layout.PLOTS_PER_SIDE = 4
Layout.PLOT_WIDTH = 64
Layout.PLOT_DEPTH = 96
Layout.PLOT_SPACING = 72 -- centre to centre along the street
Layout.STREET_WIDTH = 28
Layout.FLOOR_TOP = 1 -- the floor's top surface, in studs above the baseplate

Layout.ZONES = 3 -- one per district
Layout.ZONE_DEPTH = 32
Layout.SPOTS_PER_ZONE = 4

-- The counter runs across the front of the plot; counter customers queue on
-- the pavement in front of it, from the serving window to the left.
Layout.COUNTER = Vector3.new(0, 2.5, -41)
Layout.COUNTER_SIZE = Vector3.new(20, 3, 3)
Layout.REGISTER = Vector3.new(16, 1.2, -41)
Layout.REBIRTH_STAND = Vector3.new(28.5, 4, 44.5)
Layout.SIGN = Vector3.new(-30, 9, -40)
Layout.SPAWN = Vector3.new(28, 4, -34)

-- The plot's frame in the world: beside the street, facing it.
function Layout.plotCFrame(index: number): CFrame
	local side = if index <= Layout.PLOTS_PER_SIDE then 1 else -1
	local column = (index - 1) % Layout.PLOTS_PER_SIDE
	local x = (column - (Layout.PLOTS_PER_SIDE - 1) / 2) * Layout.PLOT_SPACING
	local z = side * (Layout.STREET_WIDTH / 2 + Layout.PLOT_DEPTH / 2)
	return CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, 0))
end

-- The middle of a district's zone (district 1 is at the street).
function Layout.zoneCenter(district: number): Vector3
	local z = -Layout.PLOT_DEPTH / 2 + Layout.ZONE_DEPTH * (district - 0.5)
	return Vector3.new(0, Layout.FLOOR_TOP, z)
end

-- Spots are numbered 1-4 in Cart Corner, 5-8 in Market Row, 9-12 Downtown.
function Layout.spot(spot: number): Vector3
	local district = (spot - 1) // Layout.SPOTS_PER_ZONE + 1
	local column = (spot - 1) % Layout.SPOTS_PER_ZONE
	local center = Layout.zoneCenter(district)
	return Vector3.new(-21 + column * 14, Layout.FLOOR_TOP + 0.2, center.Z + 5)
end

-- Where the n-th counter customer stands (1 = at the serving window).
function Layout.queuePoint(n: number): Vector3
	return Vector3.new(-1 - (n - 1) * 2.4, Layout.FLOOR_TOP + 2, -45.5)
end

-- Where a cook's walk-up customer stands, in front of a station.
function Layout.walkUpPoint(spot: number): Vector3
	return Layout.spot(spot) + Vector3.new(0, 1.8, -6)
end

local STATION_COLORS: { [string]: Color3 } = {
	HotDogCart = Color3.fromRGB(220, 80, 60),
	LemonadeStand = Color3.fromRGB(250, 230, 90),
	PretzelOven = Color3.fromRGB(190, 130, 70),
	FryStation = Color3.fromRGB(240, 190, 60),
	TacoTruck = Color3.fromRGB(110, 190, 90),
	NoodleBar = Color3.fromRGB(240, 220, 170),
	DumplingSteamer = Color3.fromRGB(230, 230, 230),
	SmoothieBar = Color3.fromRGB(240, 120, 180),
	PizzaOven = Color3.fromRGB(200, 60, 40),
	BarbecuePit = Color3.fromRGB(90, 60, 50),
	SushiCounter = Color3.fromRGB(70, 130, 200),
	DessertCafe = Color3.fromRGB(190, 140, 230),
}

function Layout.stationColor(stationId: string): Color3
	return STATION_COLORS[stationId] or Color3.fromRGB(180, 180, 180)
end

local COOK_COLORS: { [string]: Color3 } = {
	Trainee = Color3.fromRGB(240, 240, 240),
	LineCook = Color3.fromRGB(90, 160, 255),
	Chef = Color3.fromRGB(255, 190, 40),
}

function Layout.cookColor(tier: string): Color3
	return COOK_COLORS[tier] or Color3.fromRGB(240, 240, 240)
end

local DISTRICT_COLORS = {
	Color3.fromRGB(170, 160, 140),
	Color3.fromRGB(150, 135, 115),
	Color3.fromRGB(125, 125, 135),
}

function Layout.districtColor(district: number): Color3
	return DISTRICT_COLORS[district] or DISTRICT_COLORS[1]
end

-- "HotDogCart" -> "Hot Dog Cart"
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

-- 1234 -> "$1.23K"
function Layout.cash(n: number): string
	return "$" .. Layout.shortNumber(n)
end

-- 75 -> "1:15"
function Layout.duration(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Layout
