--!strict
-- The apartment decor each tower floor shows (config/towerDecor.luau): which
-- upgrade groups a floor has, where each item goes, and the plot attributes
-- the server writes so every client can furnish every tower
-- (server/World syncTower, client/TowerDecorView).
--
-- Pure functions, so Lune tests check them.

local TowerDecor = {}

export type Item = { prop: string, x: number, z: number, yaw: number, y: number, scale: number }
export type Floor = { names: { string }, upgrades: { [number]: { Item } } }
export type Lighting = { brightness: number, range: number, color: { number }, neon: boolean }
export type View = {
	maxFloors: number,
	phoneMaxFloors: number,
	near: number,
	far: number,
	boxesPerFrame: number,
	phoneBoxesPerFrame: number,
}
export type Config = { lighting: Lighting, view: View, floors: { [number]: Floor } }

-- "0,2,4" -> { 0, 2, 4 } (floor 1 first). Anything that is not a whole
-- number reads as 0, so a bad attribute shows a bare room, never an error.
function TowerDecor.parseUpgrades(text: any): { number }
	local out = {}
	if type(text) ~= "string" or text == "" then
		return out
	end
	for piece in string.gmatch(text, "[^,]+") do
		local n = tonumber(piece)
		table.insert(out, if n and n >= 0 and n == math.floor(n) then n else 0)
	end
	return out
end

-- The upgrade groups floor `floor` shows with `upgrades` bought: floor 1
-- always shows its starter room (group 0); a higher floor shows groups 1 to
-- `upgrades`.
function TowerDecor.groups(config: Config, floor: number, upgrades: number): { number }
	local entry = config.floors[floor]
	if entry == nil then
		return {}
	end
	local out = {}
	if entry.upgrades[0] then
		table.insert(out, 0)
	end
	for n = 1, math.min(upgrades, 4) do
		if entry.upgrades[n] then
			table.insert(out, n)
		end
	end
	return out
end

-- What the next upgrade on `floor` adds ("Reading lamps"), or nil when the
-- floor has them all or no names.
function TowerDecor.nextName(config: Config, floor: number, upgrades: number): string?
	local entry = config.floors[floor]
	if entry == nil then
		return nil
	end
	return entry.names[upgrades + 1]
end

-- Base-local position of an item on a floor whose walking height is
-- `floorTop` (base space): x, y, z of its base centre and its yaw in radians.
function TowerDecor.place(item: Item, floorTop: number): (number, number, number, number)
	return item.x, floorTop + item.y, item.z, math.rad(item.yaw)
end

return TowerDecor
