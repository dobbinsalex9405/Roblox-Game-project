--!strict
-- The outdoor nature (tools/art/env -> shared/EnvArt) must be well formed
-- and light enough for a phone, and NaturePlan must put it where nothing
-- else is: off the bases, out of the hub, clear of the farm, the same on
-- every server.
local EnvArt = require("../src/shared/EnvArt")
local NaturePlan = require("../src/shared/NaturePlan")
local atmosphere = require("../config/atmosphere")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

-- shared/Layout (needs Vector3, so not required here): 8 bases on a ring of
-- radius 110, each 64 studs square.
local Layout = { PLOTS = 8, RING_RADIUS = 110, PLOT_SIZE = 64 }

-- Most triangles one model of each kind may have (all its meshes together).
local BUDGET: { [string]: number } = {
	tree = 16000,
	bush = 4000,
	rock = 4000,
	flowers = 2500,
	grass = 1500,
	shrooms = 1500,
}

local nature = atmosphere.scenery.nature

local function always(_: number): boolean
	return true
end

local function plan(clear: ((number) -> boolean)?)
	return NaturePlan.plan(nature :: any, Layout.PLOTS, clear or always, {
		{ x = 320, z = 0, top = 60, width = 40 },
		{ x = 0, z = 320, top = 60, width = 40 },
	})
end

describe("Nature art", function()
	it("has five tree species in their sizes, and the small props", function()
		for _, species in { "PuffOak", "Blossom", "StarPine", "Willow", "Toadstool" } do
			expect(#NaturePlan.sizesOf(species)).toBe(3)
		end
		expect(#NaturePlan.sizesOf("AmberOak")).toBe(2)
		for _, id in
			{ "BerryBush", "HydrangeaBush", "RockS", "RockM", "RockL", "GrassTuft", "FlowerPatchPink" }
		do
			expect(EnvArt.models[id] ~= nil and id or `{id} is missing`).toBe(id)
		end
	end)

	it("is well formed and within each kind's triangle budget", function()
		for id, model in EnvArt.models do
			local budget = BUDGET[model.kind]
			expect(budget ~= nil and id or `{id}: unknown kind {model.kind}`).toBe(id)
			expect(model.tris <= budget and id or `{id}: {model.tris} triangles, budget {budget}`).toBe(id)
			expect(model.assetId >= 0 and model.assetId == math.floor(model.assetId)).toBe(true)
			expect(#model.size).toBe(3)
			expect(#model.meshes).toBeAtLeast(1)
			local names: { [string]: boolean } = {}
			for _, mesh in model.meshes do
				expect(names[mesh.name] == nil and mesh.name or `{id}: {mesh.name} twice`).toBe(mesh.name)
				names[mesh.name] = true
				expect(
					string.match(mesh.color, "^%x%x%x%x%x%x$") ~= nil and mesh.color or `{id}: {mesh.color}`
				).toBe(mesh.color)
				expect(#mesh.center).toBe(3)
				expect(#mesh.size).toBe(3)
				-- every mesh sits on or above the ground
				expect(mesh.center[2] - mesh.size[2] / 2 >= -0.01 and mesh.name or `{mesh.name} below ground`).toBe(
					mesh.name
				)
			end
		end
	end)

	it("knows every image the game asks for", function()
		for _, k in { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp", "Grass" } do
			local id = (EnvArt.images :: any)[k]
			expect(type(id) == "number" and id >= 0 and k or `{k}: {id}`).toBe(k)
		end
	end)

	it("is uploaded all together or not at all", function()
		-- a half-finished upload would leave some spots as box trees and drop
		-- some small props, so it must not reach players
		local uploaded, missing = 0, {}
		for id, model in EnvArt.models do
			if model.assetId > 0 then
				uploaded += 1
			else
				table.insert(missing, id)
			end
		end
		table.sort(missing)
		local ok = uploaded == 0 or #missing == 0
		expect(ok and "ok" or `not uploaded: {table.concat(missing, ", ")}`).toBe("ok")
		local images = 0
		for _, id in EnvArt.images :: any do
			if id > 0 then
				images += 1
			end
		end
		expect(images == 0 or images == 7).toBe(true)
	end)

	it("only names models that exist in the config", function()
		for _, id in nature.gapTrees do
			expect(EnvArt.models[id] ~= nil and id or `gapTrees: no model {id}`).toBe(id)
		end
		for species in nature.wood.species do
			expect(#NaturePlan.sizesOf(species) > 0 and species or `wood: no models for {species}`).toBe(
				species
			)
		end
	end)
end)

describe("Nature plan", function()
	it("is the same every time", function()
		local a, b = plan(), plan()
		expect(#a).toBe(#b)
		for i = 1, #a, 17 do
			expect(a[i].model).toBe(b[i].model)
			expect(a[i].x).toBe(b[i].x)
			expect(a[i].z).toBe(b[i].z)
		end
	end)

	it("places the trees and props the config asks for", function()
		local counts: { [string]: number } = {}
		for _, spot in plan() do
			local kind = EnvArt.models[spot.model].kind
			counts[kind] = (counts[kind] or 0) + 1
		end
		-- gap trees + the wood + one pine on every other hill (two hills here, so one)
		expect(counts.tree).toBe(Layout.PLOTS + nature.wood.count + 1)
		expect(counts.rock).toBe(nature.scatter.rocks)
		expect(counts.grass).toBe(nature.scatter.tufts)
	end)

	it("keeps off the bases and out of the hub", function()
		for _, spot in plan() do
			local r = math.sqrt(spot.x * spot.x + spot.z * spot.z)
			-- bases reach about 145 studs from the centre (ring 110, 64 wide)
			expect(r >= 146 and spot.model or `{spot.model} at r {r}`).toBe(spot.model)
			for index = 1, Layout.PLOTS do
				local angle = (index - 1) / Layout.PLOTS * math.pi * 2
				-- the spot in the base's own frame: along the ring's radius and across it
				local ux, uz = math.cos(angle), math.sin(angle)
				local along = spot.x * ux + spot.z * uz - Layout.RING_RADIUS
				local across = -spot.x * uz + spot.z * ux
				local half = Layout.PLOT_SIZE / 2 + 1
				local on = math.abs(along) <= half and math.abs(across) <= half
				expect(not on and spot.model or `{spot.model} on base {index}`).toBe(spot.model)
			end
		end
	end)

	it("keeps trees apart and respects the farm's clear angles", function()
		local blocked = function(angle: number): boolean
			local degrees = math.deg(angle) % 360
			return not (degrees > 10 and degrees < 35)
		end
		local trees = {}
		for _, spot in plan(blocked) do
			local degrees = math.deg(math.atan2(spot.z, spot.x)) % 360
			if spot.y == 0 then
				expect(blocked(math.rad(degrees)) and spot.model or `{spot.model} at {degrees} degrees`).toBe(
					spot.model
				)
			end
			if spot.tree then
				table.insert(trees, spot)
			end
		end
		for i, a in trees do
			for j = i + 1, #trees do
				local b = trees[j]
				local d = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
				expect(d >= nature.wood.minSpacing / 2 and "ok" or `{a.model} and {b.model} {d} apart`).toBe(
					"ok"
				)
			end
		end
	end)
end)
