--!strict
-- Every player action in the base loop, as the server runs it: check the
-- request against saved data, change the data in one atomic update, then tell
-- the economy, analytics and the player what happened.
--
-- Runs only on the server. It lives in Shared so the server and the Lune tests
-- load the exact same code; a client that requires it gets nothing, because
-- every call needs the server's services. Roblox-specific effects (the mount
-- model, messages to the client) come in as callbacks, which keeps this file
-- testable without Roblox.

local Conveyor = require("./Conveyor")
local Daily = require("./Daily")
local Eggs = require("./Eggs")
local Hatchery = require("./Hatchery")

export type Perks = {
	doubleCoins: boolean,
	extraIncubators: boolean,
	autoCollect: boolean,
}

export type Options = {
	-- Core services (see packages/core).
	data: any,
	economy: any,
	odds: any,
	policy: any,
	analytics: any,
	config: { economy: any, creatures: any, eggs: { any } },
	sellsCurrency: boolean, -- coins are sold for Robux, so coin eggs are paid random items
	perks: (player: any) -> Perks,
	now: () -> number, -- unix seconds (os.time)
	serverTime: () -> number, -- shared server clock for the conveyor (workspace:GetServerTimeNow)
	plotOf: (player: any) -> number?,
	-- Effects on the player.
	notify: (player: any, text: string) -> (),
	hatched: (player: any, speciesId: string, eggId: string, isNew: boolean) -> (),
	welcome: (player: any, coins: number, readyEggs: number) -> (),
	mount: (player: any, speed: number?) -> (), -- speed nil = dismount
}

export type Actions = {
	join: (self: Actions, player: any) -> (),
	tick: (self: Actions, player: any) -> (),
	leave: (self: Actions, player: any) -> (),
	buyEgg: (self: Actions, player: any, index: number) -> (boolean, string?),
	hatch: (self: Actions, player: any, slot: number) -> (boolean, string?),
	buySlot: (self: Actions, player: any) -> (boolean, string?),
	collect: (self: Actions, player: any) -> (boolean, string?),
	claimDaily: (self: Actions, player: any) -> (boolean, string?),
	rebirth: (self: Actions, player: any) -> (boolean, string?),
	ride: (self: Actions, player: any, uid: string) -> (boolean, string?),
	dismount: (self: Actions, player: any) -> (boolean, string?),
	-- Studio test panel only: adds a creature of any species, placed like a
	-- hatch. Returns whether it worked and what to show.
	grantCreature: (self: Actions, player: any, speciesId: string) -> (boolean, string),
	-- For the raid layer (Raids.luau): one atomic update with income brought
	-- up to date; `fn` returns a refusal or nil.
	change: (
		self: Actions,
		player: any,
		fn: (d: Hatchery.Data, ledger: any) -> string?
	) -> (boolean, string?),
	onboarding: (self: Actions, player: any, step: number?) -> (),
}

local Actions = {}

