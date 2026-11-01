--!strict
-- A whole Tidecatch Cove server without Roblox: the real core services on a
-- fake session-locked store, the real Actions, a hand-moved clock with a
-- task.delay stand-in, and recorded effects. Used by the session tests.

local Analytics = require("@core/Analytics")
local DataService = require("@core/DataService")
local Economy = require("@core/Economy")
local Odds = require("@core/Odds")
local Policy = require("@core/Policy")
local Actions = require("../src/shared/Actions")
local Catch = require("../src/shared/Catch")
local DataTemplate = require("../src/shared/DataTemplate")
local Fakes = require("../../../packages/core/tests/Fakes")

local config = {
	fishing = require("../config/fishing"),
	species = require("../config/species"),
	pools = require("../config/pools"),
	economy = require("../config/economy"),
	monetization = require("../config/monetization"),
}

local Harness = {}
Harness.config = config
Harness.TICK = 10 -- the server's tick, in seconds

export type Options = {
	restricted: boolean?, -- PolicyService says paid random items are restricted
	perks: Actions.Perks?,
	seed: number?, -- fixes the dice
	store: any?, -- reuse a store to simulate another server
	start: number?,
	sellsCurrency: boolean?,
	fishing: any?, -- replaces config.fishing (to test a Robux bait, say)
}

function Harness.new(options: Options?)
	local opts: Options = options or {}
	local h: any = {}
	h.time = opts.start or 1_800_000_000
	h.store = opts.store or Fakes.store()
	h.notices = {} :: { string }
	h.casts = {} :: { { id: number, spot: string } }
	h.bites = {} :: { { id: number, rarity: string, at: number } }
	h.caught = {} :: { Actions.Caught }
	h.escaped = {} :: { { id: number, text: string } }
	h.welcomes = {} :: { { grew: number, restocked: boolean } }
	h.events = {} :: { { kind: string, args: { any } } }
	h.perks = opts.perks or { autoReel = false, extraPools = false, sellMultiplier = false }
	h.reachable = true
	h.lowTide = false
	local cfg = table.clone(config)
	if opts.fishing then
		cfg.fishing = opts.fishing
	end
	h.config = cfg

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
	local function nextInt(): number
		state = (state * 48271) % 2147483647
		return state
	end
	h.odds = Odds.new({
		randomInteger = function(min: number, max: number)
			return min + nextInt() % (max - min + 1)
		end,
	})
	for _, def in
		Catch.oddsTables(cfg.fishing, config.species.species, Odds.normalize, opts.sellsCurrency == true)
	do
		h.odds:define(def)
	end
	h.policy = Policy.new({
		fetch = function()
			return { ArePaidRandomItemsRestricted = opts.restricted == true, IsPaidItemTradingAllowed = false }
		end,
	})
	function h.random(): number
		return (nextInt() - 1) / 2147483646
	end

	-- task.delay stand-in: runs when the clock passes `at`.
	h.queue = {} :: { { at: number, fn: () -> () } }

	h.actions = Actions.new({
		data = h.data,
		economy = h.economy,
		odds = h.odds,
		policy = h.policy,
		analytics = h.analytics,
		config = cfg,
		sellsCurrency = opts.sellsCurrency == true,
		perks = function()
			return h.perks
		end,
		now = function()
			return math.floor(h.time)
		end,
		clock = function()
			return h.time
		end,
		random = h.random,
		schedule = function(seconds: number, fn: () -> ())
			table.insert(h.queue, { at = h.time + seconds, fn = fn })
		end,
		canReach = function()
			return h.reachable
		end,
		spotOpen = function()
			return h.lowTide
		end,
		notify = function(_player: any, text: string)
			table.insert(h.notices, text)
		end,
		castStarted = function(_player: any, castId: number, spotId: string)
			table.insert(h.casts, { id = castId, spot = spotId })
		end,
		bite = function(_player: any, castId: number, rarity: string)
			table.insert(h.bites, { id = castId, rarity = rarity, at = h.time })
		end,
		caught = function(_player: any, caught: Actions.Caught)
			table.insert(h.caught, caught)
		end,
		escaped = function(_player: any, castId: number, text: string)
			table.insert(h.escaped, { id = castId, text = text })
		end,
		welcome = function(_player: any, grew: number, restocked: boolean)
			table.insert(h.welcomes, { grew = grew, restocked = restocked })
		end,
	})

	-- What CoreServer does on join, then the game's onPlayerReady.
	function h.join(player: any)
		local result = h.data:load(player, player.UserId)
		assert(result == "loaded", `load failed: {result}`)
		h.policy:load(player)
		h.analytics:sessionStart(player, { firstJoinAt = 0, lastJoinAt = 0 }, h.time)
		h.actions:join(player)
		h.player = player
		h.nextTick = h.time + Harness.TICK
	end

	-- What CoreServer does on leave.
	function h.leave(player: any)
		h.actions:leave(player)
		h.analytics:sessionEnd(player, h.time)
		h.odds:forget(player)
		h.policy:release(player)
		h.data:release(player)
		h.player = nil
	end

	function h.get(player: any): { [string]: any }
		return h.data:get(player) :: any
	end

	-- Moves the clock, running scheduled tasks in order and ticking every 10
	-- seconds like the server.
	function h.wait(seconds: number)
		local target = h.time + seconds
		while true do
			local nextAt = target
			local nextIndex: number? = nil
			for index, item in h.queue do
				if item.at <= nextAt then
					nextAt = item.at
					nextIndex = index
				end
			end
			local tickAt = h.nextTick or math.huge
			if tickAt <= nextAt then
				h.time = tickAt
				h.nextTick = tickAt + Harness.TICK
				if h.player and h.data:isLoaded(h.player) then
					h.actions:tick(h.player)
				end
			elseif nextIndex then
				local item = table.remove(h.queue, nextIndex)
				h.time = math.max(h.time, item.at)
				item.fn()
			else
				h.time = target
				return
			end
		end
	end

	-- Casts and waits for the bite. Returns the bite, or nil if the cast was refused.
	function h.castAndWait(
		player: any,
		spotId: string,
		baitId: string
	): { id: number, rarity: string, at: number }?
		local before = #h.bites
		if not h.actions:cast(player, spotId, baitId) then
			return nil
		end
		for _ = 1, 200 do
			if #h.bites > before then
				return h.bites[#h.bites]
			end
			h.wait(0.25)
		end
		error("no bite came")
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

	function h.customEvents(name: string): { { any } }
		local out = {}
		for _, args in h.eventsOf("custom") do
			if args[1] == name then
				table.insert(out, args)
			end
		end
		return out
	end

	return h
end

return Harness
