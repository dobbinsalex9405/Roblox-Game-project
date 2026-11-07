--!strict
-- Charms, the items (config/charms.luau): what a player owns, which are
-- equipped and shown, what they add up to, and fusion, as pure functions
-- over saved data. Every change runs inside DataService:update on the
-- server (through Actions:change), so a refusal leaves the save untouched;
-- the client reads the same functions to draw the Charms window.
--
-- Save fields (DataTemplate): `charms` { { uid, id, gotAt, source } },
-- `charmNextUid`, `charmEquipped` { [kind] = uid }, `charmHidden`
-- { [kind] = true }, `charmsShown`.

local Eggs = require("./Eggs")
local Tower = require("./Tower")

export type Data = { [string]: any }

export type Def = {
	id: string,
	name: string,
	kind: string,
	tier: string,
	value: number,
	rank: number, -- 1 Common .. 7 Godly
}

export type Owned = { uid: string, id: string, gotAt: number, source: string }

export type Stats = {
	income: number, -- fraction added to income (0.03 = +3%)
	luck: number, -- multiplier on Rare-and-rarer hatch weights (1 = none)
	hatchCut: number, -- fraction of hatch time removed
	shieldSeconds: number,
	thiefSlow: number,
	carryBonus: number,
}

export type Ledger = {
	spend: (self: any, currency: string, amount: number, reason: string) -> boolean,
	balance: (self: any, currency: string) -> number,
}

export type FuseStep = { from: string, to: string, times: number }

local Charms = {}

-- The stats each kind can change, and their value with nothing equipped.
local NEUTRAL: Stats = table.freeze({
	income = 0,
	luck = 1,
	hatchCut = 0,
	shieldSeconds = 0,
	thiefSlow = 0,
	carryBonus = 0,
})
Charms.NEUTRAL = NEUTRAL

type Index = {
	byId: { [string]: Def },
	byKindRank: { [string]: { [number]: Def } },
	kinds: { [string]: any },
	kindOrder: { string },
}

local indexes: { [any]: Index } = setmetatable({}, { __mode = "k" }) :: any

local function index(config: any): Index
	local hit = indexes[config]
	if hit then
		return hit
	end
	local idx: Index = { byId = {}, byKindRank = {}, kinds = {}, kindOrder = {} }
	for _, kind in config.kinds do
		idx.kinds[kind.id] = kind
		table.insert(idx.kindOrder, kind.id)
		idx.byKindRank[kind.id] = {}
	end
	for _, c in config.charms do
		local rank = table.find(config.tiers, c.tier) or 1
		local def: Def =
			{ id = c.id, name = c.name, kind = c.kind, tier = c.tier, value = c.value, rank = rank }
		idx.byId[c.id] = def
		if idx.byKindRank[c.kind] then
			idx.byKindRank[c.kind][rank] = def
		end
	end
	indexes[config] = idx
	return idx
end

function Charms.def(config: any, id: string): Def?
	return index(config).byId[id]
end

function Charms.kind(config: any, kindId: string): any?
	return index(config).kinds[kindId]
end

-- The kinds players can get and use right now, in inventory order (steal
-- kinds only once `stealCharms` is on).
function Charms.activeKinds(config: any): { string }
	local out = {}
	for _, kind in config.kinds do
		if config.stealCharms or not kind.steal then
			table.insert(out, kind.id)
		end
	end
	return out
end

function Charms.isActive(config: any, kindId: string): boolean
	return table.find(Charms.activeKinds(config), kindId) ~= nil
end

-- The charm of `kindId` at tier `rank` (1 Common .. 7 Godly).
function Charms.at(config: any, kindId: string, rank: number): Def?
	local row = index(config).byKindRank[kindId]
	return row and row[rank]
end

-- The charm a fusion of `id` makes (same kind, one tier up), or nil for Godly.
function Charms.nextTier(config: any, id: string): Def?
	local def = Charms.def(config, id)
	if def == nil then
		return nil
	end
	return Charms.at(config, def.kind, def.rank + 1)
