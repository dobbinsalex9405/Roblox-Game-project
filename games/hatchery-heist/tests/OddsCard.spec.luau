--!strict
-- The odds card beside an egg's Buy prompt always fits the screen.
local OddsCard = require("../src/shared/OddsCard")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

describe("Odds card", function()
	it("keeps its usual size when it fits", function()
		-- An everyday card (214 px) on a desktop and on a phone held sideways.
		expect(OddsCard.scale(720, 214, 8)).toBe(1)
		expect(OddsCard.scale(390, 214, 168)).toBe(0.75)
	end)

	it("shrinks a long card to fit the screen", function()
		-- Studio gate (#126): a restricted player's fixed-order card, 1,142 px
		-- on a 672 px screen, ran off the top and bottom.
		for _, case in { { 672, 1142, 8 }, { 672, 330, 8 }, { 392, 330, 168 }, { 360, 330, 168 } } do
			local screenY, natural, top = case[1], case[2], case[3]
			local scale = OddsCard.scale(screenY, natural, top)
			local fits = natural * scale <= screenY - top - 8 + 1e-9
			expect(fits or scale == 0.5).toBe(true)
			expect(scale <= 1).toBe(true)
		end
		-- Never so small it cannot be read.
		expect(OddsCard.scale(300, 5000, 168)).toBe(0.5)
	end)
end)
