--!strict
-- A whole Hatchery Heist server without Roblox: the real core services on a
-- fake session-locked store, the real Actions, a hand-moved clock and
-- recorded effects. Used by the session tests.

local Analytics = require("@core/Analytics")
local DataService = require("@core/DataService")
local Economy = require("@core/Economy")
local Odds = require("@core/Odds")
local Policy = require("@core/Policy")
local Actions = require("../src/shared/Actions")
local Conveyor = require("../src/shared/Conveyor")
local DataTemplate = require("../src/shared/DataTemplate")
local Eggs = require("../src/shared/Eggs")
local Raids = require("../src/shared/Raids")
local Fakes = require("../../../packages/core/tests/Fakes")

local config = {
	economy = require("../config/economy"),
	creatures = require("../config/creatures"),
	eggs = require("../config/eggs"),
	raids = require("../config/raids"),
}

local Harness = {}
Harness.config = config

export type Options = {
	restricted: boolean?, -- PolicyService says paid random items are restricted
	perks: Actions.Perks?,
	seed: number?, -- fixes the dice
	store: any?, -- reuse a store to simulate another server
	start: number?,
}

function Harness.new(options: Options?)
	local opts: Options = options or {}
	local h: any = {}
	h.clock = Fakes.clock(opts.start or 1_800_000_000)
	h.store = opts.store or Fakes.store()
	h.notices = {} :: { string }
	h.noticesFor = {} :: { { player: any, text: string } }
	h.stuns = {} :: { { player: any, seconds: number } }
	h.slows = {} :: { { player: any, factor: number } }
	h.hatched = {} :: { string }
	h.welcomes = {} :: { { coins: number, ready: number } }
	h.mounts = {} :: { number | false }
	h.events = {} :: { { kind: string, args: { any } } }
	h.perks = opts.perks or { doubleCoins = false, extraIncubators = false, autoCollect = false }

	local function record(kind: string)
		return function(_player: any, ...: any)
			table.insert(h.events, { kind = kind, args = { ... } })
		end
	end
	h.analytics = Analytics.new({
		economy = record("economy"),
		onboarding = record("onboarding"),
		funnel = record("funnel"),
		progression = record("progression"),
		custom = record("custom"),
	})

	h.data = DataService.new({
		store = h.store,
		template = DataTemplate.template,
		migrations = DataTemplate.migrations,
	})
	h.economy = Economy.new({
		data = h.data,
		currencies = { coins = { field = "coins", max = config.economy.coinsMax } },
		onChange = function(change)
			h.analytics:economy(change)
		end,
	})
	-- Park-Miller dice: deterministic, and exact in a double.
	local state = opts.seed or 7
	h.odds = Odds.new({
		randomInteger = function(min: number, max: number)
			state = (state * 48271) % 2147483647
			return min + state % (max - min + 1)
		end,
	})
	for _, def in Eggs.oddsTables(config.eggs, true) do
		h.odds:define(def)
	end
	h.policy = Policy.new({
		fetch = function()
			return { ArePaidRandomItemsRestricted = opts.restricted == true, IsPaidItemTradingAllowed = false }
		end,
	})

	h.actions = Actions.new({
		data = h.data,
		economy = h.economy,
		odds = h.odds,
		policy = h.policy,
		analytics = h.analytics,
		config = config,
		sellsCurrency = true,
		perks = function()
			return h.perks
		end,
		now = h.clock.now,
		serverTime = h.clock.now,
		plotOf = function()
			return 1
		end,
		notify = function(player: any, text: string)
			table.insert(h.notices, text)
			table.insert(h.noticesFor, { player = player, text = text })
		end,
		hatched = function(_player: any, speciesId: string)
			table.insert(h.hatched, speciesId)
		end,
		welcome = function(_player: any, coins: number, ready: number)
			table.insert(h.welcomes, { coins = coins, ready = ready })
		end,
		mount = function(_player: any, speed: number?)
			table.insert(h.mounts, speed or false)
		end,
	})

	h.raids = Raids.new({
		actions = h.actions,
		data = h.data,
		analytics = h.analytics,
		config = config,
		now = h.clock.now,
		notify = function(player: any, text: string)
			table.insert(h.notices, text)
			table.insert(h.noticesFor, { player = player, text = text })
		end,
		name = function(player: any)
			return player.Name
		end,
		userId = function(player: any)
			return player.UserId
		end,
		stun = function(player: any, seconds: number)
			table.insert(h.stuns, { player = player, seconds = seconds })
		end,
		slow = function(player: any, factor: number, _seconds: number)
			table.insert(h.slows, { player = player, factor = factor })
		end,
		changed = function() end,
	})

	-- The last notice a player got.
	function h.lastNotice(player: any): string?
		for i = #h.noticesFor, 1, -1 do
			if h.noticesFor[i].player == player then
				return h.noticesFor[i].text
			end
		end
		return nil
	end

	-- What CoreServer does on join, then the game's onPlayerReady.
	function h.join(player: any)
		local result = h.data:load(player, player.UserId)
		assert(result == "loaded", `load failed: {result}`)
		h.policy:load(player)
		h.analytics:sessionStart(player, { firstJoinAt = 0, lastJoinAt = 0 }, h.clock.now())
		h.actions:join(player)
	end

	-- What CoreServer does on leave (the game's onPlayerLeaving first).
	function h.leave(player: any)
		h.raids:leave(player)
		h.actions:leave(player)
		h.analytics:sessionEnd(player, h.clock.now())
		h.odds:forget(player)
		h.policy:release(player)
		h.data:release(player)
	end

	function h.get(player: any): { [string]: any }
		return h.data:get(player) :: any
	end

	-- The index of an egg of kind `eggId` on the belt right now that this
	-- harness has not bought yet, if any.
	h.taken = {} :: { [number]: boolean }
	function h.findOnBelt(eggId: string): number?
		for _, egg in Conveyor.onBelt(h.clock.now(), 1, config.economy.conveyor) do
			if egg.eggId == eggId and egg.progress < 0.9 and not h.taken[egg.index] then
				return egg.index
			end
		end
		return nil
	end

	-- Waits (moving the clock, ticking like the server) until an egg of that
	-- kind is on the belt, then buys it.
	function h.buy(player: any, eggId: string): (boolean, string?)
		for _ = 1, 200 do
			local index = h.findOnBelt(eggId)
			if index then
				local ok, err = h.actions:buyEgg(player, index)
				if ok then
					h.taken[index] = true
				end
				return ok, err
			end
			h.wait(player, 1)
		end
		error(`no {eggId} came along the belt`)
	end

	-- Moves the clock, ticking every 10 seconds like the server does.
	function h.wait(player: any, seconds: number)
		local left = seconds
		while left > 0 do
			local step = math.min(left, 10)
			h.clock.advance(step)
			left -= step
			if h.data:isLoaded(player) then
				h.actions:tick(player)
			end
		end
	end

	function h.eventsOf(kind: string): { { any } }
		local out = {}
		for _, e in h.events do
			if e.kind == kind then
				table.insert(out, e.args)
			end
		end
		return out
	end

	return h
end

return Harness
