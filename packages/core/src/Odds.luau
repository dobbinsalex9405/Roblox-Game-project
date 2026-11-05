--!strict
-- Module 7: Odds.
-- One odds table per roll, stored as whole-number weights out of 10,000 (or
-- out of a larger power of ten, `total`, for tables with very rare outcomes),
-- so shown percentages are exact and always total exactly 100%.
-- The server rolls from the same effective table that `display` returns, so
-- the odds screen and the roll can never disagree. Boosts and exclusions
-- (outcomes a player can only get once) recompute that one table, and
-- listeners are told so the screen updates live.
--
-- Paid tables (bought with Robux, or with currency bought with Robux) can only
-- be rolled through `rollPaid`, which checks the Policy module first. `roll`
-- refuses them, so no code path can skip the policy check by accident.

local Log = require("./Log")
local Util = require("./Util")

export type Outcome = { id: string, weight: number }

export type TableDef = {
	id: string,
	paid: boolean,
	outcomes: { Outcome },
	-- What the weights total: 10,000 when left out (1 = 0.01%). A larger power
	-- of ten allows rarer outcomes: 100,000 makes 1 = 0.001% (1 in 100,000).
	total: number?,
}

export type Boost = {
	id: string,
	multipliers: { [string]: number }, -- outcome id -> multiplier (> 0)
}

export type DisplayRow = {
	id: string,
	weight: number,
	percent: string, -- "12.34%" (more decimals for tables out of more than 10,000)
	oneIn: string, -- "1 in 8.3", "1 in 5,556"
}

export type Display = {
	tableId: string,
	paid: boolean,
	total: number,
	boosts: { string },
	rows: { DisplayRow },
}

export type PolicyCheck = { paidRandomAllowed: (self: any, player: any) -> boolean }

export type Options = {
	-- Returns a whole number in [min, max]. Roblox: Random.new():NextInteger(min, max).
	randomInteger: ((min: number, max: number) -> number)?,
}

export type Odds = {
	define: (self: Odds, def: TableDef) -> (),
	has: (self: Odds, tableId: string) -> boolean,
	effective: (self: Odds, tableId: string, player: any) -> { Outcome },
	display: (self: Odds, tableId: string, player: any) -> Display,
	roll: (self: Odds, tableId: string, player: any) -> string,
	rollPaid: (self: Odds, tableId: string, player: any, policy: PolicyCheck) -> (string?, string?),
	setBoosts: (self: Odds, player: any, tableId: string, boosts: { Boost }) -> (),
	setExcluded: (self: Odds, player: any, tableId: string, outcomeIds: { string }) -> (),
	onChanged: (self: Odds, listener: (player: any, tableId: string) -> ()) -> (),
	forget: (self: Odds, player: any) -> (),
}

local TOTAL = 10000
local MAX_TOTAL = 10000000
local ID_PATTERN = "^[%a][%w_]*$"

local log = Log.new("Odds")

local Odds = {}
Odds.TOTAL = TOTAL

-- What a table's weights total: its `total`, or 10,000.
function Odds.totalOf(def: { total: number? }): number
	return def.total or TOTAL
end

local function validTotal(total: any): boolean
	if type(total) ~= "number" or total < 100 or total > MAX_TOTAL then
		return false
	end
	local n = total
	while n > 1 do
		if n % 10 ~= 0 then
			return false
		end
		n //= 10
	end
	return true
end

