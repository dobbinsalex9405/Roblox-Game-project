--!strict
local Fakes = require("./Fakes")
local Odds = require("@core/Odds")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local BASIC: Odds.TableDef = {
	id = "BasicEgg",
	paid = false,
	outcomes = {
		{ id = "Chick", weight = 6000 },
		{ id = "Duckling", weight = 3000 },
		{ id = "Gosling", weight = 900 },
		{ id = "Phoenix", weight = 100 },
	},
}

local function totalOf(outcomes: { Odds.Outcome }): number
	local sum = 0
	for _, o in outcomes do
		sum += o.weight
	end
	return sum
end

local function percentTotal(display: Odds.Display): number
	-- Sum the shown strings exactly, in hundredths of a percent.
	local hundredths = 0
	for _, row in display.rows do
		local whole, frac = string.match(row.percent, "^(%d+)%.(%d%d)%%$")
		assert(whole and frac, `bad percent {row.percent}`)
		hundredths += tonumber(whole) :: number * 100 + tonumber(frac) :: number
	end
	return hundredths
end

describe("Odds", function()
	it("requires weights that total exactly 10,000", function()
		local odds = Odds.new()
		expect(function()
			odds:define({
				id = "Bad",
				paid = false,
				outcomes = { { id = "A", weight = 5000 }, { id = "B", weight = 4999 } },
			})
		end).toThrow("must total exactly 10000")
		expect(function()
			odds:define({
				id = "Frac",
				paid = false,
				outcomes = { { id = "A", weight = 9999.5 }, { id = "B", weight = 0.5 } },
			})
		end).toThrow("whole weight")
		expect(function()
			odds:define({
				id = "Dup",
				paid = false,
				outcomes = { { id = "A", weight = 5000 }, { id = "A", weight = 5000 } },
			})
		end).toThrow("twice")
	end)

	it("shows every outcome with percentages that total exactly 100.00%", function()
		local odds = Odds.new()
		odds:define(BASIC)
		local display = odds:display("BasicEgg", Fakes.player(1))
		expect(#display.rows).toBe(4)
		expect(display.rows[1].percent).toBe("60.00%")
		expect(display.rows[4].percent).toBe("1.00%")
		expect(percentTotal(display)).toBe(10000)
	end)

	it("the screen and the roll read one table", function()
		local odds = Odds.new()
		odds:define(BASIC)
		local p = Fakes.player(1)
		odds:setBoosts(p, "BasicEgg", { { id = "Luck", multipliers = { Phoenix = 3, Gosling = 2 } } })
		local shown = odds:display("BasicEgg", p)
		local effective = odds:effective("BasicEgg", p)
		for i, row in shown.rows do
			expect(row.weight).toBe(effective[i].weight)
		end
		expect(shown.boosts).toEqual({ "Luck" })
	end)

	it("a boost recomputes both the screen and the roll, still totalling 100%", function()
		local odds = Odds.new()
		odds:define(BASIC)
		local p, other = Fakes.player(1), Fakes.player(2)
		local notified = {}
		odds:onChanged(function(player, tableId)
			table.insert(notified, { player, tableId })
		end)
		odds:setBoosts(p, "BasicEgg", { { id = "Luck", multipliers = { Phoenix = 3 } } })
		expect(#notified).toBe(1)
		local boosted = odds:effective("BasicEgg", p)
		expect(totalOf(boosted)).toBe(10000)
		-- 100 * 3 = 300 raw out of 10200 raw total => 294.1 => 294
		expect(boosted[4].weight).toBe(294)
		expect(percentTotal(odds:display("BasicEgg", p))).toBe(10000)
		-- Another player is unaffected.
		expect(odds:effective("BasicEgg", other)[4].weight).toBe(100)
		-- Removing the boost restores the base table.
		odds:setBoosts(p, "BasicEgg", {})
		expect(odds:effective("BasicEgg", p)[4].weight).toBe(100)
	end)

	it("outcomes a player can only get once drop out of their table", function()
		local odds = Odds.new()
		odds:define(BASIC)
		local p = Fakes.player(1)
		odds:setExcluded(p, "BasicEgg", { "Phoenix" })
		local effective = odds:effective("BasicEgg", p)
		expect(effective[4].weight).toBe(0)
		expect(totalOf(effective)).toBe(10000)
		for _ = 1, 2000 do
			expect(odds:roll("BasicEgg", p) ~= "Phoenix").toBe(true)
		end
	end)

	it("normalize keeps every possible outcome at 0.01% or more", function()
		local result = Odds.normalize({ { id = "Huge", weight = 1e9 }, { id = "Tiny", weight = 1 } })
		expect(result[2].weight).toBe(1)
		expect(totalOf(result)).toBe(10000)
		local many = {}
		for i = 1, 37 do
			table.insert(many, { id = `O{i}`, weight = 1 })
		end
		expect(totalOf(Odds.normalize(many))).toBe(10000)
	end)

	it("1M rolls match the published odds", function()
		local seed = 12345
		-- Park-Miller generator so the test is deterministic.
		local function randomInteger(min: number, max: number): number
			seed = (seed * 16807) % 2147483647
			return min + seed % (max - min + 1)
		end
		local odds = Odds.new({ randomInteger = randomInteger })
		odds:define(BASIC)
		local p = Fakes.player(1)
		local counts: { [string]: number } = {}
		local n = 1000000
		for _ = 1, n do
			local id = odds:roll("BasicEgg", p)
			counts[id] = (counts[id] or 0) + 1
		end
		for _, o in BASIC.outcomes do
			local prob = o.weight / 10000
			local expected = n * prob
			local sigma = math.sqrt(n * prob * (1 - prob))
			-- Five standard deviations: a correct roller fails this about once in 3.5 million runs.
			expect(math.abs((counts[o.id] or 0) - expected)).toBeAtMost(5 * sigma)
		end
	end)

	it("formats percentages exactly", function()
		expect(Odds.formatPercent(1)).toBe("0.01%")
		expect(Odds.formatPercent(10000)).toBe("100.00%")
		expect(Odds.formatPercent(1234)).toBe("12.34%")
	end)
end)

describe("Odds out of a larger total", function()
	local RARE: Odds.TableDef = {
		id = "RareEgg",
		paid = false,
		total = 100000,
		outcomes = {
			{ id = "Chick", weight = 92000 },
			{ id = "Gosling", weight = 7980 },
			{ id = "Dragonling", weight = 18 },
			{ id = "Phoenix", weight = 2 },
		},
	}

	it("accepts a power-of-ten total and checks the weights against it", function()
		local odds = Odds.new()
		odds:define(RARE)
		expect(function()
			odds:define({
				id = "Short",
				paid = false,
				total = 100000,
				outcomes = { { id = "A", weight = 9000 }, { id = "B", weight = 1000 } },
			})
		end).toThrow("must total exactly 100000")
		expect(function()
			odds:define({
				id = "Odd",
				paid = false,
				total = 12345,
				outcomes = { { id = "A", weight = 12345 } },
			})
		end).toThrow("power of ten")
	end)

	it("shows exact percentages with three decimals and a 1 in N reading", function()
		local odds = Odds.new()
		odds:define(RARE)
		local display = odds:display("RareEgg", "p")
		expect(display.total).toBe(100000)
		local byId = {}
		for _, row in display.rows do
			byId[row.id] = row
		end
		expect(byId.Chick.percent).toBe("92.000%")
		expect(byId.Phoenix.percent).toBe("0.002%")
		expect(byId.Phoenix.oneIn).toBe("1 in 50,000")
		expect(byId.Dragonling.oneIn).toBe("1 in 5,556")
		expect(byId.Gosling.oneIn).toBe("1 in 12.5")
		expect(byId.Chick.oneIn).toBe("1 in 1.1")
	end)

	it("rolls across the whole total, so the rarest outcome can still come up", function()
		local picks = { 100000, 99999, 99998, 1 }
		local i = 0
		local odds = Odds.new({
			randomInteger = function(min: number, max: number): number
				expect(min).toBe(1)
				expect(max).toBe(100000)
				i += 1
				return picks[i]
			end,
		})
		odds:define(RARE)
		expect(odds:roll("RareEgg", "p")).toBe("Phoenix")
		expect(odds:roll("RareEgg", "p")).toBe("Phoenix")
		expect(odds:roll("RareEgg", "p")).toBe("Dragonling")
		expect(odds:roll("RareEgg", "p")).toBe("Chick")
	end)

	it("keeps boosted tables on the same total", function()
		local odds = Odds.new()
		odds:define(RARE)
		odds:setBoosts("p", "RareEgg", { { id = "Luck", multipliers = { Phoenix = 2, Dragonling = 2 } } })
		local sum = 0
		for _, o in odds:effective("RareEgg", "p") do
			sum += o.weight
		end
		expect(sum).toBe(100000)
		expect(Odds.formatPercent(1, 1000000)).toBe("0.0001%")
		expect(Odds.formatPercent(5, 100)).toBe("5%")
	end)
end)
