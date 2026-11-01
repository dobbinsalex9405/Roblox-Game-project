--!strict
-- Every player action in the dive loop, as the server runs it: check the
-- request against server state and saved data, change the data in one atomic
-- update, then tell the mine, the economy, analytics and the player.
--
-- The loop: step onto the mine and the lamp lights -> mine blocks, ore goes in
-- the pack -> climb out before the oil runs dry (or walk out) -> sell at camp
-- -> upgrade pick, pack and lamp. If the oil runs dry first, the player keeps
-- only part of the pack and wakes up at camp.
--
-- Runs only on the server. It lives in Shared so the server and the Lune tests
-- load the exact same code; a client that requires it gets nothing, because
-- every call needs the server's services. Roblox-specific effects (moving the
-- character, drawing the mine, messages) come in as callbacks.

local Boosts = require("./Boosts")
local Gear = require("./Gear")
local Lamp = require("./Lamp")
local Layout = require("./Layout")
local MineGrid = require("./MineGrid")
local Pack = require("./Pack")

export type Phase = "Camp" | "Diving" | "Climbing"
export type Point = Layout.Point
export type Perks = Gear.Perks

-- How a dive ended.
export type Ending = "ClimbedOut" | "WalkedOut" | "LeftSafe" | "LampOut" | "Fainted" | "LeftInDark"

export type Options = {
	-- Core services (see packages/core).
	data: any,
	economy: any,
	analytics: any,
	grid: MineGrid.Grid,
	config: { mine: any, blocks: { [string]: any }, gear: any, dive: any, monetization: any },
	perks: (player: any) -> Perks,
	now: () -> number, -- server time in seconds (fractions allowed)
	position: (player: any) -> Point?, -- the character's root, nil when it has none
	-- Effects.
	notify: (player: any, text: string) -> (),
	dive: (
		player: any,
		phase: Phase,
		meter: Lamp.Meter,
		capacity: number,
		climbEndsAt: number,
		refilled: boolean
	) -> (),
	ore: (player: any, blockId: string) -> (),
	lampOut: (player: any, kept: number, dropped: number, row: number) -> (),
	sold: (player: any, coins: number, pieces: number) -> (),
	mineChanged: (changes: MineGrid.Changes) -> (),
	damaged: (key: number, fraction: number) -> (),
	climbing: (player: any, on: boolean) -> (), -- hold the character on the rope (or let go)
	rescue: (player: any) -> (), -- move the character to camp
}

export type Session = {
	phase: Phase,
	meter: Lamp.Meter,
	capacity: number, -- oil a full lamp holds this dive
	row: number, -- depth row the player is at (0 = top face)
	climbEndsAt: number,
	lastSwing: number,
	joinedAt: number,
	diveDeepest: number,
	refilled: boolean, -- an oil refill was poured this dive
	lastNotice: string,
	lastNoticeAt: number,
}

