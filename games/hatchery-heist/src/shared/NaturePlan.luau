--!strict
-- Where Hatchery Heist's outdoor nature goes: a small tree on each side of
-- every gap between neighbouring bases (framing the farm there), a wood of mixed trees round the outside of the ring,
-- pines on the hills, and bushes, rocks, flower patches, grass tufts and
-- mushroom rings scattered through it. Pure and seeded, so every server
-- (and the tests) plan the same world. Models come from EnvArt
-- (tools/art/env); numbers from config/atmosphere.luau `scenery.nature`.
--
-- Angles are radians round the ring (0 = +X, as Layout.plotCFrame), radii
-- in studs from the centre. `clear(x, z)` says whether a point on the
-- ground is free (the farm keeps its spots clear).

local EnvArt = require("./EnvArt")

export type Spot = {
	model: string,
	x: number,
	z: number,
	y: number,
	yaw: number,
	scale: number,
	tree: boolean,
}

export type Config = {
	seed: number,
	gap: { trees: { string }, bushes: { string }, radius: number, degrees: number },
	wood: {
		count: number,
		radiusMin: number,
		radiusMax: number,
		scaleMin: number,
		scaleMax: number,
		species: { [string]: number },
		minSpacing: number,
	},
	scatter: {
		radiusMin: number,
		radiusMax: number,
		bushes: number,
		rocks: number,
		flowers: number,
		tufts: number,
		mushroomRings: number,
	},
	hillPines: number,
	hillPine: string,
}

export type Hill = { x: number, z: number, top: number, width: number }

local NaturePlan = {}

local SIZES = { "S", "M", "L" }

type Rng = { next: () -> number, range: (number, number) -> number, int: (number, number) -> number }

