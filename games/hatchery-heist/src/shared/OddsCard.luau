--!strict
-- How the odds card beside an egg's Buy prompt is sized. Pure, for tests.

local OddsCard = {}

OddsCard.WIDTH = 280
OddsCard.MARGIN = 8 -- px kept clear below the card
-- The smallest the card is drawn: its smallest text (13) stays about 9 px
-- or more (Studio gate, #126: 5.6 px on a phone was a regression).
OddsCard.MIN_SCALE = 0.7

-- The card's scale on a screen `screenY` px tall: smaller on a phone held
-- sideways, so the egg and its Buy prompt stay in view (Studio gate, Nov 5:
-- 75% at 392 px).
function OddsCard.scale(screenY: number): number
	return math.clamp(screenY / 520, 0.75, 1)
end

-- The card's scale and its height in its own (unscaled) pixels, for `rows`
-- px of rows on a screen `screenY` px tall whose GUI area below Roblox's
-- top bar is `guiHeight` px, the card starting `top` px down. Drawn, it
-- ends at least MARGIN px above the bottom (Studio gate, #126: a long card
-- ran off a 392 px phone). A card a little too tall is drawn a little
-- smaller, down to MIN_SCALE; past that its rows scroll.
function OddsCard.fit(rows: number, screenY: number, guiHeight: number, top: number): (number, number)
	local room = guiHeight - top - OddsCard.MARGIN
	local scale = OddsCard.scale(screenY)
	if rows > 0 and rows * scale > room then
		scale = math.max(OddsCard.MIN_SCALE, math.min(scale, room / rows))
	end
	return scale, math.max(0, math.min(rows, room / scale))
end

return OddsCard
