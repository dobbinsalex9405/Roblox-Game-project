--!strict
-- The claw machine's numbers (shared/Claw.luau): prices, the odds tables the
-- server rolls and shows, the 10- and 100-pull promises and pity.
local Charms = require("../src/shared/Charms")
local Claw = require("../src/shared/Claw")
local DataTemplate = require("../src/shared/DataTemplate")
local Odds = require("@core/Odds")
local Util = require("@core/Util")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local config = require("../config/charms")

local function save(): { [string]: any }
	return Util.deepCopy(DataTemplate.template) :: any
end

local function tableById(id: string): any
	for _, def in Claw.oddsTables(config) do
		if def.id == id then
			return def
		end
	end
	error(`no table {id}`)
end

local function rankOf(id: string): number
	return (Charms.def(config, id) :: Charms.Def).rank
end

-- A roll that always gives the first charm of a table, or a chosen one.
local function rollFirst(tableId: string): string
	return tableById(tableId).outcomes[1].id
end

describe("Claw prices", function()
	it("a pull costs 5 minutes of the best income ever, at least 5,000 coins, three digits", function()
		expect(Claw.unitPrice(0, config)).toBe(5000)
		expect(Claw.unitPrice(10, config)).toBe(5000) -- 3,000 is under the floor
		expect(Claw.unitPrice(1234.5, config)).toBe(370000) -- 370,350 rounded down
		expect(Claw.price(1234.5, config, 10)).toBe(370000 * 9)
		expect(Claw.price(1234.5, config, 100)).toBe(370000 * 80)
	end)

	it("the fusing fee is a tenth of a pull, and the Charm Counter sells up to Rare", function()
		expect(Claw.fuseFee(0, config)).toBe(500)
		expect(Claw.counterPrice(0, config, "Common")).toBe(5000)
		expect(Claw.counterPrice(0, config, "Uncommon")).toBe(20000)
		expect(Claw.counterPrice(0, config, "Rare")).toBe(50000)
		expect(Claw.counterPrice(0, config, "Ultra Rare")).toBeNil()
	end)

	it("the best income never goes down", function()
		local d = save()
		Claw.notePeak(d, 50)
		Claw.notePeak(d, 20)
		expect(d.incomePeak).toBe(50)
		Claw.notePeak(d, 0 / 0)
		expect(d.incomePeak).toBe(50)
	end)

	it("the Robux pulls are 10 and 100 pulls", function()
		expect(Claw.productPulls(config, "ClawPull10")).toBe(10)
		expect(Claw.productPulls(config, "ClawPull100")).toBe(100)
		expect(Claw.productPulls(config, "CoinPack")).toBeNil()
	end)
end)

describe("Claw odds", function()
	it("every table is paid, valid and totals exactly 100,000", function()
		for _, def in Claw.oddsTables(config) do
			expect(def.paid).toBe(true)
			Odds.validate(def :: any)
			local sum = 0
			for _, o in def.outcomes do
				sum += o.weight
				expect(o.weight > 0).toBe(true)
			end
			expect(sum).toBe(100000)
		end
	end)

	it("each tier's share is exact and split evenly across the three active kinds", function()
		local main = tableById(Claw.TABLE)
		expect(#main.outcomes).toBe(21)
		local byTier: { [string]: { number } } = {}
		for _, o in main.outcomes do
			local def = Charms.def(config, o.id) :: Charms.Def
			byTier[def.tier] = byTier[def.tier] or {}
			table.insert(byTier[def.tier], o.weight)
		end
		for tier, weight in config.claw.tierWeights do
			local parts = byTier[tier]
			local sum = 0
			for _, w in parts do
				sum += w
			end
			expect(sum).toBe(weight)
			expect(#parts).toBe(3)
			-- Evenly: no two kinds differ by more than one.
			expect(math.max(table.unpack(parts)) - math.min(table.unpack(parts)) <= 1).toBe(true)
		end
		-- The shown percentages add up to exactly 100%.
		local odds = Odds.new()
		odds:define(main)
		local display = odds:display(Claw.TABLE, {})
		local thousandths = 0
		for _, row in display.rows do
			local whole, frac = string.match(row.percent, "^(%d+)%.(%d+)%%$")
			assert(whole and frac, row.percent)
			thousandths += tonumber(whole) :: number * 1000 + tonumber(frac) :: number
		end
		expect(thousandths).toBe(100000)
	end)

	it("the promised and pity tables hold only their tier and rarer", function()
		for tier, id in Claw.FLOOR_TABLES do
			local lowest = table.find(config.tiers, tier) :: number
			for _, o in tableById(id).outcomes do
				expect(rankOf(o.id) >= lowest).toBe(true)
			end
		end
	end)

	it("never offers a charm of a kind that is still asleep", function()
		for _, def in Claw.oddsTables(config) do
			for _, o in def.outcomes do
				local c = Charms.def(config, o.id) :: Charms.Def
				expect(Charms.isActive(config, c.kind)).toBe(true)
			end
		end
	end)
end)

describe("Claw pulls", function()
	it("a 10-pull with nothing Rare or better rolls its last pull from Rare and up", function()
		local d = save()
		local asked: { string } = {}
		local got = Claw.pull(d, config, 10, function(tableId)
			table.insert(asked, tableId)
			return rollFirst(tableId)
		end, 100, "claw")
		assert(got)
		expect(#got).toBe(10)
		expect(asked[9]).toBe(Claw.TABLE)
		expect(asked[10]).toBe("ClawRarePlus")
		expect(rankOf(got[10].id) >= 3).toBe(true)
		expect(d.clawPulls).toBe(10)
		expect(Charms.bagCount(d)).toBe(10)
	end)

	it("a 10-pull that already had a Rare keeps its last pull ordinary", function()
		local d = save()
		local asked: { string } = {}
		local n = 0
		Claw.pull(d, config, 10, function(tableId)
			n += 1
			table.insert(asked, tableId)
			return if n == 3 then "HoneyPot" else rollFirst(tableId)
		end, 100, "claw")
		expect(asked[10]).toBe(Claw.TABLE)
	end)

	it("a 100-pull promises an Epic or better", function()
		local d = save()
		local got = Claw.pull(d, config, 100, rollFirst, 100, "claw")
		assert(got)
		expect(Claw.bestRank(config, got) >= 5).toBe(true)
	end)

	it("pity: 199 pulls without a Legendary make the 200th Legendary or better, then it resets", function()
		local d = save()
		d.clawPity = 198
		expect(Claw.pityLeft(d, config)).toBe(2)
		local got = Claw.pull(d, config, 1, rollFirst, 100, "claw")
		assert(got)
		expect(d.clawPity).toBe(199)
		expect(Claw.pityLeft(d, config)).toBe(1)
		local asked: string? = nil
		got = Claw.pull(d, config, 1, function(tableId)
			asked = tableId
			return rollFirst(tableId)
		end, 100, "claw")
		assert(got)
		expect(asked).toBe("ClawLegendaryPlus")
		expect(rankOf(got[1].id) >= 6).toBe(true)
		expect(d.clawPity).toBe(0)
	end)

	it("a refused roll part-way changes nothing", function()
		local d = save()
		local n = 0
		local got, refusal = Claw.pull(d, config, 10, function(tableId)
			n += 1
			return if n == 5 then nil else rollFirst(tableId)
		end, 100, "claw")
		expect(got).toBeNil()
		expect(refusal).toBe("The claw machine isn't available to you.")
		expect(Charms.bagCount(d)).toBe(0)
		expect(d.clawPulls).toBe(0)
		expect(d.clawPity).toBe(0)
	end)
end)
