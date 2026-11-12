--!strict
-- The apartment shells the client draws over each tower (TowerShellView).
local Geometry = require("../src/shared/Geometry")
local Tower = require("../src/shared/Tower")
local TowerShell = require("../src/shared/TowerShell")
local WorldArt = require("../src/shared/WorldArt")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

describe("Tower shells", function()
	it("draws five pieces a storey and the roof above the top one", function()
		local pieces = TowerShell.pieces(3)
		expect(#pieces).toBe(3 * 5 + 1)
		expect(pieces[#pieces].prop).toBe("TowerRoof")
		expect(pieces[#pieces].storey).toBe(4)
		expect(pieces[1].prop).toBe("TowerFloor1")
		expect(pieces[1].lift > 0).toBe(true) -- above the base's own floor
		expect(pieces[6].lift).toBe(0)
	end)

	it("shows one storey on a base nobody owns, and never more than 10", function()
		expect(TowerShell.storeys(nil, 10)).toBe(1)
		expect(TowerShell.storeys(0, 10)).toBe(1)
		expect(TowerShell.storeys(4, 10)).toBe(4)
		expect(TowerShell.storeys(12, 10)).toBe(10)
	end)

	-- Placing a piece puts its anchor at the base's centre; every box must
	-- then land on the tower's footprint (x -24..24, z -3..23; the ground
	-- floor's door canopy reaches 2.6 studs out front) and between its
	-- storey's floor and the next.
	it("lands every piece of every storey on the tower's footprint", function()
		for _, piece in TowerShell.pieces(10) do
			local prop = WorldArt.props[piece.prop]
			expect(prop ~= nil and "ok" or `{piece.prop} is missing from WorldArt`).toBe("ok")
			local s = prop.voxel
			local anchor = prop.anchor or { 0, 0, 0 }
			for _, part in prop.parts do
				local b = part.boxes
				for i = 1, #b, 7 do
					local x0, y0, z0 =
						(b[i] - anchor[1]) * s, (b[i + 1] - anchor[2]) * s, (b[i + 2] - anchor[3]) * s
					local x1, z1 = x0 + b[i + 3] * s, z0 + b[i + 5] * s
					local y1 = y0 + b[i + 4] * s
					local inside = x0 >= Geometry.TOWER_MIN[1] - 1.5
						and x1 <= Geometry.TOWER_MAX[1] + 1.5
						and z0 >= Geometry.TOWER_MIN[2] - 3
						and z1 <= Geometry.TOWER_MAX[2] + 1.5
						and y0 >= -1
						and y1 <= Geometry.FLOOR_HEIGHT + (if piece.prop == "TowerRoof" then 8 else 0.5)
					if not inside then
						expect(`{piece.prop} box at x {x0}..{x1} y {y0}..{y1} z {z0}..{z1} is off the tower`).toBe(
							"inside"
						)
						return
					end
				end
			end
		end
	end)

	it("leaves out ground-storey boxes that would sit below the floor", function()
		expect(TowerShell.drawn(1, -0.2)).toBe(false)
		expect(TowerShell.drawn(1, 0)).toBe(false)
		expect(TowerShell.drawn(1, 0.04)).toBe(true)
		expect(TowerShell.drawn(2, -0.2)).toBe(true)
	end)

	-- A box of a placed piece in base-local studs (y up, front -z).
	type Placed = { prop: string, part: string, lo: { number }, hi: { number }, color: number }
	local function placedBoxes(storeys: number): { Placed }
		local out: { Placed } = {}
		for _, piece in TowerShell.pieces(storeys) do
			local prop = WorldArt.props[piece.prop]
			local s = prop.voxel
			local anchor = prop.anchor or { 0, 0, 0 }
			local up = (piece.storey - 1) * Geometry.FLOOR_HEIGHT + piece.lift
			for _, part in prop.parts do
				local b = part.boxes
				for i = 1, #b, 7 do
					local x0, y0, z0 =
						(b[i] - anchor[1]) * s, (b[i + 1] - anchor[2]) * s, (b[i + 2] - anchor[3]) * s
					local x1, y1, z1 = x0 + b[i + 3] * s, y0 + b[i + 4] * s, z0 + b[i + 5] * s
					if TowerShell.drawn(piece.storey, y1 + piece.lift) then
						table.insert(out, {
							prop = piece.prop,
							part = part.name,
							lo = { x0, y0 + up, z0 },
							hi = { x1, y1 + up, z1 },
							color = b[i + 6],
						})
					end
				end
			end
		end
		return out
	end

	-- Alex, Nov 12: "overlapping texture on the frames of the apartment
	-- building in some spots". Two pieces filling the same space each draw a
	-- face in the same plane, and the two flicker (z-fighting): the front
	-- corner pillars sat inside the side walls on every floor, and wall tops
	-- and slab edges met the same way. tools/art/world/export.py now gives
	-- every bit of space to one piece. Checked here on a full tower: no face
	-- of one piece lies on a face of another, facing the same way, where it
	-- can be seen.
	it("never draws two pieces' faces in the same place (no flicker)", function()
		local boxes = placedBoxes(Tower.FLOORS)
		local E = 1e-3
		-- Boxes by 4-stud cell, to look up what covers a point.
		local CELL = 4
		local cells: { [string]: { number } } = {}
		local function key(x: number, y: number, z: number): string
			return `{math.floor(x / CELL)},{math.floor(y / CELL)},{math.floor(z / CELL)}`
		end
		for i, b in boxes do
			for cx = math.floor(b.lo[1] / CELL), math.floor(b.hi[1] / CELL) do
				for cy = math.floor(b.lo[2] / CELL), math.floor(b.hi[2] / CELL) do
					for cz = math.floor(b.lo[3] / CELL), math.floor(b.hi[3] / CELL) do
						local k = `{cx},{cy},{cz}`
						cells[k] = cells[k] or {}
						table.insert(cells[k], i)
					end
				end
			end
		end
		local function covered(p: { number }): boolean
			for _, i in cells[key(p[1], p[2], p[3])] or {} do
				local b = boxes[i]
				if
					p[1] > b.lo[1] + 1e-4
					and p[1] < b.hi[1] - 1e-4
					and p[2] > b.lo[2] + 1e-4
					and p[2] < b.hi[2] - 1e-4
					and p[3] > b.lo[3] + 1e-4
					and p[3] < b.hi[3] - 1e-4
				then
					return true
				end
			end
			return false
		end
		-- Faces by axis, side and plane.
		local planes: { [string]: { number } } = {}
		for i, b in boxes do
			for axis = 1, 3 do
				for side = 0, 1 do
					local at = if side == 0 then b.lo[axis] else b.hi[axis]
					local k = `{axis}|{side}|{math.round(at * 100)}`
					planes[k] = planes[k] or {}
					table.insert(planes[k], i)
				end
			end
		end
		local found: { string } = {}
		for k, list in planes do
			if #list < 2 then
				continue
			end
			local axis, side, at = string.match(k, "^(%d)|(%d)|(-?%d+)$")
			local a, sd, plane =
				tonumber(axis) :: number, tonumber(side) :: number, (tonumber(at) :: number) / 100
			local u, v = if a == 1 then 2 else 1, if a == 3 then 2 else 3
			for x = 1, #list do
				local A = boxes[list[x]]
				for y = x + 1, #list do
					local B = boxes[list[y]]
					if A.prop == B.prop and A.part == B.part then
						continue
					end
					local u0, u1 = math.max(A.lo[u], B.lo[u]), math.min(A.hi[u], B.hi[u])
					local v0, v1 = math.max(A.lo[v], B.lo[v]), math.min(A.hi[v], B.hi[v])
					if u1 - u0 <= E or v1 - v0 <= E then
						continue
					end
					-- Seen if a point just outside the shared patch is clear.
					for _, fu in { 0.25, 0.5, 0.75 } do
						for _, fv in { 0.25, 0.5, 0.75 } do
							local p = { 0, 0, 0 }
							p[u] = u0 + (u1 - u0) * fu
							p[v] = v0 + (v1 - v0) * fv
							p[a] = plane + (if sd == 1 then 0.01 else -0.01)
							if not covered(p) and #found < 5 then
								table.insert(
									found,
									`{A.prop}/{A.part} and {B.prop}/{B.part} at {("xyz"):sub(a, a)} = {plane} ({u0}..{u1}, {v0}..{v1})`
								)
							end
						end
					end
				end
			end
		end
		expect(table.concat(found, "; ")).toBe("")
	end)

	-- Alex, Nov 12: "there is no front wall". Every storey is closed in
	-- front: a wall the full width of the tower and floor to ceiling, with
	-- see-through window glass (part "pane"), and on the ground floor a door
	-- (x -4.5..4.5) to walk in by.
	it("closes every storey with a front wall, windows and a door on the ground floor", function()
		local front = Geometry.TOWER_MIN[2]
		for storey = 1, Tower.FLOORS do
			local prop = WorldArt.props[`TowerFront{storey}`]
			local panes = false
			for _, part in prop.parts do
				panes = panes or (part.name == "pane" and #part.boxes > 0)
			end
			expect(panes and storey or `TowerFront{storey} has no window glass`).toBe(storey)
		end
		local lo, hi = { math.huge, math.huge }, { -math.huge, -math.huge }
		local door = false
		for _, b in placedBoxes(Tower.FLOORS) do
			local inWall = b.lo[3] < front + 1 and b.hi[3] > front - 0.5
			if inWall and string.sub(b.prop, 1, 10) == "TowerFront" then
				lo[1], hi[1] = math.min(lo[1], b.lo[1]), math.max(hi[1], b.hi[1])
				lo[2], hi[2] = math.min(lo[2], b.lo[2]), math.max(hi[2], b.hi[2])
			end
			-- Nothing in the doorway of the ground floor, any piece.
			if
				inWall
				and b.lo[1] < 3.5
				and b.hi[1] > -3.5
				and b.lo[2] < 7
				and b.hi[2] > 0.5
				and b.lo[3] < front + 0.8
			then
				door = true
			end
		end
		expect(lo[1] <= Geometry.TOWER_MIN[1] + 1).toBe(true)
		expect(hi[1] >= Geometry.TOWER_MAX[1] - 1).toBe(true)
		expect(lo[2] <= 0.5).toBe(true)
		expect(hi[2] >= (Tower.FLOORS - 1) * Geometry.FLOOR_HEIGHT + 11).toBe(true)
		expect(door).toBe(false)
	end)

	it("fades the fronts between the camera and a player inside, only then", function()
		local function top(n: number): number
			return 10 + (n - 1) * Geometry.FLOOR_HEIGHT
		end
		-- Inside on storey 2, camera out front: storeys 2 and 3 fade.
		local f = TowerShell.fadedFronts(0, top(2) + 3, 8, -15, 4, top)
		expect(f[2]).toBe(true)
		expect(f[3]).toBe(true)
		expect(f[1]).toBeNil()
		-- The top storey has none above it.
		f = TowerShell.fadedFronts(0, top(4) + 3, 8, -15, 4, top)
		expect(f[4]).toBe(true)
		expect(f[5]).toBeNil()
		-- Camera inside the room too, or the player outside: nothing fades.
		expect(next(TowerShell.fadedFronts(0, top(2) + 3, 8, 2, 4, top))).toBeNil()
		expect(next(TowerShell.fadedFronts(0, top(1) + 3, -8, -15, 4, top))).toBeNil()
		expect(next(TowerShell.fadedFronts(30, top(1) + 3, 8, -15, 4, top))).toBeNil()
	end)
end)
