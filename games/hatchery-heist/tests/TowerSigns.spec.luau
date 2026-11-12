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
-- up to 0.5 past the footprint; floor 1's striped awning over the door
-- stands 2.9 out, x -6..6, from 8.8 to 11.4 over the floor.
local WALL_REACH = 0.5
local AWNING = { reach = 2.9, halfWidth = 6, bottom = 8.8, top = 11.4 }
local VIEW_ANGLE = 60

-- How far in front of the tower a camera-facing label of `width` must hang
-- so that, seen from up to 60 degrees off the front, its near half stays in
-- front of whatever the wall carries at its height on floor 1 (the awning
-- is the furthest out).
local function needsOut(width: number, bottom: number, top: number): number
	local reach = WALL_REACH
	if bottom < AWNING.top and top > AWNING.bottom then
		reach = AWNING.reach
	end
	return reach + width / 2 * math.sin(math.rad(VIEW_ANGLE)) + 0.2
end

describe("Next-floor price sign", function()
	-- Studio gate on #184 (phone, 844x392): hung over the roof, the sign sat
	-- behind the GOAL banner and the coin box from every yard camera. It now
	-- hangs right under the top built floor's name plaque, which the same
	-- phone shots show clear of the HUD. At the same distance out and lower
	-- down, it never shows higher on the screen than that plaque.
	local box = Geometry.FLOOR_LABEL
	local plaque = Geometry.FLOOR_PLAQUE

	it("hangs under the top floor's name plaque, never higher on screen", function()
		expect(Geometry.priceSignZ()).toBe(Geometry.plaqueZ())
		local top = box.above + box.height / 2
		local plaqueBottom = plaque.above - plaque.height / 2
		if top > plaqueBottom - 0.1 then
			error(`the price sign's top ({top}) is not under the name plaque (bottom {plaqueBottom})`)
		end
		-- Above everyone's head, and under the next deck.
		expect(box.above - box.height / 2 >= 6).toBe(true)
		expect(top <= Geometry.FLOOR_HEIGHT - 0.5).toBe(true)
	end)

	it("reads whole from up to 60 degrees off the front, even over the awning", function()
		local bottom = box.above - box.height / 2
		local top = box.above + box.height / 2
		local out = Geometry.TOWER_MIN[2] - Geometry.priceSignZ()
		local needed = needsOut(box.width, bottom, top)
		if out < needed then
			error(`the price sign hangs {out} out; {box.width} wide it needs {needed}`)
		end
		expect(box.width <= 13).toBe(true)
	end)
end)

describe("Floor name plaque by the awning", function()
	-- Studio gate on #184: at +-60 degrees floor 1's door awning cut the
	-- plaque's first or last word.
	it("reads whole from up to 60 degrees off the front on floor 1", function()
		local p = Geometry.FLOOR_PLAQUE
		local out = Geometry.TOWER_MIN[2] - Geometry.plaqueZ()
		local needed = needsOut(p.width, p.above - p.height / 2, p.above + p.height / 2)
		if out < needed then
			error(`the plaque hangs {out} out; {p.width} wide it needs {needed}`)
		end
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