function Actions.new(options: Options): Actions
	local config = options.config
	local economyConfig = config.economy
	local data = options.data
	local economy = options.economy
	local analytics = options.analytics

	-- Conveyor eggs each player has bought recently: { [player] = { [index] = true } }.
	local boughtOnBelt: { [any]: { [number]: boolean } } = {}
	local lastAutoCollect: { [any]: number } = {}
	-- Storage auto-sales are reported at most once per SOLD_NOTICE_SECONDS,
	-- summed, so they never drown out other notices.
	local SOLD_NOTICE_SECONDS = 20
	type SoldNotice = { at: number, count: number, coins: number, what: string }
	local soldNotice: { [any]: SoldNotice } = {}

	local function flushSold(player: any, now: number, force: boolean)
		local pending = soldNotice[player]
		if pending == nil or pending.count == 0 then
			return
		end
		if not force and now - pending.at < SOLD_NOTICE_SECONDS then
			return
		end
		local what = if pending.count == 1 then pending.what else `{pending.count} creatures`
		options.notify(player, `Storage is full: sold {what} for {pending.coins} coins.`)
		pending.at = now
		pending.count = 0
		pending.coins = 0
	end

	local function perSecond(d: Hatchery.Data, player: any): number
		local perks = options.perks(player)
		return Hatchery.incomePerSecond(
			d,
			config,
			{ doubleCoins = perks.doubleCoins, extraIncubators = perks.extraIncubators }
		)
	end

	local function onboarding(player: any, step: number?)
		if step then
			analytics:onboarding(player, step, Hatchery.ONBOARDING[step])
		end
	end

	-- Runs `fn(d, ledger)` in one atomic update, after bringing income up to
	-- date at the old rate. `fn` returns a refusal message, or nil on success.
	-- The ledger's coin changes are reported only when the update lands.
	local function change(player: any, fn: (d: Hatchery.Data, ledger: any) -> string?): (boolean, string?)
		local ledger: any = nil
		local refusal: string? = nil
		local now = options.now()
		local ok, err = data:update(player, function(d: Hatchery.Data)
			if d.lastIncomeAt > 0 and now > d.lastIncomeAt then
				d.stats.playSeconds += now - d.lastIncomeAt
			end
			Hatchery.accrue(d, now, perSecond(d, player))
			ledger = economy:ledger(player, d)
			refusal = fn(d, ledger)
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

	function actions.change(
		_self: Actions,
		player: any,
		fn: (d: Hatchery.Data, ledger: any) -> string?
	): (boolean, string?)
		return change(player, fn)
	end

	function actions.onboarding(_self: Actions, player: any, step: number?)
		onboarding(player, step)
	end

	-- Call once the player's data has loaded (the core's onPlayerReady).
	function actions.join(_self: Actions, player: any)
		local now = options.now()
		local earned: number = 0
		local ready: number = 0
		local step: number? = nil
		local mountSpeed: number? = nil
		local ok = data:update(player, function(d: Hatchery.Data)
			Hatchery.backfillFound(d)
			earned = Hatchery.welcomeBack(d, now, perSecond(d, player), economyConfig)
			for _, incubator in d.incubators do
				if incubator.readyAt <= now then
					ready += 1
				end
			end
			step = Hatchery.markFirst(d, "Joined", now)
			if d.mountUid ~= "" then
				local speed = Hatchery.ride(d, d.mountUid, config.creatures)
				if speed == nil then
					Hatchery.dismount(d)
				end
				mountSpeed = speed
			end
		end)
		if not ok then
			return
		end
		lastAutoCollect[player] = now
		onboarding(player, step)
		if earned > 0 or ready > 0 then
			options.welcome(player, math.floor(earned), ready)
		end
		if mountSpeed then
			options.mount(player, mountSpeed)
		end
	end

	-- Call every few seconds for each player in the server.
	function actions.tick(_self: Actions, player: any)
		local now = options.now()
		local autoCollect = options.perks(player).autoCollect
			and now - (lastAutoCollect[player] or now) >= economyConfig.autoCollectSeconds
		local step: number? = nil
		change(player, function(d, ledger)
			if autoCollect and Hatchery.collect(d, ledger) > 0 then
				step = Hatchery.markFirst(d, "FirstCollect", now)
			end
			return nil
		end)
		if autoCollect then
			lastAutoCollect[player] = now
		end
		onboarding(player, step)
		flushSold(player, now, false)
	end

	-- Call when the player leaves, before their data is released.
	function actions.leave(_self: Actions, player: any)
		change(player, function()
			return nil
		end)
		boughtOnBelt[player] = nil
		lastAutoCollect[player] = nil
		soldNotice[player] = nil
	end

	function actions.buyEgg(_self: Actions, player: any, index: number): (boolean, string?)
		local plot = options.plotOf(player)
		if plot == nil then
			return false, "no base"
		end
		local belt = economyConfig.conveyor
		local serverNow = options.serverTime()
		if not Conveyor.canBuy(index, serverNow, belt) then
			options.notify(player, "That egg has left the conveyor.")
			return false, "egg not on the belt"
		end
		local bought: { [number]: boolean } = boughtOnBelt[player] or {}
		boughtOnBelt[player] = bought
		if bought[index] then
			return false, "egg already bought"
		end
		local egg = Hatchery.eggById(config.eggs, Conveyor.eggAt(index, plot, belt))
		if egg == nil then
			return false, "unknown egg"
		end

		-- Restricted players always get the shown fixed order (the client shows
		-- it whenever PaidRandomRestricted is set), whether or not this egg
		-- counts as paid; everyone else rolls from the odds table they saw.
		local paid = Eggs.isPaid(egg, options.sellsCurrency)
		local function pick(e: any, boughtBefore: number): string?
			if not options.policy:paidRandomAllowed(player) then
				return Hatchery.fixedOrderOutcome(e, boughtBefore)
			end
			if paid then
				return (options.odds:rollPaid(e.id, player, options.policy))
			end
			return options.odds:roll(e.id, player)
		end

		local step: number? = nil
		local ok, err = change(player, function(d, ledger)
			local perks = options.perks(player)
			local slots = Hatchery.slotCount(d, economyConfig, {
				doubleCoins = perks.doubleCoins,
				extraIncubators = perks.extraIncubators,
			})
			local incubator, refusal = Hatchery.buyEgg(d, ledger, egg, slots, options.now(), pick)
			if incubator then
				step = Hatchery.markFirst(d, "FirstEggBought", options.now())
			end
			return refusal
		end)
		if ok then
			bought[index] = true
			-- Forget eggs that have left the belt.
			for i in bought do
				if not Conveyor.canBuy(i, serverNow, belt) then
					bought[i] = nil
				end
			end
			onboarding(player, step)
		end
		return ok, err
	end

	function actions.hatch(_self: Actions, player: any, slot: number): (boolean, string?)
		local creature: any = nil
		local sold: { any } = {}
		local step: number? = nil
		local fullStep: number? = nil
		local isNew = false
		local now = options.now()
		local ok, err = change(player, function(d, ledger)
			local refusal: string?
			local foundBefore = Hatchery.foundCount(d, config.creatures)
			creature, refusal, sold = Hatchery.hatch(d, ledger, slot, now, config.creatures, economyConfig)
			isNew = Hatchery.foundCount(d, config.creatures) > foundBefore
			if creature then
				step = Hatchery.markFirst(d, "FirstHatch", now)
				if Hatchery.padsFull(d, economyConfig.creaturePads) then
					fullStep = Hatchery.markFirst(d, "PadsFull", now)
				end
			end
			return refusal
		end)
		if ok and creature then
			onboarding(player, step)
			onboarding(player, fullStep)
			analytics:custom(player, "Egg:Hatched", 1, { creature.eggId, creature.speciesId })
			options.hatched(player, creature.speciesId, creature.eggId, isNew)
			if #sold > 0 then
				local pending: SoldNotice = soldNotice[player]
					or { at = -math.huge, count = 0, coins = 0, what = "" }
				soldNotice[player] = pending
				for _, c in sold do
					pending.coins += Hatchery.sellValue(c, config.creatures, economyConfig)
				end
				pending.count += #sold
				pending.what = sold[1].speciesId
				flushSold(player, now, false)
			end
		end
		return ok, err
	end

	function actions.buySlot(_self: Actions, player: any): (boolean, string?)
		local step: number? = nil
		local ok, err = change(player, function(d, ledger)
			local done, refusal = Hatchery.buySlot(d, ledger, economyConfig)
			if done then
				step = Hatchery.markFirst(d, "FirstSlot", options.now())
			end
			return if done then nil else refusal
		end)
		if ok then
			onboarding(player, step)
		end
		return ok, err
	end

	function actions.collect(_self: Actions, player: any): (boolean, string?)
		local step: number? = nil
		local ok, err = change(player, function(d, ledger)
			if Hatchery.collect(d, ledger) > 0 then
				step = Hatchery.markFirst(d, "FirstCollect", options.now())
			end
			return nil
		end)
		if ok then
			onboarding(player, step)
		end
		return ok, err
	end

	-- Daily Rewards: today's coins, once a UTC day (shared/Daily.luau).
	function actions.claimDaily(_self: Actions, player: any): (boolean, string?)
		local coins: number? = nil
		local day = 0
		local ok, err = change(player, function(d, ledger)
			local paid, result =
				Daily.claim(d, ledger, options.now(), perSecond(d, player), economyConfig.daily)
			if paid == nil then
				return result :: string
			end
			coins, day = paid, result :: number
			return nil
		end)
		if ok and coins then
			options.notify(player, `Day {day} reward: +{coins} coins!`)
		end
		return ok, err
	end

	function actions.rebirth(_self: Actions, player: any): (boolean, string?)
		local level = 0
		local step: number? = nil
		local ok, err = change(player, function(d, ledger)
			local done, refusal = Hatchery.rebirth(d, ledger, economyConfig)
			level = d.rebirths
			if done then
				step = Hatchery.markFirst(d, "FirstRebirth", options.now())
			end
			return if done then nil else refusal
		end)
		if ok then
			onboarding(player, step)
			analytics:progression(player, "Rebirth", "Complete", level)
			options.mount(player, nil)
		end
		return ok, err
	end

	function actions.ride(_self: Actions, player: any, uid: string): (boolean, string?)
		local speed: number? = nil
		local step: number? = nil
		local ok, err = change(player, function(d)
			local refusal: string?
			speed, refusal = Hatchery.ride(d, uid, config.creatures)
			if speed then
				step = Hatchery.markFirst(d, "FirstRide", options.now())
			end
			return refusal
		end)
		if ok and speed then
			onboarding(player, step)
			options.mount(player, speed)
		end
		return ok, err
	end

	function actions.dismount(_self: Actions, player: any): (boolean, string?)
		local ok, err = change(player, function(d)
			Hatchery.dismount(d)
			return nil
		end)
		if ok then
			options.mount(player, nil)
		end
		return ok, err
	end

	function actions.grantCreature(_self: Actions, player: any, speciesId: string): (boolean, string)
		if config.creatures.species[speciesId] == nil then
			return false, `No creature called {speciesId}.`
		end
		-- Record the first egg that can hatch it, so it looks like any other.
		local eggId: string? = nil
		for _, egg in config.eggs do
			for _, outcome in egg.outcomes do
				if eggId == nil and outcome.id == speciesId then
					eggId = egg.id
				end
			end
		end
		local creature: any = nil
		local now = options.now()
		local ok, err = change(player, function(d, ledger)
			creature = Hatchery.receive(d, ledger, {
				speciesId = speciesId,
				mutation = "None",
				eggId = eggId or config.eggs[1].id,
				hatchedAt = now,
			}, config.creatures, economyConfig)
			return nil
		end)
		if not ok or creature == nil then
			return false, `Could not add {speciesId}: {err or "unknown"}.`
		end
		if creature.slot == nil then
			return true, `{speciesId} added to storage (every pad holds a better creature).`
		end
		return true, `{speciesId} added on pad {creature.slot}, ready to ride or guard.`
	end

	return (actions :: any) :: Actions
end

return Actions
