--!strict
-- Staging playtest, Nov 12: "eggs in the hatcheries are still their same
-- base color orb". The Egg Market belt drew each egg from its patterned art
-- (WorldArt, via VoxelProp), but the server put a plain ball in the egg's
-- colour on every incubator. Incubators now use the same art.
local fs = require("@lune/fs")
local WorldArt = require("../src/shared/WorldArt")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local eggs = require("../config/eggs")
local atmosphere = require("../config/atmosphere")

describe("Incubator eggs", function()
	it("has patterned art for every egg", function()
		local missing = {}
		for _, egg in eggs do
			local prop = WorldArt.props[egg.id]
			if prop == nil or prop.kind ~= "egg" then
				table.insert(missing, egg.id)
			end
		end
		expect(table.concat(missing, ", ")).toBe("")
	end)

	it("draws the egg in an incubator from that art, not a plain ball", function()
		local source = fs.readFile("games/hatchery-heist/src/server/World.luau")
		local body = string.match(source, "local function syncIncubators.-\nend\n") or ""
		expect(string.find(body, "incubatorEgg%(incubator%.eggId") ~= nil).toBe(true)
		local maker = string.match(source, "local function incubatorEgg.-\nend\n") or ""
		expect(string.find(maker, "VoxelProp%.build%(eggId") ~= nil).toBe(true)
	end)

	it("keeps the egg about as tall as before", function()
		expect(atmosphere.incubatorEggs.height).toBe(2.6)
	end)
end)
