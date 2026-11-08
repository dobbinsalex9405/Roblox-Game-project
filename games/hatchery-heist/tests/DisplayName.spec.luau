--!strict
-- Ids are CamelCase words; DisplayName spaces them for players.
-- An id whose words do not split cleanly carries an explicit name.
local displayName = require("../src/shared/DisplayName")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

describe("DisplayName", function()
	it("spaces CamelCase ids", function()
		expect(displayName("BasicEgg")).toBe("Basic Egg")
		expect(displayName("CloverPony")).toBe("Clover Pony")
	end)

	it("names the Will-o'-Wisp properly, not 'Will OWisp'", function()
		expect(displayName("WillOWisp")).toBe("Will-o'-Wisp")
	end)
end)