-- A small seeded generator (the same on the server and in Lune tests).
local function rng(seed: number): Rng
	local state = (seed * 7919 + 104729) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local self = {} :: any
	function self.next(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	function self.range(lo: number, hi: number): number
		return lo + (hi - lo) * self.next()
	end
	function self.int(lo: number, hi: number): number
		return math.min(hi, lo + math.floor(self.next() * (hi - lo + 1)))
	end
	return self
end

-- The models of one species that exist in EnvArt, smallest first.
function NaturePlan.sizesOf(species: string): { string }
	local out = {}
	for _, s in SIZES do
		if EnvArt.models[species .. s] then
			table.insert(out, species .. s)
		end
	end
	return out
end

local function weighted(r: Rng, weights: { [string]: number }): string
	local keys = {}
	local total = 0
	for k, w in weights do
		table.insert(keys, k)
		total += w
	end
	table.sort(keys) -- pairs order is not stable; sorted keys keep the plan the same everywhere
	local pick = r.next() * total
	for _, k in keys do
		pick -= weights[k]
		if pick <= 0 then
			return k
		end
	end
	return keys[#keys]
end

function NaturePlan.plan(
	config: Config,
	plots: number,
	clear: (number, number) -> boolean,
	hills: { Hill }?
): { Spot }
	local r = rng(config.seed)
	local spots: { Spot } = {}
	local taken: { { x: number, z: number, r: number } } = {}

	local function free(x: number, z: number, radius: number): boolean
		for _, t in taken do
			local dx, dz = x - t.x, z - t.z
			if dx * dx + dz * dz < (radius + t.r) ^ 2 then
				return false
			end
		end
		return true
	end
	local function add(model: string, x: number, z: number, scale: number, tree: boolean, y: number?)
		local entry = EnvArt.models[model]
		assert(entry, `no EnvArt model {model}`)
		table.insert(spots, {
			model = model,
			x = x,
			z = z,
			y = y or 0,
			yaw = r.range(0, math.pi * 2),
			scale = scale,
			tree = tree,
		})
		local footprint = math.max(entry.size[1], entry.size[3]) * scale * 0.5
		table.insert(taken, { x = x, z = z, r = if tree then footprint * 0.6 else footprint })
	end

	-- a small tree each side of every gap between neighbouring bases, and a
	-- bush at the foot of one of them (the side alternates round the ring)
	local g = config.gap
	for index = 1, plots do
		local middle = (index - 0.5) / plots * math.pi * 2
		local model = g.trees[(index - 1) % #g.trees + 1]
		for side = -1, 1, 2 do
			local angle = middle + side * math.rad(g.degrees)
			local x, z = math.cos(angle) * g.radius, math.sin(angle) * g.radius
			if clear(x, z) then
				add(model, x, z, r.range(0.95, 1.1), true)
				if #g.bushes > 0 and side == (if index % 2 == 0 then 1 else -1) then
					-- just outside the tree's trunk, a little further out
					local bush = g.bushes[(index - 1) % #g.bushes + 1]
					local bx, bz = math.cos(angle) * (g.radius + 6), math.sin(angle) * (g.radius + 6)
					if clear(bx, bz) and free(bx, bz, EnvArt.models[bush].size[1] * 0.5) then
						add(bush, bx, bz, r.range(0.95, 1.15), false)
					end
				end
			end
		end
	end

	-- the wood: species by weight, bigger trees further out
	local w = config.wood
	local tries = 0
	local placed = 0
	while placed < w.count and tries < w.count * 30 do
		tries += 1
		local angle = r.range(0, math.pi * 2)
		local radius = r.range(w.radiusMin, w.radiusMax)
		if not clear(math.cos(angle) * radius, math.sin(angle) * radius) then
			continue
		end
		local t = (radius - w.radiusMin) / math.max(w.radiusMax - w.radiusMin, 1)
		local sizes = NaturePlan.sizesOf(weighted(r, w.species))
		if #sizes == 0 then
			continue
		end
		-- inner edge mostly small and medium, more large ones further out
		local k = math.clamp(math.floor((t * 0.5 + r.next() * 0.6) * #sizes) + 1, 1, #sizes)
		local model = sizes[k]
		local scale = r.range(w.scaleMin, w.scaleMax)
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		local entry = EnvArt.models[model]
		local need = math.max(entry.size[1], entry.size[3]) * scale * 0.5 * 0.6
		if free(x, z, math.max(need, w.minSpacing * 0.5)) then
			add(model, x, z, scale, true)
			placed += 1
		end
	end

	-- pines standing on top of some of the hills
	if hills then
		local n = 0
		for i, hill in hills do
			if n >= config.hillPines then
				break
			end
			if i % 2 == 1 then
				-- the medium pine, scaled up: from the hills' distance the large
				-- one's extra detail is never seen, only its triangles
				local model = config.hillPine
				if EnvArt.models[model] then
					add(model, hill.x, hill.z, math.clamp(hill.width / 30, 1.2, 1.7), true, hill.top)
					n += 1
				end
			end
		end
	end

	-- small things scattered under and between the trees
	local s = config.scatter
	local function scatter(models: { string }, count: number, scaleMin: number, scaleMax: number)
		local done = 0
		local attempts = 0
		while done < count and attempts < count * 20 do
			attempts += 1
			local angle = r.range(0, math.pi * 2)
			local radius = r.range(s.radiusMin, s.radiusMax)
			local x, z = math.cos(angle) * radius, math.sin(angle) * radius
			if not clear(x, z) then
				continue
			end
			local model = models[r.int(1, #models)]
			if EnvArt.models[model] == nil then
				continue
			end
			local scale = r.range(scaleMin, scaleMax)
			local entry = EnvArt.models[model]
			if free(x, z, math.max(entry.size[1], entry.size[3]) * scale * 0.5) then
				add(model, x, z, scale, false)
				done += 1
			end
		end
	end
	scatter({ "RockL", "RockM", "RockM", "RockS", "RockS" }, s.rocks, 0.9, 1.2)
	scatter({ "BerryBush", "HydrangeaBush", "BerryBush" }, s.bushes, 0.9, 1.25)
	scatter({ "FlowerPatchPink", "FlowerPatchSunny", "FlowerPatchViolet" }, s.flowers, 0.9, 1.2)
	scatter({ "MushroomRing" }, s.mushroomRings, 1, 1.3)
	scatter({ "GrassTuft", "GrassTuft", "GrassTuftTall" }, s.tufts, 0.9, 1.4)
	return spots
end

return NaturePlan
