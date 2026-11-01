--!strict
-- A simple player for session and pacing tests. By default it is attentive:
-- every second it serves up to `servesPerSecond` waiting customers, collects
-- the register every 30 seconds and buys the cheapest useful thing it can
-- afford: a station, an upgrade, a cook or a better cook, or the next
-- district. With `checkInSeconds` it is a casual player instead, who looks
-- in only that often and then serves the whole line, collects and shops.

local Restaurant = require("../src/shared/Restaurant")

export type Options = {
	servesPerSecond: number?,
	-- Never hire cooks.
	noCooks: boolean?,
	-- Act only every this many seconds (default 1: every second).
	checkInSeconds: number?,
}

-- What one run of Bot.play saw. `reached` holds the clock time each milestone
-- (District1..3, RebirthReady) was first reached; `purchases` the clock time
-- of every purchase; `served` and `collected` the cash from the counter and
-- from the register.
export type Run = {
	reached: { [string]: number },
	purchases: { number },
	served: number,
	collected: number,
}

local Bot = {}

-- The cheapest useful purchase: { cost, run } or nil.
function Bot.nextPurchase(h: any, player: any, options: Options?): { cost: number, run: () -> any }?
	local config = h.config
	local d = h.get(player)
	local now = h.clock.now()
	local candidates: { { cost: number, run: () -> any } } = {}

	local spots = Restaurant.spotCount(d.districts, config)
	local freeSpot: number? = nil
	for spot = 1, spots do
		if Restaurant.stationAt(d, spot) == nil then
			freeSpot = spot
			break
		end
	end
	if freeSpot then
		for _, station in config.stations do
			if station.district <= d.districts and Restaurant.stationById(d, station.id) == nil then
				local spot = freeSpot :: number
				table.insert(candidates, {
					cost = station.levels[1].cost,
					run = function()
						return h.actions:build(player, station.id, spot)
					end,
				})
			end
		end
	end

	for _, station in d.stations do
		local cost = Restaurant.upgradeCost(station, config)
		if cost and not Restaurant.isBuilding(station, now) then
			local spot = station.spot
			table.insert(candidates, {
				cost = cost,
				run = function()
					return h.actions:upgrade(player, spot)
				end,
			})
		end
	end

	if not (options and options.noCooks) then
		local tiers = config.cooks.tiers
		for _, station in d.stations do
			local cook = Restaurant.cookAt(d, station.stationId)
			local rank = 0
			if cook then
				for index, tier in tiers do
					if tier.id == cook.tier then
						rank = index
					end
				end
			end
			local better = tiers[rank + 1]
			if better then
				local spot = station.spot
				table.insert(candidates, {
					cost = Restaurant.hireCost(d, config, better.id) :: number,
					run = function()
						return h.actions:hireCook(player, better.id, spot)
					end,
				})
			end
		end
	end

	local districtCost = Restaurant.nextDistrictCost(d, config)
	if districtCost then
		table.insert(candidates, {
			cost = districtCost,
			run = function()
				return h.actions:unlockDistrict(player)
			end,
		})
	end

	table.sort(candidates, function(a, b)
		return a.cost < b.cost
	end)
	return candidates[1]
end

-- Plays for `seconds`.
function Bot.play(h: any, player: any, seconds: number, options: Options?): Run
	local servesPerSecond = (options and options.servesPerSecond) or 1
	local checkIn = (options and options.checkInSeconds) or 1
	local run: Run = { reached = {}, purchases = {}, served = 0, collected = 0 }
	local reached = run.reached
	local sinceCollect = 0
	for second = 0, seconds - 1 do
		if second % checkIn == 0 then
			local d = h.get(player)
			-- An attentive player keeps up with the line; a casual one serves
			-- everyone waiting when they look in.
			local serves = if checkIn == 1 then servesPerSecond else math.huge
			local served = 0
			while served < serves and Restaurant.waiting(d.queue) >= 1 do
				local ok = h.actions:serve(player)
				assert(ok, "serve refused")
				run.served += h.served[#h.served]
				served += 1
				d = h.get(player)
			end
			if sinceCollect >= 30 or checkIn > 1 then
				local before = h.get(player).cash
				h.actions:collect(player)
				run.collected += h.get(player).cash - before
				sinceCollect = 0
			end
			for _ = 1, if checkIn == 1 then 5 else 1000 do
				local purchase = Bot.nextPurchase(h, player, options)
				if purchase == nil or h.get(player).cash < purchase.cost then
					break
				end
				purchase.run()
				table.insert(run.purchases, h.clock.now())
			end
		end
		local d = h.get(player)
		local key = `District{d.districts}`
		if reached[key] == nil then
			reached[key] = h.clock.now()
		end
		if reached.RebirthReady == nil and d.districts == #h.config.districts then
			local cash = d.cash + d.pendingCash
			if cash >= h.config.economy.rebirth.cost then
				reached.RebirthReady = h.clock.now()
			end
		end
		h.wait(player, 1)
		sinceCollect += 1
	end
	return run
end

-- The longest stretch, in seconds, between `from` and `to` (clock times)
-- with no purchase.
function Bot.longestGap(run: Run, from: number, to: number): number
	local longest = 0
	local last = from
	for _, at in run.purchases do
		if at > to then
			break
		end
		if at >= from then
			longest = math.max(longest, at - last)
			last = at
		end
	end
	return math.max(longest, to - last)
end

return Bot
