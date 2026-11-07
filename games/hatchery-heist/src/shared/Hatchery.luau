--!strict
-- The Hatchery Heist base loop as pure functions over saved data:
-- buy an egg off the conveyor into a free incubator, wait, hatch it into a
-- creature on a pad, earn coins per second into a pending pile, collect, buy
-- slots, ride a creature, rebirth.
--
-- Every function runs inside DataService:update on the server, so a refusal
-- or an error leaves the save untouched. Coins only move through the Economy
-- ledger passed in. Nothing here yields, reads a clock or rolls dice: time and
-- hatch outcomes are arguments, which keeps every rule unit-testable.

local Book = require("./Book")
local Creatures = require("./Creatures")
local Numbers = require("./Numbers")
local Tower = require("./Tower")

export type Data = { [string]: any }

-- The parts of Economy's ledger used here.
export type Ledger = {
	add: (self: any, currency: string, amount: number, reason: string) -> number,
	spend: (self: any, currency: string, amount: number, reason: string) -> boolean,
	balance: (self: any, currency: string) -> number,
}

export type Perks = {
	doubleCoins: boolean,
	extraIncubators: boolean,
}

export type Incubator = {
	slot: number,
	eggId: string,
	startedAt: number,
	readyAt: number,
	outcome: string, -- decided and paid for at purchase; shown when it hatches
}

-- Chooses what an egg will hatch. `boughtBefore` counts this player's earlier
-- purchases of the same egg (for the fixed-order alternative). Returns nil
-- when the egg cannot be sold to this player.
export type PickOutcome = (egg: any, boughtBefore: number) -> string?

-- First-time moments, in the order the onboarding funnel reports them.
-- New steps are added at the end so earlier step numbers never change.
local ONBOARDING = {
	"Joined",
	"FirstEggBought",
	"FirstHatch",
	"FirstRide",
	"FirstRaidTried",
	"FirstRaidDefended",
	"FirstCollect",
	"FirstSlot",
	"PadsFull",
	"FirstRebirth",
}

local Hatchery = {}
Hatchery.ONBOARDING = table.freeze(ONBOARDING)

local function eggById(eggs: { any }, eggId: string): any?
	for _, egg in eggs do
		if egg.id == eggId then
			return egg
		end
	end
	return nil
end
Hatchery.eggById = eggById

-- Coins per second one creature earns before rebirth and pass multipliers.
function Hatchery.creatureIncome(creature: any, creatureConfig: any): number
	local species = creatureConfig.species[creature.speciesId]
	if species == nil then
		return 0
	end
	return species.coinsPerSecond * (creatureConfig.mutations[creature.mutation] or 1)
end

function Hatchery.creatureByUid(d: Data, uid: string): any?
	for _, creature in d.creatures do
		if creature.uid == uid then
			return creature
		end
	end
	return nil
end

-- Incubator slots the player can use right now.
function Hatchery.slotCount(d: Data, economy: any, perks: Perks): number
	return d.slots + (if perks.extraIncubators then economy.incubators.passBonusSlots else 0)
end

-- Hatchery Book: notes that the player owns a species, at `at` (unix
-- seconds). Returns true the first time.
function Hatchery.noteFound(d: Data, speciesId: string, at: number): boolean
	if d.found == nil then
		d.found = {}
	end
	if d.found[speciesId] ~= nil then
		return false
	end
	d.found[speciesId] = at
	return true
end

-- Adds every species the player owns now to the book (for saves made before
-- the book existed). Returns how many were new.
function Hatchery.backfillFound(d: Data): number
	local added = 0
	for _, creature in d.creatures do
		if Hatchery.noteFound(d, creature.speciesId, creature.hatchedAt or 0) then
			added += 1
		end
	end
	return added
end

-- How many of the game's species are in the player's book.
function Hatchery.foundCount(d: Data, creatureConfig: any): number
	local n = 0
	for speciesId in d.found or {} do
		if creatureConfig.species[speciesId] ~= nil then
			n += 1
		end
	end
	return n
end

-- The book's income bonus: 0.07 means +7%, at most economy.book.maxBonus
-- for a full book (shared/Book.luau).
function Hatchery.bookBonus(d: Data, config: any): number
	return Book.bonus(d.found, config.creatures.species, config.economy.book)
end

