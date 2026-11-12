--!strict
-- Each built floor's name ("2. Book nook  x1.25") floats on a label in
-- front of its storey. Since every storey got a front wall (#175) the label
-- sat inside that wall's thickness, at window height, and the wall hid it
-- from outside (Studio gate on #175). It now hangs in front of the wall's
-- outermost sills and flower boxes, in the band above the windows and
-- under the next deck.
local Geometry = require("../src/shared/Geometry")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

-- From tools/art/world/tower.py: the front wall's outside face is the
-- footprint edge, and its sills and flower boxes stand out up to 0.5 more
-- (OUTER 1.3 from the inside face, 0.8 thick). Its windows' frames reach
-- 9.6 studs above the floor (z1 8.6 + 1).
local FRONT_REACH = 0.5
local WINDOW_TOP = 9.6

describe("Floor name plaque", function()
	local p = Geometry.FLOOR_PLAQUE
	it("hangs in front of the front wall and everything on it", function()
		local frontFace = Geometry.TOWER_MIN[2]
		local z = Geometry.plaqueZ()
		expect(z < frontFace - FRONT_REACH - 0.5).toBe(true)
	end)

	it("sits above the windows and under the next floor's deck", function()
		local bottom = p.above - p.height / 2
		local top = p.above + p.height / 2
		expect(bottom >= WINDOW_TOP - 0.05).toBe(true)
		expect(top <= Geometry.FLOOR_HEIGHT - 0.5).toBe(true)
	end)
end)
