--!strict
-- Hatchery Heist progression simulator: plays the game's economy, from the
-- real config files and the real income, tower and daily-reward code, for a
-- player who plays a set number of minutes a day, and records when they reach
-- each milestone (first Rare, each tower floor, each incubator ...).
--
-- It models choices, not walking: a simulated player hatches what is ready,
-- presses Place best, buys the floor, upgrade or incubator that pays for
-- itself fastest, and buys the eggs that raise income most for the time and
-- coins they cost. Walking to the Egg Market and back, buying and hatching
-- cost the seconds in `Sim.TIMING`. The belt is shared, so each egg type
-- arrives for this player at its share of the belt divided between
-- `competitors` other shoppers.
--
-- Used by tools/economy/run.luau (tables for the economy proposal) and
-- tools/tests/EconomySim.spec.luau. See ops/ECONOMY.md.

local Creatures = require("../../games/hatchery-heist/src/shared/Creatures")
local Daily = require("../../games/hatchery-heist/src/shared/Daily")
local Eggs = require("../../games/hatchery-heist/src/shared/Eggs")
local Hatchery = require("../../games/hatchery-heist/src/shared/Hatchery")
local Tower = require("../../games/hatchery-heist/src/shared/Tower")

local Sim = {}

local SIM_STORED = 24

-- How far ahead (seconds of play) a simulated player weighs a tower buy
-- against spending the same coins on eggs.
Sim.HORIZON = 8 * 3600

Sim.RARITIES = Eggs.RARITIES

-- Seconds each step takes in the real game (measured on the Staging map:
-- base to Egg Market is about 85 studs, plus the elevator or ladder).
Sim.TIMING = {
	marketStuds = 85, -- one way, base to belt
	tripOverhead = 4, -- leaving the tower, lining up at the belt
	walkSpeed = 16, -- on foot; riding uses the best owned creature's mountSpeed
	buySeconds = 1, -- per egg: the Buy prompt
	hatchSeconds = 0.5, -- per egg: the Hatch prompt
	marketWait = 10, -- longest wait at the belt for a wanted egg to come round
}

-- Timed events (the events thread's design, Nov 7: one random 30-minute
-- window a UTC day, one kind per day). Not in config/ yet; set
-- `Sim.EVENTS.enabled = false` to play without them.
Sim.EVENTS = {
	enabled = true,
	windowSeconds = 30 * 60,
	kinds = {
		{ id = "EggSale", priceFactor = 0.5 },
		{ id = "SpeedyIncubators", hatchFactor = 0.5 },
		{ id = "MoneyRush", incomeFactor = 2 },
		{ id = "LuckyHatch", luckFactor = 2 }, -- Rare and rarer weights x2
	},
}

-- How eggs are sold. `shop = true` models a proposed Egg Shop counter that
-- always has every unlocked egg (the belt then only adds deals), so no egg
-- is ever sold out.
Sim.MARKET = { shop = false }

export type Profile = {
	name: string,
	label: string,
	firstSessionMinutes: number,
	sessionsPerDay: number,
	sessionMinutes: number,
	perks: { doubleCoins: boolean, extraIncubators: boolean },
	competitors: number,
	-- Equipped charms (items design, Nov 7): income adds to the book bonus,
	-- luck multiplies Rare-and-up weights, hatch multiplies hatch time.
	charms: { income: number, luck: number, hatch: number }?,
}

