--!strict
-- How the hatch reveal answers a tap, a gamepad's B button and the Roblox
-- menu (Escape, or Back on Android). Every other window closes on B and the
-- menu (CoreClient/Modal, #175); the reveal took only taps, so a gamepad
-- player, or anyone who opened the menu over it, could not get past it
-- without a pointer (Studio gate on #175).
local RevealInput = require("../src/shared/RevealInput")
local fs = require("@lune/fs")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local GRACE = 0.35

describe("RevealInput.action", function()
	it("a tap or B cracks a wobbling egg, then closes the reveal", function()
		for _, source in { "tap", "back" } do
			expect(RevealInput.action(source, "wobble", 1.0, 0.0, 0, GRACE)).toBe("crack")
			expect(RevealInput.action(source, "shown", 5.0, 0.0, 4.0, GRACE)).toBe("close")
		end
	end)

	it("ignores a tap or B straight after the egg appears or the creature shows", function()
		expect(RevealInput.action("tap", "wobble", 0.1, 0.0, 0, GRACE)).toBe(nil)
		expect(RevealInput.action("back", "shown", 4.1, 0.0, 4.0, GRACE)).toBe(nil)
	end)

	it("the Roblox menu skips the whole reveal, queued hatches included", function()
		expect(RevealInput.action("menu", "wobble", 0.05, 0.0, 0, GRACE)).toBe("skipAll")
		expect(RevealInput.action("menu", "shown", 4.0, 0.0, 4.0, GRACE)).toBe("skipAll")
	end)

	it("does nothing when no reveal is showing or one is already closing", function()
		for _, source in { "tap", "back", "menu" } do
			expect(RevealInput.action(source, "idle", 9, 0, 0, GRACE)).toBe(nil)
			expect(RevealInput.action(source, "closing", 9, 0, 0, GRACE)).toBe(nil)
		end
	end)

	it("the reveal listens for B and the Roblox menu, not only taps", function()
		local src = fs.readFile("games/hatchery-heist/src/client/HatchReveal.luau")
		expect(string.find(src, "Enum.KeyCode.ButtonB", 1, true) ~= nil).toBe(true)
		expect(string.find(src, "MenuOpened", 1, true) ~= nil).toBe(true)
		expect(string.find(src, "RevealInput.action", 1, true) ~= nil).toBe(true)
	end)
end)
