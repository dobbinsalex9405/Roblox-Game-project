--!strict
-- The Street Food Empire restaurant as pure functions over saved data.
--
-- How the numbers work:
--   * The counter: customers walk up at the foot traffic of every unlocked
--     district (customers per minute) and wait in the counter queue, up to
--     customers.queueMax; past that they walk on by. Each one orders the
--     whole menu: a meal is worth the sum of the dish prices of every
--     finished station, at its working level. The player serves them by
--     hand, for the meal plus a bonus, straight into the wallet. An empty
--     lot with no finished station gets no customers.
--   * Cooks: each station can have one cook, who sells that station's dish
--     to walk-up customers at the cook's own pace (servesPerMinute). Their
--     sales go into the register (pendingCash), which the player collects.
--     So a better cook belongs on a pricier station.
--   * A Speed Boost brings customers faster to both; rebirth and the 2x Cash
--     pass multiply every sale.
--
-- Rates only change at known moments (a station finishing, a boost running
-- out), so income between two times is computed exactly, piece by piece,
-- instead of being sampled. That keeps a 10-second server tick, a rejoin and
-- an offline absence in exact agreement.
--
-- Every function that changes data runs inside DataService:update on the
-- server, so a refusal or an error leaves the save untouched. Cash only moves
-- through the Economy ledger passed in. Nothing here yields, reads a clock or
-- rolls dice: time is an argument, which keeps every rule unit-testable.

export type Data = { [string]: any }

-- The parts of Economy's ledger used here.
export type Ledger = {
	add: (self: any, currency: string, amount: number, reason: string) -> number,
	spend: (self: any, currency: string, amount: number, reason: string) -> boolean,
	balance: (self: any, currency: string) -> number,
}

export type Perks = {
	doubleCash: boolean,
}

export type Config = {
	economy: any,
	districts: { any },
	stations: { any },
	cooks: any,
	monetization: any,
}

export type Station = {
	stationId: string,
	spot: number,
	level: number, -- the level being built or reached
	readyAt: number, -- unix seconds the current build or upgrade finishes
}

export type Cook = {
	uid: string,
	tier: string,
	stationId: string,
}

export type Rates = {
	customersPerSecond: number, -- customers joining the counter queue
	meal: number, -- cash one counter customer's meal is worth, before multipliers
	cookSalesPerSecond: number, -- dishes the cooks sell, all stations together
	multiplier: number,
	registerPerSecond: number, -- cash the cooks earn into the register
}

-- First-time moments, in the order the onboarding funnel reports them.
-- Once the game is live, new steps go at the end so earlier step numbers
-- never change.
local ONBOARDING = {
	"Joined",
	"FirstCustomerServed",
	"FirstStationBought",
	"FirstUpgrade",
	"FirstCookHired",
	"SecondDistrictUnlocked",
}

local Restaurant = {}
Restaurant.ONBOARDING = table.freeze(ONBOARDING)

-- Config lookups ----------------------------------------------------------

function Restaurant.stationConfig(config: Config, stationId: string): any?
	for _, station in config.stations do
		if station.id == stationId then
			return station
		end
	end
	return nil
end

function Restaurant.tierConfig(config: Config, tierId: string): any?
	for _, tier in config.cooks.tiers do
		if tier.id == tierId then
			return tier
		end
	end
	return nil
end