Sim.PROFILES = {
	{
		name = "casual",
		label = "Casual: 25 min on day 1, then 20 min a day",
		firstSessionMinutes = 25,
		sessionsPerDay = 1,
		sessionMinutes = 20,
		perks = { doubleCoins = false, extraIncubators = false },
		competitors = 3,
	},
	{
		name = "regular",
		label = "Regular: 40 min on day 1, then 2 x 30 min a day",
		firstSessionMinutes = 40,
		sessionsPerDay = 2,
		sessionMinutes = 30,
		perks = { doubleCoins = false, extraIncubators = false },
		competitors = 3,
	},
	{
		name = "grinder",
		label = "Grinder: 90 min on day 1, then 3 x 60 min a day",
		firstSessionMinutes = 90,
		sessionsPerDay = 3,
		sessionMinutes = 60,
		perks = { doubleCoins = false, extraIncubators = false },
		competitors = 3,
	},
	{
		name = "charms",
		label = "Regular with a full set of Godly charms from day 1",
		firstSessionMinutes = 40,
		sessionsPerDay = 2,
		sessionMinutes = 30,
		perks = { doubleCoins = false, extraIncubators = false },
		competitors = 3,
		charms = { income = 0.12, luck = 1.2, hatch = 0.8 },
	},
	{
		name = "heist",
		label = "Regular on a Heist Island (+30% income while there)",
		firstSessionMinutes = 40,
		sessionsPerDay = 2,
		sessionMinutes = 30,
		perks = { doubleCoins = false, extraIncubators = false },
		competitors = 3,
		-- modelled as an income bonus beside the book's, like a charm
		charms = { income = 0.3, luck = 1, hatch = 1 },
	},
	{
		name = "payer",
		label = "Regular who buys Double Coins + Extra Incubators on day 1",
		firstSessionMinutes = 40,
		sessionsPerDay = 2,
		sessionMinutes = 30,
		perks = { doubleCoins = true, extraIncubators = true },
		competitors = 3,
	},
} :: { Profile }

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

-- The game's config as the server loads it, copied so a patch can change it.
-- `patch` (optional) is called with the raw tables before eggs are expanded.
function Sim.loadConfig(patch: ((any) -> ())?): any
	local raw = {
		economy = deepCopy(require("../../games/hatchery-heist/config/economy")),
		creatures = deepCopy(require("../../games/hatchery-heist/config/creatures")),
		eggs = deepCopy(require("../../games/hatchery-heist/config/eggs")),
	}
	if patch then
		patch(raw)
	end
	raw.expanded = Eggs.expand(raw.eggs, raw.creatures.species)
	return raw
end

-- Park-Miller: the same numbers on every machine for the same seed.
local function rng(seed: number): () -> number
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function(): number
		state = (state * 48271) % 2147483647
		return (state - 1) / 2147483646
	end
end

local function rarityIndex(r: string): number
	for i, name in Sim.RARITIES do
		if name == r then
			return i
		end
	end
	return 0
end

-- Per-egg facts the player uses to choose: outcomes with their income, size
-- and chance.
local function eggFacts(config: any): { any }
	local out = {}
	for _, egg in config.expanded do
		if egg.priceCoins then
			local total = 0
			for _, o in egg.outcomes do
				total += o.weight
			end
			local outcomes = {}
			for _, o in egg.outcomes do
				local s = config.creatures.species[o.id]
				table.insert(outcomes, {
					id = o.id,
					p = o.weight / total,
					income = s.coinsPerSecond,
					size = config.economy.tower.slotsByRarity[s.rarity] or 1,
					rarity = s.rarity,
				})
			end
			table.insert(out, {
				id = egg.id,
				price = egg.priceCoins,
				hatch = egg.hatchSeconds,
				total = total,
				outcomes = outcomes,
				share = (config.economy.conveyor.weights[egg.id] or 0),
				requiresFloor = egg.requiresFloor, -- proposed field: tower floors needed to buy
			})
		end
	end
	local shareTotal = 0
	for _, e in out do
		shareTotal += e.share
	end
	for _, e in out do
		e.share = if shareTotal > 0 then e.share / shareTotal else 0
	end
	return out
end

-- Spot multipliers (every pad on every owned floor, best first) and per-pad
-- incomes (every creature split over the pads it takes, best first): the
-- tower's income before global multipliers is the sum of their products.
local function spotMults(d: any, economy: any, floors: number?, bump: { [number]: number }?): { number }
	local out = {}
	for floor = floors or Tower.owned(d), 1, -1 do
		local m = if floor <= Tower.owned(d) then Tower.multiplier(d, floor, economy) else 0
		if floor > Tower.owned(d) then
			-- a floor not bought yet: what it earns on the day it is bought
			local t = economy.tower
			m = 1 + t.floorBonus * (floor - 2) + t.startBonus
		end
		if bump and bump[floor] then
			m += bump[floor]
		end
		for _ = 1, Tower.SPOTS do
			table.insert(out, m)
		end
	end
	table.sort(out, function(a, b)
		return a > b
	end)
	return out
