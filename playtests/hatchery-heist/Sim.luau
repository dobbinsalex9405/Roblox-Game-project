--!nocheck
-- Playtest harness: a whole Hatchery Heist server without Roblox, with
-- per-player plots (8 bases), a hand-moved clock and recorded effects.
-- Built on the same core services and Actions the real server uses.

local Analytics = require("@core/Analytics")
local DataService = require("@core/DataService")
local Economy = require("@core/Economy")
local Odds = require("@core/Odds")
local Policy = require("@core/Policy")
local Actions = require("../../games/hatchery-heist/src/shared/Actions")
local Conveyor = require("../../games/hatchery-heist/src/shared/Conveyor")
local DataTemplate = require("../../games/hatchery-heist/src/shared/DataTemplate")
local Eggs = require("../../games/hatchery-heist/src/shared/Eggs")
local Fakes = require("../../packages/core/tests/Fakes")

local config = {
	economy = require("../../games/hatchery-heist/config/economy"),
	creatures = require("../../games/hatchery-heist/config/creatures"),
	eggs = Eggs.expand(
		require("../../games/hatchery-heist/config/eggs"),
		require("../../games/hatchery-heist/config/creatures").species
	),
	monetization = require("../../games/hatchery-heist/config/monetization"),
	raids = require("../../games/hatchery-heist/config/raids"),
}

local Sim = {}
Sim.config = config

function Sim.new(options)
	local opts = options or {}
	local h = {}
	h.clock = Fakes.clock(opts.start or 1_800_000_000)
	h.store = opts.store or Fakes.store()
	h.notices = {} -- { {player=, text=} }
	h.hatched = {}
	h.welcomes = {}
	h.mounts = {} -- { {player=, speed=} }
	h.events = {}
	h.perksOf = {} -- [player] = perks
	h.defaultPerks = opts.perks or { doubleCoins = false, extraIncubators = false, autoCollect = false }
	h.restricted = {} -- [player] = true
	h.plots = {} -- [player] = plot index
	h.nextPlot = 1

	local function record(kind)
		return function(player, ...)
			table.insert(h.events, { kind = kind, player = player, args = { ... } })
		end
	end
	h.analytics = Analytics.new({
		economy = function(player, flow, currency, amount, balance, transactionType, sku)
			table.insert(h.events, {
				kind = "economy",
				player = player,
				args = {
					{
						flow = flow,
						currency = currency,
						amount = amount,
						balance = balance,
						transactionType = transactionType,
						sku = sku,
					},
				},
			})
		end,
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
	local state = opts.seed or 7
	h.odds = Odds.new({
		randomInteger = function(min, max)
			state = (state * 48271) % 2147483647
			return min + state % (max - min + 1)
		end,
	})
	for _, def in Eggs.oddsTables(config.eggs, true) do
		h.odds:define(def)
	end
	h.policy = Policy.new({
		fetch = function(player)
			return {
				ArePaidRandomItemsRestricted = h.restricted[player] == true,
				IsPaidItemTradingAllowed = false,
			}
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
		perks = function(player)
			return h.perksOf[player] or h.defaultPerks
		end,
		now = h.clock.now,
		serverTime = h.clock.now,
		plotOf = function(player)
			return h.plots[player]
		end,
		notify = function(player, text)
			table.insert(h.notices, { player = player, text = text, at = h.clock.now() })
		end,
		hatched = function(player, speciesId)
			table.insert(h.hatched, { player = player, speciesId = speciesId, at = h.clock.now() })
		end,
		welcome = function(player, coins, ready)
			table.insert(h.welcomes, { player = player, coins = coins, ready = ready })
		end,
		mount = function(player, speed)
			table.insert(h.mounts, { player = player, speed = speed or false })
		end,
	})

	-- CoreServer join + the game's onPlayerReady (World.claim gives the first free plot).
	function h.join(player, restricted)
		h.restricted[player] = restricted == true
		local result, why = h.data:load(player, player.UserId)
		assert(result == "loaded", `load failed: {result} {why}`)
		h.data:update(player, function(d)
			d.meta = d.meta or {}
			if (d.meta.firstJoinAt or 0) <= 0 then
				d.meta.firstJoinAt = h.clock.now()
			end
			d.meta.lastJoinAt = h.clock.now()
			d.meta.sessions = (d.meta.sessions or 0) + 1
		end)
		h.policy:load(player)
		h.analytics:sessionStart(player, { firstJoinAt = 0, lastJoinAt = 0 }, h.clock.now())
		-- World.claim: first free plot of 8
		local taken = {}
		for _, p in h.plots do
			taken[p] = true
		end
		local plot = nil
		for i = 1, 8 do
			if not taken[i] then
				plot = i
				break
			end
		end
		if plot == nil then
			-- server full: the game kicks, CoreServer releases the data
			h.analytics:sessionEnd(player, h.clock.now())
			h.policy:release(player)
			h.data:release(player)
			return nil
		end
		h.plots[player] = plot
		h.actions:join(player)
		return plot
	end

	function h.leave(player)
		h.actions:leave(player)
		h.analytics:sessionEnd(player, h.clock.now())
		h.odds:forget(player)
		h.policy:release(player)
		h.data:release(player)
		h.plots[player] = nil
	end

	function h.get(player)
		return h.data:get(player)
	end

	h.taken = {} -- [player] = { [index] = true }
	function h.findOnBelt(player, eggId, maxProgress)
		local plot = h.plots[player]
		local taken = h.taken[player] or {}
		h.taken[player] = taken
		for _, egg in Conveyor.onBelt(h.clock.now(), plot, config.economy.conveyor) do
			if egg.eggId == eggId and egg.progress < (maxProgress or 0.9) and not taken[egg.index] then
				return egg.index
			end
		end
		return nil
	end

	function h.buyNow(player, eggId)
		local index = h.findOnBelt(player, eggId)
		if index == nil then
			return false, "no such egg on the belt right now"
		end
		local ok, err = h.actions:buyEgg(player, index)
		if ok then
			h.taken[player][index] = true
		end
		return ok, err
	end

	-- Waits until an egg of that kind is on the belt, then buys it.
	function h.buy(player, eggId)
		for _ = 1, 200 do
			local index = h.findOnBelt(player, eggId)
			if index then
				local ok, err = h.actions:buyEgg(player, index)
				if ok then
					h.taken[player][index] = true
				end
				return ok, err
			end
			h.wait(1, { player })
		end
		error(`no {eggId} came along the belt`)
	end

	-- Moves the clock; the server ticks every 10 seconds for every loaded player.
	h.sinceTick = 0
	function h.wait(seconds)
		local left = seconds
		while left > 0 do
			local step = math.min(left, 1)
			h.clock.advance(step)
			left -= step
			h.sinceTick += step
			if h.sinceTick >= 10 then
				h.sinceTick = 0
				for player in h.plots do
					if h.data:isLoaded(player) then
						h.actions:tick(player)
					end
				end
			end
		end
	end

	function h.eventsOf(kind, player)
		local out = {}
		for _, e in h.events do
			if e.kind == kind and (player == nil or e.player == player) then
				table.insert(out, e.args)
			end
		end
		return out
	end

	function h.noticesOf(player)
		local out = {}
		for _, n in h.notices do
			if n.player == player then
				table.insert(out, n.text)
			end
		end
		return out
	end

	return h
end

return Sim
