--!strict
-- Studio play-solo for #123 (issue #183): since the tower got its front wall
-- and roof (#175), (1) the "Floor N: <price> coins" sign over the next floor
-- to buy hung 2 studs over that floor's deck, inside the roof, where nobody
-- could see it, and (2) the rebirth stand's sign, 3 studs off the tower's
-- right wall, was cut to "Rebirth: 50M coi" from the side. Labels turn to
-- face the camera, so seen from off to the side their near half swings back
-- by half their width times the sine of the angle.
local Geometry = require("../src/shared/Geometry")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

-- From tools/art/world/tower.py: the walls' sills and flower boxes stand out
-- up to 0.5 past the footprint. The roof sits where the next floor would:
-- its mansard rises 3.2 and the dormers along its front 4.0 over that floor's
-- walking height; only the dome (round the tower's middle) and the two front
-- corner turrets (x +-21.8, 1.8 round) stand higher.
local WALL_REACH = 0.5
local ROOF_FRONT_TOP = 4.0
local TURRET_INNER_X = 21.8 - 1.8

describe("Next-floor price sign", function()
	local box = Geometry.FLOOR_LABEL

	it("hangs out in front of the tower, not over the deck inside the roof", function()
		expect(Geometry.priceSignZ() < Geometry.TOWER_MIN[2] - WALL_REACH - 0.5).toBe(true)
	end)

	it("clears the roof's front from any angle", function()
		-- Seen from the side its near half swings back over the roof: it
		-- must ride above the mansard and dormers there ...
		local bottom = box.above - box.height / 2
		if bottom < ROOF_FRONT_TOP + 0.3 then
			error(`the sign's bottom ({bottom}) is down among the roof's dormers (top {ROOF_FRONT_TOP})`)
		end
		-- ... and between the turrets.
		expect(box.width / 2 < TURRET_INNER_X).toBe(true)
	end)

	it("stays clear of the top floor's name sign below it", function()
		local plaque = Geometry.FLOOR_PLAQUE
		local plaqueTop = plaque.above + plaque.height / 2 - Geometry.FLOOR_HEIGHT -- under the next floor's walking height
		local bottom = box.above - box.height / 2
		expect(bottom - plaqueTop >= 1.5).toBe(true)
	end)
end)

describe("Rebirth stand sign", function()
	local sign = Geometry.REBIRTH_LABEL

	it("reads whole from every angle beside the tower's right wall", function()
		local wall = Geometry.TOWER_MAX[1] + WALL_REACH
		for a = 0, 90, 5 do
			local nearEdge = Geometry.REBIRTH_STAND[1] - sign.width / 2 * math.sin(math.rad(a))
			if nearEdge <= wall + 0.2 then
				error(`at {a} degrees the sign's near edge (x {nearEdge}) is in the wall (x {wall})`)
			end
		end
	end)

	it("keeps the stand on the base", function()
		expect(Geometry.REBIRTH_STAND[1] + 2 <= Geometry.HALF_SIZE).toBe(true)
	end)
end)
