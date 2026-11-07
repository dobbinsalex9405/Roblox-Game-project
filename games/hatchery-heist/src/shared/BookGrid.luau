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

-- The cards kept built around the drawn range `first`..`last`: that range
-- widened evenly both ways until it holds `cap` cards, any spare past one end
-- of the tab going to the other side. A brand-new ViewportFrame takes up to
-- a second to draw its first frame, so the book builds these ahead while it
-- is open and a fast flick lands on cards that are already drawn.
function BookGrid.warm(count: number, first: number, last: number, cap: number): (number, number)
	if count <= 0 or last < first then
		return 1, 0
	end
	local spare = math.max(0, cap - (last - first + 1))
	local before = math.min(first - 1, spare // 2)
	local after = math.min(count - last, spare - before)
	before = math.min(first - 1, spare - after)
	return first - before, last + after
end

-- Cards to warm this frame, `elapsed` seconds after a tab was shown: none
-- until the cards on screen have had `delay` to draw (new pictures queue to
-- draw together, so warming at once left cards on screen blank), then
-- `perFrame`.
function BookGrid.warmBudget(elapsed: number, delay: number, perFrame: number): number
	return if elapsed < delay then 0 else perFrame
end

-- Where a warming card waits while its picture draws for the first time:
-- behind one of the cards on screen (`first`..`last`, no overscan), spread
-- across them by index. A ViewportFrame scrolled out of sight never draws,
-- so a card built off screen would still be blank when a flick reaches it.
function BookGrid.host(index: number, first: number, last: number): number
	local count = math.max(1, last - first + 1)
	return first + (index - 1) % count
end

return BookGrid
