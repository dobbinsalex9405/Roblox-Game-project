--!strict
-- A whole Street Food Empire server without Roblox: the real core services on
-- a fake session-locked store, the real Actions, a hand-moved clock and
-- recorded effects. Used by the session tests.

local Analytics = require("@core/Analytics")
local DataService = require("@core/DataService")
local Economy = require("@core/Economy")
local Actions = require("../src/shared/Actions")
local DataTemplate = require("../src/shared/DataTemplate")
local Fakes = require("../../../packages/core/tests/Fakes")

local config = {
	economy = require("../config/economy"),
	districts = require("../config/districts"),
	stations = require("../config/stations"),
	cooks = require("../config/cooks"),
	monetization = require("../config/monetization"),
}

local Harness = {}
Harness.config = config

export type Options = {
	perks: Actions.Perks?,
	store: any?, -- reuse a store to simulate another server
	start: number?,
}

function Harness.new(options: Options?)
	local opts: Options = options or {}
	local h: any = {}
	h.config = config
	h.clock = Fakes.clock(opts.start or 1_800_000_000)
	h.store = opts.store or Fakes.store()
	h.notices = {} :: { string }
	h.served = {} :: { number }
	h.welcomes = {} :: { { cash: number, waiting: number } }
	h.events = {} :: { { kind: string, args: { any } } }
	h.perks = opts.perks or { doubleCash = false, autoCollect = false }

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
		currencies = { cash = { field = "cash", max = config.economy.cashMax } },
		onChange = function(change)
			h.analytics:economy(change)
		end,
	})

	h.actions = Actions.new({
		data = h.data,
		economy = h.economy,
		analytics = h.analytics,
		config = config,
		perks = function()
			return h.perks
		end,
		now = h.clock.now,
		notify = function(_player: any, text: string)
			table.insert(h.notices, text)
		end,
		served = function(_player: any, cash: number)
			table.insert(h.served, cash)
		end,
		welcome = function(_player: any, cash: number, waiting: number)
			table.insert(h.welcomes, { cash = cash, waiting = waiting })
		end,
	})

	-- What CoreServer does on join, then the game's onPlayerReady.
	function h.join(player: any)
		local result = h.data:load(player, player.UserId)
		assert(result == "loaded", `load failed: {result}`)
		h.analytics:sessionStart(player, { firstJoinAt = 0, lastJoinAt = 0 }, h.clock.now())
		h.actions:join(player)
	end

	-- What CoreServer does on leave.
	function h.leave(player: any)
		h.actions:leave(player)
		h.analytics:sessionEnd(player, h.clock.now())
		h.data:release(player)
	end

	function h.get(player: any): { [string]: any }
		return h.data:get(player) :: any
	end

	-- Gives the player cash, as a test grant.
	function h.give(player: any, cash: number)
		assert(h.economy:add(player, "cash", cash, "Admin:Test"))
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