export type Actions = {
	join: (self: Actions, player: any) -> (),
	step: (self: Actions, player: any) -> (),
	leave: (self: Actions, player: any) -> (),
	hit: (self: Actions, player: any, x: number, y: number, z: number) -> (boolean, string?),
	climb: (self: Actions, player: any) -> (boolean, string?),
	sell: (self: Actions, player: any) -> (boolean, string?),
	upgrade: (self: Actions, player: any, kind: Gear.Kind) -> (boolean, string?),
	died: (self: Actions, player: any) -> (),
	-- Pours one of the player's oil refills into the lamp (one per dive).
	-- `bought` is set when a purchase just landed: outside a dive, or when
	-- one was already poured, the refill is kept for later instead.
	refill: (self: Actions, player: any, bought: boolean?) -> (boolean, string?),
	-- A short message for the player (from the shop's grants).
	notice: (self: Actions, player: any, text: string) -> (),
	regrowMine: (self: Actions) -> (),
	session: (self: Actions, player: any) -> Session?,
}

-- The onboarding funnel: first-time moments every player meets in this order
-- (you must sell before you can afford an upgrade). Roblox drops a step
-- reported after a later one, so moments that can come in any order
-- (FirstLampOut, Layer2Reached) are saved in `firsts` and reported as their
-- own events (`Dive:LampOut` First/Repeat, Layer progression) instead. New
-- steps go at the end so earlier step numbers never change.
local ONBOARDING = { "Joined", "FirstBlockMined", "FirstSale", "FirstUpgrade" }

local NOTICE_REPEAT_SECONDS = 2 -- the same refusal is shown at most this often
local REFILL_FULL_FRACTION = 0.9 -- a lamp fuller than this is not refilled (it would waste the oil)
local CAMP_HEIGHT = -1 -- a root above this, outside the shaft, is standing at camp

local Actions = {}
Actions.ONBOARDING = table.freeze(ONBOARDING)

function Actions.new(options: Options): Actions
	local config = options.config
	local mine, blocks, gear, dive = config.mine, config.blocks, config.gear, config.dive
	local boosts = config.monetization and config.monetization.boosts
	local grid = options.grid
	local data = options.data
	local economy = options.economy
	local analytics = options.analytics
	local totalRows = Layout.totalRows(mine)

	local sessions: { [any]: Session } = {}

	-- Saves a first-time moment. Returns its onboarding step when it is new
	-- and in the funnel, else nil.
	local function markFirst(d: { [string]: any }, moment: string, now: number): number?
		if d.firsts[moment] then
			return nil
		end
		d.firsts[moment] = math.floor(now)
		return table.find(ONBOARDING, moment)
	end

	local function onboarding(player: any, step: number?)
		if step then
			analytics:onboarding(player, step, ONBOARDING[step])
		end
	end

	local function notify(player: any, s: Session?, text: string, now: number)
		if s then
			if s.lastNotice == text and now - s.lastNoticeAt < NOTICE_REPEAT_SECONDS then
				return
			end
			s.lastNotice = text
			s.lastNoticeAt = now
		end
		options.notify(player, text)
	end

	local function sendDive(player: any, s: Session)
		options.dive(player, s.phase, s.meter, s.capacity, s.climbEndsAt, s.refilled)
	end

	-- Runs `fn(d, ledger)` in one atomic update. `fn` returns a refusal
	-- message, or nil on success. Coin changes are reported only when the
	-- update lands.
	local function change(player: any, fn: (d: { [string]: any }, ledger: any) -> string?): (boolean, string?)
		local ledger: any = nil
		local refusal: string? = nil
		local ok, err = data:update(player, function(d)
			ledger = economy:ledger(player, d)
			refusal = fn(d, ledger)
		end)
		if not ok then
			return false, err
		end
		economy:commit(ledger)
		if refusal then
			return false, refusal
		end
		return true, nil
	end

	local function oilCapacity(player: any): number
		local d = data:get(player)
		if d == nil then
			return gear.lamp[1].oilSeconds
		end
		return Gear.oilCapacity(d, gear, options.perks(player))
	end

	local function fullMeter(capacity: number, now: number): Lamp.Meter
		return { oil = capacity, rate = 0, at = now }
	end

	-- Sells the whole pack inside an update (an Ore Boost multiplies the
	-- price). Returns coins and pieces.
	local function sellInto(d: { [string]: any }, ledger: any, now: number): (number, number)
		local pieces = Pack.count(d.pack)
		local coins = math.floor(Pack.value(d.pack, blocks) * Boosts.sellMultiplier(d, boosts, now))
		if coins > 0 then
			ledger:add("coins", coins, "Sell:Ore")
		end
		table.clear(d.pack)
		d.stats.oreSold += pieces
		d.stats.coinsEarned += coins
		return coins, pieces
	end

	local function startDive(player: any, s: Session, now: number, row: number)
		s.capacity = oilCapacity(player)
		s.row = row
		s.meter = { oil = s.capacity, rate = Lamp.rateAt(mine, row), at = now }
		s.phase = "Diving"
		s.climbEndsAt = 0
		s.diveDeepest = 0
		s.refilled = false
		sendDive(player, s)
		analytics:custom(player, "Dive:Start", 1)
	end

	local function backToCamp(player: any, s: Session, now: number)
		local wasClimbing = s.phase == "Climbing"
		s.phase = "Camp"
		s.capacity = oilCapacity(player)
		s.meter = fullMeter(s.capacity, now)
		s.climbEndsAt = 0
		s.row = 0
		s.refilled = false
		if wasClimbing then
			options.climbing(player, false)
		end
	end

	-- The dive ended with the pack intact.
	local function endDive(player: any, s: Session, now: number, ending: Ending)
		local autoSell = options.perks(player).autoSell
		local coins, pieces = 0, 0
		local step: number? = nil
		-- Walking across the top face without mining is not a dive.
		local mined = s.diveDeepest > 0
		change(player, function(d, ledger)
			if mined then
				d.stats.dives += 1
			end
			if autoSell and Pack.count(d.pack) > 0 then
				coins, pieces = sellInto(d, ledger, now)
				step = markFirst(d, "FirstSale", now)
			end
			return nil
		end)
		local leaving = ending == "LeftSafe"
		local deepest = s.diveDeepest
		backToCamp(player, s, now)
		analytics:custom(player, "Dive:End", deepest, { ending })
		if leaving then
			return
		end
		if ending == "ClimbedOut" then
			options.rescue(player)
		end
		sendDive(player, s)
		onboarding(player, step)
		if pieces > 0 then
			options.sold(player, coins, pieces)
		end
	end

	-- The lamp ran dry (or the dive ended in the dark some other way): keep
	-- part of the pack, wake up at camp.
	local function lampOut(player: any, s: Session, now: number, ending: Ending)
		local row = s.row
		local kept, dropped = 0, 0
		local first = false
		change(player, function(d)
			local keep, drop = Pack.split(d.pack, dive.lampOut.keepFraction, blocks, dive.lampOut.minKeep)
			kept, dropped = Pack.count(keep), Pack.count(drop)
			table.clear(d.pack)
			for id, count in keep do
				d.pack[id] = count
			end
			d.stats.lampOuts += 1
			first = d.firsts.FirstLampOut == nil
			markFirst(d, "FirstLampOut", now)
			return nil
		end)
		-- M4: the dropped haul stays where the player fell for anyone to find.
		backToCamp(player, s, now)
		local fields: { string } = {
			ending,
			`Layer{Layout.layerOf(mine, math.max(1, row))}`,
			if first then "First" else "Repeat",
		}
		analytics:custom(player, "Dive:LampOut", dropped, fields)
		if ending == "LeftInDark" then
			return
		end
		options.rescue(player)
		sendDive(player, s)
		options.lampOut(player, kept, dropped, row)
	end

	local actions = {}

	function actions.session(_self: Actions, player: any): Session?
		return sessions[player]
	end

	-- Call once the player's data has loaded (the core's onPlayerReady).
	function actions.join(_self: Actions, player: any)
		local now = options.now()
		local capacity = oilCapacity(player)
		local s: Session = {
			phase = "Camp",
			meter = fullMeter(capacity, now),
			capacity = capacity,
			row = 0,
			climbEndsAt = 0,
			lastSwing = -math.huge,
			joinedAt = now,
			diveDeepest = 0,
			refilled = false,
			lastNotice = "",
			lastNoticeAt = -math.huge,
		}
		sessions[player] = s
		local step: number? = nil
		data:update(player, function(d)
			step = markFirst(d, "Joined", now)
		end)
		onboarding(player, step)
		sendDive(player, s)
	end

	-- Call several times a second for each player: lights the lamp on the
	-- mine, burns oil by depth, and ends dives (climbed out, walked out, or dry).
	function actions.step(_self: Actions, player: any)
		local s = sessions[player]
		if s == nil then
			return
		end
		local now = options.now()
		local pos = options.position(player)

		if s.phase == "Camp" then
			if pos and (Layout.inFootprint(mine, pos) or pos.y < CAMP_HEIGHT) then
				startDive(player, s, now, math.clamp(Layout.rowAt(mine, pos.y), 0, totalRows))
			end
			return
		end

		if s.phase == "Climbing" then
			-- Judge the climb at the moment it finished, not at this step's time.
			local at = math.min(now, s.climbEndsAt)
			-- Arriving with exactly enough oil is a safe climb.
			if s.meter.oil - s.meter.rate * (at - s.meter.at) < 0 then
				lampOut(player, s, now, "LampOut")
			elseif now >= s.climbEndsAt then
				endDive(player, s, now, "ClimbedOut")
			end
			return
		end

		-- Diving.
		local rateChanged = false
		if pos then
			local row = math.clamp(Layout.rowAt(mine, pos.y), 0, totalRows)
			s.row = row
			local rate = Lamp.rateAt(mine, row)
			if rate ~= s.meter.rate then
				s.meter = Lamp.settle(s.meter, now, rate)
				rateChanged = true
			end
		end
		if Lamp.oilAt(s.meter, now) <= 0 then
			lampOut(player, s, now, "LampOut")
			return
		end
		if pos and not Layout.inFootprint(mine, pos) and pos.y >= CAMP_HEIGHT then
			endDive(player, s, now, "WalkedOut")
			return
		end
		if rateChanged then
			sendDive(player, s)
		end
	end

	-- Call when the player leaves, before their data is released. Leaving
	-- mid-dive keeps the pack only if the oil left could have climbed out
	-- from where they were; otherwise it counts as a lamp-out, so quitting
	-- never beats the lamp.
	function actions.leave(_self: Actions, player: any)
		local s = sessions[player]
		if s == nil then
			return
		end
		local now = options.now()
		if s.phase ~= "Camp" then
			local oil = Lamp.oilAt(s.meter, now)
			local need = if s.phase == "Climbing"
				then math.max(0, s.climbEndsAt - now) * dive.climb.oilPerSecond
				else Lamp.climbOil(dive, s.row)
			if oil >= need then
				endDive(player, s, now, "LeftSafe")
			else
				lampOut(player, s, now, "LeftInDark")
			end
		end
		local played = math.max(0, math.floor(now - s.joinedAt))
		change(player, function(d)
			d.stats.playSeconds += played
			return nil
		end)
		sessions[player] = nil
	end

	function actions.hit(_self: Actions, player: any, x: number, y: number, z: number): (boolean, string?)
		local s = sessions[player]
		if s == nil then
			return false, "not joined"
		end
		if s.phase == "Climbing" then
			return false, "climbing"
		end
		local pos = options.position(player)
		if pos == nil then
			return false, "no character"
		end
		if not grid:inBounds(x, y, z) then
			return false, "outside the mine"
		end
		if not grid:isExposed(x, y, z) then
			return false, "block not exposed"
		end
		if Layout.distance(pos, Layout.blockCenter(mine, x, y, z)) > dive.reach then
			return false, "out of reach"
		end
		local now = options.now()
		if now - s.lastSwing < dive.swingSeconds * dive.swingTolerance then
			return false, "swing too fast"
		end
		local d = data:get(player)
		if d == nil then
			return false, "no data"
		end

		local layerIndex = Layout.layerOf(mine, y)
		local layer = mine.layers[layerIndex]
		local blockId = grid:blockAt(x, y, z)
		local block = blocks[blockId]
		if Gear.tier(d, "Pick") < layer.minPickTier then
			local needed = gear.pick[layer.minPickTier].name
			notify(player, s, `{layer.name} needs the {needed} or better. Upgrade at camp.`, now)
			return false, "pick too weak"
		end

		if s.phase == "Camp" then
			if Layout.inFootprint(mine, pos) or pos.y < CAMP_HEIGHT then
				startDive(player, s, now, math.clamp(Layout.rowAt(mine, pos.y), 0, totalRows))
			else
				notify(player, s, "Step onto the mine to light your lamp.", now)
				return false, "not on the mine"
			end
		end

		local capacity = Gear.packCapacity(d, gear, options.perks(player))
		if block.value > 0 and Pack.count(d.pack) >= capacity then
			notify(player, s, "Your pack is full. Climb out and sell!", now)
			return false, "pack full"
		end

		s.lastSwing = now
		local hp = grid:hp(x, y, z)
		local left = grid:hit(x, y, z, Gear.pickPower(d, gear))
		if left > 0 then
			options.damaged(grid:key(x, y, z), 1 - left / hp)
			return true, nil
		end

		-- The block breaks: the pack first, then the mine, so a failed save
		-- never hands out a block for nothing.
		local steps: { number } = {}
		local newLayer: number? = nil
		local ok, err = change(player, function(dd)
			if block.value > 0 then
				Pack.add(dd.pack, blockId, capacity)
			end
			dd.stats.blocksMined += 1
			table.insert(steps, markFirst(dd, "FirstBlockMined", now) or 0)
			if y > dd.deepestRow then
				dd.deepestRow = y
			end
			if layerIndex > dd.layersReached then
				dd.layersReached = layerIndex
				newLayer = layerIndex
				if layerIndex == 2 then
					markFirst(dd, "Layer2Reached", now)
				end
			end
			return nil
		end)
		if not ok then
			return false, err
		end
		options.mineChanged(grid:breakBlock(x, y, z, now))
		s.diveDeepest = math.max(s.diveDeepest, y)
		for _, step in steps do
			if step > 0 then
				onboarding(player, step)
			end
		end
		if newLayer then
			analytics:progression(player, "Layer", "Start", newLayer)
		end
		if block.value > 0 then
			options.ore(player, blockId)
		end
		return true, nil
	end

	function actions.climb(_self: Actions, player: any): (boolean, string?)
		local s = sessions[player]
		if s == nil or s.phase ~= "Diving" then
			return false, "not diving"
		end
		local now = options.now()
		local pos = options.position(player)
		if pos then
			s.row = math.clamp(Layout.rowAt(mine, pos.y), 0, totalRows)
		end
		s.meter = Lamp.settle(s.meter, now, dive.climb.oilPerSecond)
		if Lamp.oilAt(s.meter, now) <= 0 then
			lampOut(player, s, now, "LampOut")
			return false, "lamp out"
		end
		s.phase = "Climbing"
		s.climbEndsAt = now + Lamp.climbSeconds(dive, s.row)
		options.climbing(player, true)
		sendDive(player, s)
		return true, nil
	end

	function actions.sell(_self: Actions, player: any): (boolean, string?)
		local s = sessions[player]
		if s == nil then
			return false, "not joined"
		end
		local now = options.now()
		if s.phase ~= "Camp" then
			notify(player, s, "Climb out of the mine to sell.", now)
			return false, "not at camp"
		end
		local coins, pieces = 0, 0
		local step: number? = nil
		local ok, refusal = change(player, function(d, ledger)
			if Pack.count(d.pack) == 0 then
				return "Your pack is empty. Go mining!"
			end
			coins, pieces = sellInto(d, ledger, now)
			step = markFirst(d, "FirstSale", now)
			return nil
		end)
		if not ok then
			notify(player, s, refusal or "Could not sell.", now)
			return false, refusal
		end
		onboarding(player, step)
		options.sold(player, coins, pieces)
		return true, nil
	end

	function actions.upgrade(_self: Actions, player: any, kind: Gear.Kind): (boolean, string?)
		local s = sessions[player]
		if s == nil then
			return false, "not joined"
		end
		local now = options.now()
		if s.phase ~= "Camp" then
			notify(player, s, "Climb out of the mine to upgrade.", now)
			return false, "not at camp"
		end
		local step: number? = nil
		local tierName = ""
		local tier = 0
		local ok, refusal = change(player, function(d, ledger)
			local done, why = Gear.upgrade(d, ledger, gear, kind)
			if not done then
				return why
			end
			local current = Gear.current(d, gear, kind)
			tierName = current.name
			tier = Gear.tier(d, kind)
			step = markFirst(d, "FirstUpgrade", now)
			return nil
		end)
		if not ok then
			notify(player, s, refusal or "Could not upgrade.", now)
			return false, refusal
		end
		if kind == "Lamp" then
			s.capacity = oilCapacity(player)
			s.meter = fullMeter(s.capacity, now)
			sendDive(player, s)
		end
		onboarding(player, step)
		analytics:custom(player, "Gear:Upgrade", tier, { kind })
		notify(player, s, `Upgraded to the {tierName}!`, now)
		return true, nil
	end

	-- The character died (reset, or fell somewhere it should not): in the
	-- mine that is a lamp-out, so resetting never beats the lamp.
	function actions.died(_self: Actions, player: any)
		local s = sessions[player]
		if s and s.phase ~= "Camp" then
			lampOut(player, s, options.now(), "Fainted")
		end
	end

	function actions.refill(_self: Actions, player: any, bought: boolean?): (boolean, string?)
		local s = sessions[player]
		if s == nil then
			return false, "not joined"
		end
		local now = options.now()
		local d = data:get(player)
		if d == nil then
			return false, "no data"
		end
		local stock = d.oilRefills or 0
		local saved = `Oil refill saved for a later dive. You have {stock}.`
		if s.phase == "Camp" then
			notify(player, s, if bought then saved else "Oil refills pour during a dive.", now)
			return false, "not diving"
		end
		if s.refilled then
			notify(player, s, if bought then `{saved} One refill per dive.` else "One refill per dive.", now)
			return false, "one per dive"
		end
		local oil = Lamp.oilAt(s.meter, now)
		if oil <= 0 then
			-- Too late: the next step turns this into a lamp-out, and a bought
			-- refill stays in stock.
			return false, "lamp out"
		end
		if oil > s.capacity * REFILL_FULL_FRACTION then
			notify(
				player,
				s,
				if bought then saved else "Your lamp is nearly full. Keep the refill for later.",
				now
			)
			return false, "lamp nearly full"
		end
		local ok, refusal = change(player, function(dd)
			if (dd.oilRefills or 0) < 1 then
				return "You have no oil refills."
			end
			dd.oilRefills -= 1
			return nil
		end)
		if not ok then
			notify(player, s, refusal or "Could not refill.", now)
			return false, refusal
		end
		s.refilled = true
		s.meter = { oil = s.capacity, rate = s.meter.rate, at = now }
		sendDive(player, s)
		analytics:custom(player, "Dive:Refill", s.row, { if bought then "Bought" else "Stock" })
		notify(player, s, "Lamp refilled! That's your one refill this dive.", now)
		return true, nil
	end

	function actions.notice(_self: Actions, player: any, text: string)
		notify(player, sessions[player], text, options.now())
	end

	-- Grows back old mined-out blocks nobody is standing near.
	function actions.regrowMine(_self: Actions)
		local positions: { Point } = {}
		for player in sessions do
			local pos = options.position(player)
			if pos then
				table.insert(positions, pos)
			end
		end
		local clearance = mine.regrowClearance
		local changes = grid:regrow(options.now(), function(x: number, y: number, z: number): boolean
			local center = Layout.blockCenter(mine, x, y, z)
			for _, pos in positions do
				if Layout.distance(pos, center) <= clearance then
					return true
				end
				-- Never seal the way up above someone in the mine.
				local dx, dz = pos.x - center.x, pos.z - center.z
				if center.y > pos.y and math.sqrt(dx * dx + dz * dz) <= clearance then
					return true
				end
			end
			return false
		end)
		if #changes.shown > 0 or #changes.hidden > 0 then
			options.mineChanged(changes)
		end
	end

	return (actions :: any) :: Actions
end

return Actions