-- The player opened the Hatchery Book at `at`: cards found since stop
-- being NEW.
function Hatchery.seeBook(d: Data, at: number)
	d.bookSeenAt = math.max(d.bookSeenAt or 0, at)
end

-- Coins per second from creatures placed on the tower, each times its
-- floor's bonus, with rebirth, pass and book multipliers.
function Hatchery.incomePerSecond(d: Data, config: any, perks: Perks): number
	local base = 0
	for _, c in d.creatures do
		if c.slot then
			base += Hatchery.creatureIncome(c, config.creatures) * Tower.multiplier(
				d,
				Tower.floorOf(c.slot),
				config.economy
			)
		end
	end
	return base
		* Creatures.multiplier(d.rebirths, perks.doubleCoins, config.economy)
		* (1 + Hatchery.bookBonus(d, config))
end

-- One placed creature's coins per second with every bonus, as the Creatures
-- menu shows it; 0 in the inventory.
function Hatchery.earning(d: Data, creature: any, config: any, perks: Perks): number
	if creature.slot == nil then
		return 0
	end
	return Hatchery.creatureIncome(creature, config.creatures)
		* Tower.multiplier(d, Tower.floorOf(creature.slot), config.economy)
		* Creatures.multiplier(d.rebirths, perks.doubleCoins, config.economy)
		* (1 + Hatchery.bookBonus(d, config))
end

-- Adds earnings since `lastIncomeAt` to the pending pile at full rate.
-- Call while the player is in the server: on a timer, and before any change
-- to what earns (hatching, rebirth, a pass purchase), so the old rate is paid
-- for the time it applied.
function Hatchery.accrue(d: Data, now: number, perSecond: number)
	if d.lastIncomeAt <= 0 or now < d.lastIncomeAt then
		d.lastIncomeAt = now
		return
	end
	d.pendingCoins += perSecond * (now - d.lastIncomeAt)
	d.lastIncomeAt = now
end

-- The pending pile as it stands at `now`, for display (does not change data).
function Hatchery.pendingAt(d: Data, now: number, perSecond: number): number
	local since = if d.lastIncomeAt > 0 then math.max(0, now - d.lastIncomeAt) else 0
	return d.pendingCoins + perSecond * since
end

-- Call once when the player joins, before anything else touches income. Pays
-- for the time away at the offline rate, capped, and returns the coins added
-- to the pending pile.
function Hatchery.welcomeBack(d: Data, now: number, perSecond: number, economy: any): number
	local earned = 0
	if d.lastIncomeAt > 0 and now > d.lastIncomeAt then
		earned = Creatures.offlineEarnings(perSecond, now - d.lastIncomeAt, economy)
		d.pendingCoins += earned
	end
	d.lastIncomeAt = now
	return earned
end

-- Moves whole pending coins into the wallet. Returns the amount collected.
function Hatchery.collect(d: Data, ledger: Ledger): number
	local amount = math.floor(d.pendingCoins)
	if amount <= 0 then
		return 0
	end
	local applied = ledger:add("coins", amount, "Gameplay:Collect")
	-- Coins above the wallet cap are not kept back in the pile; the cap is
	-- far beyond reach (1e15) and a pile that never empties would confuse.
	d.pendingCoins -= amount
	return applied
end

function Hatchery.incubatorAt(d: Data, slot: number): (Incubator?, number?)
	for index, incubator in d.incubators do
		if incubator.slot == slot then
			return incubator, index
		end
	end
	return nil, nil
end

function Hatchery.freeSlot(d: Data, slotCount: number): number?
	local used: { [number]: boolean } = {}
	for _, incubator in d.incubators do
		used[incubator.slot] = true
	end
	for slot = 1, slotCount do
		if not used[slot] then
			return slot
		end
	end
	return nil
end

-- What a player short of coins for `egg` is told: which egg it was and its
-- price (the belt keeps moving, so the nearest Buy is often a dearer egg),
-- and the cheapest egg on sale when that is a different one.
function Hatchery.shortOfCoins(egg: any, cheapest: any?): string
	local function name(e: any): string
		return (string.gsub(e.id, "(%l)(%u)", "%1 %2"))
	end
	local article = if string.find(egg.id, "^[AEIOU]") then "an" else "a"
	local text = `Not enough coins: {article} {name(egg)} costs {Numbers.short(egg.priceCoins)}.`
	if cheapest and cheapest.id ~= egg.id and cheapest.priceCoins then
		text ..= ` {name(cheapest)}s cost {Numbers.short(cheapest.priceCoins)}.`
	end
	return text
