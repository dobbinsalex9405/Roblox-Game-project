--!strict
-- Every player action in the restaurant loop, as the server runs it: check
-- the request against saved data, change the data in one atomic update, then
-- tell the economy, analytics and the player what happened.
--
-- Runs only on the server. It lives in Shared so the server and the Lune tests
-- load the exact same code; a client that requires it gets nothing, because
-- every call needs the server's services. Roblox-specific effects (messages
-- to the client) come in as callbacks, which keeps this file testable without
-- Roblox.

local Restaurant = require("./Restaurant")

export type Perks = {
	doubleCash: boolean,
	autoCollect: boolean,
}

export type Options = {
	-- Core services (see packages/core).
	data: any,
	economy: any,
	analytics: any,
	config: Restaurant.Config,
	perks: (player: any) -> Perks,
	now: () -> number, -- unix seconds (os.time)
	-- Effects on the player.
	notify: (player: any, text: string) -> (),
	served: (player: any, cash: number) -> (),
	welcome: (player: any, cash: number, waiting: number) -> (),
}

export type Actions = {
	join: (self: Actions, player: any) -> (),
	tick: (self: Actions, player: any) -> (),
	leave: (self: Actions, player: any) -> (),
	serve: (self: Actions, player: any) -> (boolean, string?),
	collect: (self: Actions, player: any) -> (boolean, string?),
	build: (self: Actions, player: any, stationId: string, spot: number) -> (boolean, string?),
	upgrade: (self: Actions, player: any, spot: number) -> (boolean, string?),
	move: (self: Actions, player: any, from: number, to: number) -> (boolean, string?),
	hireCook: (self: Actions, player: any, tierId: string, spot: number) -> (boolean, string?),
	unlockDistrict: (self: Actions, player: any) -> (boolean, string?),
	rebirth: (self: Actions, player: any) -> (boolean, string?),
}

local Actions = {}

