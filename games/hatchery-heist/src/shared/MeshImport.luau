--!strict
-- How Roblox's importer turned a creature's uploaded model, so the client
-- can turn each mesh back (Alex, Nov 12: "the part that moves is displaced
-- heavily", "every creature's face is backwards").
--
-- tools/art/blender writes each creature's FBX in the game frame (front -Z,
-- feet at the origin), and CreatureMeshes lists where each mesh's centre
-- is. Roblox's importer turns the whole model half a turn about Y and bakes
-- that turn into the vertices: every MeshPart comes back at (-x, y, -z) of
-- its listed centre with no rotation of its own (real-engine probe, Nov 12:
-- AlleyCat_body at (0, 0.602, 0.1) for a listed (0, 0.602, -0.1), each
-- MeshPart's CFrame unrotated). The client places each mesh at its listed
-- centre, so every piece was drawn turned round inside its own box: faces on
-- the back of the head, and the body's leg sockets and haunches at the wrong
-- ends, so the legs stuck out of the wrong places once they swung.
--
-- So the server measures the turn from where the MeshParts landed (`fit`)
-- and tags each species model with it (CreatureAssets: `ImportYaw`); the
-- client adds it to every mesh it places (`place`). Measured, never assumed,
-- so an importer that one day keeps the frame needs no change here.

local MeshImport = {}

MeshImport.ATTRIBUTE = "ImportYaw" -- radians about Y on each species model
MeshImport.FIT_ATTRIBUTE = "ImportFit" -- studs: the worst mesh's miss after the turn
-- A MeshPart's centre may miss its listed one by this much (rounding in
-- CreatureMeshes is 0.0001; the importer's float maths far less).
MeshImport.TOLERANCE = 0.01

export type Pair = {
	listed: { number }, -- CreatureMeshes centre (x, y, z)
	landed: { number }, -- the imported MeshPart's position (x, y, z)
}

-- The point (x, y, z) turned by `yaw` about Y (the same turn as
-- CFrame.Angles(0, yaw, 0)).
function MeshImport.turn(yaw: number, x: number, y: number, z: number): (number, number, number)
	local c, s = math.cos(yaw), math.sin(yaw)
	return x * c + z * s, y, -x * s + z * c
end

-- The quarter turn about Y (0, pi/2, pi or 3pi/2) that carries the listed
-- centres onto where the MeshParts landed, and the worst miss in studs
-- after it. The importer also moves the model as a whole (it centres it on
-- its own box: real-engine probe, Nov 12: 198 of 509 species moved along
-- Z), which the client never uses, so the best shift is taken out first:
-- only pieces that moved against each other count as a miss.
function MeshImport.fit(pairs: { Pair }): (number, number)
	local bestYaw, bestMiss = 0, math.huge
	local n = math.max(1, #pairs)
	for quarter = 0, 3 do
		local yaw = quarter * math.pi / 2
		local turned = {}
		local sx, sy, sz = 0, 0, 0
		for i, p in pairs do
			local x, y, z = MeshImport.turn(yaw, p.listed[1], p.listed[2], p.listed[3])
			turned[i] = { x, y, z }
			sx += p.landed[1] - x
			sy += p.landed[2] - y
			sz += p.landed[3] - z
		end
		sx, sy, sz = sx / n, sy / n, sz / n
		local miss = 0
		for i, p in pairs do
			local t = turned[i]
			local dx, dy, dz = t[1] + sx - p.landed[1], t[2] + sy - p.landed[2], t[3] + sz - p.landed[3]
			miss = math.max(miss, math.sqrt(dx * dx + dy * dy + dz * dz))
		end
		if miss < bestMiss - 1e-9 then
			bestYaw, bestMiss = yaw, miss
		end
	end
	return bestYaw, bestMiss
end

-- Where a point of the art lands when its mesh is placed at `center` with
-- the turn `yaw` undone: `vertex` is the point as the importer stored it,
-- relative to the MeshPart's centre (already turned by the importer).
function MeshImport.place(center: { number }, vertex: { number }, yaw: number): (number, number, number)
	local x, y, z = MeshImport.turn(-yaw, vertex[1], vertex[2], vertex[3])
	return center[1] + x, center[2] + y, center[3] + z
end

return MeshImport
