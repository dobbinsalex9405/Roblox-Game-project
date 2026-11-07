--!strict
-- The claw machine (config/charms.luau `claw`) as pure functions: what a
-- pull costs, the odds tables it rolls from, and a pull of 1, 10 or 100 with
-- its guarantee and the pity counter. The server rolls through the core odds
-- service (rollPaid, so the PolicyService check always runs), the client
-- shows the same tables, and the tests drive it with fixed dice.
--
-- Pulls roll a tier, then one of the active kinds in it: each charm's
-- weight is its tier's weight split evenly (largest remainder) across the
-- kinds, so every tier's chance is exact. A guaranteed pull, and a pity
-- pull, roll from the tiers at or above the promised one by their relative
-- weights, which is the same as re-rolling until one of them comes up.

local Charms = require("./Charms")

export type Data = { [string]: any }

export type OddsTable = {
	id: string,
	paid: boolean,
	total: number,
	outcomes: { { id: string, weight: number } },
}

export type Ledger = {
	spend: (self: any, currency: string, amount: number, reason: string) -> boolean,
	balance: (self: any, currency: string) -> number,
}

local Claw = {}

-- The odds tables: every pull, then the guaranteed and pity pulls.
Claw.TABLE = "Claw"
local FLOOR_TABLES = { Rare = "ClawRarePlus", Epic = "ClawEpicPlus", Legendary = "ClawLegendaryPlus" }
Claw.FLOOR_TABLES = table.freeze(FLOOR_TABLES)

-- The table of pulls promised `tier` or better.
function Claw.floorTable(tier: string): string
	local id = FLOOR_TABLES[tier]
	assert(id, `no claw odds table for {tier} or better`)
	return id
end

-- A number rounded down to its first three digits (123,456 -> 123,000), the
-- same rounding as the coin packs (shared/Products), so prices read cleanly
-- and only change when income really does.
local function three(n: number): number
	if n < 1000 then
		return math.floor(n)
	end
	local unit = 10 ^ (math.floor(math.log10(n)) - 2)
	return math.floor(n / unit) * unit
end

-- The price of one pull for a player whose best income ever is `peak`
-- coins a second.
function Claw.unitPrice(peak: number, charms: any): number
	local claw = charms.claw
	return math.max(claw.minCoins, three(math.max(0, peak) * 60 * claw.incomeMinutes))
end

-- The pull size's entry in config (count, multiple, product, atLeast).
function Claw.size(charms: any, count: number): any?
	for _, pull in charms.claw.pulls do
		if pull.count == count then
			return pull
		end
	end
	return nil
end

-- What `count` pulls cost in coins.
function Claw.price(peak: number, charms: any, count: number): number
	local pull = Claw.size(charms, count)
	assert(pull, `no claw pull of {count}`)
	return Claw.unitPrice(peak, charms) * pull.multiple
end

-- The pull size a Robux product gives (ClawPull10 -> 10), or nil.
function Claw.productPulls(charms: any, key: string): number?
	for _, pull in charms.claw.pulls do
		if pull.product == key then
			return pull.count
		end
	end
	return nil
end

-- What fusing costs: a share of the 1-pull price.
function Claw.fuseFee(peak: number, charms: any): number
	return math.floor(Claw.unitPrice(peak, charms) * charms.fuseFeeShare)
end

-- The Charm Counter's price for a charm of `tier`, or nil if it sells none.
function Claw.counterPrice(peak: number, charms: any, tier: string): number?
	local multiple = charms.claw.counter[tier]
	if multiple == nil then
		return nil
	end
	return Claw.unitPrice(peak, charms) * multiple
end

