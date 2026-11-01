--!strict
-- The Tidecatch Cove loop as pure functions over saved data: a catch goes
-- into the bucket (or sells when the bucket is full), bucket creatures are
-- placed in tide pools or sold, pools grow by the saved clock and are fed and
-- sold, and coins buy pools, rods and bait.
--
-- Every function runs inside DataService:update on the server, so a refusal
-- or an error leaves the save untouched. Coins only move through the Economy
-- ledger passed in. Nothing here yields, reads a clock or rolls dice: time
-- and catches are arguments, which keeps every rule unit-testable.

local Catch = require("./Catch")
local Creatures = require("./Creatures")

export type Data = { [string]: any }

-- The parts of Economy's ledger used here.
export type Ledger = {
	add: (self: any, currency: string, amount: number, reason: string) -> number,
	spend: (self: any, currency: string, amount: number, reason: string) -> boolean,
	balance: (self: any, currency: string) -> number,
}

export type Config = {
	fishing: any,
	species: any,
	pools: any,
	economy: any,
	monetization: any,
}

export type Perks = {
	autoReel: boolean,
	extraPools: boolean,
	sellMultiplier: boolean,
}

-- What came off the line: decided by the server at the bite.
export type Catch = {
	speciesId: string,
	kg: number,
	mutation: string,
	spotId: string,
}

-- First-time moments reported as onboarding steps, in the only order they
-- can happen. New steps go at the end so step numbers never change. Other
-- first-time moments (a first sale can come before or after a first
-- placement) are recorded in `firsts` and reported as custom events.
local ONBOARDING = { "Joined", "FirstCast", "FirstCatch", "FirstPlaced", "FirstGrowth" }

local Cove = {}
Cove.ONBOARDING = table.freeze(ONBOARDING)

-- A shorter absence is a server hop, not time away: a restock alone is not
-- worth a welcome-back message then.
Cove.WELCOME_MIN_AWAY_SECONDS = 120

-- Records a first-time moment. Returns true the first time it happens for
-- this player, ever, plus its onboarding step number when it has one.
function Cove.markFirst(d: Data, name: string, now: number): (boolean, number?)
	if d.firsts[name] ~= nil then
		return false, nil
	end
	d.firsts[name] = now
	return true, table.find(ONBOARDING, name)
end

-- Gives a brand-new player their starting bait. Call on join, before
-- marking "Joined". Returns true for a new player.
function Cove.welcomeNew(d: Data, economy: any): boolean
	if d.firsts.Joined ~= nil then
		return false
	end
	for baitId, count in economy.startingBait do
		d.bait[baitId] = (d.bait[baitId] or 0) + count
	end
	return true
end

-- Brings pool growth up to date when the player joins: time away counts up to
-- `pools.offline.maxSeconds`, then each growth timer is moved forward so the
-- rest of the absence is never counted later. Returns how many creatures
-- reached a new stage while the player was away, and whether the bait shop
-- restocked meanwhile (only after at least WELCOME_MIN_AWAY_SECONDS away).
function Cove.welcomeBack(d: Data, now: number, config: Config): (number, boolean)
	local lastSeenAt: number = d.lastSeenAt
	local grew = 0
	local restocked = false
	if lastSeenAt > 0 and now > lastSeenAt then
		local cap = config.pools.offline.maxSeconds
		for _, pooled in d.pools do
			local def = config.species.species[pooled.speciesId]
			if def then
				local before = Creatures.stage(pooled, lastSeenAt, config.species, config.pools)
				-- Online time before lastSeenAt counts fully; time away up to the
				-- cap (the same rule as core Timers.rebase).
				local online = math.max(0, lastSeenAt - pooled.placedAt)
				local away = math.max(0, now - math.max(lastSeenAt, pooled.placedAt))
				pooled.placedAt = now - (online + math.min(away, cap))
				local after = Creatures.stage(pooled, now, config.species, config.pools)
				if after > before then
					grew += 1
				end
			end
		end
		local period = config.economy.restockSeconds
		restocked = now - lastSeenAt >= Cove.WELCOME_MIN_AWAY_SECONDS and now // period > lastSeenAt // period
	end
	d.lastSeenAt = now
	return grew, restocked
end