end

-- Buys a coin egg into the first free incubator. `pick` decides the outcome
-- at the moment of payment (a paid roll, or the fixed-order alternative).
function Hatchery.buyEgg(
	d: Data,
	ledger: Ledger,
	egg: any,
	slotCount: number,
	now: number,
	pick: PickOutcome
): (Incubator?, string?)
	if egg.priceCoins == nil then
		return nil, "this egg is bought with Robux"
	end
	local slot = Hatchery.freeSlot(d, slotCount)
	if slot == nil then
		return nil, "Your incubators are full. Hatch an egg first."
	end
	if ledger:balance("coins") < egg.priceCoins then
		return nil, "Not enough coins."
	end
	local boughtBefore = d.eggsBought[egg.id] or 0
	local outcome = pick(egg, boughtBefore)
	if outcome == nil then
		return nil, "This egg is not available to you."
	end
	local known = false
	for _, o in egg.outcomes do
		if o.id == outcome then
			known = true
		end
	end
	assert(known, `egg {egg.id} cannot hatch {outcome}`)
	ledger:spend("coins", egg.priceCoins, `Shop:{egg.id}`)
	d.eggsBought[egg.id] = boughtBefore + 1
	local incubator: Incubator = {
		slot = slot,
		eggId = egg.id,
		startedAt = now,
		readyAt = now + egg.hatchSeconds,
		outcome = outcome,
	}
	table.insert(d.incubators, incubator)
	return incubator, nil
end

local function gcd(a: number, b: number): number
	while b ~= 0 do
		a, b = b, a % b
	end
	return a
end

-- The alternative for players who may not receive paid random items: a fixed
-- order with each outcome exactly as often as its odds say, so a restricted
-- player gets the expected mix, no more and no less. The next results are
-- shown before purchase, so nothing about them is random.
--
-- A cycle is the egg's total / (the weights' greatest common divisor) eggs.
-- Outcome i (reduced weight w) is due at the middle of each of its w equal
-- shares of the cycle: its k-th turn (from 0) at (2k + 1) / (2w) of the way
-- round. The cycle lists every turn in that order (ties: the earlier
-- outcome first), so each outcome comes exactly w times a cycle, evenly
-- spaced. Any place is worked out on its own from those turns, so a cycle
-- of 10,000,000 eggs costs no memory (economy thread, Nov 7).
type Order = { ids: { string }, weights: { number }, length: number }
local orders: { [any]: Order } = setmetatable({}, { __mode = "k" }) :: any

local function orderOf(egg: any): Order
	local cached = orders[egg]
	if cached then
		return cached
	end
	local divisor = 0
	for _, o in egg.outcomes do
		divisor = gcd(divisor, o.weight)
	end
	local ids, weights, length = {}, {}, 0
	for i, o in egg.outcomes do
		ids[i] = o.id
		weights[i] = o.weight // divisor
		length += weights[i]
	end
	local order = { ids = ids, weights = weights, length = length }
	orders[egg] = order
	return order
end

-- The place in the cycle (from 0) of outcome i's k-th turn: how many turns
-- of every outcome come before it. Exact in whole numbers: turn l of
-- outcome j comes first when (2l + 1) * w_i < (2k + 1) * w_j, or on a tie
-- when j is the earlier outcome. Products stay below 2^53 for weights up
-- to 10,000,000.
local function placeOf(order: Order, i: number, k: number): number
	local weights = order.weights
	local wi = weights[i]
	local place = 0
	for j, wj in weights do
		local a = (2 * k + 1) * wj
		local largest = if j < i then a // wi else (a - 1) // wi -- largest odd 2l+1 that comes first
		place += (largest + 1) // 2
	end
	return place
end

-- The first turn k of outcome i whose place is at least `at`, or the
-- outcome's weight when every turn is earlier.
local function firstTurnFrom(order: Order, i: number, at: number): number
	local lo, hi = 0, order.weights[i]
	while lo < hi do
		local mid = (lo + hi) // 2
		if placeOf(order, i, mid) < at then
			lo = mid + 1
		else
			hi = mid
		end
	end
	return lo
end

-- How many eggs a fixed-order cycle of this kind is.
function Hatchery.fixedOrderLength(egg: any): number
	return orderOf(egg).length
