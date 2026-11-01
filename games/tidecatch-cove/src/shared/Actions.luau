--!strict
-- Every player action in Tidecatch Cove, as the server runs it: check the
-- request against saved data, change the data in one atomic update, then tell
-- the economy, analytics and the player what happened.
--
-- Fishing is a short state machine kept in server memory per player:
--   cast   -> the bait is used and a bite is scheduled at a random moment
--   bite   -> the server rolls the catch (species and size) from the odds
--             table of that spot and bait, with the player's rod applied
--   reel   -> the client reports the minigame result; the server accepts a
--             catch only if it took at least Reel.minSeconds since the bite
-- A line in the water is not saved: leaving mid-cast loses the cast (the bait
-- was already used), never the save.
--
-- Runs only on the server. It lives in Shared so the server and the Lune tests
-- load the exact same code; a client that requires it gets nothing, because
-- every call needs the server's services. Roblox-specific effects (timers,
-- messages to the client, where the character stands) come in as callbacks.

local Catch = require("./Catch")
local Cove = require("./Cove")
local Reel = require("./Reel")

export type Perks = Cove.Perks

export type Caught = {
	castId: number,
	uid: string,
	speciesId: string,
	kg: number,
	soldFor: number, -- > 0 when the bucket was full and it sold at once
	isNew: boolean,
}

export type Options = {
	-- Core services (see packages/core).
	data: any,
	economy: any,
	odds: any,
	policy: any,
	analytics: any,
	config: Cove.Config,
	sellsCurrency: boolean, -- coins are sold for Robux, so every bait cast is a paid roll
	perks: (player: any) -> Perks,
	now: () -> number, -- unix seconds, for saved times (os.time)
	clock: () -> number, -- precise seconds, for bite and reel timing (workspace:GetServerTimeNow)
	random: () -> number, -- [0, 1), for bite delays and sizes
	schedule: (seconds: number, fn: () -> ()) -> (), -- task.delay
	canReach: (player: any, spotId: string) -> boolean,
	spotOpen: (spotId: string) -> boolean, -- low tide (milestone M4)
	-- Effects on the player.
	notify: (player: any, text: string) -> (),
	castStarted: (player: any, castId: number, spotId: string) -> (),
	bite: (player: any, castId: number, rarity: string) -> (),
	caught: (player: any, caught: Caught) -> (),
	escaped: (player: any, castId: number, text: string) -> (),
	welcome: (player: any, grew: number, restocked: boolean) -> (),
}

export type Actions = {
	join: (self: Actions, player: any) -> (),
	tick: (self: Actions, player: any) -> (),
	leave: (self: Actions, player: any) -> (),
	cast: (self: Actions, player: any, spotId: string, baitId: string) -> (boolean, string?),
	reel: (self: Actions, player: any, castId: number, success: boolean) -> (boolean, string?),
	sellCatch: (self: Actions, player: any, uid: string) -> (boolean, string?),
	sellBucket: (self: Actions, player: any) -> (boolean, string?),
	place: (self: Actions, player: any, uid: string) -> (boolean, string?),
	feed: (self: Actions, player: any, slot: number) -> (boolean, string?),
	sellPool: (self: Actions, player: any, slot: number) -> (boolean, string?),
	buyPool: (self: Actions, player: any) -> (boolean, string?),
	buyRod: (self: Actions, player: any, tier: number) -> (boolean, string?),
	buyBait: (self: Actions, player: any, baitId: string, count: number) -> (boolean, string?),
	refreshOdds: (self: Actions, player: any) -> (),
	line: (self: Actions, player: any) -> Line?,
}

-- A line in the water.
export type Line = {
	id: number,
	spotId: string,
	baitId: string,
	tableId: string,
	paid: boolean,
	castAt: number,
	hookedAt: number?, -- clock time of the bite
	speciesId: string?,
	kg: number?,
}

local name = Catch.displayName

local Actions = {}