-- Call while the player is online (every tick and before every action):
-- counts play time and marks the player as seen.
function Cove.touch(d: Data, now: number)
	if d.lastSeenAt > 0 and now > d.lastSeenAt then
		d.stats.playSeconds += math.min(now - d.lastSeenAt, 60)
	end
	if now > d.lastSeenAt then
		d.lastSeenAt = now
	end
end

-- Pools the player can use right now.
function Cove.poolCount(d: Data, pools: any, perks: Perks): number
	return d.poolSlots + (if perks.extraPools then pools.passBonusSlots else 0)
end

function Cove.poolAt(d: Data, slot: number): (any?, number?)
	for index, pooled in d.pools do
		if pooled.slot == slot then
			return pooled, index
		end
	end
	return nil, nil
end

function Cove.freePool(d: Data, poolCount: number): number?
	for slot = 1, poolCount do
		if Cove.poolAt(d, slot) == nil then
			return slot
		end
	end
	return nil
end

function Cove.bucketIndex(d: Data, uid: string): number?
	for index, c in d.bucket do
		if c.uid == uid then
			return index
		end
	end
	return nil
end

-- The coins a sale pays, with the Sell Multiplier pass.
function Cove.salePrice(value: number, config: Config, perks: Perks): number
	if perks.sellMultiplier then
		return math.floor(value * config.monetization.sellMultiplier)
	end
	return value
end

local function sell(d: Data, ledger: Ledger, coins: number, reason: string)
	ledger:add("coins", coins, reason)
	d.stats.sold += 1
	d.stats.coinsFromSales += coins
end

-- Records a catch in the journal and stats. Returns true when the species is
-- new to this player's journal.
local function record(d: Data, catch: Catch, now: number): boolean
	local entry = d.journal[catch.speciesId]
	local isNew = entry == nil
	if entry == nil then
		entry = { caught = 0, bestKg = 0, firstAt = now }
		d.journal[catch.speciesId] = entry
	end
	entry.caught += 1
	entry.bestKg = math.max(entry.bestKg, catch.kg)
	d.stats.catches += 1
	if catch.kg > d.stats.biggestKg then
		d.stats.biggestKg = catch.kg
		d.stats.biggestSpecies = catch.speciesId
	end
	return isNew
end

export type Landed = {
	uid: string,
	soldFor: number, -- > 0 when the new catch itself sold at once (bucket full)
	isNew: boolean, -- first of its species in the journal
	-- A bucket creature sold to make room for the new catch (bucket full).
	madeRoom: { speciesId: string, coins: number }?,
}

-- Lands a catch into the bucket. When the bucket is full, the least valuable
-- of the bucket and the new catch sells at once, so a full bucket never
-- throws away a rare catch for small change. A tie keeps what was already in
-- the bucket.
function Cove.land(d: Data, ledger: Ledger, catch: Catch, now: number, config: Config, perks: Perks): Landed
	assert(config.species.species[catch.speciesId], `unknown species {catch.speciesId}`)
	local isNew = record(d, catch, now)
	local uid = tostring(d.nextUid)
	d.nextUid += 1
	local creature = {
		uid = uid,
		speciesId = catch.speciesId,
		kg = catch.kg,
		mutation = catch.mutation,
		caughtAt = now,
		spotId = catch.spotId,
	}
	if #d.bucket >= config.fishing.bucketSlots then
		local function price(c: any): number
			return Cove.salePrice(Creatures.value(c, 1, config.species, config.pools), config, perks)
		end
		local cheapest: number? = nil
		for index, c in d.bucket do
			if cheapest == nil or price(c) < price(d.bucket[cheapest]) then
				cheapest = index
			end
		end
		local newPrice = price(creature)
		if cheapest and price(d.bucket[cheapest]) < newPrice then
			local sold: any = table.remove(d.bucket, cheapest)
			local coins = price(sold)
			sell(d, ledger, coins, "Gameplay:SellCatch")
			table.insert(d.bucket, creature)
			return {
				uid = uid,
				soldFor = 0,
				isNew = isNew,
				madeRoom = { speciesId = sold.speciesId, coins = coins },
			}
		end
		sell(d, ledger, newPrice, "Gameplay:SellCatch")
		return { uid = uid, soldFor = newPrice, isNew = isNew, madeRoom = nil }
	end
	table.insert(d.bucket, creature)
	return { uid = uid, soldFor = 0, isNew = isNew, madeRoom = nil }
end