end

-- The outcome of a restricted player's next egg of this kind.
function Hatchery.fixedOrderOutcome(egg: any, boughtBefore: number): string
	local order = orderOf(egg)
	local at = boughtBefore % order.length
	for i in order.weights do
		local k = firstTurnFrom(order, i, at)
		if k < order.weights[i] and placeOf(order, i, k) == at then
			return order.ids[i]
		end
	end
	error(`no outcome at place {at} of {egg.id}`) -- every place holds exactly one turn
end

-- How many more eggs of this kind until `outcomeId` hatches (0 = the next one).
function Hatchery.fixedOrderWait(egg: any, boughtBefore: number, outcomeId: string): number?
	local order = orderOf(egg)
	local i = table.find(order.ids, outcomeId)
	if i == nil or order.weights[i] <= 0 then
		return nil
	end
	local at = boughtBefore % order.length
	local k = firstTurnFrom(order, i, at)
	if k < order.weights[i] then
		return placeOf(order, i, k) - at
	end
	return placeOf(order, i, 0) + order.length - at -- round to the next cycle
end

-- The whole cycle, in order. For tests and small eggs only: game code asks
-- for single places, which cost nothing however long the cycle is.
function Hatchery.fixedOrderCycle(egg: any): { string }
	local order = orderOf(egg)
	local cycle = table.create(order.length)
	for i, w in order.weights do
		for k = 0, w - 1 do
			cycle[placeOf(order, i, k) + 1] = order.ids[i]
		end
	end
	return cycle
end

-- Whether the tower has no room left for even a 1-slot creature.
function Hatchery.padsFull(d: Data, creatureConfig: any, economy: any): boolean
	return Tower.full(d, creatureConfig, economy)
end

-- Coins a stored creature sells for when storage overflows.
function Hatchery.sellValue(creature: any, creatureConfig: any, economy: any): number
	return math.max(
		1,
		math.floor(Hatchery.creatureIncome(creature, creatureConfig) * economy.storage.sellSeconds)
	)
end

-- Keeps storage within its size: while it is over, the weakest stored creature
-- is sold for coins. Returns the creatures sold.
local function trimStorage(d: Data, ledger: Ledger, creatureConfig: any, economy: any): { any }
	local sold = {}
	while true do
		local stored = 0
		local weakestIndex: number? = nil
		for index, c in d.creatures do
			if c.slot == nil then
				stored += 1
				if
					c.uid ~= d.mountUid
					and c.uid ~= d.guardUid
					and (
						weakestIndex == nil
						or Hatchery.creatureIncome(c, creatureConfig)
							< Hatchery.creatureIncome(d.creatures[weakestIndex], creatureConfig)
					)
				then
					weakestIndex = index
				end
			end
		end
		if stored <= economy.storage.slots or weakestIndex == nil then
			return sold
		end
		local c = table.remove(d.creatures, weakestIndex :: number)
		ledger:add("coins", Hatchery.sellValue(c, creatureConfig, economy), "Gameplay:SellCreature")
		table.insert(sold, c)
	end
end

-- Hatches the ready egg in `slot` into the creature chosen when it was bought.
-- Returns the new creature, or nil and a refusal, plus any stored creatures
-- sold to make room.
function Hatchery.hatch(
	d: Data,
	ledger: Ledger,
	slot: number,
	now: number,
	creatureConfig: any,
	economy: any
): (any?, string?, { any })
	local incubator, index = Hatchery.incubatorAt(d, slot)
	if incubator == nil or index == nil then
		return nil, "That incubator is empty.", {}
	end
	if now < incubator.readyAt then
		return nil, `Ready in {math.ceil(incubator.readyAt - now)}s.`, {}
	end
	if creatureConfig.species[incubator.outcome] == nil then
		return nil, "unknown creature", {}
	end
	table.remove(d.incubators, index)
	local creature = {
		uid = tostring(d.nextUid),
		speciesId = incubator.outcome,
		mutation = "None",
		slot = nil :: number?,
		eggId = incubator.eggId,
		hatchedAt = now,
	}
	d.nextUid += 1
	Tower.autoPlace(d, creature, creatureConfig, economy)
	table.insert(d.creatures, creature)
	Hatchery.noteFound(d, creature.speciesId, now)
	local sold = trimStorage(d, ledger, creatureConfig, economy)
	return creature, nil, sold
