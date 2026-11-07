--!strict
-- Luck on every egg: with the Luck Boost, any Clover, or both, the odds a
-- player is shown are exactly the odds they roll, every table still totals
-- exactly, and no boosted creature ever gets more than its base weight times
-- its boost (capped at x3 overall), even after rounding to whole numbers.
local Charms = require("../src/shared/Charms")
local DataTemplate = require("../src/shared/DataTemplate")
local Eggs = require("../src/shared/Eggs")
local Harness = require("./Harness")
local Odds = require("@core/Odds")
local Util = require("@core/Util")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local config = Harness.config
local charms = config.charms
local species = config.creatures.species
local luckBoost = require("../config/monetization").boosts.LuckBoost

local ALLOW = {
	paidRandomAllowed = function()
		return true
	end,
}

-- Every Clover tier, plus none.
local function clovers(): { string | false }
	local out: { string | false } = { false }
	for _, c in charms.charms do
		if c.kind == "Clover" then
			table.insert(out, c.id)
		end
	end
	return out
end

-- The boost lists one combination gives one egg, by source.
local function boostsFor(egg: any, withLuckBoost: boolean, clover: string | false): { [string]: { any } }
	local sources: { [string]: { any } } = { luckboost = {}, charms = {} }
	if withLuckBoost and table.find(luckBoost.eggs, egg.id) then
		local m = Eggs.boostMultipliers(egg, luckBoost, species)
		if next(m) then
			sources.luckboost = { { id = "Luck Boost", multipliers = m } }
		end
	end
	if clover then
		local d = Util.deepCopy(DataTemplate.template) :: any
		Charms.add(d, clover, 1, "test")
		assert(Charms.equip(d, charms, clover), `could not equip {clover}`)
		sources.charms = Charms.luckBoosts(d, charms, egg, species)
	end
	return sources
end

-- The product of every boost on one outcome, before the cap.
local function product(sources: { [string]: { any } }, id: string): number
	local m = 1
	for _, list in sources do
		for _, boost in list do
			m *= boost.multipliers[id] or 1
		end
	end
	return m
end

-- Checks one egg under one combination with the given cap; returns how many
-- outcomes the boost touched.
local function check(egg: any, sources: { [string]: { any } }, cap: number?): number
	local pick = 1
	local odds = Odds.new({
		randomInteger = function(min: number, max: number)
			assert(min == 1 and pick >= min and pick <= max, "pick out of range")
			return pick
		end,
	})
	for _, def in Eggs.oddsTables(config.eggs, true) do
		odds:define(def)
	end
	odds:setBoostCap(cap)
	local player = {}
	for source, list in sources do
		odds:setSourceBoosts(player, egg.id, source, list)
	end
	local total = egg.total or 10000
	local display = odds:display(egg.id, player)
	local effective = odds:effective(egg.id, player)
	expect(#display.rows).toBe(#egg.outcomes)
	expect(display.total).toBe(total)
	local sum, boosted = 0, 0
	local cumulative = 0
	for i, row in display.rows do
		-- Shown is rolled: same row, same weight, and both ends of the row's
		-- range roll that creature.
		expect(row.id).toBe(effective[i].id)
		expect(row.weight).toBe(effective[i].weight)
		expect(row.weight >= 1).toBe(true)
		sum += row.weight
		pick = cumulative + 1
		expect(odds:rollPaid(egg.id, player, ALLOW)).toBe(row.id)
		cumulative += row.weight
		pick = cumulative
		expect(odds:rollPaid(egg.id, player, ALLOW)).toBe(row.id)
		-- Never above base x boost, and never above base x cap.
		local base = egg.outcomes[i].weight
		local m = product(sources, row.id)
		if cap then
			m = math.min(m, cap)
		end
		if m > 1 then
			boosted += 1
			if row.weight > base * m then
				error(`{egg.id} {row.id}: {row.weight} is above {base} x {m}`)
			end
		end
	end
	expect(sum).toBe(total)
	return boosted
end

describe("Luck on eggs", function()
	it(
		"every egg, with every Clover and with or without the Luck Boost: shown is rolled, never above the boost",
		function()
			local combos, touched = 0, 0
			for _, egg in config.eggs do
				for _, withLuckBoost in { false, true } do
					for _, clover in clovers() do
						combos += 1
						touched += check(egg, boostsFor(egg, withLuckBoost, clover), charms.luckCap)
					end
				end
			end
			expect(combos).toBe(#config.eggs * 2 * 8)
			-- The loop really boosted things.
			expect(touched > 0).toBe(true)
		end
	)

	it("the cap binds: a tighter cap holds every boosted creature at base x cap", function()
		for _, egg in config.eggs do
			for _, clover in clovers() do
				check(egg, boostsFor(egg, true, clover), 1.5)
			end
		end
	end)

	it("Luck Boost with the best Clover stays under x3 on the rarest creature", function()
		for _, egg in config.eggs do
			if table.find(luckBoost.eggs, egg.id) then
				local sources = boostsFor(egg, true, "StarOfFortune")
				local rarest, best = nil :: string?, -1
				for _, o in egg.outcomes do
					local m = product(sources, o.id)
					if m > best then
						rarest, best = o.id, m
					end
				end
				-- At most x2 Luck Boost and x1.2 Clover, x2.4: under the x3 cap.
				expect(rarest ~= nil).toBe(true)
				expect(best > 1 and best <= 2.4 + 1e-9).toBe(true)
				check(egg, sources, charms.luckCap)
			end
		end
	end)
end)