-- Sells one creature from the bucket. Returns the coins, or nil and a refusal.
function Cove.sellFromBucket(
	d: Data,
	ledger: Ledger,
	uid: string,
	config: Config,
	perks: Perks
): (number?, string?)
	local index = Cove.bucketIndex(d, uid)
	if index == nil then
		return nil, "That creature is not in your bucket."
	end
	local creature: any = table.remove(d.bucket, index)
	local coins = Cove.salePrice(Creatures.value(creature, 1, config.species, config.pools), config, perks)
	sell(d, ledger, coins, "Gameplay:SellCatch")
	return coins, nil
end

-- Sells the whole bucket. Returns the coins and how many creatures sold.
function Cove.sellBucket(d: Data, ledger: Ledger, config: Config, perks: Perks): (number, number)
	local total, count = 0, 0
	for _, creature in d.bucket do
		local coins =
			Cove.salePrice(Creatures.value(creature, 1, config.species, config.pools), config, perks)
		total += coins
		count += 1
		d.stats.sold += 1
	end
	if total > 0 then
		ledger:add("coins", total, "Gameplay:SellBucket")
		d.stats.coinsFromSales += total
	end
	table.clear(d.bucket)
	return total, count
end

-- Moves a bucket creature into the first free pool. Returns the pool slot.
function Cove.place(d: Data, uid: string, now: number, poolCount: number): (number?, string?)
	local index = Cove.bucketIndex(d, uid)
	if index == nil then
		return nil, "That creature is not in your bucket."
	end
	local slot = Cove.freePool(d, poolCount)
	if slot == nil then
		return nil, "Every pool is full. Sell a grown creature first."
	end
	local creature: any = table.remove(d.bucket, index)
	table.insert(d.pools, {
		slot = slot,
		uid = creature.uid,
		speciesId = creature.speciesId,
		kg = creature.kg,
		mutation = creature.mutation,
		placedAt = now,
		fed = 0,
		lastFedAt = 0,
	})
	return slot, nil
end

-- Seconds until a pool can be fed again (0 = now).
function Cove.feedCooldown(pooled: any, now: number, pools: any): number
	if pooled.lastFedAt <= 0 then
		return 0
	end
	return math.max(0, pooled.lastFedAt + pools.feed.cooldownSeconds - now)
end

-- Feeds the creature in a pool: adds growth at once, on a cooldown.
function Cove.feed(d: Data, slot: number, now: number, config: Config): (boolean, string?)
	local pooled = Cove.poolAt(d, slot)
	if pooled == nil then
		return false, "That pool is empty."
	end
	local def = config.species.species[pooled.speciesId]
	if def == nil then
		return false, "unknown creature"
	end
	local pools = config.pools
	if Creatures.grown(pooled, now, def.rarity, pools) >= Creatures.growthSeconds(def.rarity, pools) then
		return false, "It is fully grown. Sell it!"
	end
	local wait = Cove.feedCooldown(pooled, now, pools)
	if wait > 0 then
		return false, `Not hungry yet. Feed again in {math.ceil(wait)}s.`
	end
	pooled.fed += pools.stageSeconds[def.rarity] * pools.feed.stageFraction
	pooled.lastFedAt = now
	return true, nil
end

-- Sells the creature in a pool at its current stage. Returns the coins and
-- the stage it sold at.
function Cove.sellFromPool(
	d: Data,
	ledger: Ledger,
	slot: number,
	now: number,
	config: Config,
	perks: Perks
): (number?, number?, string?)
	local pooled, index = Cove.poolAt(d, slot)
	if pooled == nil or index == nil then
		return nil, nil, "That pool is empty."
	end
	local stage = Creatures.stage(pooled, now, config.species, config.pools)
	local coins = Cove.salePrice(Creatures.value(pooled, stage, config.species, config.pools), config, perks)
	table.remove(d.pools, index)
	sell(d, ledger, coins, "Gameplay:SellGrown")
	return coins, stage, nil
end

function Cove.nextPoolCost(d: Data, pools: any): number?
	return pools.slotCosts[d.poolSlots - pools.startingSlots + 1]
end

function Cove.buyPool(d: Data, ledger: Ledger, pools: any): (boolean, string?)
	local cost = Cove.nextPoolCost(d, pools)
	if cost == nil then
		return false, "Every pool is unlocked."
	end
	if not ledger:spend("coins", cost, "Shop:TidePool") then
		return false, "Not enough coins."
	end
	d.poolSlots += 1
	return true, nil
end