end

local function padValues(d: any, config: any): { number }
	local out = {}
	local limit = Tower.owned(d) * Tower.SPOTS + Tower.SPOTS
	for _, c in d.creatures do
		local s = config.creatures.species[c.speciesId]
		local size = config.economy.tower.slotsByRarity[s.rarity] or 1
		local each = Hatchery.creatureIncome(c, config.creatures) / size
		for _ = 1, size do
			table.insert(out, each)
		end
	end
	table.sort(out, function(a, b)
		return a > b
	end)
	-- only the best `limit` can ever be placed (one floor of headroom for the
	-- floor-buy estimate)
	for k = #out, limit + 1, -1 do
		out[k] = nil
	end
	return out
end

local function dot(values: { number }, mults: { number }): number
	local total = 0
	for i = 1, math.min(#values, #mults) do
		total += values[i] * mults[i]
	end
	return total
end

-- Income added by one more creature earning `income` over `size` pads.
local function insertGain(values: { number }, mults: { number }, income: number, size: number): number
	local each = income / size
	local merged = {}
	local placed = 0
	for _, v in values do
		while placed < size and each > v do
			table.insert(merged, each)
			placed += 1
		end
		table.insert(merged, v)
	end
	while placed < size do
		table.insert(merged, each)
		placed += 1
	end
	return dot(merged, mults) - dot(values, mults)
end

export type Result = {
	profile: string,
	seed: number,
	milestones: { [string]: { minutes: number, day: number } },
	days: { any },
}

-- Plays one player for `days` days. Returns when each milestone was first
-- reached (in minutes of play and the day) and a snapshot at each day's end.
function Sim.run(config: any, profile: Profile, days: number, seed: number): Result
	local random = rng(seed)
	local economy = config.economy
	local T = Sim.TIMING
	local facts = eggFacts(config)
	local perks = { doubleCoins = profile.perks.doubleCoins, extraIncubators = profile.perks.extraIncubators }

	local d: any = {
		coins = economy.startingCoins,
		rebirths = 0,
		slots = economy.incubators.startingSlots,
		incubators = {},
		creatures = {},
		nextUid = 1,
		found = {},
		floors = 1,
		floorUpgrades = {},
		mountUid = "",
		guardUid = "",
	}
	local now = 0 -- simulated wall clock, seconds
	local played = 0 -- seconds of play
	local day = 1
	local milestones: { [string]: { minutes: number, day: number } } = {}
	local eggsBought: { [string]: number } = {}
	local tokens: { [string]: number } = {}
	local streak = 0

	local function mark(name: string)
		if milestones[name] == nil then
			milestones[name] = { minutes = played / 60, day = day }
		end
	end

	local function slotCount(): number
		return d.slots + (if perks.extraIncubators then economy.incubators.passBonusSlots else 0)
	end

	-- Today's event window: { startAt, endAt, kind }.
	local eventToday: any = nil
	local eventActive: any = nil
	local function pickEvent(dayIndex: number)
		if not Sim.EVENTS.enabled then
			eventToday = nil
			return
		end
		local kinds = Sim.EVENTS.kinds
		local startAt = (dayIndex - 1) * 86400 + random() * (86400 - Sim.EVENTS.windowSeconds)
		eventToday = {
			startAt = startAt,
			endAt = startAt + Sim.EVENTS.windowSeconds,
			kind = kinds[math.floor(random() * #kinds) + 1],
		}
	end
	local charms = profile.charms or { income = 0, luck = 1, hatch = 1 }
	local function incomeBoost(): number
		local book = Hatchery.bookBonus(d, { creatures = config.creatures, economy = economy })
		local charm = (1 + book + charms.income) / (1 + book)
		return charm * (if eventActive and eventActive.incomeFactor then eventActive.incomeFactor else 1)
	end
	local function priceOf(e: any): number
		return if eventActive and eventActive.priceFactor
			then math.floor(e.price * eventActive.priceFactor)
			else e.price
	end
	local function hatchOf(e: any): number
		local factor = charms.hatch
			* (if eventActive and eventActive.hatchFactor then eventActive.hatchFactor else 1)
		return e.hatch * math.max(factor, 0.5) -- charms and events together: at most -50%
	end

	-- Income and the choice inputs only change when the tower or the
	-- creatures do, so they are cached until `dirty()`.
	local cachedIncome: number? = nil
	local ctx: any = nil
	local function dirty()
		cachedIncome = nil
		ctx = nil
	end
	local function income(): number
		if cachedIncome == nil then
			cachedIncome = Hatchery.incomePerSecond(
				d,
				{ creatures = config.creatures, economy = economy },
				perks
			) * incomeBoost()
		end
		return cachedIncome :: number
	end

	local function globalMult(): number
		return Creatures.multiplier(d.rebirths, perks.doubleCoins, economy)
			* (1 + Hatchery.bookBonus(d, { creatures = config.creatures, economy = economy }))
	end

	local function tierCounts(): { [string]: number }
		local out = {}
		for _, s in config.creatures.species do
			out[s.rarity] = (out[s.rarity] or 0) + 1
		end
		return out
	end
	local counts = tierCounts()

	local function bestMountSpeed(): number
		local best = T.walkSpeed
		for _, c in d.creatures do
			best = math.max(best, config.creatures.species[c.speciesId].mountSpeed or T.walkSpeed)
		end
		return best
	end

	local function placeBest()
		Tower.placeBest(d, config.creatures, economy, function(c)
			return Hatchery.creatureIncome(c, config.creatures)
		end)
		dirty()
	end

	-- Advance the clock while playing: income lands, belt eggs arrive.
	local function advance(dt: number)
		if dt <= 0 then
			return
		end
		d.coins += income() * dt
		now += dt
		played += dt
		for _, e in facts do
			if Sim.MARKET.shop then
				tokens[e.id] = math.huge
			else
				local cap = 60 * e.share / profile.competitors
				local rate = 2 * e.share / profile.competitors
				tokens[e.id] = math.min(cap, (tokens[e.id] or cap) + rate * dt)
			end
		end
	end

	local function hatchReady(): number
		local n = 0
		local keep = {}
		local bestNew = 0 -- best new per-pad income
		local newBook = false
		for _, inc in d.incubators do
			if inc.readyAt <= now then
				local species = config.creatures.species[inc.outcome]
				bestNew = math.max(
					bestNew,
					species.coinsPerSecond / (economy.tower.slotsByRarity[species.rarity] or 1)
				)
				newBook = newBook or d.found[inc.outcome] == nil
				local creature = {
					uid = tostring(d.nextUid),
					speciesId = inc.outcome,
					mutation = "None",
					slot = nil,
				}
				d.nextUid += 1
				table.insert(d.creatures, creature)
				if d.found[inc.outcome] == nil then
					d.found[inc.outcome] = now
				end
				local rarity = config.creatures.species[inc.outcome].rarity
				mark("first " .. rarity)
				n += 1
			else
				table.insert(keep, inc)
			end
		end
		d.incubators = keep
		if n > 0 then
			-- Place best changes nothing when the tower is full and every new
			-- creature earns less per pad than the weakest placed one.
			local weakest = math.huge
			for _, c in d.creatures do
				if c.slot then
					local sp = config.creatures.species[c.speciesId]
					local size = economy.tower.slotsByRarity[sp.rarity] or 1
					weakest = math.min(weakest, Hatchery.creatureIncome(c, config.creatures) / size)
				end
			end
			if bestNew <= weakest and Tower.full(d, config.creatures, economy) then
				if newBook then
					dirty() -- the book bonus moved
				end
			else
				placeBest()
			end
			-- Storage: keep the best placed + `storage.slots` stored.
			local stored = {}
			for i, c in d.creatures do
				if c.slot == nil then
					table.insert(stored, i)
				end
			end
			-- The game sells the weakest stored creature once storage passes
			-- `storage.slots`. Stored creatures never earn, so the sim keeps
			-- only the best SIM_STORED (fast; the coins lost are a rounding
			-- error: a Common sells for 20 s of 1-3 coins/s).
			local keepStored = math.min(economy.storage.slots, SIM_STORED)
			if #stored > keepStored then
				table.sort(stored, function(a, b)
					return Hatchery.creatureIncome(d.creatures[a], config.creatures)
						> Hatchery.creatureIncome(d.creatures[b], config.creatures)
				end)
				local drop = {}
				for k = keepStored + 1, #stored do
					drop[stored[k]] = true
				end
				local kept = {}
				for i, c in d.creatures do
					if drop[i] then
						d.coins += Hatchery.sellValue(c, config.creatures, economy)
					else
						table.insert(kept, c)
					end
				end
				d.creatures = kept
			end
		end
		return n
	end

	-- Expected income gain (coins/s, after global multipliers) from one egg.
	local function eggGain(e: any, values: { number }, mults: { number }, gm: number, baseNow: number): number
		local cache: { [string]: number } = {}
		local gain = 0
		for _, o in e.outcomes do
			local key = `{o.income}/{o.size}`
			local g = cache[key]
			if g == nil then
				g = insertGain(values, mults, o.income, o.size)
				cache[key] = g
			end
			local bookGain = 0
			if d.found[o.id] == nil then
				bookGain = economy.book.maxBonus
					* (economy.book.tierShare[o.rarity] or 0)
					/ counts[o.rarity]
					* baseNow
			end
			gain += o.p * (g * gm + bookGain)
		end
		return gain
	end

	-- The best tower purchase now: { kind, floor?, price, gain }.
	local function bestUpgrade(values: { number }, gm: number): any?
		local base = dot(values, spotMults(d, economy))
		local best = nil
		local function consider(option: any)
			if option.gain <= 0 then
				return
			end
			option.payback = option.price / option.gain
			if best == nil or option.payback < best.payback then
				best = option
			end
		end
		local floorPrice = Tower.nextFloorPrice(d, economy)
		if floorPrice then
			local mults = spotMults(d, economy, Tower.owned(d) + 1)
			consider({ kind = "floor", price = floorPrice, gain = (dot(values, mults) - base) * gm })
		end
		for floor = 2, Tower.owned(d) do
			local price = Tower.nextUpgradePrice(d, floor, economy)
			if price then
				local mults = spotMults(d, economy, nil, { [floor] = economy.tower.upgradeBonus })
				consider({
					kind = "upgrade",
					floor = floor,
					price = price,
					gain = (dot(values, mults) - base) * gm,
				})
			end
		end
		return best
	end

	local function context(): any
		if ctx == nil then
			local values = padValues(d, config)
			local mults = spotMults(d, economy)
			local gm = globalMult()
			local baseNow = dot(values, mults) * Creatures.multiplier(d.rebirths, perks.doubleCoins, economy)
			local gains = {}
			-- Egg spending's best rate of income growth (coins/s gained per
			-- second): an egg's expected gain times how fast eggs can be bought,
			-- by coins or by incubators, whichever runs out first.
			local eggRate = 0
			local inc = math.max(income(), 0.5)
			for _, e in facts do
				local g = eggGain(e, values, mults, gm, baseNow)
				gains[e.id] = g
				if g > 0 and Tower.owned(d) >= (e.requiresFloor or 1) then
					local perSecond = math.min(slotCount() / hatchOf(e), inc / priceOf(e))
					eggRate = math.max(eggRate, g * perSecond)
				end
			end
			ctx = {
				values = values,
				mults = mults,
				gm = gm,
				gains = gains,
				eggRate = eggRate,
				upgrade = bestUpgrade(values, gm),
			}
		end
		return ctx
	end

	local function rollOutcome(e: any): string
		local luck = charms.luck
			* (if eventActive and eventActive.luckFactor then eventActive.luckFactor else 1)
		local function w(o: any): number
			if luck ~= 1 and rarityIndex(o.rarity) >= 3 then
				return o.p * luck
			end
			return o.p
		end
		local total = 0
		for _, o in e.outcomes do
			total += w(o)
		end
		local r = random() * total
		for _, o in e.outcomes do
			r -= w(o)
			if r < 0 then
				return o.id
			end
		end
		return e.outcomes[#e.outcomes].id
	end

	-- What the player does while at their base: tower buys, incubators, rebirth.
	-- Returns the coins they are saving (not to be spent on eggs).
	local function spendAtBase(): number
		local reserve = 0
		for _ = 1, 50 do
			local inc = income()
			local c = context()
			local up = c.upgrade
			local eggRate = c.eggRate
			-- Incubators: the next one once it costs at most a few minutes of
			-- income (or a third of the purse early on).
			local slotCost = Hatchery.nextSlotCost(d, economy)
			if slotCost and d.coins >= slotCost and (slotCost <= inc * 180 or slotCost <= d.coins / 3) then
				d.coins -= slotCost
				d.slots += 1
				mark(`incubator {slotCount()}`)
				dirty()
				continue
			end
			-- Rebirth once the tower is bought out to where the next floor costs
			-- more than the rebirth, every upgrade is done, and they can pay.
			local rebirthCost = Creatures.rebirthCost(d.rebirths, economy)
			local nextFloor = Tower.nextFloorPrice(d, economy) or math.huge
			if d.coins >= rebirthCost and up == nil and rebirthCost < nextFloor and #d.creatures > 0 then
				d.coins = economy.startingCoins
				d.creatures = {}
				d.rebirths += 1
				mark(`rebirth {d.rebirths}`)
				dirty()
				continue
			end
			-- Tower buys against eggs over the next HORIZON seconds of play: the
			-- upgrade's gain from when it is paid for, against the egg income
			-- growth given up while its price is saved and spent.
			local wanted = false
			if up then
				local H = Sim.HORIZON
				local t = math.min(up.price / math.max(inc, 0.5), H)
				local wait = math.max(0, up.price - d.coins) / math.max(inc, 0.5)
				wanted = wait < H and up.gain * (H - wait) >= eggRate * t * (H - t / 2)
			end
			if up and wanted then
				if d.coins >= up.price then
					d.coins -= up.price
					if up.kind == "floor" then
						d.floors = Tower.owned(d) + 1
						mark(`floor {d.floors}`)
					else
						d.floorUpgrades[up.floor] = Tower.upgrades(d, up.floor) + 1
						if Tower.upgrades(d, up.floor) == #economy.tower.upgradeShares then
							mark(`floor {up.floor} full`)
						end
					end
					placeBest()
					continue
				end
				reserve = up.price
			end
			break
		end
		return reserve
	end

	-- Picks the egg for the next free incubator: most income per second of
	-- the scarcer resource (coins at today's income, or incubator time).
	local function pickEgg(reserve: number, _free: number): any?
		local c = context()
		local inc = math.max(income(), 0.5)
		local best, bestScore = nil, 0
		for _, e in facts do
			if
				d.coins - reserve >= priceOf(e)
				and (tokens[e.id] or 0) >= 1
				and Tower.owned(d) >= (e.requiresFloor or 1)
			then
				local g = c.gains[e.id]
				local cost = priceOf(e) / inc + hatchOf(e) / math.max(1, slotCount())
				local score = g / cost
				if score > bestScore then
					best, bestScore = e, score
				end
			end
		end
		return best
	end

	local function wantedButMissing(reserve: number): boolean
		-- an egg they can afford and want is not on the belt right now
		local c = context()
		for _, e in facts do
			if
				d.coins - reserve >= priceOf(e)
				and (tokens[e.id] or 0) < 1
				and Tower.owned(d) >= (e.requiresFloor or 1)
			then
				if c.gains[e.id] > 0 then
					return true
				end
			end
		end
		return false
	end

	local function snapshot(): any
		local best = 0
		for _, c in d.creatures do
			best = math.max(best, rarityIndex(config.creatures.species[c.speciesId].rarity))
		end
		local upgrades = 0
		for floor = 2, Tower.owned(d) do
			upgrades += Tower.upgrades(d, floor)
		end
		local found = 0
		for _ in d.found do
			found += 1
		end
		local total = 0
		for _ in config.creatures.species do
			total += 1
		end
		return {
			day = day,
			minutes = played / 60,
			income = income(),
			coins = d.coins,
			floors = Tower.owned(d),
			upgrades = upgrades,
			incubators = slotCount(),
			rebirths = d.rebirths,
			bestTier = if best > 0 then Sim.RARITIES[best] else "-",
			bookFound = found,
			bookTotal = total,
			eggs = table.clone(eggsBought),
		}
	end

	local function playSession(seconds: number)
		local stop = played + seconds
		while played < stop do
			local active = if eventToday
					and now >= eventToday.startAt
					and now < eventToday.endAt
				then eventToday.kind
				else nil
			if active ~= eventActive then
				eventActive = active
				if active then
					mark(`event seen`)
				end
				dirty()
			end
			if hatchReady() > 0 then
				advance(T.hatchSeconds)
			end
			local reserve = spendAtBase()
			local free = slotCount() - #d.incubators
			local first = if free > 0 then pickEgg(reserve, free) else nil
			if first then
				local speed = bestMountSpeed()
				advance(T.marketStuds / speed + T.tripOverhead)
				local waited = 0
				while free > 0 do
					local e = pickEgg(reserve, free)
					if e == nil then
						if waited < T.marketWait and wantedButMissing(reserve) then
							advance(2)
							waited += 2
							continue
						end
						break
					end
					d.coins -= priceOf(e)
					tokens[e.id] -= 1
					eggsBought[e.id] = (eggsBought[e.id] or 0) + 1
					table.insert(d.incubators, {
						readyAt = now + hatchOf(e),
						eggId = e.id,
						outcome = rollOutcome(e),
					})
					free -= 1
					advance(T.buySeconds)
				end
				advance(T.marketStuds / speed + T.tripOverhead)
			else
				-- Wait at base for the next hatch, or a few seconds of income.
				local nextReady = math.huge
				for _, inc in d.incubators do
					nextReady = math.min(nextReady, inc.readyAt)
				end
				local wait = math.clamp(nextReady - now, 1, 30)
				advance(math.min(wait, stop - played))
			end
		end
	end

	local results = {}
	local sessionGap = 86400 / profile.sessionsPerDay
	for dayIndex = 1, days do
		day = dayIndex
		pickEvent(dayIndex)
		for session = 1, profile.sessionsPerDay do
			local minutes = if dayIndex == 1 and session == 1
				then profile.firstSessionMinutes
				else profile.sessionMinutes
			local startAt = (dayIndex - 1) * 86400 + (session - 1) * sessionGap
			if now > 0 and startAt > now then
				-- offline: half income for up to 2 hours, eggs keep hatching
				local away = startAt - now
				d.coins += Creatures.offlineEarnings(income(), away, economy)
				now = startAt
			end
			now = math.max(now, startAt)
			if session == 1 then
				streak = streak % #economy.daily.rewards + 1
				d.coins += Daily.amount(streak, income(), economy.daily)
			end
			playSession(minutes * 60)
		end
		table.insert(results, snapshot())
	end

	return { profile = profile.name, seed = seed, milestones = milestones, days = results }
end

-- Runs `runs` seeds of a profile; returns every result.
function Sim.batch(config: any, profile: Profile, days: number, runs: number, firstSeed: number?): { Result }
	local out = {}
	for i = 1, runs do
		table.insert(out, Sim.run(config, profile, days, (firstSeed or 1) + i * 7919))
	end
	return out
end

-- The q-quantile (0..1) of a list; math.huge entries count as "not reached".
function Sim.quantile(values: { number }, q: number): number
	local sorted = table.clone(values)
	table.sort(sorted)
	if #sorted == 0 then
		return math.huge
	end
	local i = math.clamp(math.floor(q * (#sorted - 1) + 0.5) + 1, 1, #sorted)
	return sorted[i]
end

return Sim
