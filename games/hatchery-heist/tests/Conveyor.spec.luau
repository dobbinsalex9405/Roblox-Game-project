--!strict
local Conveyor = require("../src/shared/Conveyor")
local economy = require("../config/economy")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local belt = economy.conveyor

describe("Conveyor", function()
	it("hashes exactly like the reference lowbias32 (no lost precision)", function()
		-- Values from a Python reference with arbitrary-precision integers.
		expect(Conveyor.mix(0)).toBe(0)
		expect(Conveyor.mix(1)).toBe(1753845952)
		expect(Conveyor.mix(123456789)).toBe(2834422664)
	end)

	it("is the same belt for everyone at the same time", function()
		local a = Conveyor.onBelt(1_800_000_000.25, belt)
		local b = Conveyor.onBelt(1_800_000_000.25, belt)
		expect(#a).toBe(#b)
		for i, egg in a do
			expect(egg.index).toBe(b[i].index)
			expect(egg.eggId).toBe(b[i].eggId)
		end
	end)

	it("holds travelSeconds / spawnSeconds eggs, each between start and end", function()
		local eggs = Conveyor.onBelt(1_800_000_001.7, belt)
		local expected = math.floor(belt.travelSeconds / belt.spawnSeconds)
		expect(#eggs >= expected and #eggs <= expected + 1).toBe(true)
		for _, egg in eggs do
			expect(egg.progress >= 0 and egg.progress <= 1).toBe(true)
		end
	end)

	it("picks egg kinds close to the configured weights", function()
		local counts: { [string]: number } = {}
		local n = 20000
		for i = 1, n do
			local id = Conveyor.eggAt(600_000_000 + i, belt)
			counts[id] = (counts[id] or 0) + 1
		end
		local total = 0
		for _, w in belt.weights do
			total += w
		end
		for id, w in belt.weights do
			local share = (counts[id] or 0) / n
			expect(math.abs(share - w / total) < 0.02).toBe(true)
		end
	end)

	it("takes turns between the lanes, so each gets an egg every spawnSeconds * lanes", function()
		local counts = {}
		for i = 1, 100 do
			local lane = Conveyor.laneOf(1000 + i, belt)
			expect(lane >= 1 and lane <= belt.lanes).toBe(true)
			counts[lane] = (counts[lane] or 0) + 1
		end
		for lane = 1, belt.lanes do
			expect(counts[lane]).toBe(100 / belt.lanes)
		end
		expect(Conveyor.laneOf(1000, belt) == Conveyor.laneOf(1001, belt)).toBe(false)
	end)

	it("only sells eggs that are on the belt, with a little latency allowance", function()
		local index = 600_000_000
		local appears = Conveyor.spawnTime(index, belt)
		expect(Conveyor.canBuy(index, appears + 1, belt)).toBe(true)
		expect(Conveyor.canBuy(index, appears + belt.travelSeconds + 1, belt)).toBe(true)
		expect(Conveyor.canBuy(index, appears + belt.travelSeconds + 5, belt)).toBe(false)
		expect(Conveyor.canBuy(index, appears - 10, belt)).toBe(false)
	end)

	it("offers Buy only on eggs you can afford, unless you can afford none", function()
		-- 60 coins, cheapest egg 50: the 50 egg shows Buy, the 2,500 egg does not.
		expect(Conveyor.offered(50, 60, 50)).toBe(true)
		expect(Conveyor.offered(2500, 60, 50)).toBe(false)
		expect(Conveyor.offered(2500, 2500, 50)).toBe(true)
		-- 20 coins: every egg shows Buy, so pressing it says what eggs cost.
		expect(Conveyor.offered(50, 20, 50)).toBe(true)
		expect(Conveyor.offered(2500, 20, 50)).toBe(true)
	end)
end)