end

-- Equip slots open for the floors built.
function Charms.slots(d: Data, config: any): number
	local floors = Tower.owned(d)
	local slots = 0
	for _, step in config.slotsByFloor do
		if floors >= step.floors then
			slots = math.max(slots, step.slots)
		end
	end
	return slots
end

-- The floor that opens slot number `slot`, or nil if it is open from the start.
function Charms.slotFloor(config: any, slot: number): number?
	local best: number? = nil
	for _, step in config.slotsByFloor do
		if step.slots >= slot and (best == nil or step.floors < best) then
			best = step.floors
		end
	end
	if best == 1 then
		return nil
	end
	return best
end

-- The most slots there will ever be.
function Charms.maxSlots(config: any): number
	local most = 0
	for _, step in config.slotsByFloor do
		most = math.max(most, step.slots)
	end
	return most
end

local function list(d: Data): { Owned }
	if d.charms == nil then
		d.charms = {}
	end
	return d.charms
end

local function equippedMap(d: Data): { [string]: string }
	if d.charmEquipped == nil then
		d.charmEquipped = {}
	end
	return d.charmEquipped
end

function Charms.bagCount(d: Data): number
	return if d.charms then #d.charms else 0
end

-- Whether `n` more charms fit in the bag.
function Charms.hasRoom(d: Data, config: any, n: number): boolean
	return Charms.bagCount(d) + n <= config.bagSlots
end

function Charms.find(d: Data, uid: string): (Owned?, number?)
	for i, c in d.charms or {} do
		if c.uid == uid then
			return c, i
		end
	end
	return nil, nil
end

function Charms.isEquipped(d: Data, uid: string): boolean
	for _, equippedUid in d.charmEquipped or {} do
		if equippedUid == uid then
			return true
		end
	end
	return false
end

-- Adds one charm to the bag (the caller checks room first). Returns it.
function Charms.add(d: Data, id: string, now: number, source: string): Owned
	local uid = tostring(d.charmNextUid or 1)
	d.charmNextUid = (d.charmNextUid or 1) + 1
	local owned: Owned = { uid = uid, id = id, gotAt = now, source = source }
	table.insert(list(d), owned)
	return owned
end

-- How many of each id the player owns: all of them, and those not equipped.
function Charms.counts(d: Data): ({ [string]: number }, { [string]: number })
	local all: { [string]: number } = {}
	local free: { [string]: number } = {}
	local equipped: { [string]: boolean } = {}
	for _, uid in d.charmEquipped or {} do
		equipped[uid] = true
	end
	for _, c in d.charms or {} do
		all[c.id] = (all[c.id] or 0) + 1
		if not equipped[c.uid] then
			free[c.id] = (free[c.id] or 0) + 1
		end
	end
	return all, free
end

-- The equipped charm of each kind: { [kind] = { owned, def } }. Charms that
-- are no longer owned or known are skipped.
function Charms.equipped(d: Data, config: any): { [string]: { owned: Owned, def: Def } }
	local out = {}
	for kindId, uid in d.charmEquipped or {} do
		local owned = Charms.find(d, uid)
		local def = owned and Charms.def(config, owned.id)
		if owned and def and def.kind == kindId then
			out[kindId] = { owned = owned, def = def }
		end
	end
	return out
end

-- What the equipped charms add up to. Hidden charms count in full; kinds
-- that are switched off (steal kinds before Egg Heist) count nothing.
function Charms.stats(d: Data, config: any): Stats
	local stats: any = table.clone(NEUTRAL)
	for kindId, entry in Charms.equipped(d, config) do
		local kind = Charms.kind(config, kindId)
		if kind and Charms.isActive(config, kindId) then
			local stat = kind.stat
			if stat == "luck" then
				stats.luck *= entry.def.value
			else
				stats[stat] += entry.def.value
			end
		end
	end
	return stats :: Stats