-- Spots open with `districts` districts unlocked.
function Restaurant.spotCount(districts: number, config: Config): number
	local spots = 0
	for index = 1, math.min(districts, #config.districts) do
		spots += config.districts[index].spots
	end
	return spots
end

-- Which district a spot belongs to (nil when past the last district).
function Restaurant.districtOfSpot(spot: number, config: Config): number?
	local last = 0
	for index, district in config.districts do
		last += district.spots
		if spot <= last then
			return index
		end
	end
	return nil
end

-- Saved data lookups ------------------------------------------------------

function Restaurant.stationAt(d: Data, spot: number): (Station?, number?)
	for index, station in d.stations do
		if station.spot == spot then
			return station, index
		end
	end
	return nil, nil
end

function Restaurant.stationById(d: Data, stationId: string): Station?
	for _, station in d.stations do
		if station.stationId == stationId then
			return station
		end
	end
	return nil
end

function Restaurant.cookAt(d: Data, stationId: string): (Cook?, number?)
	for index, cook in d.cooks do
		if cook.stationId == stationId then
			return cook, index
		end
	end
	return nil, nil
end

-- The level a station serves at, at time `now`: during an upgrade it keeps
-- serving at the old level; while first being built it serves nothing (0).
function Restaurant.workingLevel(station: Station, now: number): number
	if now >= station.readyAt then
		return station.level
	end
	return station.level - 1
end

function Restaurant.isBuilding(station: Station, now: number): boolean
	return now < station.readyAt
end

-- Cash multiplier from rebirths and the 2x Cash pass.
function Restaurant.multiplier(rebirths: number, perks: Perks, economy: any): number
	local m = 1 + rebirths * economy.rebirth.incomeBonusPerRebirth
	if perks.doubleCash then
		m *= economy.doubleCashMultiplier
	end
	return m
end

function Restaurant.boostActive(d: Data, boostId: string, now: number): boolean
	local expiresAt = d.boosts[boostId]
	return type(expiresAt) == "number" and expiresAt > now
end

-- Everything that earns, at one moment.
function Restaurant.rates(d: Data, config: Config, perks: Perks, now: number): Rates
	local speed = 1
	local boost = config.monetization.boosts.SpeedBoost
	if boost and Restaurant.boostActive(d, "SpeedBoost", now) then
		speed = boost.customerMultiplier
	end

	local meal = 0
	local dishPrice: { [string]: number } = {}
	for _, station in d.stations do
		local level = Restaurant.workingLevel(station, now)
		local stationConfig = Restaurant.stationConfig(config, station.stationId)
		if level >= 1 and stationConfig then
			local price = stationConfig.levels[level].price
			meal += price
			dishPrice[station.stationId] = price
		end
	end

	local customers = 0
	if meal > 0 then
		for index = 1, math.min(d.districts, #config.districts) do
			customers += config.districts[index].customersPerMinute / 60
		end
	end

	local sales, cookCash = 0, 0
	for _, cook in d.cooks do
		local tier = Restaurant.tierConfig(config, cook.tier)
		local price = dishPrice[cook.stationId]
		if tier and price then
			local perSecond = tier.servesPerMinute / 60 * speed
			sales += perSecond
			cookCash += perSecond * price
		end
	end

	local multiplier = Restaurant.multiplier(d.rebirths, perks, config.economy)
	return {
		customersPerSecond = customers * speed,
		meal = meal,
		cookSalesPerSecond = sales,
		multiplier = multiplier,
		registerPerSecond = cookCash * multiplier,
	}
end

-- Cash for serving one waiting customer by hand right now (0 = nothing to serve).
function Restaurant.handServeValue(d: Data, config: Config, perks: Perks, now: number): number
	local rates = Restaurant.rates(d, config, perks, now)
	if rates.meal <= 0 then
		return 0
	end
	local value = rates.meal * (1 + config.economy.customers.handServeBonus) * rates.multiplier
	return math.max(1, math.floor(value))
end

-- Income over time ---------------------------------------------------------

-- Moments in (from, to) where a rate changes.
local function changePoints(d: Data, from: number, to: number): { number }
	local points = {}
	for _, station in d.stations do
		if station.readyAt > from and station.readyAt < to then
			table.insert(points, station.readyAt)
		end
	end
	for _, expiresAt in d.boosts do
		if type(expiresAt) == "number" and expiresAt > from and expiresAt < to then
			table.insert(points, expiresAt)
		end
	end
	table.sort(points)
	table.insert(points, to)
	return points
end

-- Runs the restaurant from `from` to `to`: the register earns at
-- `incomeRate` times the cooks' rate (1 online, the offline rate away, 0 past
-- the offline cap) and the counter queue fills, capped. Returns the cash
-- added to the register. Pass `perks` as they were over that time.
function Restaurant.advance(
	d: Data,
	config: Config,
	perks: Perks,
	from: number,
	to: number,
	incomeRate: number
): number
	if to <= from then
		return 0
	end
	local earned = 0
	local queueMax = config.economy.customers.queueMax
	local t = from
	for _, point in changePoints(d, from, to) do
		if point > t then
			-- Rates are constant inside the piece; sample its middle, so a
			-- station finishing exactly at `t` counts.
			local rates = Restaurant.rates(d, config, perks, (t + point) / 2)
			local seconds = point - t
			earned += rates.registerPerSecond * seconds * incomeRate
			d.queue = math.min(queueMax, d.queue + rates.customersPerSecond * seconds)
			t = point
		end
	end
	d.pendingCash += earned
	return earned
end

-- Brings the restaurant up to `now` while the player is in the server. Call
-- on a timer and before any change to what earns.
function Restaurant.accrue(d: Data, config: Config, perks: Perks, now: number)
	if d.lastIncomeAt <= 0 or now < d.lastIncomeAt then
		d.lastIncomeAt = now
		return
	end
	Restaurant.advance(d, config, perks, d.lastIncomeAt, now, 1)
	d.lastIncomeAt = now
end

-- Call once when the player joins, before anything else touches income. The
-- cooks earn at the offline rate for at most offline.maxSeconds of the time
-- away; the queue fills for all of it. Returns the cash added to the register.
function Restaurant.welcomeBack(d: Data, config: Config, perks: Perks, now: number): number
	local earned = 0
	if d.lastIncomeAt > 0 and now > d.lastIncomeAt then
		local offline = config.economy.offline
		local paidUntil = math.min(now, d.lastIncomeAt + offline.maxSeconds)
		earned = Restaurant.advance(d, config, perks, d.lastIncomeAt, paidUntil, offline.rate)
		Restaurant.advance(d, config, perks, paidUntil, now, 0)
	end
	d.lastIncomeAt = now
	return earned
end

-- The register and the queue as they stand at `now`, for display. Does not
-- change `d`.
function Restaurant.preview(d: Data, config: Config, perks: Perks, now: number): (number, number)
	local copy: Data = {
		stations = d.stations,
		cooks = d.cooks,
		boosts = d.boosts,
		districts = d.districts,
		rebirths = d.rebirths,
		queue = d.queue,
		pendingCash = d.pendingCash,
	}
	if d.lastIncomeAt > 0 and now > d.lastIncomeAt then
		Restaurant.advance(copy, config, perks, d.lastIncomeAt, now, 1)
	end
	return copy.pendingCash, copy.queue
end

-- Customers waiting at the counter (whole people).
function Restaurant.waiting(queue: number): number
	-- A hair of tolerance so 2.9999999 customers from float sums shows as 3.
	return math.floor(queue + 1e-9)
end

-- Actions --------------------------------------------------------------------

-- Moves whole cash from the register into the wallet. Returns the amount.
function Restaurant.collect(d: Data, ledger: Ledger): number
	local amount = math.floor(d.pendingCash)
	if amount <= 0 then
		return 0
	end
	local applied = ledger:add("cash", amount, "Gameplay:Collect")
	-- Cash above the wallet cap is not kept back in the register; the cap is
	-- far beyond reach (1e15) and a register that never empties would confuse.
	d.pendingCash -= amount
	return applied
end

-- Serves the customer at the front of the counter queue by hand. Returns the
-- cash earned, or nil and a refusal.
function Restaurant.serve(
	d: Data,
	ledger: Ledger,
	config: Config,
	perks: Perks,
	now: number
): (number?, string?)
	if Restaurant.waiting(d.queue) < 1 then
		return nil, "Nobody is waiting. Customers are on their way!"
	end
	local value = Restaurant.handServeValue(d, config, perks, now)
	if value <= 0 then
		return nil, "Finish building a station first."
	end
	d.queue = math.max(0, d.queue - 1)
	ledger:add("cash", value, "Gameplay:Serve")
	d.stats.customersServed += 1
	return value, nil
end

-- Builds a new station on a free spot. It starts serving when the build finishes.
function Restaurant.build(
	d: Data,
	ledger: Ledger,
	config: Config,
	stationId: string,
	spot: number,
	now: number
): (Station?, string?)
	local stationConfig = Restaurant.stationConfig(config, stationId)
	if stationConfig == nil then
		return nil, "unknown station"
	end
	if Restaurant.stationById(d, stationId) then
		return nil, "You already have that station."
	end
	if stationConfig.district > d.districts then
		local district = config.districts[stationConfig.district]
		local name = if district then (string.gsub(district.id, "(%l)(%u)", "%1 %2")) else "that district"
		return nil, `Open {name} first.`
	end
	if spot < 1 or spot > Restaurant.spotCount(d.districts, config) then
		return nil, "That spot is not open yet."
	end
	if Restaurant.stationAt(d, spot) then
		return nil, "That spot is taken."
	end
	local level = stationConfig.levels[1]
	if not ledger:spend("cash", level.cost, `Shop:{stationId}`) then
		return nil, "Not enough cash."
	end
	local station: Station = {
		stationId = stationId,
		spot = spot,
		level = 1,
		readyAt = now + level.buildSeconds,
	}
	table.insert(d.stations, station)
	return station, nil
end

-- The cost of the station's next upgrade, or nil at the top level.
function Restaurant.upgradeCost(station: Station, config: Config): number?
	local stationConfig = Restaurant.stationConfig(config, station.stationId)
	local nextLevel = stationConfig and stationConfig.levels[station.level + 1]
	return if nextLevel then nextLevel.cost else nil
end

-- Upgrades the station on `spot` one level. It keeps serving at its old level
-- until the upgrade finishes.
function Restaurant.upgrade(
	d: Data,
	ledger: Ledger,
	config: Config,
	spot: number,
	now: number
): (Station?, string?)
	local station = Restaurant.stationAt(d, spot)
	if station == nil then
		return nil, "There is no station there."
	end
	if Restaurant.isBuilding(station, now) then
		return nil,
			if station.level == 1
				then "That station is still being built."
				else "That station is still being upgraded."
	end
	local stationConfig = Restaurant.stationConfig(config, station.stationId)
	local nextLevel = stationConfig and stationConfig.levels[station.level + 1]
	if nextLevel == nil then
		return nil, "That station is fully upgraded."
	end
	if not ledger:spend("cash", nextLevel.cost, `Shop:{station.stationId}Upgrade`) then
		return nil, "Not enough cash."
	end
	station.level += 1
	station.readyAt = now + nextLevel.buildSeconds
	return station, nil
end

-- Moves the station on `from` to `to`, swapping with whatever is there. Its
-- cook goes with it. Free; rearranging matters for customer moods from M4.
function Restaurant.move(d: Data, config: Config, from: number, to: number): (boolean, string?)
	local station = Restaurant.stationAt(d, from)
	if station == nil then
		return false, "There is no station there."
	end
	if to < 1 or to > Restaurant.spotCount(d.districts, config) then
		return false, "That spot is not open yet."
	end
	if from == to then
		return false, "It is already there."
	end
	local other = Restaurant.stationAt(d, to)
	if other then
		other.spot = from
	end
	station.spot = to
	return true, nil
end

-- What hiring a cook of `tierId` costs right now: the tier's cost, times
-- costGrowth for every cook of that tier already working.
function Restaurant.hireCost(d: Data, config: Config, tierId: string): number?
	local tier = Restaurant.tierConfig(config, tierId)
	if tier == nil then
		return nil
	end
	local working = 0
	for _, cook in d.cooks do
		if cook.tier == tierId then
			working += 1
		end
	end
	return math.floor(tier.cost * tier.costGrowth ^ working)
end

local function tierRank(config: Config, tierId: string): number
	for index, tier in config.cooks.tiers do
		if tier.id == tierId then
			return index
		end
	end
	return 0
end

-- Hires a cook for the station on `spot`. A station has one cook; hiring a
-- better tier replaces the one there (who leaves). Returns the new cook and
-- the tier it replaced, if any.
function Restaurant.hireCook(
	d: Data,
	ledger: Ledger,
	config: Config,
	tierId: string,
	spot: number
): (Cook?, string?, string?)
	local station = Restaurant.stationAt(d, spot)
	if station == nil then
		return nil, "Build a station here first.", nil
	end
	local cost = Restaurant.hireCost(d, config, tierId)
	if cost == nil then
		return nil, "unknown cook", nil
	end
	local current, index = Restaurant.cookAt(d, station.stationId)
	if current and tierRank(config, current.tier) >= tierRank(config, tierId) then
		return nil, "This station already has a cook that good.", nil
	end
	if not ledger:spend("cash", cost, `Shop:{tierId}`) then
		return nil, "Not enough cash.", nil
	end
	local replaced: string? = nil
	if current and index then
		replaced = current.tier
		table.remove(d.cooks, index)
	end
	local cook: Cook = { uid = tostring(d.nextUid), tier = tierId, stationId = station.stationId }
	d.nextUid += 1
	table.insert(d.cooks, cook)
	return cook, nil, replaced
end

-- The cost of the next district, or nil when every district is open.
function Restaurant.nextDistrictCost(d: Data, config: Config): number?
	local district = config.districts[d.districts + 1]
	return if district then district.cost else nil
end

function Restaurant.unlockDistrict(d: Data, ledger: Ledger, config: Config): (boolean, string?)
	local district = config.districts[d.districts + 1]
	if district == nil then
		return false, "Every district is open."
	end
	if not ledger:spend("cash", district.cost, `Shop:{district.id}`) then
		return false, "Not enough cash."
	end
	d.districts += 1
	return true, nil
end

-- Why the player cannot rebirth yet, or nil when they can.
function Restaurant.rebirthBlocker(d: Data, ledger: Ledger, config: Config): string?
	local rebirth = config.economy.rebirth
	if d.rebirths >= rebirth.maxRebirths then
		return "You have done every rebirth for now. More are coming!"
	end
	if d.districts < #config.districts then
		return "Open every district before you rebirth."
	end
	if ledger:balance("cash") < rebirth.cost then
		return "Not enough cash to rebirth."
	end
	return nil
end

-- The stations every restaurant starts with: the starter station, built, on spot 1.
function Restaurant.starterStations(config: Config): { Station }
	return { { stationId = config.economy.starterStation, spot = 1, level = 1, readyAt = 0 } }
end

-- Rebirth: pay the cost, then start over from a cart with more cash from
-- every customer. Cash, the register, the queue, districts, stations and
-- cooks reset; boosts, passes and stats stay. Nothing is deleted from the
-- save: the old restaurant is kept in `rebirthArchive` for support.
function Restaurant.rebirth(d: Data, ledger: Ledger, config: Config): (boolean, string?)
	local blocker = Restaurant.rebirthBlocker(d, ledger, config)
	if blocker then
		return false, blocker
	end
	local economy = config.economy
	ledger:spend("cash", economy.rebirth.cost, "Gameplay:Rebirth")
	local remaining = ledger:balance("cash")
	if remaining > 0 then
		ledger:spend("cash", remaining, "Gameplay:RebirthReset")
	end
	if economy.startingCash > 0 then
		ledger:add("cash", economy.startingCash, "Gameplay:RebirthStart")
	end
	table.insert(d.rebirthArchive, {
		rebirth = d.rebirths + 1,
		districts = d.districts,
		stations = d.stations,
		cooks = d.cooks,
	})
	while #d.rebirthArchive > 5 do
		table.remove(d.rebirthArchive, 1)
	end
	d.stations = Restaurant.starterStations(config)
	d.cooks = {}
	d.districts = 1
	d.pendingCash = 0
	d.queue = 0
	d.rebirths += 1
	return true, nil
end

-- Finishes every build and upgrade in progress (the Instant Build product).
-- Returns how many it finished.
function Restaurant.finishBuilds(d: Data, now: number): number
	local finished = 0
	for _, station in d.stations do
		if station.readyAt > now then
			station.readyAt = now
			finished += 1
		end
	end
	return finished
end

-- Starts or extends a timed boost.
function Restaurant.startBoost(d: Data, boostId: string, now: number, seconds: number)
	local current = d.boosts[boostId]
	local from = if type(current) == "number" and current > now then current else now
	d.boosts[boostId] = from + seconds
end

-- How many onboarding steps, from the first, have all happened.
local function reached(d: Data): number
	local count = 0
	for _, name in ONBOARDING do
		if d.firsts[name] == nil then
			break
		end
		count += 1
	end
	return count
end

-- Records a first-time moment and returns the onboarding steps to report
-- now, in order. The funnel only counts steps in order, so a moment that
-- comes early (building a station before serving anyone) is held back and
-- reported right after the steps before it happen. Each step is returned
-- once per player, ever.
function Restaurant.markFirst(d: Data, name: string, now: number): { number }
	assert(table.find(ONBOARDING, name), `unknown onboarding moment {name}`)
	if d.firsts[name] ~= nil then
		return {}
	end
	local before = reached(d)
	d.firsts[name] = now
	local steps = {}
	for step = before + 1, reached(d) do
		table.insert(steps, step)
	end
	return steps
end

return Restaurant
