--!strict
-- Studio gate, Nov 5: at a ready egg, E set a snare (5,000 coins) instead of
-- hatching, because the trap prompts shared Hatch's key and reached it.
local PromptKeys = require("../src/shared/PromptKeys")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local raids = require("../config/raids")

describe("Prompt keys at the base", function()
	it("never puts a paid trap on Hatch's keys", function()
		for _, trap in { "Snare", "Slime" } do
			expect(PromptKeys[trap].keyboard ~= PromptKeys.Hatch.keyboard).toBe(true)
			expect(PromptKeys[trap].gamepad ~= PromptKeys.Hatch.gamepad).toBe(true)
		end
		expect(PromptKeys.Snare.keyboard ~= PromptKeys.Slime.keyboard).toBe(true)
		expect(PromptKeys.Snare.gamepad ~= PromptKeys.Slime.gamepad).toBe(true)
	end)

	it("keeps Instant Hatch (a Robux prompt) off every other base key", function()
		for _, other in { "Hatch", "Snare", "Slime" } do
			expect(PromptKeys.InstantHatch.keyboard ~= PromptKeys[other].keyboard).toBe(true)
			expect(PromptKeys.InstantHatch.gamepad ~= PromptKeys[other].gamepad).toBe(true)
		end
	end)

	it("makes buying a trap a short hold within a short reach", function()
		expect(raids.trapPrompt.holdSeconds > 0).toBe(true)
		expect(raids.trapPrompt.reach <= 6).toBe(true)
	end)
end)