end

-- The income bonus (a fraction, 0.03 = +3%) the equipped Feeder gives.
function Charms.incomeBonus(d: Data, config: any?): number
	if config == nil or d.charmEquipped == nil then
		return 0
	end
	return Charms.stats(d, config).income
end

-- An egg's hatch time bought now: the Warmer charm (and an event's factor,
-- 1 when none) never take off more than `hatchCutCap`. Whole seconds, up.
function Charms.hatchSeconds(seconds: number, d: Data, config: any?, eventFactor: number?): number
	local cut = if config then Charms.stats(d, config).hatchCut else 0
	local factor = (1 - cut) * (eventFactor or 1)
	if config then
		factor = math.max(1 - config.hatchCutCap, factor)
	end
	return math.ceil(seconds * factor - 1e-9)
end

-- The Clover's multiplier for each tier it boosts (Rare and rarer), or an
-- empty table when it changes nothing. Odds caps all sources together.
function Charms.luckMultipliers(d: Data, config: any): { [string]: number }
	local luck = Charms.stats(d, config).luck
	local out = {}
	if luck ~= 1 then
		for rank = 3, #config.tiers do
			out[config.tiers[rank]] = luck
		end
	end
	return out
end

-- The equipped Clover's boost on one egg, as the core odds service takes it
-- (source "charms"): a list of one boost named after the charm, or empty.
function Charms.luckBoosts(d: Data, config: any, egg: any, species: { [string]: any }): { any }
	local multipliers = Charms.luckMultipliers(d, config)
	local clover = Charms.equipped(d, config).Clover
	if next(multipliers) == nil or clover == nil then
		return {}
	end
	local m = Eggs.boostMultipliers(egg, { rarityMultipliers = multipliers }, species)
	if next(m) == nil then
		return {}
	end
	return { { id = clover.def.name, multipliers = m } }
end

-- Equips one owned, unequipped charm of `id`. A charm of the same kind is
-- swapped out; a new kind needs a free slot.
function Charms.equip(d: Data, config: any, id: string): (boolean, string?)
	local def = Charms.def(config, id)
	if def == nil then
		return false, "unknown charm"
	end
	if not Charms.isActive(config, def.kind) then
		return false, `{def.name} does nothing yet: it wakes up with Egg Heist.`
	end
	local map = equippedMap(d)
	local current = map[def.kind] and Charms.find(d, map[def.kind])
	if current and current.id == id then
		return false, `{def.name} is already equipped.`
	end
	local pick: Owned? = nil
	for _, c in d.charms or {} do
		if c.id == id and not Charms.isEquipped(d, c.uid) then
			pick = c
			break
		end
	end
	if pick == nil then
		return false, `You don't have a {def.name}.`
	end
	if current == nil then
		local used = 0
		for kindId in Charms.equipped(d, config) do
			if kindId ~= def.kind then
				used += 1
			end
		end
		local slots = Charms.slots(d, config)
		if used >= slots then
			local floor = Charms.slotFloor(config, slots + 1)
			return false,
				if floor
					then `All {slots} charm slots are full. Build floor {floor} to open another slot.`
					else `All {slots} charm slots are full.`
		end
	end
	map[def.kind] = (pick :: Owned).uid
	return true, nil
end

function Charms.unequip(d: Data, kindId: string): (boolean, string?)
	local map = equippedMap(d)
	if map[kindId] == nil then
		return false, "Nothing is equipped there."
	end
	map[kindId] = nil
	return true, nil
end

-- Shows or hides worn charms: `which` is a kind id or "all".
function Charms.setShown(d: Data, config: any, which: string, shown: boolean): (boolean, string?)
	if which == "all" then
		d.charmsShown = shown
		return true, nil
	end
	if Charms.kind(config, which) == nil then
		return false, "unknown kind"
	end
	if d.charmHidden == nil then
		d.charmHidden = {}
	end
	d.charmHidden[which] = if shown then nil else true
	return true, nil
