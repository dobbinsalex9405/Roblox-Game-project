--!strict
-- Where the Hatchery Book's cards go, so a tab of hundreds of creatures
-- costs no more than the few rows on screen (BookView). The book draws a
-- small pool of card frames and moves them to whichever cards are in view;
-- this works out which those are. Pure maths, shared so it is tested.

local BookGrid = {}

export type Spec = {
	width: number, -- card width in pixels
	height: number, -- card height in pixels
	gap: number, -- space between cards, both ways
}

-- Cards per row in a page `pageWidth` pixels wide (at least one).
function BookGrid.columns(pageWidth: number, spec: Spec): number
	return math.max(1, math.floor((pageWidth + spec.gap) / (spec.width + spec.gap)))
end

-- The page's full height for `count` cards: what the scroll range covers.
function BookGrid.height(count: number, columns: number, spec: Spec): number
	local rows = math.ceil(count / columns)
	if rows == 0 then
		return 0
	end
	return rows * (spec.height + spec.gap) - spec.gap
end

-- Card `index`'s top-left corner on the page (counted from 1).
function BookGrid.position(index: number, columns: number, spec: Spec): (number, number)
	local i = index - 1
	local column = i % columns
	local row = i // columns
	return column * (spec.width + spec.gap), row * (spec.height + spec.gap)
end

-- The first and last card with any part within `overscan` rows of the view
-- (scrolled `scrollY` pixels down, `viewHeight` tall), or 1, 0 for none.
function BookGrid.visible(
	count: number,
	columns: number,
	spec: Spec,
	scrollY: number,
	viewHeight: number,
	overscan: number
): (number, number)
	if count <= 0 then
		return 1, 0
	end
	local pitch = spec.height + spec.gap
	local rows = math.ceil(count / columns)
	-- Scrolled past the end (a bounce, or the page just got shorter): the last rows.
	local firstRow = math.clamp(math.floor(scrollY / pitch) - overscan, 0, rows - 1)
	local lastRow = math.min(rows - 1, math.floor((scrollY + math.max(0, viewHeight)) / pitch) + overscan)
	if lastRow < firstRow then
		return 1, 0
	end
	return firstRow * columns + 1, math.min(count, (lastRow + 1) * columns)
end

return BookGrid
