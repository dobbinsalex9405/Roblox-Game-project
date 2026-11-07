--!strict
-- The apartment shells the client draws over each tower (TowerShellView).
local Geometry = require("../src/shared/Geometry")
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
end)