end

function Charms.isShown(d: Data, kindId: string): boolean
	return d.charmsShown ~= false and not (d.charmHidden and d.charmHidden[kindId])
end

-- The ids of the equipped charms other players see, in kind order, as the
-- character attribute `Charms` holds them ("FeedBag,HeatLamp"; "" = none).
function Charms.wornAttribute(d: Data, config: any): string
	local equipped = Charms.equipped(d, config)
	local ids = {}
	for _, kindId in index(config).kindOrder do
		local entry = equipped[kindId]
		if entry and Charms.isActive(config, kindId) and Charms.isShown(d, kindId) then
			table.insert(ids, entry.def.id)
		end
	end
	return table.concat(ids, ",")
end

-- Fuses `times` x `fuseCount` unequipped charms of `id` into `times`
-- charms one tier up, for `fee` coins each. Returns the new charms.
function Charms.fuse(
	d: Data,
	ledger: Ledger,
	config: any,
	id: string,
	times: number,
	fee: number,
	now: number
): ({ Owned }?, string?)
	local def = Charms.def(config, id)
	if def == nil then
		return nil, "unknown charm"
	end
	local target = Charms.nextTier(config, id)
	if target == nil then
		return nil, `{def.name} is Godly: it can't be fused any higher.`
	end
	if times < 1 then
		return nil, "nothing to fuse"
	end
	local need = config.fuseCount * times
	local _, free = Charms.counts(d)
	if (free[id] or 0) < need then
		return nil, `Fusing needs {config.fuseCount} {def.name} that aren't equipped.`
	end
	local total = fee * times
	if ledger:balance("coins") < total then
		return nil, `Not enough coins: fusing costs {total} coins.`
	end
	if total > 0 then
		ledger:spend("coins", total, "Gameplay:CharmFuse")
	end
	-- Use the newest copies first, so the oldest (the first ever pulled) stay.
	local left = need
	local charms = list(d)
	for i = #charms, 1, -1 do
		if left == 0 then
			break
		end
		local c = charms[i]
		if c.id == id and not Charms.isEquipped(d, c.uid) then
			table.remove(charms, i)
			left -= 1
		end
	end
	local made = {}
	for _ = 1, times do
		table.insert(made, Charms.add(d, target.id, now, "fuse"))
	end
	return made, nil
end