function Actions.new(options: Options): Actions
	local config = options.config
	local data = options.data
	local economy = options.economy
	local analytics = options.analytics

	local lastAutoCollect: { [any]: number } = {}

	local function restaurantPerks(player: any): Restaurant.Perks
		return { doubleCash = options.perks(player).doubleCash }
	end

	local function onboarding(player: any, steps: { number })
		for _, step in steps do
			analytics:onboarding(player, step, Restaurant.ONBOARDING[step])
		end
	end

	-- Runs `fn(d, ledger, now)` in one atomic update, after bringing the
	-- restaurant up to date. `fn` returns a refusal message, or nil on
	-- success. The ledger's cash changes are reported only when the update lands.
	local function change(
		player: any,
		fn: (d: Restaurant.Data, ledger: any, now: number) -> string?
	): (boolean, string?)
		local ledger: any = nil
		local refusal: string? = nil
		local now = options.now()
		local ok, err = data:update(player, function(d: Restaurant.Data)
			if d.lastIncomeAt > 0 and now > d.lastIncomeAt then
				d.stats.playSeconds += now - d.lastIncomeAt
			end
			Restaurant.accrue(d, config, restaurantPerks(player), now)
			ledger = economy:ledger(player, d)
			refusal = fn(d, ledger, now)
		end)
		if not ok then
			return false, err
		end
		economy:commit(ledger)
		if refusal then
			options.notify(player, refusal)
			return false, refusal
		end
		return true, nil
	end

	local actions = {}

	-- Call once the player's data has loaded (the core's onPlayerReady).
	function actions.join(_self: Actions, player: any)
		local now = options.now()
		local earned = 0
		local waiting = 0
		local steps: { number } = {}
		local ok = data:update(player, function(d: Restaurant.Data)
			earned = Restaurant.welcomeBack(d, config, restaurantPerks(player), now)
			waiting = Restaurant.waiting(d.queue)
			steps = Restaurant.markFirst(d, "Joined", now)
		end)
		if not ok then
			return
		end
		lastAutoCollect[player] = now
		onboarding(player, steps)
		if earned >= 1 or waiting > 0 then
			options.welcome(player, math.floor(earned), waiting)
		end
	end

	-- Call every few seconds for each player in the server.
	function actions.tick(_self: Actions, player: any)
		local now = options.now()
		local autoCollect = options.perks(player).autoCollect
			and now - (lastAutoCollect[player] or now) >= config.economy.autoCollectSeconds
		change(player, function(d, ledger)
			if autoCollect then
				Restaurant.collect(d, ledger)
			end
			return nil
		end)
		if autoCollect then
			lastAutoCollect[player] = now
		end
	end

	-- Call when the player leaves, before their data is released.
	function actions.leave(_self: Actions, player: any)
		change(player, function()
			return nil
		end)
		lastAutoCollect[player] = nil
	end

	function actions.serve(_self: Actions, player: any): (boolean, string?)
		local cash: number? = nil
		local steps: { number } = {}
		local ok, err = change(player, function(d, ledger, now)
			local refusal: string?
			cash, refusal = Restaurant.serve(d, ledger, config, restaurantPerks(player), now)
			if cash then
				steps = Restaurant.markFirst(d, "FirstCustomerServed", now)
			end
			return refusal
		end)
		if ok and cash then
			onboarding(player, steps)
			options.served(player, cash)
		end
		return ok, err
	end

	function actions.collect(_self: Actions, player: any): (boolean, string?)
		return change(player, function(d, ledger)
			Restaurant.collect(d, ledger)
			return nil
		end)
	end

	function actions.build(_self: Actions, player: any, stationId: string, spot: number): (boolean, string?)
		local steps: { number } = {}
		local ok, err = change(player, function(d, ledger, now)
			local station, refusal = Restaurant.build(d, ledger, config, stationId, spot, now)
			if station then
				steps = Restaurant.markFirst(d, "FirstStationBought", now)
			end
			return refusal
		end)
		if ok then
			onboarding(player, steps)
			analytics:custom(player, "Station:Built", 1, { stationId })
		end
		return ok, err
	end

	function actions.upgrade(_self: Actions, player: any, spot: number): (boolean, string?)
		local stationId: string? = nil
		local level = 0
		local steps: { number } = {}
		local ok, err = change(player, function(d, ledger, now)
			local station, refusal = Restaurant.upgrade(d, ledger, config, spot, now)
			if station then
				stationId = station.stationId
				level = station.level
				steps = Restaurant.markFirst(d, "FirstUpgrade", now)
			end
			return refusal
		end)
		if ok and stationId then
			onboarding(player, steps)
			analytics:custom(player, "Station:Upgraded", level, { stationId })
		end
		return ok, err
	end

	function actions.move(_self: Actions, player: any, from: number, to: number): (boolean, string?)
		return change(player, function(d)
			local _, refusal = Restaurant.move(d, config, from, to)
			return refusal
		end)
	end

	function actions.hireCook(_self: Actions, player: any, tierId: string, spot: number): (boolean, string?)
		local steps: { number } = {}
		local ok, err = change(player, function(d, ledger, now)
			local cook, refusal = Restaurant.hireCook(d, ledger, config, tierId, spot)
			if cook then
				steps = Restaurant.markFirst(d, "FirstCookHired", now)
			end
			return refusal
		end)
		if ok then
			onboarding(player, steps)
			analytics:custom(player, "Cook:Hired", 1, { tierId })
		end
		return ok, err
	end

	function actions.unlockDistrict(_self: Actions, player: any): (boolean, string?)
		local district = 0
		local steps: { number } = {}
		local ok, err = change(player, function(d, ledger, now)
			local done, refusal = Restaurant.unlockDistrict(d, ledger, config)
			district = d.districts
			if done and district == 2 then
				steps = Restaurant.markFirst(d, "SecondDistrictUnlocked", now)
			end
			return if done then nil else refusal
		end)
		if ok then
			onboarding(player, steps)
			analytics:progression(player, "District", "Complete", district)
		end
		return ok, err
	end

	function actions.rebirth(_self: Actions, player: any): (boolean, string?)
		local level = 0
		local ok, err = change(player, function(d, ledger)
			local done, refusal = Restaurant.rebirth(d, ledger, config)
			level = d.rebirths
			return if done then nil else refusal
		end)
		if ok then
			analytics:progression(player, "Rebirth", "Complete", level)
		end
		return ok, err
	end

	return (actions :: any) :: Actions
end

return Actions