function Actions.new(options: Options): Actions
	local config = options.config
	local fishing = config.fishing
	local speciesConfig = config.species
	local data = options.data
	local economy = options.economy
	local analytics = options.analytics

	local lines: { [any]: Line } = {}
	local lastCastAt: { [any]: number } = {}
	local nextCastId: { [any]: number } = {}

	local function onboarding(player: any, step: number?)
		if step then
			analytics:onboarding(player, step, Cove.ONBOARDING[step])
		end
	end

	-- Runs `fn(d, ledger)` in one atomic update. `fn` returns a refusal
	-- message, or nil on success. The ledger's coin changes are reported only
	-- when the update lands; a refusal is shown to the player.
	local function change(player: any, fn: (d: Cove.Data, ledger: any) -> string?): (boolean, string?)
		local ledger: any = nil
		local refusal: string? = nil
		local now = options.now()
		local ok, err = data:update(player, function(d: Cove.Data)
			Cove.touch(d, now)
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

	-- Puts the player's rod on every catch table, so the odds board and the
	-- roll both include it.
	function actions.refreshOdds(_self: Actions, player: any)
		local d = data:get(player)
		if d == nil then
			return
		end
		local rod = Catch.rod(fishing, d.rodTier)
		for _, spot in fishing.spots do
			local ids = { Catch.tableId(spot.id, Catch.NO_BAIT) }
			for _, bait in fishing.bait do
				table.insert(ids, Catch.tableId(spot.id, bait.id))
			end
			for _, tableId in ids do
				-- The table as defined, without any player's boosts.
				local base = options.odds:effective(tableId, nil)
				local boost = Catch.rodBoost(rod, base, speciesConfig.species)
				-- The starting rod boosts nothing: skip it, so joining does
				-- not resend every odds table.
				if boost or #options.odds:display(tableId, player).boosts > 0 then
					options.odds:setBoosts(player, tableId, if boost then { boost } else {})
				end
			end
		end
	end

	-- Call once the player's data has loaded (the core's onPlayerReady).
	function actions.join(self: Actions, player: any)
		local now = options.now()
		local grew, restocked = 0, false
		local step: number? = nil
		local ok = data:update(player, function(d: Cove.Data)
			Cove.welcomeNew(d, config.economy)
			grew, restocked = Cove.welcomeBack(d, now, config)
			local _, s = Cove.markFirst(d, "Joined", now)
			step = s
		end)
		if not ok then
			return
		end
		self:refreshOdds(player)
		onboarding(player, step)
		if grew > 0 or restocked then
			options.welcome(player, grew, restocked)
		end
	end

	-- Call every few seconds for each player in the server.
	function actions.tick(_self: Actions, player: any)
		local step: number? = nil
		local now = options.now()
		change(player, function(d)
			if d.firsts.FirstGrowth == nil and Cove.anyGrown(d, now, config) then
				local _, s = Cove.markFirst(d, "FirstGrowth", now)
				step = s
			end
			return nil
		end)
		onboarding(player, step)
		-- Forget a line whose fish was never reeled in.
		local line = lines[player]
		if line and line.hookedAt and options.clock() - line.hookedAt > Reel.maxSeconds(fishing) then
			lines[player] = nil
		end
	end

	-- Call when the player leaves, before their data is released.
	function actions.leave(_self: Actions, player: any)
		change(player, function()
			return nil
		end)
		lines[player] = nil
		lastCastAt[player] = nil
		nextCastId[player] = nil
	end

	function actions.line(_self: Actions, player: any): Line?
		return lines[player]
	end

	-- The bite: roll the catch from the odds table the player saw.
	local function bite(player: any, castId: number)
		local line = lines[player]
		if line == nil or line.id ~= castId or line.hookedAt ~= nil or not data:isLoaded(player) then
			return
		end
		local speciesId: string?
		if line.paid then
			speciesId = options.odds:rollPaid(line.tableId, player, options.policy)
		else
			speciesId = options.odds:roll(line.tableId, player)
		end
		local def = speciesId and speciesConfig.species[speciesId]
		if speciesId == nil or def == nil then
			lines[player] = nil
			options.escaped(player, castId, "Nothing is biting with that bait.")
			return
		end
		line.speciesId = speciesId
		line.kg = Catch.rollKg(def, options.random())
		line.hookedAt = options.clock()
		options.bite(player, castId, def.rarity)
	end

	function actions.cast(_self: Actions, player: any, spotId: string, baitId: string): (boolean, string?)
		local d = data:get(player)
		if d == nil then
			return false, "not loaded"
		end
		local spot = Catch.spot(fishing, spotId)
		if spot == nil then
			return false, "unknown spot"
		end
		local function refuse(text: string): (boolean, string?)
			options.notify(player, text)
			return false, text
		end
		if spot.lowTideOnly and not options.spotOpen(spot.id) then
			return refuse("This spot opens at low tide.")
		end
		if d.rodTier < spot.minRod then
			return refuse(`You need a {name(Catch.rod(fishing, spot.minRod).id)} or better to fish here.`)
		end
		if not options.canReach(player, spot.id) then
			return refuse("Walk onto the dock to cast here.")
		end
		local bait = Catch.bait(fishing, baitId)
		if bait == nil and baitId ~= Catch.NO_BAIT then
			return false, "unknown bait"
		end
		local clock = options.clock()
		local last = lastCastAt[player]
		if last and clock - last < fishing.castCooldownSeconds then
			return false, "casting too fast"
		end
		-- One line at a time: a recast before the bite would burn another bait.
		if lines[player] then
			return false, "your line is already out"
		end
		local paid = Catch.isPaid(bait, options.sellsCurrency)
		if paid and not options.policy:paidRandomAllowed(player) then
			return refuse("This bait is not available to you. Cast without bait or pick another.")
		end

		local step: number? = nil
		local ok, err = change(player, function(dd)
			if not Cove.useBait(dd, baitId) then
				return `You are out of {name(baitId)}. Buy more at the bait shop.`
			end
			dd.stats.casts += 1
			local _, s = Cove.markFirst(dd, "FirstCast", options.now())
			step = s
			return nil
		end)
		if not ok then
			return false, err
		end
		onboarding(player, step)

		local castId = (nextCastId[player] or 0) + 1
		nextCastId[player] = castId
		lastCastAt[player] = clock
		lines[player] = {
			id = castId,
			spotId = spot.id,
			baitId = baitId,
			tableId = Catch.tableId(spot.id, baitId),
			paid = paid,
			castAt = clock,
		}
		local rod = Catch.rod(fishing, d.rodTier)
		local range = fishing.biteSeconds
		local wait = (range.min + (range.max - range.min) * options.random()) * rod.biteTime
		options.castStarted(player, castId, spot.id)
		options.schedule(wait, function()
			bite(player, castId)
		end)
		return true, nil
	end

	function actions.reel(_self: Actions, player: any, castId: number, success: boolean): (boolean, string?)
		local line = lines[player]
		if line == nil or line.id ~= castId then
			return false, "no line"
		end
		if line.hookedAt == nil or line.speciesId == nil or line.kg == nil then
			-- Reeling before a bite pulls the line out empty.
			lines[player] = nil
			options.escaped(player, castId, "Too early! Wait for the bite.")
			return false, "no bite yet"
		end
		lines[player] = nil
		local speciesId = line.speciesId :: string
		local kg = line.kg :: number
		local def = speciesConfig.species[speciesId]
		local elapsed = options.clock() - (line.hookedAt :: number)

		local reason: string? = nil
		if not success then
			reason = "It got away!"
			-- Rarer fish are hard on a weak rod: say what helps.
			local d = data:get(player)
			local rarer = def.rarity == "Rare" or def.rarity == "Epic" or def.rarity == "Legendary"
			if rarer and d and d.rodTier < #fishing.rods then
				reason = `{def.rarity} fish are tough! A better rod makes them easier to land.`
			end
		elseif elapsed < Reel.minSeconds(def.rarity, fishing) - fishing.reel.toleranceSeconds then
			-- Faster than a perfect human reel: a script. Count it as lost.
			analytics:custom(player, "Fish:ReelTooFast", 1, { def.rarity })
			reason = "It got away!"
		elseif elapsed > Reel.maxSeconds(fishing) then
			reason = "The fish slipped the hook."
		end
		if reason then
			change(player, function(d)
				d.stats.escapes += 1
				return nil
			end)
			analytics:custom(player, "Fish:Escaped", 1, { line.spotId, def.rarity })
			options.escaped(player, castId, reason)
			return false, reason
		end

		local landed: Cove.Landed? = nil
		local step: number? = nil
		local firstSale = false
		local ok, err = change(player, function(d, ledger)
			local now = options.now()
			landed = Cove.land(d, ledger, {
				speciesId = speciesId,
				kg = kg,
				mutation = "None",
				spotId = line.spotId,
			}, now, config, options.perks(player))
			local _, s = Cove.markFirst(d, "FirstCatch", now)
			step = s
			local l = landed :: Cove.Landed
			if l.soldFor > 0 or l.madeRoom then
				firstSale = Cove.markFirst(d, "FirstSale", now)
			end
			return nil
		end)
		if not ok or landed == nil then
			return false, err
		end
		local result = landed :: Cove.Landed
		onboarding(player, step)
		if result.madeRoom then
			local room = result.madeRoom :: { speciesId: string, coins: number }
			options.notify(
				player,
				`Bucket full: sold your {name(room.speciesId)} for {room.coins} coins to make room.`
			)
		end
		if firstSale then
			analytics:custom(player, "Onboarding:FirstSale", 1)
		end
		analytics:custom(player, "Fish:Caught", 1, { line.spotId, speciesId })
		options.caught(player, {
			castId = castId,
			uid = result.uid,
			speciesId = speciesId,
			kg = kg,
			soldFor = result.soldFor,
			isNew = result.isNew,
		})
		return true, nil
	end

	local function afterSale(player: any, firstSale: boolean)
		if firstSale then
			analytics:custom(player, "Onboarding:FirstSale", 1)
		end
	end

	function actions.sellCatch(_self: Actions, player: any, uid: string): (boolean, string?)
		local firstSale = false
		local ok, err = change(player, function(d, ledger)
			local coins, refusal = Cove.sellFromBucket(d, ledger, uid, config, options.perks(player))
			if coins then
				firstSale = Cove.markFirst(d, "FirstSale", options.now())
			end
			return refusal
		end)
		if ok then
			afterSale(player, firstSale)
		end
		return ok, err
	end

	function actions.sellBucket(_self: Actions, player: any): (boolean, string?)
		local firstSale = false
		local total, count = 0, 0
		local ok, err = change(player, function(d, ledger)
			if #d.bucket == 0 then
				return "Your bucket is empty."
			end
			total, count = Cove.sellBucket(d, ledger, config, options.perks(player))
			firstSale = Cove.markFirst(d, "FirstSale", options.now())
			return nil
		end)
		if ok then
			afterSale(player, firstSale)
			options.notify(player, `Sold {count} for {total} coins.`)
		end
		return ok, err
	end

	function actions.place(_self: Actions, player: any, uid: string): (boolean, string?)
		local step: number? = nil
		local ok, err = change(player, function(d)
			local now = options.now()
			local count = Cove.poolCount(d, config.pools, options.perks(player))
			local slot, refusal = Cove.place(d, uid, now, count)
			if slot then
				local _, s = Cove.markFirst(d, "FirstPlaced", now)
				step = s
			end
			return refusal
		end)
		if ok then
			onboarding(player, step)
		end
		return ok, err
	end

	function actions.feed(_self: Actions, player: any, slot: number): (boolean, string?)
		return change(player, function(d)
			local _, refusal = Cove.feed(d, slot, options.now(), config)
			return refusal
		end)
	end

	function actions.sellPool(_self: Actions, player: any, slot: number): (boolean, string?)
		local firstSale = false
		local sold: { coins: number, stage: number, speciesId: string }? = nil
		local ok, err = change(player, function(d, ledger)
			local pooled = Cove.poolAt(d, slot)
			local speciesId = if pooled then pooled.speciesId else ""
			local coins, stage, refusal =
				Cove.sellFromPool(d, ledger, slot, options.now(), config, options.perks(player))
			if coins and stage then
				sold = { coins = coins, stage = stage, speciesId = speciesId }
				firstSale = Cove.markFirst(d, "FirstSale", options.now())
			end
			return refusal
		end)
		if ok and sold then
			local s = sold :: { coins: number, stage: number, speciesId: string }
			afterSale(player, firstSale)
			local stageName = config.pools.stages[s.stage].name
			analytics:custom(player, "Pool:Sold", s.coins, { s.speciesId, stageName })
			options.notify(player, `Sold your {stageName} {name(s.speciesId)} for {s.coins} coins.`)
		end
		return ok, err
	end

	function actions.buyPool(_self: Actions, player: any): (boolean, string?)
		return change(player, function(d, ledger)
			local _, refusal = Cove.buyPool(d, ledger, config.pools)
			return refusal
		end)
	end

	function actions.buyRod(self: Actions, player: any, tier: number): (boolean, string?)
		local ok, err = change(player, function(d, ledger)
			local _, refusal = Cove.buyRod(d, ledger, tier, fishing)
			return refusal
		end)
		if ok then
			self:refreshOdds(player)
			analytics:progression(player, "Rod", "Complete", tier)
			options.notify(player, `You bought the {name(Catch.rod(fishing, tier).id)}!`)
		end
		return ok, err
	end

	function actions.buyBait(_self: Actions, player: any, baitId: string, count: number): (boolean, string?)
		return change(player, function(d, ledger)
			local _, refusal = Cove.buyBait(d, ledger, baitId, count, options.now(), config)
			return refusal
		end)
	end

	return (actions :: any) :: Actions
end

return Actions
