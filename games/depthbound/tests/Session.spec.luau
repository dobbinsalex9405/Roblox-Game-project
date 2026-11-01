--!strict
-- Whole dives through the real core services, a real mine and Actions. The M2
-- bar is "10 minutes of play survive a rejoin"; the rest pins down every rule
-- the server enforces (reach, swing speed, exposure, pick tier, oil).
local Fakes = require("../../../packages/core/tests/Fakes")
local Gear = require("../src/shared/Gear")
local Harness = require("./Harness")
local Lamp = require("../src/shared/Lamp")
local Layout = require("../src/shared/Layout")
local Pack = require("../src/shared/Pack")
local Util = require("@core/Util")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local config = Harness.config
local mine, blocks, gear, dive = config.mine, config.blocks, config.gear, config.dive

-- Digs straight down column (x, z) from the top face for `rows` rows, standing
-- in each cell it opens. Returns false and the refusal if a swing is refused.
local function digDown(h: any, p: any, x: number, z: number, rows: number): (boolean, string?)
	h.standOn(p, x, z)
	h.wait(p, 0.2)
	for y = 1, rows do
		local ok, err = h.mine(p, x, y, z)
		if not ok then
			return false, err
		end
		h.stand(p, x, y, z)
	end
	return true, nil
end

-- Fills the pack directly (for rules that do not care how ore got there).
local function give(h: any, p: any, items: { [string]: number })
	h.data:update(p, function(d)
		for id, n in items do
			d.pack[id] = (d.pack[id] or 0) + n
		end
	end)
end

local function phase(h: any, p: any): string
	return h.session(p).phase
end

