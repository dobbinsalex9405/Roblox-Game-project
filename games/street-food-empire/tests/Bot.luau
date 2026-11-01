--!strict
-- A simple, attentive player for session and pacing tests. Every second it
-- serves up to `servesPerSecond` waiting customers, collects the register
-- every 30 seconds and buys the cheapest useful thing it can afford: a
-- station, an upgrade, a cook or a better cook, or the next district.

local Restaurant = require("../src/shared/Restaurant")

export type Options = {
	servesPerSecond: number?,
	-- Never hire cooks.
	noCooks: boolean?,
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

-- Plays for `seconds`. Returns the clock time each milestone was first reached.
function Bot.play(h: any, player: any, seconds: number, options: Options?): { [string]: number }
	local servesPerSecond = (options and options.servesPerSecond) or 1
	local reached: { [string]: number } = {}
	local sinceCollect = 0
	for _ = 1, seconds do
		local d = h.get(player)
		for _ = 1, servesPerSecond do
			if Restaurant.waiting(d.queue) >= 1 then
				h.actions:serve(player)
				d = h.get(player)
			end
		end
		if sinceCollect >= 30 then
			h.actions:collect(player)
			sinceCollect = 0
		end
		for _ = 1, 5 do
			local purchase = Bot.nextPurchase(h, player, options)
			if purchase == nil or h.get(player).cash < purchase.cost then
				break
			end
			purchase.run()
		end
		d = h.get(player)
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
	return reached
end

return Bot
