--!strict
-- Each built floor's name ("2. Book nook  x1.25") floats on a label in
-- front of its storey. Since every storey got a front wall (#175) the label
-- sat inside that wall's thickness, at window height, and the wall hid it
-- from outside (Studio gate on #175). It now hangs in front of the wall's
-- outermost sills and flower boxes, in the band above the windows and
-- under the next deck. The label turns to face the camera, so seen from
-- off to the side its near half swings back toward the wall: at 1.5 studs
-- out the wall still cut it to "...ok Nook x1.05" at 30 degrees and
-- ": Nook x1.05" at 55 (Studio gate on #179). It must read whole from at
-- least 60 degrees off the front.
local Geometry = require("../src/shared/Geometry")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

-- From tools/art/world/tower.py: the front wall's outside face is the
-- footprint edge, and its sills and flower boxes stand out up to 0.5 more
-- (OUTER 1.3 from the inside face, 0.8 thick). Its windows' frames reach
-- 9.6 studs above the floor (z1 8.6 + 1).
local FRONT_REACH = 0.5
local WINDOW_TOP = 9.6
-- The widest angle off straight-on (degrees, either side) the whole label
-- must stay clear of the wall from.
local VIEW_ANGLE = 60

describe("Floor name plaque", function()
	local p = Geometry.FLOOR_PLAQUE
	it("hangs in front of the front wall and everything on it", function()
		local frontFace = Geometry.TOWER_MIN[2]
		local z = Geometry.plaqueZ()
		expect(z < frontFace - FRONT_REACH - 0.5).toBe(true)
	end)

	it("reads whole from up to 60 degrees off the front", function()
		-- Seen from `a` degrees off the front, the camera-facing label's near
		-- edge is half its width times sin(a) closer to the wall than its
		-- centre. It must stay in front of the sills and flower boxes.
		local clear = Geometry.TOWER_MIN[2] - FRONT_REACH
		for a = 0, VIEW_ANGLE, 5 do
			local nearEdge = Geometry.plaqueZ() + p.width / 2 * math.sin(math.rad(a))
			if nearEdge >= clear then
				error(
					`at {a} degrees the label's near edge (z {nearEdge}) is behind the wall's front (z {clear})`
				)
			end
		end
	end)

	it("sits above the windows and under the next floor's deck", function()
		local bottom = p.above - p.height / 2
		local top = p.above + p.height / 2
		expect(bottom >= WINDOW_TOP - 0.05).toBe(true)
		expect(top <= Geometry.FLOOR_HEIGHT - 0.5).toBe(true)
	end)
end)

-- Studio gate on #179: the ground floor had no name sign; only floors 2 and
-- up did. Every floor, the ground floor too, now carries one.
local fs = require("@lune/fs")
local Tower = require("../src/shared/Tower")
local economy = require("../config/economy")

describe("Floor name plaque on every floor", function()
	it("names the ground floor like the others", function()
		expect(Tower.plaqueText({}, 1, economy)).toBe("1. Cozy Studio  x1.00")
		expect(string.match(Tower.plaqueText({}, 2, economy), "^2%. Book Nook  x%d%.%d%d$") ~= nil).toBe(true)
	end)

	it("builds and labels a plaque on floor 1 as well", function()
		local source = fs.readFile("games/hatchery-heist/src/server/World.luau")
		local build = string.match(source, "local function buildTower.-\nend\n") or ""
		-- The plaque is made for every floor, not only inside the decks'
		-- `if floor > 1` block, which ends before the elevator stop.
		local upperOnly = string.match(build, "if floor > 1 then(.-)\n\t\tend\n") or ""
		expect(string.find(build, 'Name = "Plaque"', 1, true) ~= nil).toBe(true)
		expect(string.find(upperOnly, 'Name = "Plaque"', 1, true)).toBe(nil)
		local sync = string.match(source, "local function syncTower.-\nend\n") or ""
		expect(string.find(sync, "Tower.plaqueText(", 1, true) ~= nil).toBe(true)
		expect(string.find(sync, "for floor = 1, Tower.FLOORS do", 1, true) ~= nil).toBe(true)
	end)
end)