-- Throws with every problem in a table definition.
function Odds.validate(def: TableDef)
	assert(
		type(def.id) == "string" and string.match(def.id, ID_PATTERN),
		`invalid odds table id {tostring(def.id)}`
	)
	assert(type(def.paid) == "boolean", `odds table {def.id} must say paid = true or false`)
	assert(#def.outcomes >= 1, `odds table {def.id} has no outcomes`)
	assert(
		def.total == nil or validTotal(def.total),
		`odds table {def.id}: total must be a power of ten from 100 to {MAX_TOTAL}`
	)
	local total = Odds.totalOf(def)
	local seen: { [string]: boolean } = {}
	local sum = 0
	local smallest = Odds.formatPercent(1, total)
	for _, outcome in def.outcomes do
		assert(
			type(outcome.id) == "string" and string.match(outcome.id, ID_PATTERN),
			`odds table {def.id} has an invalid outcome id {tostring(outcome.id)}`
		)
		assert(not seen[outcome.id], `odds table {def.id} lists {outcome.id} twice`)
		seen[outcome.id] = true
		local w = outcome.weight
		assert(
			type(w) == "number" and w // 1 == w and w >= 1,
			`odds table {def.id}: {outcome.id} needs a whole weight of at least 1 ({smallest})`
		)
		sum += w
	end
	assert(sum == total, `odds table {def.id}: weights total {sum}, must total exactly {total}`)
end

-- Rescales raw (possibly fractional) weights to whole numbers totalling
-- `target` (10,000 when left out) with the largest-remainder method. Every
-- outcome with raw weight > 0 keeps at least 1, so anything possible is still
-- shown and still rollable.
function Odds.normalize(raw: { Outcome }, target: number?): { Outcome }
	local TOTAL = target or TOTAL
	local total = 0
	for _, o in raw do
		assert(o.weight >= 0 and o.weight == o.weight, "weights must be non-negative numbers")
		total += o.weight
	end
	assert(total > 0, "at least one outcome must stay possible")

	local result: { Outcome } = {}
	local remainders: { { index: number, frac: number } } = {}
	local sum = 0
	for index, o in raw do
		local exact = o.weight * TOTAL / total
		local base = math.floor(exact)
		if o.weight > 0 and base < 1 then
			base = 1
		end
		result[index] = { id = o.id, weight = base }
		sum += base
		table.insert(remainders, { index = index, frac = exact - math.floor(exact) })
	end

	local diff = TOTAL - sum
	if diff > 0 then
		table.sort(remainders, function(a, b)
			if a.frac ~= b.frac then
				return a.frac > b.frac
			end
			return a.index < b.index
		end)
		local i = 1
		while diff > 0 do
			local entry = remainders[((i - 1) % #remainders) + 1]
			if raw[entry.index].weight > 0 then
				result[entry.index].weight += 1
				diff -= 1
			end
			i += 1
		end
	elseif diff < 0 then
		-- Only happens when minimum-1 bumps overshoot; take from the largest weights.
		while diff < 0 do
			local largest = 1
			for index, o in result do
				if o.weight > result[largest].weight then
					largest = index
				end
			end
			assert(result[largest].weight > 1, "cannot normalize odds table")
			result[largest].weight -= 1
			diff += 1
		end
	end
	return result
end

-- The exact percentage for a whole weight out of `total` (10,000 when left
-- out): two decimals out of 10,000, three out of 100,000, and so on, so the
-- shown figure is never rounded.
function Odds.formatPercent(weight: number, total: number?): string
	local t = total or TOTAL
	local unit = t // 100 -- weight units per 1%
	local decimals = 0
	local n = unit
	while n > 1 do
		decimals += 1
		n //= 10
	end
	if decimals == 0 then
		return `{weight}%`
	end
	return string.format(`%d.%0{decimals}d%%`, weight // unit, weight % unit)
end

local function commas(n: number): string
	local out = tostring(n)
	repeat
		local count
		out, count = string.gsub(out, "^(%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return out
end

-- "1 in N" for a whole weight out of `total`: one decimal under 100, a whole
-- number with thousands commas from 100 up. A rounded reading of the exact
-- percentage, shown beside it.
function Odds.formatOneIn(weight: number, total: number?): string
	local t = total or TOTAL
	local n = t / weight
	if n < 100 then
		local tenths = math.floor(n * 10 + 0.5) / 10
		if tenths == math.floor(tenths) then
			return `1 in {math.floor(tenths)}`
		end
		return string.format("1 in %.1f", tenths)
	end
	return `1 in {commas(math.floor(n + 0.5))}`
end

function Odds.new(options: Options?): Odds
	local randomInteger: (min: number, max: number) -> number = (options and options.randomInteger)
		or function(min: number, max: number): number
			return math.random(min, max)
		end
	local tables: { [string]: TableDef } = {}
	local boosts: { [any]: { [string]: { Boost } } } = {}
	local excluded: { [any]: { [string]: { [string]: boolean } } } = {}
	local listeners: { (player: any, tableId: string) -> () } = {}

	local odds = {}

	local function getTable(tableId: string): TableDef
		local def = tables[tableId]
		if def == nil then
			error(`unknown odds table "{tostring(tableId)}"`, 3)
		end
		return def
	end

	local function changed(player: any, tableId: string)
		for _, listener in listeners do
			local ok, err = Util.try(listener, player, tableId)
			if not ok then
				log:error("onChanged listener failed", { err = err })
			end
		end
	end

	function odds.define(_self: Odds, def: TableDef)
		Odds.validate(def)
		assert(tables[def.id] == nil, `odds table {def.id} defined twice`)
		tables[def.id] = Util.deepFreeze(def)
	end

	function odds.has(_self: Odds, tableId: string): boolean
		return tables[tableId] ~= nil
	end

	-- The single source of truth for both the odds screen and the roll.
	function odds.effective(_self: Odds, tableId: string, player: any): { Outcome }
		local def = getTable(tableId)
		local playerBoosts = boosts[player] and boosts[player][tableId]
		local playerExcluded = excluded[player] and excluded[player][tableId]
		if (playerBoosts == nil or #playerBoosts == 0) and playerExcluded == nil then
			return def.outcomes
		end
		local raw: { Outcome } = {}
		for _, o in def.outcomes do
			local weight: number = o.weight
			if playerExcluded and playerExcluded[o.id] then
				weight = 0
			elseif playerBoosts then
				for _, boost in playerBoosts do
					weight *= boost.multipliers[o.id] or 1
				end
			end
			table.insert(raw, { id = o.id, weight = weight })
		end
		return Odds.normalize(raw, Odds.totalOf(def))
	end

	function odds.display(self: Odds, tableId: string, player: any): Display
		local def = getTable(tableId)
		local rows = {}
		local total = Odds.totalOf(def)
		for _, o in self:effective(tableId, player) do
			table.insert(rows, {
				id = o.id,
				weight = o.weight,
				percent = Odds.formatPercent(o.weight, total),
				oneIn = Odds.formatOneIn(o.weight, total),
			})
		end
		local boostIds = {}
		local active: { Boost } = (boosts[player] and boosts[player][tableId]) or {}
		for _, boost in active do
			table.insert(boostIds, boost.id)
		end
		return { tableId = tableId, paid = def.paid, total = total, boosts = boostIds, rows = rows }
	end

	local function rollFrom(outcomes: { Outcome }, total: number): string
		local pick = randomInteger(1, total)
		local cumulative = 0
		for _, o in outcomes do
			cumulative += o.weight
			if pick <= cumulative then
				return o.id
			end
		end
		error(`odds table does not total {total}`)
	end

	-- Rolls a free table (no Robux involved anywhere in the path).
	function odds.roll(self: Odds, tableId: string, player: any): string
		local def = getTable(tableId)
		if def.paid then
			error(`odds table {tableId} is paid; use rollPaid so the policy check runs`, 2)
		end
		return rollFrom(self:effective(tableId, player), Odds.totalOf(def))
	end

	-- Rolls a paid table after checking the player may receive paid random items.
	-- Returns nil and a reason when the player is restricted.
	function odds.rollPaid(self: Odds, tableId: string, player: any, policy: PolicyCheck): (string?, string?)
		local def = getTable(tableId)
		assert(def.paid, `odds table {tableId} is not paid; use roll`)
		if not policy:paidRandomAllowed(player) then
			return nil, "paid random items are restricted for this player"
		end
		return rollFrom(self:effective(tableId, player), Odds.totalOf(def)), nil
	end

	function odds.setBoosts(_self: Odds, player: any, tableId: string, list: { Boost })
		local def = getTable(tableId)
		for _, boost in list do
			for outcomeId, multiplier in boost.multipliers do
				local known = false
				for _, o in def.outcomes do
					if o.id == outcomeId then
						known = true
						break
					end
				end
				assert(known, `boost {boost.id} names unknown outcome {outcomeId} in {tableId}`)
				assert(
					type(multiplier) == "number" and multiplier > 0,
					`boost {boost.id} has an invalid multiplier`
				)
			end
		end
		boosts[player] = boosts[player] or {}
		boosts[player][tableId] = table.clone(list)
		changed(player, tableId)
	end

	function odds.setExcluded(_self: Odds, player: any, tableId: string, outcomeIds: { string })
		getTable(tableId)
		excluded[player] = excluded[player] or {}
		if #outcomeIds == 0 then
			excluded[player][tableId] = nil
		else
			local set = {}
			for _, id in outcomeIds do
				set[id] = true
			end
			excluded[player][tableId] = set
		end
		changed(player, tableId)
	end

	function odds.onChanged(_self: Odds, listener: (player: any, tableId: string) -> ())
		table.insert(listeners, listener)
	end

	function odds.forget(_self: Odds, player: any)
		boosts[player] = nil
		excluded[player] = nil
	end

	return (odds :: any) :: Odds
end

return Odds
