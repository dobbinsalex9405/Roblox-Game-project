--!strict
-- The apartment upgrade path (config/towerDecor.luau, made by
-- tools/art/world/rooms_layout.py): every floor's upgrades bring decor that
-- exists, belongs to that floor and stays out of the creatures' way, and
-- the helpers the client and the Tower menu use read it right.
local TowerDecor = require("../src/shared/TowerDecor")
local WorldArt = require("../src/shared/WorldArt")
local economy = require("../config/economy")
local decor: TowerDecor.Config = require("../config/towerDecor") :: any
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local UPGRADES = #economy.tower.upgradeShares
local CEILING = 11.4 -- walls are 11.4 high (tools/art/world/tower.py)
-- creatures wander their pad cells: base-local x -20..20, z 0..20
local GRID = { -20, 0, 20, 20 }
-- the deck opening players climb through beside the ladder, floors 2 to 10
-- (shared/Geometry LADDER_HOLE_MIN / MAX)
local LADDER_HOLE = { 21, 12.5, 24, 16.5 }

-- An item's footprint (x0, z0, x1, z1) and height, scaled and turned.
local function footprint(item: TowerDecor.Item): ({ number }, number)
	local prop = WorldArt.props[item.prop]
	local s = prop.voxel * item.scale
	local w, h, d = prop.size[1] * s, prop.size[2] * s, prop.size[3] * s
	if math.abs(math.sin(math.rad(item.yaw))) > 0.5 then
		w, d = d, w
	end
	return { item.x - w / 2, item.z - d / 2, item.x + w / 2, item.z + d / 2 }, h
end

local function overlaps(a: { number }, b: { number }, eps: number): boolean
	return a[1] < b[3] - eps and b[1] < a[3] - eps and a[2] < b[4] - eps and b[2] < a[4] - eps
end

describe("Tower decor", function()
	it("has a starter room on floor 1 and four named upgrades on floors 2 to 10", function()
		local f1 = decor.floors[1]
		expect(#f1.upgrades[0]).toBeAtLeast(4)
		for floor = 2, 10 do
			local f = decor.floors[floor]
			expect(#f.names).toBe(UPGRADES)
			for n = 1, UPGRADES do
				expect(#f.upgrades[n]).toBeAtLeast(2)
				expect(#f.names[n]).toBeAtLeast(3)
			end
		end
	end)

	it("only places props that exist, on their own floor", function()
		for floor, f in decor.floors do
			for _, items in f.upgrades do
				for _, item in items do
					local prop = WorldArt.props[item.prop]
					expect(if prop then item.prop else `{item.prop} is not in WorldArt`).toBe(item.prop)
					if prop and (prop.kind == "decor" or prop.kind == "room") then
						expect(if prop.floor == floor then floor else `{item.prop} is floor {prop.floor}'s`).toBe(
							floor
						)
					end
					expect(item.scale > 0 and item.scale <= 1).toBe(true)
				end
			end
		end
	end)

	it("every furnished floor gets beds on all eight pads and a rug, lights, plants and a crest", function()
		for floor = 2, 10 do
			local zones: { [number]: { [string]: number } } = {}
			for n = 1, UPGRADES do
				zones[n] = {}
				for _, item in decor.floors[floor].upgrades[n] do
					local zone = WorldArt.props[item.prop].zone or "?"
					zones[n][zone] = (zones[n][zone] or 0) + 1
				end
			end
			expect(zones[1].bed).toBe(8)
			expect(zones[2].rug).toBe(1)
			expect(zones[3].ceiling).toBe(4)
			expect(zones[4].plant).toBe(4)
			expect(zones[4].crest).toBe(1)
		end
	end)

	it("keeps the creatures' cells clear and everything inside the room", function()
		for floor, f in decor.floors do
			for n, items in f.upgrades do
				for _, item in items do
					local rect, h = footprint(item)
					local zone = WorldArt.props[item.prop].zone
					local flat = (zone == "bed" or zone == "rug" or item.prop == "RuneRing") and h <= 1.3
					local high = item.y >= 8.5
					local where = `floor {floor} upgrade {n} {item.prop}`
					if
						overlaps(rect, GRID, WorldArt.props[item.prop].voxel * item.scale + 0.05)
						and not flat
						and not high
					then
						expect(`{where} is in the creature cells`).toBe("")
					end
					-- nothing standing within 2 studs of the ladder opening; flat beds
					-- and rugs keep half a stud
					local margin = if flat then 0.5 else 2
					local hole = {
						LADDER_HOLE[1] - margin,
						LADDER_HOLE[2] - margin,
						LADDER_HOLE[3] + margin,
						LADDER_HOLE[4] + margin,
					}
					if overlaps(rect, hole, 0) and not high then
						expect(`{where} blocks the ladder opening`).toBe("")
					end
					expect(if item.y + h <= CEILING + 0.05 then "" else `{where} goes through the ceiling`).toBe(
						""
					)
					-- the Parts version rounds out by up to a coarse voxel
					local slack = WorldArt.props[item.prop].voxel * item.scale + 0.05
					local inside = rect[1] >= -23.2 - slack
						and rect[3] <= 23.2 + slack
						and rect[2] >= -2.4 - slack
						and rect[4] <= 22.0 + slack
					expect(if inside then "" else `{where} is outside the room`).toBe("")
				end
			end
		end
	end)

	it("reads the plot attributes forgivingly", function()
		expect(TowerDecor.parseUpgrades("0,2,4")).toEqual({ 0, 2, 4 })
		expect(TowerDecor.parseUpgrades("")).toEqual({})
		expect(TowerDecor.parseUpgrades(nil)).toEqual({})
		expect(TowerDecor.parseUpgrades("1,x,-3,2.5")).toEqual({ 1, 0, 0, 0 })
	end)

	it("shows the groups bought, and names the next one", function()
		expect(TowerDecor.groups(decor, 1, 0)).toEqual({ 0 })
		expect(TowerDecor.groups(decor, 3, 0)).toEqual({})
		expect(TowerDecor.groups(decor, 3, 2)).toEqual({ 1, 2 })
		expect(TowerDecor.groups(decor, 3, 9)).toEqual({ 1, 2, 3, 4 })
		expect(TowerDecor.groups(decor, 11, 2)).toEqual({})
		expect(TowerDecor.nextName(decor, 2, 0)).toBe(decor.floors[2].names[1])
		expect(TowerDecor.nextName(decor, 2, 3)).toBe(decor.floors[2].names[4])
		expect(TowerDecor.nextName(decor, 2, 4)).toBeNil()
		expect(TowerDecor.nextName(decor, 1, 0)).toBeNil()
	end)
end)
