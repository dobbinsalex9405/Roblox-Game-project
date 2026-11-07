--!strict
-- How the odds card beside an egg's Buy prompt is sized. Pure, for tests.

local OddsCard = {}

OddsCard.WIDTH = 280
OddsCard.MARGIN = 8 -- px kept clear below the card
-- The smallest text on the card, and the smallest the card is drawn, so no
-- text is under 11 px on screen: this card is the paid-odds disclosure
-- (verifier, #126: 5.6 px on a phone was a regression; main reads 14.4).
OddsCard.MIN_TEXT_SIZE = 14
OddsCard.MIN_SCALE = 0.8

-- The card's scale on a screen `screenY` px tall: smaller on a phone held
-- sideways, so the egg and its Buy prompt stay in view (Studio gate, Nov 5),
-- but never under MIN_SCALE.
function OddsCard.scale(screenY: number): number
	return math.clamp(screenY / 520, OddsCard.MIN_SCALE, 1)
end

-- The card's scale and its height in its own (unscaled) pixels, for `rows`
-- px of rows on a screen `screenY` px tall whose GUI area below Roblox's
-- top bar is `guiHeight` px, the card starting `top` px down. Drawn, it
-- ends at least MARGIN px above the bottom (Studio gate, #126: a long card
-- ran off a 392 px phone). Past MIN_SCALE its rows scroll instead.
function OddsCard.fit(rows: number, screenY: number, guiHeight: number, top: number): (number, number)
	local room = guiHeight - top - OddsCard.MARGIN
	local scale = OddsCard.scale(screenY)
	if rows > 0 and rows * scale > room then
		scale = math.max(OddsCard.MIN_SCALE, math.min(scale, room / rows))
	end
	return scale, math.max(0, math.min(rows, room / scale))
end

return OddsCard
