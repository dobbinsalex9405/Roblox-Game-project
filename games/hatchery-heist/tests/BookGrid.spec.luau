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

	it("keeps pictures warm well past the view, so a fast flick lands on drawn cards", function()
		-- Studio gate (#119, Nov 7): four 350 px jumps in 0.12 s left two
		-- whole rows blank for up to a second: a brand-new ViewportFrame
		-- takes that long to draw its first frame, so cards are built while
		-- the book is open, outward from the view, and kept while near it.
		local cap = atmosphere.book.warmCards
		local columns, view = 6, 380
		-- The whole Common tab (91 today) stays warm, wherever you look.
		local first, last = BookGrid.visible(91, columns, SPEC, 0, view, 2)
		local a, b = BookGrid.warm(91, first, last, cap)
		expect(a).toBe(1)
		expect(b).toBe(91)
		-- A 200-card tab: the gate's 1,400 px flick lands inside the warm
		-- window it had before the flick, both ways.
		for scroll = 1400, 3200, 97 do
			first, last = BookGrid.visible(200, columns, SPEC, scroll, view, 2)
			a, b = BookGrid.warm(200, first, last, cap)
			expect(a <= first and b >= last).toBe(true)
			expect(b - a + 1 <= math.max(cap, last - first + 1)).toBe(true)
			for _, jump in { -1400, 1400 } do
				local f2, l2 = BookGrid.visible(200, columns, SPEC, scroll + jump, view, 0)
				local inside = f2 >= a and l2 <= b
				expect(inside or `{scroll}+{jump}: {f2}-{l2} outside {a}-{b}`).toBe(true)
			end
		end
		-- Near an end the spare goes to the other side.
		first, last = BookGrid.visible(200, columns, SPEC, 0, view, 2)
		a, b = BookGrid.warm(200, first, last, cap)
		expect(a).toBe(1)
		expect(b).toBe(cap)
	end)

	it("starts warming the moment a tab is shown, several cards a frame", function()
		-- Studio gate (#119 d9dc0ff): waiting 0.3 s and then warming 4 cards
		-- a frame left rows of empty wells at 0, 0.3 and 1 s. Warming starts
		-- at once, 8 or more a frame, nearest rows first; warmBudget still
		-- holds off for any delay the config sets.
		local look = atmosphere.book
		expect(look.warmDelaySeconds).toBe(0)
		expect(look.warmPerFrame >= 8).toBe(true)
		expect(BookGrid.warmBudget(0, look.warmDelaySeconds, look.warmPerFrame)).toBe(look.warmPerFrame)
		expect(BookGrid.warmBudget(0.1, 0.3, 4)).toBe(0)
		expect(BookGrid.warmBudget(0.3, 0.3, 4)).toBe(4)
	end)

	it("warms a new card's picture behind a card on screen", function()
		-- Studio gate (#119, Nov 7): a ViewportFrame scrolled out of sight
		-- never draws, so a flick in the first second after opening landed
		-- on pictures that were built but had never drawn. A warming card
		-- first sits exactly behind a card in view (hidden by it, but on
		-- screen, so it draws), then moves to its place.
		for _, range in { { 1, 18 }, { 37, 54 }, { 7, 7 }, { 199, 200 } } do
			local first, last = range[1], range[2]
			for index = 1, 200 do
				local host = BookGrid.host(index, first, last)
				expect(host >= first and host <= last).toBe(true)
			end
		end
		-- Warming cards spread across the cards in view, not all on one.
		expect(BookGrid.host(19, 1, 18) ~= BookGrid.host(20, 1, 18)).toBe(true)
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