-- Splits `total` across `weights` in proportion, whole numbers adding up to
-- exactly `total`, largest remainder first (ties to the earlier entry).
function Claw.split(total: number, weights: { number }): { number }
	local sum = 0
	for _, w in weights do
		sum += w
	end
	local parts = {}
	local given = 0
	local remainders = {}
	for i, w in weights do
		local exact = total * w / sum
		parts[i] = math.floor(exact)
		given += parts[i]
		table.insert(remainders, { i = i, r = exact - parts[i] })
	end
	table.sort(remainders, function(a, b)
		if a.r ~= b.r then
			return a.r > b.r
		end
		return a.i < b.i
	end)
	local k = 1
	while given < total do
		local i = remainders[(k - 1) % #remainders + 1].i
		parts[i] += 1
		given += 1
		k += 1
	end
	return parts
end

-- One odds table of the charms of the tiers from rank `lowest` up.
local function tableFrom(charms: any, id: string, lowest: number): OddsTable
	local claw = charms.claw
	local kinds = Charms.activeKinds(charms)
	local tiers = {}
	local weights = {}
	for rank = lowest, #charms.tiers do
		local tier = charms.tiers[rank]
		table.insert(tiers, rank)
		table.insert(weights, claw.tierWeights[tier])
	end
	-- Rescaled to the table's total when only some tiers are in it.
	local tierParts = if lowest == 1 then weights else Claw.split(claw.total, weights)
	local outcomes = {}
	for i, rank in tiers do
		local even = table.create(#kinds, 1)
		local kindParts = Claw.split(tierParts[i], even)
		for k, kindId in kinds do
			local def = Charms.at(charms, kindId, rank)
			assert(def, `no {charms.tiers[rank]} {kindId} charm`)
			table.insert(outcomes, { id = def.id, weight = kindParts[k] })
		end
	end
	return { id = id, paid = true, total = claw.total, outcomes = outcomes }
end

-- Every claw odds table, for the core odds service. Paid: coins are sold
-- for Robux, and two pull sizes are sold for Robux directly.
function Claw.oddsTables(charms: any): { OddsTable }
	local out = { tableFrom(charms, Claw.TABLE, 1) }
	local floors = {}
	for _, pull in charms.claw.pulls do
		if pull.atLeast then
			floors[pull.atLeast] = true
		end
	end
	floors[charms.claw.pityTier] = true
	for _, tier in charms.tiers do
		if floors[tier] then
			table.insert(
				out,
				tableFrom(charms, Claw.floorTable(tier), table.find(charms.tiers, tier) :: number)
			)
		end
	end
	return out
end

-- Pulls left until pity: "Legendary or better within N pulls".
function Claw.pityLeft(d: Data, charms: any): number
	return math.max(1, charms.claw.pityAt - (d.clawPity or 0))
end

-- Runs `count` pulls. `roll(tableId)` returns a charm id from that table
-- (the server: odds:rollPaid); nil means the player may not be given paid
-- random items, and nothing changes. The caller has checked the bag has room
-- and taken the price. Returns the charms pulled, in pull order.
function Claw.pull(
	d: Data,
	charms: any,
	count: number,
	roll: (tableId: string) -> string?,
	now: number,
	source: string
): ({ Charms.Owned }?, string?)
	local pull = Claw.size(charms, count)
	if pull == nil then
		return nil, "unknown pull size"
	end
	local claw = charms.claw
	local pityRank = table.find(charms.tiers, claw.pityTier) :: number
	local promised = if pull.atLeast then table.find(charms.tiers, pull.atLeast) :: number else nil
	-- Roll everything first: a refusal part-way must change nothing.
	local ids = {}
	local pity = d.clawPity or 0
	local best = 0
	for i = 1, count do
		local tableId = Claw.TABLE
		if pity >= claw.pityAt - 1 then
			tableId = Claw.floorTable(claw.pityTier)
		elseif promised and i == count and best < promised then
			tableId = Claw.floorTable(pull.atLeast)
		end
		local id = roll(tableId)
		if id == nil then
			return nil, "The claw machine isn't available to you."
		end
		local def = Charms.def(charms, id)
		assert(def, `claw rolled unknown charm {id}`)
		best = math.max(best, def.rank)
		pity = if def.rank >= pityRank then 0 else pity + 1
		table.insert(ids, id)
	end
	d.clawPity = pity
	d.clawPulls = (d.clawPulls or 0) + count
	local got = {}
	for _, id in ids do
		table.insert(got, Charms.add(d, id, now, source))
	end
	return got, nil
end

-- The best tier among pulled charms (1 Common .. 7 Godly).
function Claw.bestRank(charms: any, got: { Charms.Owned }): number
	local best = 0
	for _, owned in got do
		local def = Charms.def(charms, owned.id)
		if def then
			best = math.max(best, def.rank)
		end
	end
	return best
end

-- Raises the player's best income ever (what a pull's price follows).
-- Taking creatures off floors never lowers it.
function Claw.notePeak(d: Data, perSecond: number)
	if perSecond == perSecond and perSecond > (d.incomePeak or 0) then
		d.incomePeak = perSecond
	end
end

return Claw
