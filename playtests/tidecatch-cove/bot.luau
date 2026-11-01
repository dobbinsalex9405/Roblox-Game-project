--!strict
-- A Tidecatch Cove player for headless playtests. It fishes through the
-- game's own Harness (the real Actions on a fake store with a hand-moved
-- clock), plays the reel like a person with 0.2 s of reaction lag, keeps or
-- sells what it catches, tends its tide pools and shops, with walking time
-- charged for every trip between the dock, the cove and the island shop.
--
-- Styles differ in what they do with a catch and how patient they are with
-- the pools; see Bot.STYLES.

local Harness = require("../../games/tidecatch-cove/tests/Harness")
local Catch = require("../../games/tidecatch-cove/src/shared/Catch")
local Cove = require("../../games/tidecatch-cove/src/shared/Cove")
local Creatures = require("../../games/tidecatch-cove/src/shared/Creatures")
local Reel = require("../../games/tidecatch-cove/src/shared/Reel")
local Log = require("../../packages/core/src/Log")

Log.setSink(function() end)

local config = Harness.config
local fishing = config.fishing
local species = config.species.species
local pools = config.pools

local Bot = {}

-- Walking, in seconds, from the grey-box Layout: docks at radius 58, coves
-- at 160, the shop on the island at the centre; 16 studs/s.
Bot.COVE_TRIP = 13 -- dock -> cove -> dock
Bot.SHOP_TRIP = 8 -- dock -> island shop -> dock
Bot.LOOK_AT_CATCH = 1 -- the catch card
Bot.REACTION = 0.2

export type Style = {
	name: string,
	-- keep: which rarities go to a pool ("all", "uncommon", "rare", "none")
	keep: string,
	-- sell pools at this stage (5 = Giant), earlier when a pool is needed
	sellStage: number,
	-- feed pools on cooldown when at the cove
	feeds: boolean,
	-- visit the cove at least this often (seconds); 0 = only when needed
	visitEvery: number,
	-- bait policy: "none", "worm" (always worms), "ev" (the bait whose extra
	-- expected value per cast beats its price, if any)
	bait: string,
	-- coins kept back when buying
	reserve: number,
}

Bot.STYLES = {
	-- Pools the best of every catch, sells the rest, feeds, sells at Giant.
	keeper = { name = "keeper", keep = "all", sellStage = 5, feeds = true, visitEvery = 120, bait = "ev", reserve = 50 },
	-- Only Uncommon and up go to a pool.
	grower = { name = "grower", keep = "uncommon", sellStage = 5, feeds = true, visitEvery = 180, bait = "ev", reserve = 50 },
	-- Only Rare and up; feeds them (feeding is worth most on slow growers).
	rareOnly = { name = "rareOnly", keep = "rare", sellStage = 5, feeds = true, visitEvery = 300, bait = "ev", reserve = 50 },
	-- Never uses the pools: sells every catch from the card.
	seller = { name = "seller", keep = "none", sellStage = 5, feeds = false, visitEvery = 0, bait = "ev", reserve = 50 },
	-- Sells pools at Grown (x3) to turn them over fast; always buys worms.
	flipper = { name = "flipper", keep = "all", sellStage = 3, feeds = false, visitEvery = 90, bait = "worm", reserve = 50 },
	-- Never buys bait.
	baitless = { name = "baitless", keep = "all", sellStage = 5, feeds = true, visitEvery = 120, bait = "none", reserve = 50 },
} :: { [string]: Style }

local RARITY_RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }

export type State = {
	style: Style,
	player: any,
	h: any,
	t0: number,
	casts: number,
	catches: number,
	escapes: number,
	tooFast: number,
	swaps: number,
	autoSold: number,
	earned: { fish: number, pool: number },
	spent: { rod: number, pool: number, bait: number },
	walked: number, -- seconds spent walking
	reeling: number, -- seconds in the reel
	waiting: number, -- seconds waiting for bites
	lastVisit: number,
	milestones: { { name: string, at: number } },
	seen: { [string]: boolean },
	timeline: { any },
	refusals: { [string]: number },
	byRarity: { [string]: number },
}

local function mark(b: State, name: string)
	if b.seen[name] then
		return
	end
	b.seen[name] = true
	table.insert(b.milestones, { name = name, at = b.h.time - b.t0 })
