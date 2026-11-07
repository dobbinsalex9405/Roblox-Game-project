--!strict
-- How the odds card beside an egg's Buy prompt is sized. Pure, for tests.

local OddsCard = {}

-- The odds card's scale on a screen `screenY` px tall: smaller on a phone
-- held sideways (75% at 392 px, Studio gate Nov 5), and never taller than
-- the screen below `top` px with an 8 px margin, so a long card (a restricted
-- player's fixed order, Studio gate #126) never runs off it. `naturalY` is the
-- card's height at 100%. Never below 50%.
function OddsCard.scale(screenY: number, naturalY: number, top: number): number
	local scale = math.clamp(screenY / 520, 0.75, 1)
	if naturalY > 0 then
		scale = math.min(scale, (screenY - top - 8) / naturalY)
	end
	return math.max(scale, 0.5)
end

return OddsCard
