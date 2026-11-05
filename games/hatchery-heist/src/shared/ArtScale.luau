--!strict
-- How big to draw a creature's voxel art on the part the server stands it
-- on. Plain maths, so tests can check it without the engine.

local ArtScale = {}

-- How much to scale a creature's art, `artHeight` studs tall at its native
-- voxel size, so that the whole art, crest and all, stands exactly as tall as
-- the server's stand-in (`standIn` studs). The stand-in is the creature's
-- size on a pad (Layout.raritySize), a stud bigger when ridden or smaller
-- when carried, so Layout.raritySize is the only size knob, and no ridden
-- creature ever passes the 6-stud mount limit.
function ArtScale.drawScale(standIn: number, artHeight: number): number
	return standIn / math.max(artHeight, 1e-6)
end

return ArtScale