end

local function clockStr(seconds: number): string
	seconds = math.floor(seconds)
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end
Bot.clockStr = clockStr

-- Plays one reel like a person: a 0.2 s stale view of the fish, leading the
-- zone by its speed (the same player as tests/Reel.spec). Returns caught and
-- the seconds it took after the bite, hook tap included.
function Bot.playReel(rarity: string, rodTier: number, random: () -> number): (boolean, number)
	local params = Reel.params(rarity, rodTier, fishing)
	local state = Reel.new(params, random)
	local dt = 1 / 60
	local seen: { number } = {}
	local lagFrames = math.floor(Bot.REACTION / dt)
	while true do
		table.insert(seen, state.fish)
		local delayed = seen[math.max(1, #seen - lagFrames)]
		local holding = state.zone + state.zoneVelocity * 0.35 < delayed
		local result = Reel.step(state, params, dt, holding, random)
		if result then
			return result == "caught", fishing.reel.reactionSeconds + 0.15 + state.elapsed
		end
	end
end

local function bestSpot(d: any): any
	local best = fishing.spots[1]
	for _, spot in fishing.spots do
		if not spot.lowTideOnly and d.rodTier >= spot.minRod then
			best = spot
		end
	end
	return best
end

local function value(creature: any, stage: number): number
	return Creatures.value(creature, stage, config.species, pools)
end

local function keeps(style: Style, speciesId: string): boolean
	local rank = RARITY_RANK[species[speciesId].rarity]
	if style.keep == "all" then
		return true
	elseif style.keep == "uncommon" then
		return rank >= 2
	elseif style.keep == "rare" then
		return rank >= 3
	end
	return false
end

local function refused(b: State, ok: boolean, why: string?)
	if not ok then
		local key = why or "?"
		b.refusals[key] = (b.refusals[key] or 0) + 1
	end
	return ok
end

-- Coins earned from sales so far: fish (bucket and auto) and pool sales.
-- Economy events arrive as (flow, currency, amount, balance, type, sku).
local function earned(b: State): (number, number)
	local fish, pool = 0, 0
	for _, e in b.h.eventsOf("economy") do
		if e[1] == "Source" and e[5] == "Gameplay" then
			if e[6] == "SellGrown" then
				pool += e[3]
			else
				fish += e[3]
			end
		end
	end
	return fish, pool
end

local function walk(b: State, seconds: number)
	b.walked += seconds
	b.h.wait(seconds)
end

-- Potential value: what the creature sells for as a Giant.
local function potential(creature: any): number
	return value(creature, 5)
end

-- The pool worth replacing: the lowest potential, if it is still Tiny or
-- Young (a Grown or better pool is left to finish). Returns it and its potential.
local function worstPool(d: any, now: number): (any?, number)
	local worst, worstValue = nil, math.huge
	for _, pooled in d.pools do
		local stage = Creatures.stage(pooled, now, config.species, pools)
		local v = potential(pooled)
		if stage <= 2 and v < worstValue then
			worst, worstValue = pooled, v
		end
	end
	return worst, worstValue
end

-- Whether a kept creature should wait in the bucket for a pool swap.
local function swapWorth(d: any, creature: any, now: number): boolean
	local worst, worstValue = worstPool(d, now)
	return worst ~= nil and potential(creature) > worstValue * 1.5
end

-- What the bot does at the cove: sell pools at the target stage, swap a
-- weak pool for a better bucket creature, feed, and place from the bucket.
local function tendPools(b: State)
	local h, p, style = b.h, b.player, b.style
	local d = h.get(p)
	local now = math.floor(h.time)
	for _, pooled in table.clone(d.pools) do
		local stage = Creatures.stage(pooled, now, config.species, pools)
		if stage >= style.sellStage then
			if refused(b, h.actions:sellPool(p, pooled.slot)) then
				mark(b, "FirstPoolSale")
				if stage == 5 then
					mark(b, "FirstGiantSold")
				end
			end
		elseif style.feeds and Cove.feedCooldown(pooled, now, pools) == 0 then
			if refused(b, h.actions:feed(p, pooled.slot)) then
				mark(b, "FirstFeed")
			end
		end
	end
	-- Bucket creatures waiting for a pool: best first.
	local bucket = table.clone(h.get(p).bucket)
	table.sort(bucket, function(a, c)
		return potential(a) > potential(c)
	end)
	local count = Cove.poolCount(h.get(p), pools, h.perks)
	for _, creature in bucket do
		local dd = h.get(p)
		if Cove.freePool(dd, count) == nil then
			if swapWorth(dd, creature, now) then
				local worst = worstPool(dd, now)
				refused(b, h.actions:sellPool(p, (worst :: any).slot))
				b.swaps += 1
			end
		end
		if Cove.freePool(h.get(p), count) ~= nil then
			if refused(b, h.actions:place(p, creature.uid)) then
				mark(b, "FirstPlaced")
			end
		else
			refused(b, h.actions:sellCatch(p, creature.uid))
		end
	end
end

-- The catch card: keep (place from the HUD when a pool is free, or hold it
-- for a swap at the cove) or sell.
local function decideCatch(b: State, creature: any)
	local h, p, style = b.h, b.player, b.style
	local d = h.get(p)
	local now = math.floor(h.time)
	if not keeps(style, creature.speciesId) then
		refused(b, h.actions:sellCatch(p, creature.uid))
		return
	end
	local count = Cove.poolCount(d, pools, h.perks)
	if Cove.freePool(d, count) ~= nil then
		if refused(b, h.actions:place(p, creature.uid)) then
			mark(b, "FirstPlaced")
		end
		return
	end
	if swapWorth(d, creature, now) and #d.bucket <= 3 then
		return -- wait for the next cove trip
	end
	refused(b, h.actions:sellCatch(p, creature.uid))
end

local function shop(b: State)
	local h, p, style = b.h, b.player, b.style
	local d = h.get(p)
	local coins = d.coins - style.reserve
	local trips = 0
	local function buy(fn: () -> boolean): boolean
		if trips == 0 then
			walk(b, Bot.SHOP_TRIP / 2)
		end
		trips += 1
		return fn()
	end
	-- Rod first: it opens a spot and widens the zone.
	local nextRod = fishing.rods[d.rodTier + 1]
	if nextRod and coins >= nextRod.priceCoins then
		if buy(function()
			return refused(b, h.actions:buyRod(p, d.rodTier + 1))
		end) then
			b.spent.rod += nextRod.priceCoins
			mark(b, nextRod.id)
			coins -= nextRod.priceCoins
		end
	end
	-- Pools while there is something to put in them.
	local poolCost = Cove.nextPoolCost(h.get(p), pools)
	if style.keep ~= "none" and poolCost and coins >= poolCost then
		if buy(function()
			return refused(b, h.actions:buyPool(p))
		end) then
			b.spent.pool += poolCost
			mark(b, `Pool{h.get(p).poolSlots}`)
			coins -= poolCost
		end
	end
	-- Bait: the style's bait, a few casts' worth at a time.
	local want = Bot.baitFor(b)
	if want then
		local have = h.get(p).bait[want.id] or 0
		if have < 3 and coins >= want.priceCoins then
			local now = math.floor(h.time)
			local left = Cove.stockLeft(h.get(p), want, now, config.economy)
			local count = math.min(5, left, coins // want.priceCoins)
			if count >= 1 then
				if buy(function()
					return refused(b, h.actions:buyBait(p, want.id, count))
				end) then
					b.spent.bait += count * want.priceCoins
				end
			elseif left == 0 then
				local key = "(sold out: " .. want.id .. ")"
				b.refusals[key] = (b.refusals[key] or 0) + 1
			end
		end
	end
	if trips > 0 then
		walk(b, Bot.SHOP_TRIP / 2)
	end
end

-- Expected coins per cast at a spot with a bait, as the odds board shows it
-- for this player (rod included), at the Tiny sale price of an average size.
function Bot.expectedValue(h: any, player: any, spotId: string, baitId: string): number
	local rows = h.odds:display(Catch.tableId(spotId, baitId), player).rows
	local ev = 0
	for _, row in rows do
		local def = species[row.id]
		local avg = { uid = "", speciesId = row.id, kg = (def.minKg + def.maxKg) / 2, mutation = "None" }
		ev += row.weight / 10000 * value(avg, 1)
	end
	return ev
end

-- The bait the style buys at the best spot: nil for none.
function Bot.baitFor(b: State): any?
	local h, p, style = b.h, b.player, b.style
	if style.bait == "none" then
		return nil
	elseif style.bait == "worm" then
		return Catch.bait(fishing, "Worm")
	end
	local d = h.get(p)
	local spot = bestSpot(d)
	local base = Bot.expectedValue(h, p, spot.id, Catch.NO_BAIT)
	local best, bestGain = nil, 0
	for _, bait in fishing.bait do
		local gain = Bot.expectedValue(h, p, spot.id, bait.id) - base - bait.priceCoins
		if gain > bestGain and d.coins - style.reserve >= bait.priceCoins * 5 then
			best, bestGain = bait, gain
		end
	end
	return best
end

local function pickBait(b: State): string
	local d = b.h.get(b.player)
	if b.style.bait == "none" then
		return Catch.NO_BAIT
	end
	local best = Catch.NO_BAIT
	for _, bait in fishing.bait do
		if (d.bait[bait.id] or 0) > 0 then
			best = bait.id
		end
	end
	return best
end

-- One cast to the end, then the catch card. Returns "caught", "escaped" or "refused".
local function fishOnce(b: State): string
	local h, p = b.h, b.player
	local d = h.get(p)
	local spot = bestSpot(d)
	local baitId = pickBait(b)
	local before = #h.bites
	local t = h.time
	local ok, why = h.actions:cast(p, spot.id, baitId)
	if not refused(b, ok, why) then
		return "refused"
	end
	b.casts += 1
	mark(b, "FirstCast")
	local bite = nil
	for _ = 1, 200 do
		if #h.bites > before then
			bite = h.bites[#h.bites]
			break
		end
		h.wait(0.25)
	end
	b.waiting += h.time - t
	if bite == nil then
		-- "Nothing is biting" (no bait match) or the line was lost.
		return "escaped"
	end
	local caught, seconds = Bot.playReel(bite.rarity, d.rodTier, h.random)
	b.reeling += seconds
	h.wait(seconds)
	local landed = h.actions:reel(p, bite.id, caught)
	if not landed then
		b.escapes += 1
		return "escaped"
	end
	b.catches += 1
	local last = h.caught[#h.caught]
	local def = species[last.speciesId]
	b.byRarity[def.rarity] = (b.byRarity[def.rarity] or 0) + 1
	mark(b, "FirstCatch")
	mark(b, `First{def.rarity}`)
	if last.isNew then
		local n = Cove.journalCount(h.get(p), config.species)
		if n == 5 or n == 10 or n == 15 or n == 20 or n == 25 then
			mark(b, `Journal{n}`)
		end
	end
	if last.soldFor > 0 then
		mark(b, "BucketFullAutoSale")
		b.autoSold += 1
	end
	h.wait(Bot.LOOK_AT_CATCH)
	if last.soldFor == 0 then
		local creature = h.get(p).bucket[Cove.bucketIndex(h.get(p), last.uid) :: number]
		if creature then
			decideCatch(b, creature)
		end
	end
	return "caught"
end

function Bot.new(h: any, player: any, style: Style): State
	return {
		style = style,
		player = player,
		h = h,
		t0 = h.time,
		casts = 0,
		catches = 0,
		escapes = 0,
		tooFast = 0,
		swaps = 0,
		autoSold = 0,
		earned = { fish = 0, pool = 0 },
		spent = { rod = 0, pool = 0, bait = 0 },
		walked = 0,
		reeling = 0,
		waiting = 0,
		lastVisit = h.time,
		milestones = {},
		seen = {},
		timeline = {},
		refusals = {},
		byRarity = {},
	}
end

-- Whether a trip to the cove is worth it right now.
local function wantsCove(b: State): boolean
	local h, p, style = b.h, b.player, b.style
	local d = h.get(p)
	local now = math.floor(h.time)
	if style.keep == "none" then
		return false
	end
	for _, pooled in d.pools do
		if Creatures.stage(pooled, now, config.species, pools) >= style.sellStage then
			return true
		end
	end
	for _, c in d.bucket do
		if keeps(style, c.speciesId) and swapWorth(d, c, now) then
			return true
		end
	end
	if style.visitEvery > 0 and h.time - b.lastVisit >= style.visitEvery then
		for _, pooled in d.pools do
			local def = species[pooled.speciesId]
			if style.feeds and Creatures.grown(pooled, now, def.rarity, pools) < Creatures.growthSeconds(def.rarity, pools) then
				return true
			end
		end
	end
	return false
end

-- Plays for `seconds`, recording a timeline row every minute.
function Bot.play(b: State, seconds: number, onMinute: ((b: State, minute: number) -> ())?)
	local h, p = b.h, b.player
	local stop = b.t0 + seconds
	local nextMinute = 1
	while h.time < stop do
		if wantsCove(b) then
			walk(b, Bot.COVE_TRIP / 2)
			tendPools(b)
			b.lastVisit = h.time
			walk(b, Bot.COVE_TRIP / 2)
		end
		shop(b)
		fishOnce(b)
		local firsts = h.get(p).firsts
		if firsts.FirstGrowth then
			mark(b, "FirstGrowth")
		end
		if firsts.FirstSale then
			mark(b, "FirstSale")
		end
		-- Timeline.
		while h.time - b.t0 >= nextMinute * 60 and nextMinute * 60 <= seconds do
			local dd = h.get(p)
			local fish, pool = earned(b)
			b.earned.fish, b.earned.pool = fish, pool
			local poolValueNow = 0
			local now = math.floor(h.time)
			for _, pooled in dd.pools do
				poolValueNow += value(pooled, Creatures.stage(pooled, now, config.species, pools))
			end
			local journal = Cove.journalCount(dd, config.species)
			table.insert(b.timeline, {
				minute = nextMinute,
				coins = dd.coins,
				fish = fish,
				pool = pool,
				casts = b.casts,
				catches = b.catches,
				escapes = b.escapes,
				rod = dd.rodTier,
				slots = dd.poolSlots,
				pooled = #dd.pools,
				poolValue = poolValueNow,
				bucket = #dd.bucket,
				journal = journal,
				worms = dd.bait.Worm or 0,
			})
			if onMinute then
				onMinute(b, nextMinute)
			end
			nextMinute += 1
		end
	end
	b.tooFast = #h.customEvents("Fish:ReelTooFast")
	local fish, pool = earned(b)
	b.earned.fish, b.earned.pool = fish, pool
end

function Bot.printTimeline(b: State)
	print("  min   coins   fish$  pool$  casts catch  esc  rod slots pooled poolVal bucket journal worms")
	for _, r in b.timeline do
		print(string.format(
			"  %3d %7d %7d %6d  %5d %5d %4d  %3d  %4d  %5d  %6d  %5d  %5d  %5d",
			r.minute, r.coins, r.fish, r.pool, r.casts, r.catches, r.escapes, r.rod, r.slots, r.pooled,
			r.poolValue, r.bucket, r.journal, r.worms
		))
	end
end

function Bot.printMilestones(b: State)
	for _, m in b.milestones do
		print(string.format("  %8s  %s", clockStr(m.at), m.name))
	end
end

function Bot.summary(b: State): string
	local d = b.h.get(b.player)
	local journal = Cove.journalCount(d, config.species)
	local parts = {}
	for _, r in { "Common", "Uncommon", "Rare", "Epic", "Legendary" } do
		table.insert(parts, `{r} {b.byRarity[r] or 0}`)
	end
	return string.format(
		"coins %d (fish sales %d, pool sales %d; spent rod %d, pools %d, bait %d), casts %d, catches %d, escapes %d, too-fast %d, swaps %d, auto-sold %d, rod %d, pools %d/%d, journal %d/25, walked %ds, reeling %ds, waiting %ds; %s",
		d.coins, b.earned.fish, b.earned.pool, b.spent.rod, b.spent.pool, b.spent.bait,
		b.casts, b.catches, b.escapes, b.tooFast, b.swaps, b.autoSold, d.rodTier, #d.pools, d.poolSlots, journal,
		b.walked, b.reeling, b.waiting, table.concat(parts, ", ")
	)
end

return Bot