end

-- Removes a creature for a raid that succeeded. The creature being ridden and
-- the guard cannot be taken. Returns the creature, or nil if it is gone.
function Hatchery.takeCreature(d: Data, uid: string): any?
	if uid == d.mountUid or uid == d.guardUid then
		return nil
	end
	for index, c in d.creatures do
		if c.uid == uid then
			return table.remove(d.creatures, index)
		end
	end
	return nil
end

-- Gives a player a creature from elsewhere (a raid). It gets a new uid in
-- their save and is placed like a fresh hatch. Returns it and any stored
-- creatures sold to make room.
function Hatchery.receive(
	d: Data,
	ledger: Ledger,
	from: any,
	creatureConfig: any,
	economy: any
): (any, { any })
	local creature = {
		uid = tostring(d.nextUid),
		speciesId = from.speciesId,
		mutation = from.mutation,
		slot = nil :: number?,
		eggId = from.eggId,
		hatchedAt = from.hatchedAt,
	}
	d.nextUid += 1
	Tower.autoPlace(d, creature, creatureConfig, economy)
	table.insert(d.creatures, creature)
	Hatchery.noteFound(d, creature.speciesId, creature.hatchedAt)
	return creature, trimStorage(d, ledger, creatureConfig, economy)
end

function Hatchery.nextSlotCost(d: Data, economy: any): number?
	local index = d.slots - economy.incubators.startingSlots + 1
	return economy.incubators.slotCosts[index]
end

function Hatchery.buySlot(d: Data, ledger: Ledger, economy: any): (boolean, string?)
	local cost = Hatchery.nextSlotCost(d, economy)
	if cost == nil then
		return false, "Every incubator slot is unlocked."
	end
	if not ledger:spend("coins", cost, "Shop:IncubatorSlot") then
		return false, "Not enough coins."
	end
	d.slots += 1
	return true, nil
end

-- Starts riding one of the player's creatures. Returns its mount speed.
function Hatchery.ride(d: Data, uid: string, creatureConfig: any): (number?, string?)
	local creature = Hatchery.creatureByUid(d, uid)
	if creature == nil then
		return nil, "You do not own that creature."
	end
	if uid == d.guardUid then
		return nil, "That creature is guarding your base."
	end
	if creature.slot == nil then
		return nil, "Only a creature on a floor can be ridden."
	end
	local species = creatureConfig.species[creature.speciesId]
	if species == nil then
		return nil, "unknown creature"
	end
	d.mountUid = uid
	return species.mountSpeed, nil
end

function Hatchery.dismount(d: Data)
	d.mountUid = ""
end

-- Rebirth: pay the cost, then start over with more income per creature.
-- Coins, pending earnings and creatures reset; eggs already in incubators,
-- bought slots, passes and stats stay. Nothing is deleted from the save: the
-- old creatures are kept in `rebirthArchive` so support can restore them.
function Hatchery.rebirth(d: Data, ledger: Ledger, economy: any): (boolean, string?)
	local cost = Creatures.rebirthCost(d.rebirths, economy)
	if ledger:balance("coins") < cost then
		return false, "Not enough coins to rebirth."
	end
	ledger:spend("coins", cost, "Gameplay:Rebirth")
	local remaining = ledger:balance("coins")
	if remaining > 0 then
		ledger:spend("coins", remaining, "Gameplay:RebirthReset")
	end
	if economy.startingCoins > 0 then
		ledger:add("coins", economy.startingCoins, "Gameplay:RebirthStart")
	end
	table.insert(d.rebirthArchive, { rebirth = d.rebirths + 1, creatures = d.creatures })
	while #d.rebirthArchive > 5 do
		table.remove(d.rebirthArchive, 1)
	end
	d.creatures = {}
	d.pendingCoins = 0
	d.mountUid = ""
	d.guardUid = ""
	d.rebirths += 1
	return true, nil
end

-- Records a first-time moment. Returns its onboarding step number the first
-- time it happens for this player, ever, and nil after that.
function Hatchery.markFirst(d: Data, name: string, now: number): number?
	local step = table.find(ONBOARDING, name)
	assert(step, `unknown onboarding moment {name}`)
	if d.firsts[name] ~= nil then
		return nil
	end
	d.firsts[name] = now
	return step
end

return Hatchery
