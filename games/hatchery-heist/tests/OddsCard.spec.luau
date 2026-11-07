--!strict
-- The odds card beside an egg's Buy prompt always fits the screen.
local OddsCard = require("../src/shared/OddsCard")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

describe("Odds card", function()
	it("is smaller on a phone held sideways", function()
		expect(OddsCard.scale(720)).toBe(1)
		expect(OddsCard.scale(390)).toBe(0.75)
	end)

	it("keeps an everyday card whole", function()
		-- 214 px: every tier and the button, on a desktop and on a phone.
		expect(OddsCard.height(214, 672, 8)).toBe(214)
		expect(OddsCard.height(214, 392, 168)).toBe(214)
	end)

	it("never runs past the screen; the rows scroll instead", function()
		-- Studio gate (#126): 310 px from y 168 on a 392 px phone ended at
		-- y 478, 86 px off-screen; 1,142 px on a 672 px desktop.
		for _, case in { { 310, 392, 168 }, { 1142, 672, 8 }, { 1142, 392, 168 } } do
			local rows, screenY, top = case[1], case[2], case[3]
			local height = OddsCard.height(rows, screenY, top)
			-- Fits even when drawn at full size, so any scale only helps.
			expect(top + height <= screenY - 8).toBe(true)
		end
	end)
end)
