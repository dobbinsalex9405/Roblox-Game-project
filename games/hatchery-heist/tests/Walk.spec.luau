--!strict
-- Creatures wander their own spot on a floor and really walk (Alex, Nov 5):
-- legs swing in their gait's pattern, not a side-to-side tilt.
local Walk = require("../src/shared/Walk")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local atmosphere = require("../config/atmosphere")
local cfg = atmosphere.wander :: Walk.Config

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-6)
end

describe("Walk schedule", function()
	it("keeps every creature inside its own spot", function()
		for _, spots in { 1, 2, 3 } do
			for _, footprint in { 2, 3.8 } do
				local rx, rz = Walk.range(spots, footprint, cfg.margin)
				-- Its body never crosses into the next spot (10 studs each).
				expect(rx + footprint / 2 <= spots * 5).toBe(true)
				expect(rz + footprint / 2 <= 5).toBe(true)
				local seed = Walk.seed(`uid-{spots}-{footprint}`)
				for i = 0, 2000 do
					local at = Walk.at(seed, rx, rz, 1000 + i * 0.37, cfg)
					expect(math.abs(at.x) <= rx + 1e-9).toBe(true)
					expect(math.abs(at.z) <= rz + 1e-9).toBe(true)
				end
			end
		end
	end)

	it("keeps spot 5's creatures out of the elevator shaft on every floor", function()
		-- The shaft: base x up to -17 and z from 17. Spot 5 stands at (-15, 15).
		for _, pad in { 5, 13, 77 } do
			for _, spots in { 1, 2, 3 } do
				local footprint = 3
				local cx, cz, rx, rz = Walk.cell(pad, spots, footprint, cfg.margin)
				local standX = -15 + (spots - 1) * 5
				local minX = standX + cx - rx - footprint / 2
				local maxZ = 15 + cz + rz + footprint / 2
				expect(minX >= -17).toBe(true)
				expect(maxZ <= 17).toBe(true)
			end
		end
		-- Every other spot wanders its whole cell.
		local cx, cz = Walk.cell(6, 1, 2, cfg.margin)
		expect(cx).toBe(0)
		expect(cz).toBe(0)
	end)

	it("is the same for every player (a function of uid and server time)", function()
		local seed = Walk.seed("abc")
		local a = Walk.at(seed, 3, 2, 12345.6, cfg)
		local b = Walk.at(seed, 3, 2, 12345.6, cfg)
		expect(a.x).toBe(b.x)
		expect(a.yaw).toBe(b.yaw)
		expect(Walk.seed("abc") == Walk.seed("abd")).toBe(false)
	end)

	it("moves smoothly: no jumps in place or facing between frames", function()
		local seed = Walk.seed("smooth")
		local rx, rz = Walk.range(1, 2, cfg.margin)
		local dt = 1 / 60
		local last = Walk.at(seed, rx, rz, 500, cfg)
		local walked = false
		for i = 1, 60 * 60 do
			local at = Walk.at(seed, rx, rz, 500 + i * dt, cfg)
			local step = math.sqrt((at.x - last.x) ^ 2 + (at.z - last.z) ^ 2)
			-- Never faster than twice the walking speed (easing peaks at 1.5x).
			expect(step <= cfg.speed * 2 * dt + 1e-6).toBe(true)
			local turn = math.abs((at.yaw - last.yaw + math.pi) % (2 * math.pi) - math.pi)
			expect(turn < 0.2).toBe(true)
			if at.moving > 0.5 then
				walked = true
			end
			last = at
		end
		expect(walked).toBe(true)
	end)

	it("turns to face the centre after a long stand", function()
		local seed = Walk.seed("face")
		local rx, rz = Walk.range(1, 2, cfg.margin)
		local faced = 0
		for i = 0, 600 do
			local at = Walk.at(seed, rx, rz, i * 0.5, cfg)
			if at.moving == 0 and near(at.yaw, 0, 1e-3) then
				faced += 1
			end
		end
		expect(faced > 50).toBe(true)
	end)

	it("faces the way it walks", function()
		-- Drawn facing -Z: walking toward -Z is yaw 0, toward +X is -90 degrees.
		expect(near(Walk.yawOf(0, -1), 0)).toBe(true)
		expect(near(Walk.yawOf(1, 0), -math.pi / 2)).toBe(true)
		local seed = Walk.seed("heading")
		local rx, rz = Walk.range(3, 3.8, cfg.margin)
		local checked = 0
		local prev = Walk.at(seed, rx, rz, 0, cfg)
		for i = 1, 3000 do
			local at = Walk.at(seed, rx, rz, i * 0.05, cfg)
			if at.moving >= 1 and prev.moving >= 1 then
				local dx, dz = at.x - prev.x, at.z - prev.z
				if dx * dx + dz * dz > 1e-6 then
					local d = math.abs((Walk.yawOf(dx, dz) - at.yaw + math.pi) % (2 * math.pi) - math.pi)
					expect(d < 1e-3).toBe(true)
					checked += 1
				end
			end
			prev = at
		end
		expect(checked > 20).toBe(true)
	end)
end)