describe("Depthbound dives", function()
	it("the lamp lights on the mine and burns faster deeper", function()
		local h = Harness.new()
		local p = Fakes.player(1)
		h.join(p)
		expect(phase(h, p)).toBe("Camp")
		h.wait(p, 5)
		expect(h.oil(p)).toBe(gear.lamp[1].oilSeconds) -- nothing burns at camp
		h.standOn(p, 8, 8)
		h.wait(p, 0.2)
		expect(phase(h, p)).toBe("Diving")
		h.wait(p, 10)
		expect(h.oil(p)).toBeCloseTo(gear.lamp[1].oilSeconds - 10 * mine.layers[1].oilPerSecond, 1e-3)
		-- Pretend the player is deep in layer 2 (the dig itself is tested below).
		h.stand(p, 8, Layout.layerTop(mine, 2) + 1, 8)
		h.wait(p, 0.2)
		expect(h.session(p).meter.rate).toBe(mine.layers[2].oilPerSecond)
	end)

	it("climbing out keeps the whole pack, then selling pays its value", function()
		local h = Harness.new()
		local p = Fakes.player(1)
		h.join(p)
		local x, z = h.columnWithOre(6)
		expect((digDown(h, p, x, z, 6))).toBe(true)
		local d = h.get(p)
		local pieces = Pack.count(d.pack)
		local worth = Pack.value(d.pack, blocks)
		expect(pieces >= 1).toBe(true)
		expect(#h.ores).toBe(pieces)
		expect(h.actions:climb(p)).toBe(true)
		expect(h.climbingNow).toBe(true)
		expect(h.session(p).climbEndsAt - h.clock.now()).toBeCloseTo(Lamp.climbSeconds(dive, 6), 1e-3)
		-- No mining on the rope.
		expect(select(2, h.actions:hit(p, x, 7, z))).toBe("climbing")
		h.wait(p, Lamp.climbSeconds(dive, 6) + 0.2)
		expect(phase(h, p)).toBe("Camp")
		expect(h.climbingNow).toBe(false)
		expect(h.rescues).toBe(1)
		expect(Pack.count(h.get(p).pack)).toBe(pieces)
		expect(h.get(p).stats.dives).toBe(1)
		expect(h.actions:sell(p)).toBe(true)
		expect(h.get(p).coins).toBe(worth)
		expect(Pack.count(h.get(p).pack)).toBe(0)
		expect(h.sales[1].coins).toBe(worth)
		-- Selling an empty pack is refused.
		expect((h.actions:sell(p))).toBe(false)
	end)

	it("the lamp running dry keeps a quarter of the pack and wakes you at camp", function()
		local h = Harness.new()
		local p = Fakes.player(1)
		h.join(p)
		h.standOn(p, 8, 8)
		h.wait(p, 0.2)
		give(h, p, { Coal = 9, Copper = 3 })
		h.wait(p, gear.lamp[1].oilSeconds + 1)
		expect(phase(h, p)).toBe("Camp")
		expect(#h.lampOuts).toBe(1)
		expect(h.lampOuts[1].kept).toBe(3)
		expect(h.lampOuts[1].dropped).toBe(9)
		expect(Pack.count(h.get(p).pack)).toBe(3)
		expect(h.get(p).stats.lampOuts).toBe(1)
		expect(h.rescues).toBe(1)
		-- Back at camp the lamp is full again.
		expect(h.oil(p)).toBe(gear.lamp[1].oilSeconds)
	end)

	it("a climb that outlasts the oil is a lamp-out, judged when the oil ran dry", function()
		local h = Harness.new()
		local p = Fakes.player(1)
		h.join(p)
		expect((digDown(h, p, 2, 2, 10))).toBe(true)
		give(h, p, { Coal = 4 })
		-- Burn down to just under what the climb needs.
		local need = Lamp.climbOil(dive, 10)
		local burn = (h.oil(p) - need + 0.5) / mine.layers[1].oilPerSecond
		h.clock.advance(burn)
		expect(h.actions:climb(p)).toBe(true)
		h.wait(p, Lamp.climbSeconds(dive, 10) + 1)
		expect(#h.lampOuts).toBe(1)
		expect(h.get(p).stats.dives).toBe(0)
		expect(Pack.count(h.get(p).pack)).toBe(1)
	end)

	it("a climb that just makes it is safe even if the step comes late", function()
		local h = Harness.new()
		local p = Fakes.player(1)
		h.join(p)
		expect((digDown(h, p, 3, 3, 4))).toBe(true)
		local need = Lamp.climbOil(dive, 4)
		h.clock.advance((h.oil(p) - need - 0.05) / mine.layers[1].oilPerSecond)
		expect(h.actions:climb(p)).toBe(true)
		-- One late step, well after both the climb and the oil would have ended.
		h.clock.advance(Lamp.climbSeconds(dive, 4) + 3)
		h.actions:step(p)
		expect(#h.lampOuts).toBe(0)
		expect(h.get(p).stats.dives).toBe(1)
	end)

	it("walking out ends the dive safely; Auto-Sell sells on the way", function()
		local h = Harness.new({ perks = { biggerPack = false, betterLamp = false, autoSell = true } })
		local p = Fakes.player(1)
		h.join(p)
		h.standOn(p, 1, 1)
		h.wait(p, 0.2)
		give(h, p, { Copper = 2 })
		h.toCamp(p)
		h.wait(p, 0.2)
		expect(phase(h, p)).toBe("Camp")
		expect(h.rescues).toBe(0)
		expect(h.get(p).coins).toBe(2 * blocks.Copper.value)
		expect(Pack.count(h.get(p).pack)).toBe(0)
		local ends = h.eventsOf("custom")
		local found = false
		for _, e in ends do
			if e[1] == "Dive:End" and e[3][1] == "WalkedOut" then
				found = true
			end
		end
		expect(found).toBe(true)
	end)

	it("dying in the mine is a lamp-out, so a reset never saves the haul", function()
		local h = Harness.new()
		local p = Fakes.player(1)
		h.join(p)
		h.standOn(p, 8, 8)
		h.wait(p, 0.2)
		give(h, p, { Iron = 8 })
		h.actions:died(p)
		expect(#h.lampOuts).toBe(1)
		expect(h.get(p).pack.Iron).toBe(2)
		-- Dying at camp costs nothing.
		h.actions:died(p)
		expect(#h.lampOuts).toBe(1)
	end)

	it("leaving mid-dive keeps the pack only if the oil left could climb out", function()
		local store = Fakes.store()
		local h = Harness.new({ store = store })
		local p = Fakes.player(1)
		h.join(p)
		expect((digDown(h, p, 4, 4, 3))).toBe(true)
		give(h, p, { Coal = 8 })
		local before = Pack.count(h.get(p).pack)
		h.leave(p) -- plenty of oil left
		h.join(p)
		expect(Pack.count(h.get(p).pack)).toBe(before)
		expect(h.get(p).stats.dives).toBe(1)

		expect((digDown(h, p, 5, 5, 8))).toBe(true)
		local need = Lamp.climbOil(dive, 8)
		h.clock.advance((h.oil(p) - need + 1) / mine.layers[1].oilPerSecond)
		local carried = Pack.count(h.get(p).pack)
		h.leave(p) -- too little oil: same as a lamp-out
		h.join(p)
		expect(Pack.count(h.get(p).pack)).toBe(math.floor(carried * dive.lampOut.keepFraction + 1e-9))
		expect(h.get(p).stats.lampOuts).toBe(1)
	end)
end)

describe("Depthbound swing checks", function()
	it("refuses blocks out of reach, not exposed, or outside the mine", function()
		local h = Harness.new()
		local p = Fakes.player(1)
		h.join(p)
		h.standOn(p, 1, 1)
		h.wait(p, 0.2)
		expect(select(2, h.actions:hit(p, 10, 1, 10))).toBe("out of reach")
		expect(select(2, h.actions:hit(p, 1, 3, 1))).toBe("block not exposed")
		expect(select(2, h.actions:hit(p, 0, 1, 1))).toBe("outside the mine")
		-- A teleport next to deep ore still cannot reach into solid rock.
		h.stand(p, 8, 30, 8)
		expect(select(2, h.actions:hit(p, 8, 31, 8))).toBe("block not exposed")
	end)

	it("refuses swings faster than the pick allows", function()
		local h = Harness.new()
		local p = Fakes.player(1)
		h.join(p)
		h.standOn(p, 6, 6)
		h.wait(p, 0.2)
		local hp = h.grid:hp(6, 1, 6)
		expect(hp >= 2).toBe(true)
		expect(h.actions:hit(p, 6, 1, 6)).toBe(true)
		expect(select(2, h.actions:hit(p, 6, 1, 6))).toBe("swing too fast")
		h.clock.advance(dive.swingSeconds * dive.swingTolerance)
		expect(h.actions:hit(p, 6, 1, 6)).toBe(true)
	end)

	it("deeper layers need a better pick", function()
		local h = Harness.new()
		local p = Fakes.player(1)
		h.join(p)
		local bottom = mine.layers[1].rows
		expect((digDown(h, p, 7, 7, bottom))).toBe(true)
		local ok, err = h.mine(p, 7, bottom + 1, 7)
		expect(ok).toBe(false)
		expect(err).toBe("pick too weak")
		expect(h.notices[#h.notices]).toContain(gear.pick[mine.layers[2].minPickTier].name)
		h.data:update(p, function(d)
			d.gear.pick = mine.layers[2].minPickTier
		end)
		expect((h.mine(p, 7, bottom + 1, 7))).toBe(true)
		expect(h.get(p).layersReached).toBe(2)
		expect(h.get(p).deepestRow).toBe(bottom + 1)
	end)

	it("a full pack refuses ore but still digs through rock", function()
		local h = Harness.new()
		local p = Fakes.player(1)
		h.join(p)
		h.standOn(p, 1, 1)
		h.wait(p, 0.2)
		give(h, p, { Coal = gear.pack[1].capacity })
		local oreAt, rockAt = nil, nil
		for x = 1, 3 do
			for z = 1, 3 do
				local value = blocks[h.grid:blockAt(x, 1, z)].value
				if value > 0 and oreAt == nil then
					oreAt = { x, z }
				elseif value == 0 and rockAt == nil then
					rockAt = { x, z }
				end
			end
		end
		if oreAt then
			expect(select(2, h.actions:hit(p, oreAt[1], 1, oreAt[2]))).toBe("pack full")
		end
		expect(rockAt ~= nil).toBe(true)
		local rock = rockAt :: { number }
		expect((h.mine(p, rock[1], 1, rock[2]))).toBe(true)
	end)

	it("selling and upgrading only work at camp", function()
		local h = Harness.new()
		local p = Fakes.player(1)
		h.join(p)
		h.data:update(p, function(d)
			d.coins = 1000
		end)
		give(h, p, { Coal = 1 })
		h.standOn(p, 3, 3)
		h.wait(p, 0.2)
		expect(select(2, h.actions:sell(p))).toBe("not at camp")
		expect(select(2, h.actions:upgrade(p, "Pick"))).toBe("not at camp")
		h.toCamp(p)
		h.wait(p, 0.2)
		expect(h.actions:upgrade(p, "Pick")).toBe(true)
		expect(h.get(p).gear.pick).toBe(2)
		expect(h.get(p).coins).toBe(1000 - gear.pick[2].cost)
	end)

	it("a lamp upgrade fills the bigger lamp at once", function()
		local h = Harness.new()
		local p = Fakes.player(1)
		h.join(p)
		h.data:update(p, function(d)
			d.coins = gear.lamp[2].cost
		end)
		expect(h.actions:upgrade(p, "Lamp")).toBe(true)
		expect(h.oil(p)).toBe(gear.lamp[2].oilSeconds)
		expect(h.dives[#h.dives].capacity).toBe(gear.lamp[2].oilSeconds)
	end)

	it("two players can never both break the same block", function()
		local h = Harness.new()
		local a, b = Fakes.player(1), Fakes.player(2)
		h.join(a)
		h.join(b)
		h.standOn(a, 5, 5)
		h.standOn(b, 5, 6)
		h.actions:step(a)
		h.actions:step(b)
		local broke = 0
		for _ = 1, 100 do
			for _, p in { a, b } do
				if h.grid:isSolid(5, 1, 5) then
					h.actions:hit(p, 5, 1, 5)
				end
			end
			h.clock.advance(dive.swingSeconds)
		end
		broke = h.get(a).stats.blocksMined + h.get(b).stats.blocksMined
		expect(broke).toBe(1)
	end)
end)

-- A simple player: dives in its own column, takes ore beside its shaft, digs
-- deeper while the pick allows, climbs out with a safety margin or a full
-- pack, sells, and buys the cheapest upgrade it can afford.
local function play(h: any, p: any, seconds: number, column: number)
	local stopAt = h.clock.now() + seconds
	local x, z = column, column
	local row = 0
	while h.clock.now() < stopAt do
		local s = h.session(p)
		local d = h.get(p)
		if s.phase == "Camp" then
			h.toCamp(p)
			h.actions:step(p)
			if Pack.count(d.pack) > 0 then
				h.actions:sell(p)
			end
			local bought = true
			while bought do
				bought = false
				local cheapest: string? = nil
				local price = math.huge
				for _, kind in Gear.KINDS do
					local nextTier = Gear.nextTier(h.get(p), gear, kind)
					if nextTier and nextTier.cost < price then
						cheapest, price = kind, nextTier.cost
					end
				end
				if cheapest and h.get(p).coins >= price then
					bought = (h.actions:upgrade(p, cheapest :: any))
				end
			end
			-- Next dive: a fresh column each time, so the bot never reuses its shaft.
			x = x % mine.width + 1
			z = (z + 3) % mine.length + 1
			row = 0
			h.standOn(p, x, z)
			h.wait(p, 0.2)
		elseif s.phase == "Climbing" then
			h.wait(p, 0.2)
		else
			local capacity = Gear.packCapacity(d, gear, h.perks)
			local need = Lamp.climbOil(dive, row) * 1.2 + 4
			local nextLayer = mine.layers[Layout.layerOf(mine, row + 1)]
			local canGoDeeper = row < h.grid.rows and Gear.tier(d, "Pick") >= nextLayer.minPickTier
			if h.oil(p) <= need or Pack.count(d.pack) >= capacity or not canGoDeeper then
				h.actions:climb(p)
				h.wait(p, 0.2)
			else
				-- Ore beside the shaft first, then down.
				local took = false
				if row >= 1 then
					for _, n in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
						local nx, nz = x + n[1], z + n[2]
						if
							h.grid:isExposed(nx, row, nz)
							and blocks[h.grid:blockAt(nx, row, nz)].value > 0
							and Pack.count(h.get(p).pack) < capacity
						then
							h.mine(p, nx, row, nz)
							took = true
							break
						end
					end
				end
				if not took then
					if h.grid:isSolid(x, row + 1, z) then
						h.mine(p, x, row + 1, z)
					end
					row += 1
					h.stand(p, x, row, z)
					h.wait(p, 0.2)
				end
			end
		end
	end
end

-- The parts of the save a rejoin must keep exactly.
local function kept(d: { [string]: any }): { [string]: any }
	local out = Util.deepCopy(d)
	out.meta = nil
	out.receipts = nil
	out.stats.playSeconds = nil
	return out
end

describe("Depthbound sessions", function()
	it("10 minutes of play survive a rejoin, with real progress", function()
		local store = Fakes.store()
		local h = Harness.new({ store = store, seed = 2026 })
		local p = Fakes.player(42)
		h.join(p)
		play(h, p, 600, 1)
		-- End the session cleanly at camp.
		local s = h.session(p)
		if s.phase ~= "Camp" then
			if s.phase == "Diving" then
				h.actions:climb(p)
			end
			h.wait(p, 30)
		end
		local d = h.get(p)
		expect(d.stats.blocksMined >= 100).toBe(true)
		expect(d.stats.dives >= 5).toBe(true)
		expect(d.stats.oreSold >= 30).toBe(true)
		local upgrades = d.gear.pick + d.gear.pack + d.gear.lamp - 3
		expect(upgrades >= 3).toBe(true)
		expect(d.layersReached >= 2).toBe(true)
		local snapshot = kept(d)
		h.leave(p)

		local again = Harness.new({ store = store, seed = 7 })
		again.join(p)
		expect(kept(again.get(p))).toEqual(snapshot)
		expect(again.get(p).stats.playSeconds >= 600).toBe(true)
	end)

	it("reports the onboarding funnel once per step, in order", function()
		local h = Harness.new()
		local p = Fakes.player(5)
		h.join(p)
		play(h, p, 240, 3)
		local names = {}
		for _, e in h.eventsOf("onboarding") do
			table.insert(names, e[2])
		end
		expect(names[1]).toBe("Joined")
		expect(names[2]).toBe("FirstBlockMined")
		expect(table.find(names, "FirstSale") ~= nil).toBe(true)
		expect(table.find(names, "FirstUpgrade") ~= nil).toBe(true)
		local seen = {}
		for _, name in names do
			expect(seen[name]).toBeNil()
			seen[name] = true
		end
	end)

	it("old tunnels grow back once nobody is near", function()
		local h = Harness.new()
		local p = Fakes.player(1)
		h.join(p)
		expect((digDown(h, p, 9, 9, 3))).toBe(true)
		h.actions:climb(p)
		h.wait(p, Lamp.climbSeconds(dive, 3) + 0.4)
		h.clock.advance(mine.regrowSeconds)
		h.actions:regrowMine()
		expect(h.grid:isSolid(9, 1, 9)).toBe(true)
		expect(h.grid:isSolid(9, 3, 9)).toBe(true)
		expect(h.grid.exposedCount).toBe(mine.width * mine.length)
	end)
end)
