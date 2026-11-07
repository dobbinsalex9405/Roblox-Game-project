--!strict
-- The odds card beside an egg's Buy prompt always fits the screen, with
-- text a phone can read.
local OddsCard = require("../src/shared/OddsCard")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local TOP_BAR = 58 -- Roblox's top bar; the GUI starts below it

-- Where the drawn card ends: from y 168 down on a short screen (under 500
-- px), else centred.
local function bottom(rows: number, screenY: number): (number, number, number)
	local guiHeight = screenY - TOP_BAR
	local top = if screenY < 500 then 168 else 8
	local scale, height = OddsCard.fit(rows, screenY, guiHeight, top)
	local drawn = height * scale
	local last = if top == 168 then TOP_BAR + top + drawn else TOP_BAR + guiHeight / 2 + drawn / 2
	return last, scale, height
end

describe("Odds card", function()
	it("is smaller on a phone held sideways", function()
		expect(OddsCard.scale(720)).toBe(1)
		expect(OddsCard.scale(390)).toBe(OddsCard.MIN_SCALE)
	end)

	it("keeps an everyday card whole where it fits; on a short phone its rows scroll", function()
		-- 214 px: every tier and the button.
		local _, scale, height = bottom(214, 672)
		expect(scale).toBe(1)
		expect(height).toBe(214)
		local last
		last, scale, height = bottom(214, 392)
		expect(scale).toBe(OddsCard.MIN_SCALE)
		expect(height < 214).toBe(true) -- the last rows scroll into view
		expect(last <= 392 - 8 + 1e-9).toBe(true)
	end)

	it("ends at least 8 px above the bottom with text of 11 px or more; the rows scroll", function()
		-- Studio gate (#126): on an 844x392 phone the card's bottom sat at
		-- y 388 (the 58 px top bar not counted) and its text was 5.6 px; the
		-- verifier asks 11 px or more for the paid-odds disclosure.
		for _, case in { { 310, 392 }, { 1142, 392 }, { 1142, 672 }, { 400, 600 }, { 214, 360 } } do
			local rows, screenY = case[1], case[2]
			local last, scale = bottom(rows, screenY)
			expect(last <= screenY - 8 + 1e-9).toBe(true)
			expect(OddsCard.MIN_TEXT_SIZE * scale >= 11).toBe(true)
		end
	end)
end)
