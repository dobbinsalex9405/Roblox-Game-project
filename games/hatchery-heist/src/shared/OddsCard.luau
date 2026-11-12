--!strict
-- How the odds card beside an egg's Buy prompt is sized. Pure, for tests.

local OddsCard = {}

OddsCard.WIDTH = 280
OddsCard.MARGIN = 8 -- px kept clear below the card
-- The smallest text on the card, and the smallest the card is drawn, so no
-- text is under 11 px on screen: this card is the paid-odds disclosure
-- (verifier, #126: 5.6 px on a phone was a regression; main reads 14.4).
-- 15, not 14: drawn at MIN_SCALE, TextSize 14 measured 10.4 px tall by
-- TextBounds.Y (Studio gate, #126), under the floor; 15 measured 12.0 px.
OddsCard.MIN_TEXT_SIZE = 15
OddsCard.MIN_SCALE = 0.8
-- The card's top line is its "See chances" button, with the egg's name
-- and price on it: BUTTON px tall, 40 px on screen at MIN_SCALE, big enough
-- to tap on a phone. Under it one ROW px line per tier, ROW_GAP px apart,
-- inside PAD px of padding. Small enough that a coin egg's card, the
-- button and all seven tiers, fits a phone held sideways without
-- scrolling (OddsCard.height; verifier, #173 with every tier in every egg).
OddsCard.BUTTON = 50
OddsCard.ROW = 18
OddsCard.ROW_GAP = 1
OddsCard.PAD = 5

-- The card's height in its own pixels for the button and `lines` rows.
function OddsCard.height(lines: number): number
	return OddsCard.BUTTON + lines * (OddsCard.ROW + OddsCard.ROW_GAP) + 2 * OddsCard.PAD
end
-- The smallest measured share of TextSize * scale that the text's bounds
-- really are on screen (10.4 / (14 * 0.8)), for checking the floor.
OddsCard.GLYPH_SHARE = 0.92

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

-- Each row is a name on the left and a value (the odds, or a wait) on the
-- right. The value gets the width its text needs and the name the rest,
-- GAP px apart, so the odds are never the part cut off (Studio gate, #126:
-- "0.002% · 1 in 50,000" in half a phone row read "0.002% · 1 in...").
OddsCard.GAP = 8

-- Whether a row whose name is `nameWidth` px wide and whose value is
-- `valueWidth` px (0 for none) fits `rowWidth` px at one text size.
function OddsCard.fits(nameWidth: number, valueWidth: number, rowWidth: number): boolean
	if valueWidth <= 0 then
		return nameWidth <= rowWidth - 2
	end
	return nameWidth + OddsCard.GAP + valueWidth <= rowWidth
end

-- The share of a `rowWidth` px row the value's column takes.
function OddsCard.valueShare(valueWidth: number, rowWidth: number): number
	if valueWidth <= 0 or rowWidth <= 0 then
		return 0
	end
	return math.clamp((valueWidth + 2) / rowWidth, 0, 1)
end

return OddsCard
