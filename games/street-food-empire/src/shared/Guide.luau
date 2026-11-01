--!strict
-- The first-session guide: one goal at a time, from the first customer to
-- opening Market Row, with the place to go. The client shows it as a line
-- under the cash bar and an arrow to the target, so a new player always
-- knows what to do next. It follows the onboarding funnel (Restaurant
-- ONBOARDING), so analytics show where players drop off the guide.
--
-- Pure: reads data, changes nothing. The client calls it a few times a
-- second with the live register and queue.

local Restaurant = require("./Restaurant")

export type Target = {
	kind: "Counter" | "Register" | "Spot" | "Gate",
	spot: number?, -- for "Spot"
}

export type Step = {
	id: string, -- stable name, for tests and analytics
	text: string,
	target: Target?,
}

local Guide = {}

local function emptySpot(d: Restaurant.Data, config: Restaurant.Config): number?
	for spot = 1, Restaurant.spotCount(d.districts, config) do
		if Restaurant.stationAt(d, spot) == nil then
			return spot
		end
	end
	return nil
end

-- The cheapest station the player can build now, and its cost.
local function cheapestStation(d: Restaurant.Data, config: Restaurant.Config): (string?, number)
	local best: string? = nil
	local bestCost = math.huge
	for _, station in config.stations do
		if station.district <= d.districts and Restaurant.stationById(d, station.id) == nil then
			if station.levels[1].cost < bestCost then
				best = station.id
				bestCost = station.levels[1].cost
			end
		end
	end
	return best, bestCost
end

local function spaced(id: string): string
	return (string.gsub(id, "(%l)(%u)", "%1 %2"))
end

-- The next goal, or nil once the guide is done (Market Row is open).
-- `money` formats cash for display (Layout.cash on the client).
function Guide.next(
	d: Restaurant.Data,
	config: Restaurant.Config,
	perks: Restaurant.Perks,
	now: number,
	autoCollect: boolean,
	money: (number) -> string
): Step?
	if d.districts >= 2 then
		return nil
	end
	local pending, queue = Restaurant.preview(d, config, perks, now)
	local waiting = Restaurant.waiting(queue)
	local cash = d.cash

	-- Where to get cash for a goal that costs `cost`: the register once it
	-- holds a real share of the goal (or enough to finish it), otherwise the
	-- counter. The text stays put while customers come and go.
	local function earn(id: string, goal: string, cost: number): Step
		local progress = `{goal}: {money(math.min(cash, cost))} / {money(cost)}`
		local worthCollecting = pending >= 1 and (cash + pending >= cost or pending >= cost * 0.25)
		if not autoCollect and worthCollecting then
			return {
				id = id,
				text = `Collect {money(pending)} from the register. {progress}`,
				target = { kind = "Register" },
			}
		end
		return { id = id, text = `Serve customers at the counter. {progress}`, target = { kind = "Counter" } }
	end

	if d.firsts.FirstCustomerServed == nil then
		if waiting >= 1 then
			return {
				id = "Serve",
				text = "A customer is waiting! Serve them at the counter.",
				target = { kind = "Counter" },
			}
		end
		return {
			id = "Serve",
			text = "Your food cart is open. Customers are on their way!",
			target = { kind = "Counter" },
		}
	end

	if d.firsts.FirstStationBought == nil then
		local stationId, cost = cheapestStation(d, config)
		local spot = emptySpot(d, config)
		if stationId and spot then
			local goal = `Build a {spaced(stationId)}`
			if cash >= cost then
				return {
					id = "Build",
					text = `{goal} for {money(cost)}: more dishes, bigger meals.`,
					target = { kind = "Spot", spot = spot },
				}
			end
			return earn("Build", goal, cost)
		end
	end

	if d.firsts.FirstUpgrade == nil then
		local starter = Restaurant.stationById(d, config.economy.starterStation) or d.stations[1]
		local cost = starter and Restaurant.upgradeCost(starter, config)
		if starter and cost and not Restaurant.isBuilding(starter, now) then
			local goal = `Upgrade your {spaced(starter.stationId)}`
			if cash >= cost then
				return {
					id = "Upgrade",
					text = `{goal} for {money(cost)}: its dish sells for more.`,
					target = { kind = "Spot", spot = starter.spot },
				}
			end
			return earn("Upgrade", goal, cost)
		end
	end

	if d.firsts.FirstCookHired == nil then
		local tier = config.cooks.tiers[1]
		local cost = Restaurant.hireCost(d, config, tier.id) :: number
		-- The station whose dish sells for the most, so the first cook pays best.
		local best: Restaurant.Station? = nil
		local bestPrice = -1
		for _, station in d.stations do
			local stationConfig = Restaurant.stationConfig(config, station.stationId)
			local level = stationConfig and stationConfig.levels[Restaurant.workingLevel(station, now)]
			local price = if level then level.price else 0
			if price > bestPrice then
				best = station
				bestPrice = price
			end
		end
		if best then
			local goal = "Hire a cook"
			if cash >= cost then
				return {
					id = "Hire",
					text = `{goal} for {money(cost)}: cooks sell for you, even while you're away.`,
					target = { kind = "Spot", spot = best.spot },
				}
			end
			return earn("Hire", goal, cost)
		end
	end

	local districtCost = Restaurant.nextDistrictCost(d, config)
	if districtCost == nil then
		return nil
	end
	local goal = `Open {spaced(config.districts[d.districts + 1].id)}`
	if cash >= districtCost then
		return {
			id = "Unlock",
			text = `{goal} for {money(districtCost)}: more customers and four new stations.`,
			target = { kind = "Gate" },
		}
	end
	-- On the way, the cheapest way to earn faster comes first: a new station,
	-- an upgrade or a cook. Each is a small goal of its own, so the long save
	-- for Market Row is a run of quick wins. Market Row is the goal once
	-- nothing cheaper is left.
	local growth = Guide.cheapestGrowth(d, config, now)
	if growth and growth.cost < districtCost then
		local growthGoal = `{growth.text}`
		if cash >= growth.cost then
			return {
				id = "Unlock",
				text = `{growthGoal} for {money(growth.cost)} to earn faster.`,
				target = { kind = "Spot", spot = growth.spot },
			}
		end
		return earn("Unlock", growthGoal, growth.cost)
	end
	return earn("Unlock", goal, districtCost)
end

export type Growth = {
	text: string, -- "Upgrade your Pretzel Oven"
	cost: number,
	spot: number,
}

-- The cheapest station, upgrade or cook the player can buy next, or nil.
function Guide.cheapestGrowth(d: Restaurant.Data, config: Restaurant.Config, now: number): Growth?
	local best: Growth? = nil
	local function consider(text: string, cost: number?, spot: number?)
		if cost and spot and (best == nil or cost < (best :: Growth).cost) then
			best = { text = text, cost = cost, spot = spot }
		end
	end
	local stationId, stationCost = cheapestStation(d, config)
	if stationId then
		consider(`Build a {spaced(stationId)}`, stationCost, emptySpot(d, config))
	end
	local tiers = config.cooks.tiers
	for _, station in d.stations do
		if not Restaurant.isBuilding(station, now) then
			consider(
				`Upgrade your {spaced(station.stationId)}`,
				Restaurant.upgradeCost(station, config),
				station.spot
			)
		end
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
			local verb = if cook
				then `Hire a {spaced(better.id)} for your {spaced(station.stationId)}`
				else `Hire a cook for your {spaced(station.stationId)}`
			consider(verb, Restaurant.hireCost(d, config, better.id), station.spot)
		end
	end
	return best
end

return Guide