describe("Walk gaits", function()
	it("takes the gait the art gives, else one from the legs", function()
		expect(Walk.gaitOf("hop", {}, false)).toBe("hop")
		expect(Walk.gaitOf("nonsense", { legFL = true }, false)).toBe("trot")
		expect(Walk.gaitOf(nil, { legL = true, legR = true }, false)).toBe("waddle")
		expect(Walk.gaitOf(nil, { leg1L = true }, false)).toBe("scuttle")
		expect(Walk.gaitOf(nil, {}, true)).toBe("hover")
		expect(Walk.gaitOf(nil, {}, false)).toBe("trot")
	end)

	it("swings diagonal legs together in a trot, opposite to the other pair", function()
		local p = 0.25 -- a quarter step: legs at full swing
		local fl = Walk.pose("trot", "legFL", p, 1, 2, true).rx
		local br = Walk.pose("trot", "legBR", p, 1, 2, true).rx
		local fr = Walk.pose("trot", "legFR", p, 1, 2, true).rx
		local bl = Walk.pose("trot", "legBL", p, 1, 2, true).rx
		expect(fl > 0.3).toBe(true)
		expect(near(fl, br)).toBe(true)
		expect(near(fr, -fl)).toBe(true)
		expect(near(bl, -fl)).toBe(true)
	end)

	it("alternates two legs in a waddle and three-and-three in a scuttle", function()
		local l = Walk.pose("waddle", "legL", 0.25, 1, 2, true).rx
		local r = Walk.pose("waddle", "legR", 0.25, 1, 2, true).rx
		expect(l > 0.3 and near(r, -l)).toBe(true)
		-- Bug legs stick out sideways and swing about Y: the left side turns
		-- the other way, so the same set reaches forward together.
		local a = Walk.pose("scuttle", "leg1L", 0.25, 1, 1, true).ry
		expect(math.abs(a) > 0.3).toBe(true)
		expect(near(Walk.pose("scuttle", "leg2R", 0.25, 1, 1, true).ry, -a)).toBe(true)
		expect(near(Walk.pose("scuttle", "leg3L", 0.25, 1, 1, true).ry, a)).toBe(true)
		expect(near(Walk.pose("scuttle", "leg1R", 0.25, 1, 1, true).ry, a)).toBe(true)
	end)

	it("lifts the body off the ground in a hop and waves it in a slither", function()
		local hop = Walk.pose("hop", "body", 0.3, 1, 2, false) -- the top of the hop
		expect(hop.dy > 0.5).toBe(true)
		local slither = Walk.pose("slither", "body", 0.25, 1, 2, false)
		expect(math.abs(slither.ry) > 0.05 and math.abs(slither.ry) < 0.15).toBe(true)
		expect(math.abs(slither.dx) > 0.05).toBe(true)
	end)

	it("holds still when standing, and legless stand-ins still step", function()
		local s = Walk.pose("trot", "legFL", 0.25, 0, 2, true)
		expect(s.rx).toBe(0)
		expect(s.dy).toBe(0)
		local legless = Walk.pose("trot", "body", 0.25, 1, 2, false)
		local legged = Walk.pose("trot", "body", 0.25, 1, 2, true)
		expect(legless.dy > legged.dy).toBe(true)
	end)

	it("walks a spider's eight legs as two sets of four", function()
		for _, pair in
			{ { "leg1L", "leg2R" }, { "leg3L", "leg4R" }, { "leg2L", "leg1R" }, { "leg4L", "leg3R" } }
		do
			local a = Walk.pose("scuttle", pair[1], 0.25, 1, 1, true).ry
			local b = Walk.pose("scuttle", pair[2], 0.25, 1, 1, true).ry
			expect(math.abs(a) > 0.3 and near(a, -b)).toBe(true)
		end
		-- the two sets swing opposite ways (seen from the same side)
		expect(
			near(
				Walk.pose("scuttle", "leg1L", 0.25, 1, 1, true).ry,
				-Walk.pose("scuttle", "leg2L", 0.25, 1, 1, true).ry
			)
		).toBe(true)
	end)

	it("walks a pill bug's fourteen legs, the seventh pair too", function()
		-- PillBug has leg1..leg7 pairs; only leg1..leg6 moved, so it was held
		-- back from go-live batch C4 (#150). leg7 joins the alternation:
		-- left 7 in the set of the odd lefts and even rights, right 7 in the
		-- other set.
		expect(Walk.isLeg("leg7L") and Walk.isLeg("leg7R")).toBe(true)
		local l7 = Walk.pose("scuttle", "leg7L", 0.25, 1, 1, true).ry
		local r7 = Walk.pose("scuttle", "leg7R", 0.25, 1, 1, true).ry
		expect(math.abs(l7) > 0.3 and near(l7, -Walk.pose("scuttle", "leg6R", 0.25, 1, 1, true).ry)).toBe(
			true
		)
		expect(math.abs(r7) > 0.3 and near(r7, -Walk.pose("scuttle", "leg6L", 0.25, 1, 1, true).ry)).toBe(
			true
		)
		expect(near(l7, Walk.pose("scuttle", "leg5L", 0.25, 1, 1, true).ry)).toBe(true)
		expect(near(r7, Walk.pose("scuttle", "leg5R", 0.25, 1, 1, true).ry)).toBe(true)
	end)

	it("flicks a waddling bird's wings out only while it walks", function()
		local l = Walk.pose("waddle", "wingL", 0.25, 1, 2, true).rz
		local r = Walk.pose("waddle", "wingR", 0.25, 1, 2, true).rz
		expect(l > 0.1 and near(r, -l)).toBe(true)
		expect(Walk.pose("waddle", "wingL", 0.25, 0, 2, true).rz).toBe(0)
		-- a trotting dragon's wings are left to its own flap
		expect(Walk.pose("trot", "wingL", 0.25, 1, 2, true).rz).toBe(0)
	end)

	it("lets hovering legs dangle and trail, and fish swim with tail and fins", function()
		local leg = Walk.pose("hover", "legL", 0, 1, 2, true)
		expect(leg.rx < -0.1).toBe(true)
		expect(Walk.gaitOf("swim", {}, false)).toBe("swim")
		local tail = Walk.pose("swim", "tail", 0.45, 1, 2, false)
		expect(math.abs(tail.ry) > 0.3).toBe(true)
		local finL = Walk.pose("swim", "finL", 0.25, 1, 2, false).rz
		local finR = Walk.pose("swim", "finR", 0.25, 1, 2, false).rz
		expect(math.abs(finL) > 0.3 and near(finL, finR)).toBe(true)
	end)

	it("advances the step with distance, by each gait's stride", function()
		expect(near(Walk.phase("trot", 1.8, 2), 1)).toBe(true)
		expect(Walk.phase("scuttle", 1, 1) > Walk.phase("trot", 1, 1)).toBe(true)
	end)
end)

describe("Walk poses over time", function()
	it("never jumps between frames in any gait", function()
		local anims = { "body", "head", "tail", "legFL", "legL", "leg1L", "leg4R", "wingL", "finR" }
		for _, gait in Walk.GAITS do
			for _, anim in anims do
				local last = Walk.pose(gait, anim, 0, 1, 2, true)
				for i = 1, 400 do
					local p = Walk.pose(gait, anim, i / 100, 1, 2, true)
					for _, key in { "rx", "ry", "rz", "dx", "dy" } do
						local d = math.abs((p :: any)[key] - (last :: any)[key])
						if d > 0.15 then
							error(`{gait} {anim} {key} jumps {d} at phase {i / 100}`)
						end
					end
					last = p
				end
			end
		end
	end)

	it("keeps planted feet on the ground: the body dips as legs swing out", function()
		local spread = Walk.pose("trot", "body", 0.25, 1, 2, true)
		local under = Walk.pose("trot", "body", 0, 1, 2, true)
		expect(spread.dy < under.dy).toBe(true)
	end)
end)

describe("Walk matches the Blender walk clips", function()
	it("gives the same pose as tools/art/blender/walkpose.py", function()
		-- WalkMirror.luau is written by tools/art/blender/luau.py from the
		-- Python copy of Walk.pose the design viewer's walk clips use.
		local samples = require("./WalkMirror") :: { any }
		expect(#samples > 100).toBe(true)
		local keys = { "rx", "ry", "rz", "dx", "dy" }
		for _, row in samples do
			local p = Walk.pose(row[1], row[2], row[3], row[4], row[5], row[6]) :: any
			for i, key in keys do
				if math.abs(p[key] - row[7][i]) > 1e-5 then
					error(`{row[1]} {row[2]} {key}: Walk.pose {p[key]}, walkpose.py {row[7][i]}`)
				end
			end
		end
	end)
end)

describe("Walk culling", function()
	-- Studio gates, Nov 5: culling by floor left whole floors looking empty,
	-- from the yard and inside your own tower. Only distance culls now.
	it("draws every creature of your own tower within cullStuds, whatever its floor", function()
		expect(Walk.culled(0, true, cfg)).toBe(false)
		expect(Walk.culled(9 * 12, true, cfg)).toBe(false) -- floor 10, straight up
		expect(Walk.culled(cfg.cullStuds, true, cfg)).toBe(false)
		expect(Walk.culled(cfg.cullStuds + 1, true, cfg)).toBe(true)
	end)

	-- Studio gate stress test, Nov 5: four full neighbouring towers took a
	-- phone from 59 to 37 fps. Other towers stop sooner than your own.
	it("draws other players' towers only nearby: the neighbours either side", function()
		local neighbour = 84 -- the next base round the ring
		local across = 155 -- the base after that
		expect(Walk.culled(neighbour, false, cfg)).toBe(false)
		expect(Walk.culled(across, false, cfg)).toBe(true)
		expect(cfg.cullOtherStuds < cfg.cullStuds).toBe(true)
		expect(cfg.animateOtherStuds < cfg.cullOtherStuds).toBe(true)
	end)
end)

describe("Walk without leg parts", function()
	-- Studio gate, Nov 5: meshes with no leg parts only bobbed 0.2 studs
	-- and read as gliding. They now rock, nod and swing their tails.
	it("rocks the body from side to side, one way then the other", function()
		local left = Walk.pose("trot", "body", 0.25, 1, 2, false)
		local right = Walk.pose("trot", "body", 0.75, 1, 2, false)
		expect(left.rz > 0.1).toBe(true)
		expect(right.rz < -0.1).toBe(true)
		-- A waddle rocks more than a trot.
		expect(Walk.pose("waddle", "body", 0.25, 1, 2, false).rz > left.rz).toBe(true)
	end)

	it("swings the tail and nods the head while walking, not standing", function()
		local tail = Walk.pose("trot", "tail", 0.45, 1, 2, false)
		expect(math.abs(tail.ry) > 0.3).toBe(true)
		local head = Walk.pose("trot", "head", 0.125, 1, 2, false)
		expect(head.rx > 0.1).toBe(true)
		expect(Walk.pose("trot", "tail", 0.45, 0, 2, false).ry).toBe(0)
	end)

	it("keeps the legged walk for creatures with legs", function()
		local legged = Walk.pose("trot", "body", 0.25, 1, 2, true)
		expect(legged.rz).toBe(0)
		expect(legged.dy <= 0).toBe(true)
	end)
end)

describe("Walk roles", function()
	it("walks static heads, tails and ears; leaves other static parts still", function()
		expect(Walk.role("head", "static")).toBe("head")
		expect(Walk.role("tail", "static")).toBe("tail")
		expect(Walk.role("ears", "static")).toBe("ears")
		expect(Walk.role("ears", "ears")).toBe("ears")
		expect(Walk.role("shell", "static")).toBe("static")
		expect(Walk.role("crest", "glow")).toBe("glow")
		expect(Walk.role("body", "static")).toBe("body")
	end)

	-- Godly thread, Nov 5: a 6-stud-tall Clockwork Leviathan is about 15 studs
	-- long, past a spot's 10-stud depth. It lies along its three spots' row,
	-- walks it nose first, never turns across it, and stays inside its cell.
	it("lays a creature too long for the depth along its row and keeps it there", function()
		expect(Walk.lie(4, 15, cfg.margin)).toBe(math.pi / 2)
		expect(Walk.lie(12, 5, cfg.margin)).toBe(0)
		expect(Walk.lie(3, 4, cfg.margin)).toBe(nil)

		local lie = Walk.lie(4, 15, cfg.margin) :: number
		local rx, rz = Walk.range(3, 15, cfg.margin, 4)
		expect(rx > 0).toBe(true)
		local seed = Walk.seed("leviathan")
		for i = 0, 400 do
			local at = Walk.at(seed, rx, rz, 2000 + i * 0.29, cfg, lie)
			-- Along the row: its nose and tail stay inside the 30-stud row.
			expect(math.abs(at.x) + 15 / 2 <= 15 + 1e-6).toBe(true)
			expect(math.abs(at.z) < 1e-9).toBe(true)
			-- Side-on the whole time: it never turns across the row.
			local side = math.abs(at.yaw - lie) < 1e-9
			expect(side and "along" or `yaw {at.yaw} at step {i}`).toBe("along")
		end

		-- One lying broadside sidesteps, always facing the yard.
		local wide = Walk.lie(12, 5, cfg.margin) :: number
		local wx, wz = Walk.range(3, 12, cfg.margin, 5)
		for i = 0, 200 do
			local at = Walk.at(seed, wx, wz, 3000 + i * 0.31, cfg, wide)
			expect(math.abs(at.yaw) < 1e-9).toBe(true)
		end
	end)
end)
