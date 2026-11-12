--!strict
-- Roblox's importer hands back each creature model turned half a turn about
-- Y, baked into the vertices (shared/MeshImport). Alex, Nov 12: "every
-- creature's face is backwards" and the legs sat in the wrong places.
local CreatureMeshes = require("../src/shared/CreatureMeshes")
local MeshImport = require("../src/shared/MeshImport")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

-- What the real engine loaded for AlleyCat (asset 84172167625561, the
-- real-engine probe on Staging, Nov 12): each MeshPart's position.
local ALLEY_CAT_LANDED: { [string]: { number } } = {
	AlleyCat_body = { 0, 0.602, 0.1 },
	AlleyCat_head = { 0, 1.198, 0.696 },
	AlleyCat_eyes = { 0, 1.252, 1.05 },
	AlleyCat_torn_ears = { -0.05, 1.602, 0.6 },
	AlleyCat_legBL = { 0.4, 0.154, -0.35 },
	AlleyCat_legBR = { -0.4, 0.154, -0.35 },
	AlleyCat_legFL = { 0.4, 0.154, 0.25 },
	AlleyCat_legFR = { -0.4, 0.154, 0.25 },
	AlleyCat_tail = { -0.05, 0.848, -0.746 },
}

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-3
end

local function pairsFor(id: string, landed: { [string]: { number } }): { MeshImport.Pair }
	local out: { MeshImport.Pair } = {}
	for _, part in CreatureMeshes[id].parts do
		for _, m in part.meshes do
			if landed[m.name] then
				table.insert(out, { listed = m.center, landed = landed[m.name] })
			end
		end
	end
	return out
end

describe("Imported creature meshes", function()
	it("are measured as turned half a turn when Roblox turned them", function()
		local pairs = pairsFor("AlleyCat", ALLEY_CAT_LANDED)
		expect(#pairs).toBe(9)
		local yaw, miss = MeshImport.fit(pairs)
		expect(near(yaw, math.pi)).toBe(true)
		expect(miss <= MeshImport.TOLERANCE).toBe(true)
	end)

	it("are measured as unturned when the importer keeps the frame", function()
		local landed: { [string]: { number } } = {}
		for _, part in CreatureMeshes.AlleyCat.parts do
			for _, m in part.meshes do
				landed[m.name] = m.center
			end
		end
		local yaw, miss = MeshImport.fit(pairsFor("AlleyCat", landed))
		expect(yaw).toBe(0)
		expect(miss).toBe(0)
	end)

	it("ignore the importer moving the whole model (it centres it on its box)", function()
		local landed: { [string]: { number } } = {}
		for name, at in ALLEY_CAT_LANDED do
			landed[name] = { at[1] + 0.3, at[2], at[3] - 0.45 }
		end
		local yaw, miss = MeshImport.fit(pairsFor("AlleyCat", landed))
		expect(near(yaw, math.pi)).toBe(true)
		expect(miss <= MeshImport.TOLERANCE).toBe(true)
	end)

	it("report a miss when the upload does not match the listed centres", function()
		local landed = table.clone(ALLEY_CAT_LANDED)
		landed.AlleyCat_legFR = { -0.4, 0.154, 0.6 } -- a leg somewhere else
		local _, miss = MeshImport.fit(pairsFor("AlleyCat", landed))
		expect(miss > MeshImport.TOLERANCE).toBe(true)
	end)

	it("put the face back on the front of the head once placed", function()
		-- The head's front face in the art: 0.4 studs in front (-Z) of its
		-- centre. The importer stored it turned, behind the centre.
		local yaw = MeshImport.fit(pairsFor("AlleyCat", ALLEY_CAT_LANDED))
		local head = CreatureMeshes.AlleyCat.parts[6]
		expect(head.name).toBe("head")
		local center = head.meshes[1].center
		local fx, fy, fz = MeshImport.turn(yaw, 0, 0, -0.4) -- as stored
		local x, y, z = MeshImport.place(center, { fx, fy, fz }, yaw)
		expect(near(x, center[1]) and near(y, center[2]) and near(z, center[3] - 0.4)).toBe(true)
		-- Placed without the turn (the bug), the face lands behind.
		local _, _, zBug = MeshImport.place(center, { fx, fy, fz }, 0)
		expect(near(zBug, center[3] + 0.4)).toBe(true)
	end)
end)
