--!strict
-- Issue #188: the belt odds card was rebuilt every time a passing egg's Buy
-- prompt showed (about twice a second), so taps on its "See every creature"
-- button missed. It now changes only when the egg it is about changes.
local fs = require("@lune/fs")
local PromptFocus = require("../src/shared/PromptFocus")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

describe("Odds card focus", function()
	it("is not rebuilt as more eggs of the same kind ride past", function()
		local focus = PromptFocus.new()
		local builds = 0
		local function count(action: PromptFocus.Action?)
			if action and action.kind == "show" then
				builds += 1
			end
		end
		-- Ten Meadow Eggs pass a stop, each prompt showing before the one
		-- ahead of it hides.
		count(focus:shown("p1", "MeadowEgg"))
		for i = 2, 10 do
			count(focus:shown(`p{i}`, "MeadowEgg"))
			count(focus:hidden(`p{i - 1}`))
		end
		expect(builds).toBe(1)
		expect(focus:egg()).toBe("MeadowEgg")
	end)

	it("does not hide while another egg's prompt is still up", function()
		local focus = PromptFocus.new()
		focus:shown("a", "MeadowEgg")
		focus:shown("b", "MeadowEgg")
		expect(focus:hidden("a")).toBe(nil)
		local last = focus:hidden("b")
		expect(last and last.kind).toBe("hide")
		expect(focus:egg()).toBe(nil)
	end)

	it("follows the newest prompt to a different egg, and back", function()
		local focus = PromptFocus.new()
		focus:shown("a", "MeadowEgg")
		local next = focus:shown("b", "MoonlitEgg")
		expect(next and next.kind == "show" and next.eggId).toBe("MoonlitEgg")
		local back = focus:hidden("b")
		expect(back and back.kind == "show" and back.eggId).toBe("MeadowEgg")
	end)

	it("drives the card in the client, and the card skips a rebuild for the same egg", function()
		local conveyor = fs.readFile("games/hatchery-heist/src/client/ConveyorView.luau")
		expect(string.find(conveyor, "PromptFocus.new()", 1, true) ~= nil).toBe(true)
		local hud = fs.readFile("games/hatchery-heist/src/client/Hud.luau")
		local show = string.match(hud, "showOdds = function%(eggId: string%)(.-)\n\t\tend,") or ""
		expect(string.find(show, "cardEgg ~= eggId", 1, true) ~= nil).toBe(true)
	end)
end)
