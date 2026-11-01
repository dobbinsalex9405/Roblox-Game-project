--!strict
-- A Street Food Empire player with a serving habit and a buying habit.
--
-- Serving habits (how often the player is at the counter pressing Serve):
--   attentive  serves every customer as they arrive (the game's own test bot)
--   batcher    comes back every 60 s and clears the line (the queue holds 60 s of arrivals)
--   casual     comes back every 3 minutes; two thirds of the customers walk on by
--   idle       serves once at the start and then every 10 minutes; lives off the cooks
-- Buying habits:
--   cheapest   the cheapest useful thing (the game's Bot.nextPurchase)
--   roi        the affordable purchase with the shortest payback, estimated from
--              the rates the bot would get at its serving habit
-- Every purchase costs the bot 6 s away from the counter (walking to the spot
-- and back), during which nobody is served.

local Harness = require("../../games/street-food-empire/tests/Harness")
local GameBot = require("../../games/street-food-empire/tests/Bot")
local Restaurant = require("../../games/street-food-empire/src/shared/Restaurant")
local Log = require("../../packages/core/src/Log")
Log.setSink(function() end)

local config = Harness.config
local economy = config.economy

export type Style = {
	name: string,
	serveEvery: number, -- seconds between visits to the counter (0 = always there)
	buying: "cheapest" | "roi",
	noCooks: boolean?,
}

export type Bot = {
	player: any,
	style: Style,
	startedAt: number,
	nextServeAt: number,
	awayUntil: number,
	serves: number,
	purchases: number,
	lost: number, -- customers who walked on by (queue full)
	milestones: { [string]: number },
	log: { string },
	timeline: { { [string]: any } },
	hand: number,
	register: number,
	econSeen: number,
	awaySeconds: number,
}

local Bot = {}
Bot.config = config

local PURCHASE_WALK = 6

Bot.STYLES = {
	attentive = { name = "attentive", serveEvery = 0, buying = "cheapest" } :: Style,
	attentiveRoi = { name = "attentiveRoi", serveEvery = 0, buying = "roi" } :: Style,
	batcher = { name = "batcher", serveEvery = 60, buying = "cheapest" } :: Style,
	casual = { name = "casual", serveEvery = 180, buying = "cheapest" } :: Style,
	idle = { name = "idle", serveEvery = 600, buying = "roi" } :: Style,
	handOnly = { name = "handOnly", serveEvery = 0, buying = "cheapest", noCooks = true } :: Style,
}

function Bot.new(h: any, player: any, style: Style): Bot
	return {
		player = player,
		style = style,
		startedAt = h.clock.now(),
		nextServeAt = h.clock.now(),
		awayUntil = 0,
		serves = 0,
		purchases = 0,
		lost = 0,
		milestones = {},
		log = {},
		timeline = {},
		hand = 0,
		register = 0,
		econSeen = 0,
		awaySeconds = 0,
	}
end

local function mark(b: Bot, h: any, name: string)
	if b.milestones[name] == nil then
		b.milestones[name] = h.clock.now() - b.startedAt
		table.insert(b.log, string.format("%7.0fs  %s", h.clock.now() - b.startedAt, name))
	end
end

-- The fraction of arriving customers this style serves.
local function serveFraction(style: Style): number
	if style.serveEvery <= 0 then
		return 1
	end
	-- The queue holds queueMax; arrivals beyond that during the absence are lost.
	-- Approximate with district-1 traffic (12/min): 60 s fills the queue.
	local arrivalsPerVisit = style.serveEvery * 12 / 60
	return math.min(1, economy.customers.queueMax / arrivalsPerVisit)
end

-- Best-payback purchase among what is affordable. Returns { cost, run, what } or nil.
local function roiPurchase(h: any, b: Bot): { cost: number, run: () -> any, what: string }?
	local d = h.get(b.player)
	local now = h.clock.now()
	local perks = { doubleCash = h.perks.doubleCash }
	local rates = Restaurant.rates(d, config, perks, now)
	local fraction = serveFraction(b.style)
	local handPerCustomer = (1 + economy.customers.handServeBonus) * rates.multiplier
	local customersPerSecond = 0
	for index = 1, math.min(d.districts, #config.districts) do
		customersPerSecond += config.districts[index].customersPerMinute / 60
	end
	local candidates = {}
	local function consider(cost: number, gain: number, run: () -> any, what: string)
		if cost <= d.cash and gain > 0 then
			table.insert(candidates, { cost = cost, gain = gain, payback = cost / gain, run = run, what = what })
		end
	end
	local spots = Restaurant.spotCount(d.districts, config)
	local freeSpot: number? = nil
	for spot = 1, spots do
		if Restaurant.stationAt(d, spot) == nil then
			freeSpot = spot
			break
		end
	end
	for _, station in config.stations do
		if freeSpot and station.district <= d.districts and Restaurant.stationById(d, station.id) == nil then
			local price = station.levels[1].price
			local gain = price * customersPerSecond * fraction * handPerCustomer
			local spot = freeSpot :: number
			consider(station.levels[1].cost, gain, function()
				return h.actions:build(b.player, station.id, spot)
			end, `Build:{station.id}`)
		end
	end
	for _, station in d.stations do
		local cost = Restaurant.upgradeCost(station, config)
		local sc = Restaurant.stationConfig(config, station.stationId)
		if cost and sc and not Restaurant.isBuilding(station, now) then
			local delta = sc.levels[station.level + 1].price - sc.levels[station.level].price
			local gain = delta * customersPerSecond * fraction * handPerCustomer
			local cook = Restaurant.cookAt(d, station.stationId)
			if cook then
				local tier = Restaurant.tierConfig(config, cook.tier)
				gain += delta * tier.servesPerMinute / 60 * rates.multiplier
			end
			local spot = station.spot
			consider(cost, gain, function()
				return h.actions:upgrade(b.player, spot)
			end, `Upgrade:{station.stationId}{station.level + 1}`)
		end
	end
	if not b.style.noCooks then
		for _, station in d.stations do
			local sc = Restaurant.stationConfig(config, station.stationId)
			local level = math.max(1, Restaurant.workingLevel(station, now))
			local price = if sc then sc.levels[level].price else 0
			local cook = Restaurant.cookAt(d, station.stationId)
			local currentRate = 0
			local rank = 0
			if cook then
				for index, tier in config.cooks.tiers do
					if tier.id == cook.tier then
						rank = index
						currentRate = tier.servesPerMinute / 60
					end
				end
			end
			for index = rank + 1, #config.cooks.tiers do
				local tier = config.cooks.tiers[index]
				local cost = Restaurant.hireCost(d, config, tier.id) :: number
				local gain = (tier.servesPerMinute / 60 - currentRate) * price * rates.multiplier
				local spot = station.spot
				consider(cost, gain, function()
					return h.actions:hireCook(b.player, tier.id, spot)
				end, `Hire:{tier.id}@{station.stationId}`)
			end
		end
	end
	local districtCost = Restaurant.nextDistrictCost(d, config)
	if districtCost then
		local next = config.districts[d.districts + 1]
		local moreCustomers = next.customersPerMinute / 60
		local gain = rates.meal * moreCustomers * fraction * handPerCustomer
		-- Plus the cheapest station it opens, as if it were built next.
		local cheapest: any = nil
		for _, station in config.stations do
			if station.district == d.districts + 1 and (cheapest == nil or station.levels[1].cost < cheapest.levels[1].cost) then
				cheapest = station
			end
		end
		if cheapest then
			gain += 0.5 * cheapest.levels[1].price * (customersPerSecond + moreCustomers) * fraction * handPerCustomer
		end
		consider(districtCost, gain, function()
			return h.actions:unlockDistrict(b.player)
		end, `District:{d.districts + 1}`)
	end
	table.sort(candidates, function(a, c)
		return a.payback < c.payback
	end)
	return candidates[1]
end

local function cheapestPurchase(h: any, b: Bot): { cost: number, run: () -> any, what: string }?
	local p = GameBot.nextPurchase(h, b.player, { noCooks = b.style.noCooks })
	if p == nil then
		return nil
	end
	return { cost = p.cost, run = p.run, what = "cheapest" }
end

local function describe(h: any, b: Bot)
	local d = h.get(b.player)
	for _, station in d.stations do
		mark(b, h, `Built:{station.stationId}`)
		if #d.stations >= 2 then
			mark(b, h, "FirstStation")
		end
	end
	if #d.cooks >= 1 then
		mark(b, h, "FirstCook")
	end
	for _, cook in d.cooks do
		mark(b, h, `Hired:{cook.tier}`)
	end
	mark(b, h, `District{d.districts}`)
	if d.districts == #config.districts and d.cash + d.pendingCash >= economy.rebirth.cost then
		mark(b, h, "RebirthReady")
	end
	if d.rebirths >= 1 then
		mark(b, h, "Rebirth")
	end
	if b.serves >= 1 then
		mark(b, h, "FirstServe")
	end
end

local function creditEconomy(h: any, b: Bot)
	local events = h.eventsOf("economy")
	for i = b.econSeen + 1, #events do
		local e = events[i]
		if e[1] == "Source" and e[5] == "Gameplay" then
			if e[6] == "Serve" then
				b.hand += e[3]
			elseif e[6] == "Collect" then
				b.register += e[3]
			end
		end
	end
	b.econSeen = #events
end

local function snapshot(h: any, b: Bot, minute: number)
	local d = h.get(b.player)
	local levels = 0
	for _, s in d.stations do
		levels += s.level
	end
	local perks = { doubleCash = h.perks.doubleCash }
	local rates = Restaurant.rates(d, config, perks, h.clock.now())
	table.insert(b.timeline, {
		minute = minute,
		cash = d.cash,
		hand = b.hand,
		register = b.register,
		stations = #d.stations,
		levels = levels,
		cooks = #d.cooks,
		district = d.districts,
		meal = rates.meal,
		registerPerSecond = rates.registerPerSecond,
		serves = b.serves,
		lost = b.lost,
	})
end

-- Plays `seconds` of game time, one second at a time (the harness ticks the
-- restaurant on every wait, like the server does every 10 s; the income math
-- is exact either way).
function Bot.play(h: any, b: Bot, seconds: number)
	local start = h.clock.now()
	local nextMinute = 1
	local sinceCollect = 0
	for _ = 1, seconds do
		local now = h.clock.now()
		local d = h.get(b.player)
		local perks = { doubleCash = h.perks.doubleCash }
		-- Customers walking past a full line.
		local rates = Restaurant.rates(d, config, perks, now)
		local _, queue = Restaurant.preview(d, config, perks, now)
		if queue >= economy.customers.queueMax - 1e-9 then
			b.lost += rates.customersPerSecond
		end
		local atCounter = now >= b.awayUntil and (b.style.serveEvery <= 0 or now >= b.nextServeAt)
		if now < b.awayUntil then
			b.awaySeconds += 1
		end
		if atCounter then
			-- Clear the line (the Serve prompt is one press per customer; up to 8 a second).
			local served = 0
			while Restaurant.waiting(h.get(b.player).queue) >= 1 and served < 8 do
				if not h.actions:serve(b.player) then
					break
				end
				served += 1
				b.serves += 1
			end
			if b.style.serveEvery > 0 and Restaurant.waiting(h.get(b.player).queue) < 1 then
				b.nextServeAt = now + b.style.serveEvery
			end
		end
		if now >= b.awayUntil then
			if sinceCollect >= 30 or (b.style.serveEvery > 0 and atCounter) then
				h.actions:collect(b.player)
				sinceCollect = 0
			end
			-- One purchase per visit to the spots.
			local purchase = if b.style.buying == "roi" then roiPurchase(h, b) else cheapestPurchase(h, b)
			if purchase and h.get(b.player).cash >= purchase.cost then
				local ok = purchase.run()
				if ok then
					b.purchases += 1
					b.awayUntil = now + PURCHASE_WALK
					mark(b, h, `Buy:{purchase.what}`)
				end
			end
		end
		creditEconomy(h, b)
		describe(h, b)
		h.wait(b.player, 1)
		sinceCollect += 1
		if h.clock.now() - start >= nextMinute * 60 - 1e-9 then
			snapshot(h, b, nextMinute)
			nextMinute += 1
		end
	end
	creditEconomy(h, b)
	describe(h, b)
end

return Bot
