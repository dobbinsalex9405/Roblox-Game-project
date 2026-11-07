--!strict
-- How the odds card beside an egg's Buy prompt is sized. Pure, for tests.

local OddsCard = {}

OddsCard.WIDTH = 280

-- The card's scale on a screen `screenY` px tall: smaller on a phone held
-- sideways, so the egg and its Buy prompt stay in view (Studio gate, Nov 5:
-- 75% at 392 px).
function OddsCard.scale(screenY: number): number
	return math.clamp(screenY / 520, 0.75, 1)
end

-- The card's height in its own (unscaled) pixels: as tall as its rows, but
-- never past the bottom of the screen when it starts `top` px down, with an
-- 8 px margin, even if it is drawn at full size; the rows scroll beyond
-- that (Studio gate, #126: a restricted player's fixed-order card ran 86 px
-- off a 392 px phone screen).
function OddsCard.height(rows: number, screenY: number, top: number): number
	return math.max(0, math.min(rows, screenY - top - 8))
end

return OddsCard
