--!strict
-- The Hatchery Book draws only the cards in view, so a 200-card tab stays as
-- cheap as a short one.
local BookGrid = require("../src/shared/BookGrid")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local SPEC = { width = 104, height = 150, gap = 8 }
local atmosphere = require("../config/atmosphere")

describe("Book grid", function()
	it("fits whole cards across the page, at least one", function()
		expect(BookGrid.columns(104, SPEC)).toBe(1)
		expect(BookGrid.columns(215, SPEC)).toBe(1)
		expect(BookGrid.columns(216, SPEC)).toBe(2)
		expect(BookGrid.columns(712, SPEC)).toBe(6)
		expect(BookGrid.columns(40, SPEC)).toBe(1)
	end)

	it("places cards row by row and sizes the page to the last row", function()
		local x, y = BookGrid.position(1, 6, SPEC)
		expect(x).toBe(0)
		expect(y).toBe(0)
		x, y = BookGrid.position(8, 6, SPEC)
		expect(x).toBe(112)
		expect(y).toBe(158)
		expect(BookGrid.height(0, 6, SPEC)).toBe(0)
		expect(BookGrid.height(6, 6, SPEC)).toBe(150)
		expect(BookGrid.height(7, 6, SPEC)).toBe(308)
		expect(BookGrid.height(200, 6, SPEC)).toBe(34 * 158 - 8)
	end)

	it("keeps only a few rows of a 200-card tab, wherever it is scrolled", function()
		local count, columns, view = 200, 6, 380
		local total = BookGrid.height(count, columns, SPEC)
		local scroll = 0
		while scroll <= total do
			local first, last = BookGrid.visible(count, columns, SPEC, scroll, view, 1)
			expect(last - first + 1 <= 6 * columns).toBe(true)
			-- Every card that overlaps the view is in the range.
			for i = 1, count do
				local _, y = BookGrid.position(i, columns, SPEC)
				if y + SPEC.height > scroll and y < scroll + view then
					expect(i >= first and i <= last).toBe(true)
				end
			end
			scroll += 37
		end
	end)

	it("clamps at both ends and handles an empty tab", function()
		local first, last = BookGrid.visible(10, 6, SPEC, 0, 380, 1)
		expect(first).toBe(1)
		expect(last).toBe(10)
		first, last = BookGrid.visible(200, 6, SPEC, 99999, 380, 1)
		expect(last).toBe(200)
		expect(first > 1).toBe(true)
		first, last = BookGrid.visible(0, 6, SPEC, 0, 380, 1)
		expect(last < first).toBe(true)
	end)

	it("draws two rows ahead, so a row has its picture before it scrolls in", function()
		-- Studio gate (Nov 5): after a fast flick a new row showed empty
		-- cards for a moment, while each new ViewportFrame drew its first
		-- frame. Cards two rows past either edge are already drawn.
		local overscan = atmosphere.book.overscanRows
		expect(overscan >= 2).toBe(true)
		local count, columns, view = 200, 6, 380
		local row = SPEC.height + SPEC.gap
		for scroll = 0, 3000, 53 do
			local first, last = BookGrid.visible(count, columns, SPEC, scroll, view, overscan)
			for i = 1, count do
				local _, y = BookGrid.position(i, columns, SPEC)
				local ahead = y < scroll + view + 2 * row and y + SPEC.height > scroll - 2 * row
				if ahead and y >= 0 then
					expect(i >= first and i <= last).toBe(true)
				end
			end
		end
	end)
end)
