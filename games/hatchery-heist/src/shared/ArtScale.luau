--!strict
-- How big to draw a creature's voxel art on the part the server stands it
-- on. Plain maths, so tests can check it without the engine.

local ArtScale = {}

-- How much to scale a creature's art for a stand-in part of `standIn` studs
-- when it is `padSize` studs on a pad and its art is `artHeight` studs tall
-- there (crests and horns can rise above the pad size). On its pad it is 1.
-- Ridden or carried, it scales with the stand-in (a mount is a stud bigger
-- than its pad, a carried one smaller), but never past the point where its
-- whole art fills the stand-in, so a Phoenix's crest never takes a mount
-- over its 6-stud limit.
function ArtScale.drawScale(standIn: number, padSize: number, artHeight: number): number
	if math.abs(standIn - padSize) < 1e-6 then
		return 1
	end
	return math.min(standIn / padSize, standIn / math.max(artHeight, 1e-6))
end

return ArtScale
