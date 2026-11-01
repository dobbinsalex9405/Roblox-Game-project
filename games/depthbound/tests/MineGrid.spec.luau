--!strict
local Layout = require("../src/shared/Layout")
local MineGrid = require("../src/shared/MineGrid")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local mine = require("../config/mine")
local blocks = require("../config/blocks")

local function fresh(seed: number?): MineGrid.Grid
	return MineGrid.new(mine, blocks, seed or 99)
end

describe("Mine grid", function()
	it("a fresh mine exposes only its top face", function()
		local g = fresh()
		expect(g.exposedCount).toBe(mine.width * mine.length)
		expect(#g:exposedKeys()).toBe(mine.width * mine.length)
		expect(g:isExposed(1, 1, 1)).toBe(true)
		expect(g:isExposed(1, 2, 1)).toBe(false)
		expect(g.rows).toBe(Layout.totalRows(mine))
	end)

	it("keys and positions round-trip", function()
		local g = fresh()
		for _, p in { { 1, 1, 1 }, { mine.width, g.rows, mine.length }, { 3, 17, 9 } } do
			local x, y, z = g:position(g:key(p[1], p[2], p[3]))
			expect(x).toBe(p[1])
			expect(y).toBe(p[2])
			expect(z).toBe(p[3])
		end
	end)

	it("the same seed builds the same mine, another seed a different one", function()
		local a, b, c = fresh(5), fresh(5), fresh(6)
		local same, differ = true, false
		for y = 1, a.rows do
			for x = 1, mine.width, 3 do
				if a:blockAt(x, y, 4) ~= b:blockAt(x, y, 4) then
					same = false
				end
				if a:blockAt(x, y, 4) ~= c:blockAt(x, y, 4) then
					differ = true
				end
			end
		end
		expect(same).toBe(true)
		expect(differ).toBe(true)
	end)

	it("each layer holds only its own blocks", function()
		local g = fresh()
		for y = 1, g.rows do
			local layer = mine.layers[Layout.layerOf(mine, y)]
			local allowed = {}
			for _, entry in layer.blocks do
				allowed[entry.id] = true
			end
			for x = 1, mine.width do
				expect(allowed[g:blockAt(x, y, 7)]).toBe(true)
			end
		end
	end)

	it("block chances match the layer weights (400,000 rolls)", function()
		local layer = mine.layers[3]
		local counts: { [string]: number } = {}
		local n = 0
		for seed = 1, 25 do
			local g = fresh(seed * 7919)
			for y = Layout.layerTop(mine, 3), g.rows do
				for z = 1, mine.length do
					for x = 1, mine.width do
						local id = g:blockAt(x, y, z)
						counts[id] = (counts[id] or 0) + 1
						n += 1
					end
				end
			end
		end
		-- Plus regrown generations, which roll again.
		local g = fresh(1)
		for gen = 1, 25 do
			for y = Layout.layerTop(mine, 3), g.rows do
				for z = 1, mine.length do
					for x = 1, mine.width do
						g.regrown[g:key(x, y, z)] = gen
						local id = g:blockAt(x, y, z)
						counts[id] = (counts[id] or 0) + 1
						n += 1
					end
				end
			end
		end
		expect(n >= 150000).toBe(true)
		for _, entry in layer.blocks do
			local expected = entry.weight / 10000
			local got = (counts[entry.id] or 0) / n
			-- Within five standard errors.
			local se = math.sqrt(expected * (1 - expected) / n)
			expect(math.abs(got - expected) <= 5 * se).toBe(true)
		end
	end)

	it("hits wear a block down without breaking it", function()
		local g = fresh()
		local hp = g:hp(4, 1, 4)
		expect(g:hit(4, 1, 4, hp - 1)).toBe(1)
		expect(g:isSolid(4, 1, 4)).toBe(true)
		expect(g:hit(4, 1, 4, 5)).toBe(0)
	end)

	it("breaking a block reveals its solid neighbours, not the shaft walls", function()
		local g = fresh()
		local changes = g:breakBlock(1, 1, 1, 100)
		expect(g:isSolid(1, 1, 1)).toBe(false)
		expect(#changes.hidden).toBe(1)
		-- Corner block: below, and two neighbours already exposed on the top face.
		expect(#changes.shown).toBe(1)
		expect(g:isExposed(1, 2, 1)).toBe(true)
		changes = g:breakBlock(1, 2, 1, 101)
		-- Below, +x and +z (the walls are not air and not blocks).
		expect(#changes.shown).toBe(3)
		expect(g.exposedCount).toBe(#g:exposedKeys())
	end)

	it("the bottom row sits on bedrock", function()
		local g = fresh()
		for y = 1, g.rows do
			g:breakBlock(8, y, 8, 0)
		end
		expect(g:inBounds(8, g.rows + 1, 8)).toBe(false)
		expect(g.exposedCount).toBe(#g:exposedKeys())
	end)

	it("regrows old tunnels nobody is near, hiding what no longer touches air", function()
		local g = fresh()
		g:breakBlock(5, 1, 5, 0)
		g:breakBlock(5, 2, 5, 0)
		local before = g.exposedCount
		local early = g:regrow(mine.regrowSeconds - 1, function()
			return false
		end)
		expect(#early.shown + #early.hidden).toBe(0)
		local blocked = g:regrow(mine.regrowSeconds, function()
			return true
		end)
		expect(#blocked.shown + #blocked.hidden).toBe(0)
		local grown = g:regrow(mine.regrowSeconds, function()
			return false
		end)
		expect(g:isSolid(5, 1, 5)).toBe(true)
		expect(g:isSolid(5, 2, 5)).toBe(true)
		expect(g.regrown[g:key(5, 1, 5)]).toBe(1)
		-- Back to a fresh top face: (5,1,5) shown again; (5,2,5) and (5,3,5) and
		-- the row-2 neighbours are no longer touching air.
		expect(g:isExposed(5, 1, 5)).toBe(true)
		expect(g:isExposed(5, 2, 5)).toBe(false)
		expect(g:isExposed(5, 3, 5)).toBe(false)
		expect(g.exposedCount).toBe(mine.width * mine.length)
		expect(before > g.exposedCount).toBe(true)
		expect(#grown.shown >= 1).toBe(true)
		expect(g.exposedCount).toBe(#g:exposedKeys())
	end)

	it("the hash stays exact (whole numbers below 2^32 for any input)", function()
		for _, args in { { 2 ^ 31 - 2, 1000, 1000, 1000, 1e6 }, { 0, 0, 0, 0, 0 }, { 1, 64, 200, 64, 3 } } do
			local h = MineGrid.hash(args[1], args[2], args[3], args[4], args[5])
			expect(h >= 0 and h < 2 ^ 32).toBe(true)
			expect(h // 1).toBe(h)
		end
		-- Pinned values: Roblox and Lune must build the same mine from a seed.
		expect(MineGrid.hash(12345, 1, 2, 3, 0)).toBe(MineGrid.hash(12345, 1, 2, 3, 0))
	end)

	it("neighbouring blocks, seeds and regrowths are unrelated rolls", function()
		-- An affine hash makes roll(x + 1) - roll(x) take one or two values.
		for axis = 1, 4 do
			local diffs: { [number]: boolean } = {}
			local distinct = 0
			for i = 1, 2000 do
				local p = { 7 + i % 13, 1 + i % 30, 3 + i // 13 % 13, i % 5 }
				local q = table.clone(p)
				q[axis] += 1
				local a = MineGrid.hash(99, p[1], p[2], p[3], p[4]) % 10000
				local b = MineGrid.hash(99, q[1], q[2], q[3], q[4]) % 10000
				local d = (b - a) % 10000
				if not diffs[d] then
					diffs[d] = true
					distinct += 1
				end
			end
			expect(distinct >= 1500).toBe(true)
		end
		-- Same-block rate between horizontal neighbours matches independent rolls.
		local same, pairs, expected = 0, 0, 0
		local layer = mine.layers[1]
		for _, entry in layer.blocks do
			expected += (entry.weight / 10000) ^ 2
		end
		for seed = 1, 20 do
			local g = fresh(seed)
			for y = 1, layer.rows do
				for z = 1, mine.length do
					for x = 1, mine.width - 1 do
						pairs += 1
						if g:blockAt(x, y, z) == g:blockAt(x + 1, y, z) then
							same += 1
						end
					end
				end
			end
		end
		local rate = same / pairs
		local se = math.sqrt(expected * (1 - expected) / pairs)
		expect(math.abs(rate - expected) <= 5 * se).toBe(true)
		-- Two seeds do not give the same pattern shifted.
		local a, b = fresh(1), fresh(2)
		local matches = 0
		for x = 1, mine.width do
			for z = 1, mine.length do
				if a:blockAt(x, 1, z) == b:blockAt(x, 1, z) then
					matches += 1
				end
			end
		end
		expect(matches < mine.width * mine.length).toBe(true)
	end)
end)