-- What "Fuse all" would do with `coins`: every group of `fuseCount`
-- unequipped charms of one id, from Common up (so fused charms can fuse
-- again), until no group is left or the fees run out. Active kinds only.
function Charms.fuseAllPlan(d: Data, config: any, fee: number, coins: number): ({ FuseStep }, number)
	local _, free = Charms.counts(d)
	local steps: { FuseStep } = {}
	local spent = 0
	for _, kindId in Charms.activeKinds(config) do
		local carry = 0
		for rank = 1, #config.tiers - 1 do
			local def = Charms.at(config, kindId, rank)
			local nextDef = Charms.at(config, kindId, rank + 1)
			if def and nextDef then
				local have = (free[def.id] or 0) + carry
				local times = have // config.fuseCount
				if fee > 0 then
					times = math.min(times, (coins - spent) // fee)
				end
				carry = 0
				if times > 0 then
					table.insert(steps, { from = def.id, to = nextDef.id, times = times })
					spent += fee * times
					carry = times
				end
			end
		end
	end
	return steps, spent
end

-- Runs Fuse all. Returns the steps done.
function Charms.fuseAll(
	d: Data,
	ledger: Ledger,
	config: any,
	fee: number,
	now: number
): ({ FuseStep }?, string?)
	local steps = Charms.fuseAllPlan(d, config, fee, ledger:balance("coins"))
	if #steps == 0 then
		return nil, `Nothing to fuse: you need {config.fuseCount} of the same charm, not equipped.`
	end
	for _, step in steps do
		local _, refusal = Charms.fuse(d, ledger, config, step.from, step.times, fee, now)
		if refusal then
			return nil, refusal
		end
	end
	return steps, nil
end

local function percent(fraction: number): string
	local p = fraction * 100
	if math.abs(p - math.floor(p + 0.5)) < 1e-6 then
		return tostring(math.floor(p + 0.5))
	end
	return string.format("%.1f", p)
end

local function luckText(m: number): string
	local s = string.format("%.2f", m)
	s = string.gsub(s, "0$", "")
	return s
end

-- The effect line a charm card shows ("+3% coins").
function Charms.effectText(config: any, def: Def): string
	local kind = Charms.kind(config, def.kind)
	local stat = kind and kind.stat
	if stat == "income" then
		return `+{percent(def.value)}% coins`
	elseif stat == "luck" then
		return `x{luckText(def.value)} luck on Rare and rarer`
	elseif stat == "hatchCut" then
		return `Eggs hatch {percent(def.value)}% faster`
	elseif stat == "shieldSeconds" then
		return `+{def.value} s free shield`
	elseif stat == "thiefSlow" then
		return `Thieves {percent(def.value)}% slower`
	elseif stat == "carryBonus" then
		return `Carry eggs {percent(def.value)}% faster`
	end
	return ""
end

-- The totals line under the slots ("+3% coins, x1.04 luck, eggs 5% faster"),
-- only the stats that do something; "" when nothing is equipped.
function Charms.totalsText(stats: Stats): string
	local parts = {}
	if stats.income > 0 then
		table.insert(parts, `+{percent(stats.income)}% coins`)
	end
	if stats.luck ~= 1 then
		table.insert(parts, `x{luckText(stats.luck)} luck`)
	end
	if stats.hatchCut > 0 then
		table.insert(parts, `eggs {percent(stats.hatchCut)}% faster`)
	end
	if stats.shieldSeconds > 0 then
		table.insert(parts, `+{stats.shieldSeconds} s shield`)
	end
	if stats.thiefSlow > 0 then
		table.insert(parts, `thieves {percent(stats.thiefSlow)}% slower`)
	end
	if stats.carryBonus > 0 then
		table.insert(parts, `carry {percent(stats.carryBonus)}% faster`)
	end
	return table.concat(parts, ", ")
end

-- A carrier's walk speed while holding a stolen egg (for Egg Heist):
-- 10 x (1 + their Sneak) x (1 - the owner's Snare), kept within 7..11.
function Charms.carrySpeed(thief: Stats, owner: Stats): number
	return math.clamp(10 * (1 + thief.carryBonus) * (1 - owner.thiefSlow), 7, 11)
end

-- Cards for the Charms window: one per id owned, rarest first, then by kind
-- order and name.
function Charms.stacks(
	d: Data,
	config: any,
	kindFilter: string?
): { { def: Def, count: number, free: number, equipped: boolean } }
	local all, free = Charms.counts(d)
	local equipped: { [string]: boolean } = {}
	for _, entry in Charms.equipped(d, config) do
		equipped[entry.def.id] = true
	end
	local order = index(config).kindOrder
	local out = {}
	for id, count in all do
		local def = Charms.def(config, id)
		if def and (kindFilter == nil or def.kind == kindFilter) and Charms.isActive(config, def.kind) then
			table.insert(
				out,
				{ def = def, count = count, free = free[id] or 0, equipped = equipped[id] == true }
			)
		end
	end
	table.sort(out, function(a, b)
		if a.def.rank ~= b.def.rank then
			return a.def.rank > b.def.rank
		end
		local ka, kb = table.find(order, a.def.kind) or 0, table.find(order, b.def.kind) or 0
		if ka ~= kb then
			return ka < kb
		end
		return a.def.name < b.def.name
	end)
	return out
end

return Charms