-- Buys the rod at `tier` (any tier above the one owned).
function Cove.buyRod(d: Data, ledger: Ledger, tier: number, fishing: any): (boolean, string?)
	local rod = fishing.rods[tier]
	if rod == nil then
		return false, "unknown rod"
	end
	if tier <= d.rodTier then
		return false, "You already have a rod at least this good."
	end
	if not ledger:spend("coins", rod.priceCoins, `Shop:{rod.id}`) then
		return false, "Not enough coins."
	end
	d.rodTier = tier
	return true, nil
end

-- The start of the bait shop's current restock window.
function Cove.restockWindow(now: number, economy: any): number
	local period = economy.restockSeconds
	return (now // period) * period
end

-- How many of a bait the player may still buy before the next restock.
function Cove.stockLeft(d: Data, bait: any, now: number, economy: any): number
	if d.shop.window ~= Cove.restockWindow(now, economy) then
		return bait.stock
	end
	return math.max(0, bait.stock - (d.shop.bought[bait.id] or 0))
end

-- Buys `count` of a bait with coins, within the current restock's stock.
function Cove.buyBait(
	d: Data,
	ledger: Ledger,
	baitId: string,
	count: number,
	now: number,
	config: Config
): (boolean, string?)
	local bait = Catch.bait(config.fishing, baitId)
	if bait == nil then
		return false, "unknown bait"
	end
	if bait.robux then
		return false, "That bait comes only from Bait Packs and Mystery Bait."
	end
	if count < 1 or count // 1 ~= count then
		return false, "invalid amount"
	end
	local window = Cove.restockWindow(now, config.economy)
	if d.shop.window ~= window then
		d.shop.window = window
		d.shop.bought = {}
	end
	if Cove.stockLeft(d, bait, now, config.economy) < count then
		return false, "Sold out until the next restock."
	end
	if not ledger:spend("coins", bait.priceCoins * count, `Shop:{bait.id}`) then
		return false, "Not enough coins."
	end
	d.shop.bought[bait.id] = (d.shop.bought[bait.id] or 0) + count
	d.bait[bait.id] = (d.bait[bait.id] or 0) + count
	return true, nil
end

-- Robux products. Each runs inside the core's receipt handler, in the same
-- data update that records the receipt, so it lands exactly once.

-- Adds bait to the player's tackle box (Bait Pack, Mystery Bait).
function Cove.grantBait(d: Data, baitId: string, count: number)
	assert(count >= 1 and count // 1 == count, "whole bait counts only")
	d.bait[baitId] = (d.bait[baitId] or 0) + count
end

-- Grows every pooled creature `stages` growth stages at once (Growth Boost).
-- Fully grown creatures stay fully grown. Returns how many creatures grew.
function Cove.growthBoost(d: Data, stages: number, now: number, config: Config): number
	local pools = config.pools
	local grew = 0
	for _, pooled in d.pools do
		local def = config.species.species[pooled.speciesId]
		if def then
			local total = Creatures.growthSeconds(def.rarity, pools)
			local room = total - Creatures.grown(pooled, now, def.rarity, pools)
			if room > 0 then
				pooled.fed += math.min(room, pools.stageSeconds[def.rarity] * stages)
				grew += 1
			end
		end
	end
	return grew
end

-- Restocks the bait shop for this player now (Restock Skip): everything is
-- back in stock until the next shared restock.
function Cove.restockNow(d: Data, now: number, economy: any)
	d.shop.window = Cove.restockWindow(now, economy)
	d.shop.bought = {}
end

-- Uses one bait for a cast. "None" always works.
function Cove.useBait(d: Data, baitId: string): boolean
	if baitId == Catch.NO_BAIT then
		return true
	end
	local have = d.bait[baitId] or 0
	if have < 1 then
		return false
	end
	d.bait[baitId] = have - 1
	return true
end

-- Whether any pooled creature has grown past Tiny.
function Cove.anyGrown(d: Data, now: number, config: Config): boolean
	for _, pooled in d.pools do
		if Creatures.stage(pooled, now, config.species, config.pools) > 1 then
			return true
		end
	end
	return false
end

-- Species caught at least once, and how many species exist.
function Cove.journalCount(d: Data, speciesConfig: any): (number, number)
	local caught, total = 0, 0
	for id in speciesConfig.species do
		total += 1
		if d.journal[id] then
			caught += 1
		end
	end
	return caught, total
end

return Cove
