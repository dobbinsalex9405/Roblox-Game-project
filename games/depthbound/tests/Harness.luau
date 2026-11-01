--!strict
-- A whole Depthbound server without Roblox: the real core services on a fake
-- session-locked store, a real mine grid, the real Actions, a hand-moved
-- clock, hand-placed characters and recorded effects.

local Analytics = require("@core/Analytics")
local DataService = require("@core/DataService")
local Economy = require("@core/Economy")
local Actions = require("../src/shared/Actions")
local DataTemplate = require("../src/shared/DataTemplate")
local Lamp = require("../src/shared/Lamp")
local Layout = require("../src/shared/Layout")
local MineGrid = require("../src/shared/MineGrid")
local Fakes = require("../../../packages/core/tests/Fakes")

local config = {
	mine = require("../config/mine"),
	blocks = require("../config/blocks"),
	gear = require("../config/gear"),
	dive = require("../config/dive"),
	economy = require("../config/economy"),
}

local Harness = {}
Harness.config = config

export type Options = {
	perks: Actions.Perks?,
	seed: number?,
	store: any?, -- reuse a store to simulate another server
	start: number?,
}

function Harness.new(options: Options?)
	local opts: Options = options or {}
	local mine = config.mine
	local h: any = {}
	h.clock = Fakes.clock(opts.start or 1_800_000_000)
	h.store = opts.store or Fakes.store()
	h.grid = MineGrid.new(mine, config.blocks, opts.seed or 12345)
	h.positions = {} :: { [any]: Layout.Point? }
	h.notices = {} :: { string }
	h.dives = {} :: { { phase: string, oil: number, rate: number, capacity: number, climbEndsAt: number } }
	h.ores = {} :: { string }
	h.lampOuts = {} :: { { kept: number, dropped: number, row: number } }
	h.sales = {} :: { { coins: number, pieces: number } }
	h.rescues = 0
	h.climbingNow = false
	h.changes = { shown = 0, hidden = 0 }
	h.events = {} :: { { kind: string, args: { any } } }
	h.perks = opts.perks or { biggerPack = false, betterLamp = false, autoSell = false }

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

	local camp = Layout.campSpawn(mine)

	h.actions = Actions.new({
		data = h.data,
		economy = h.economy,
		analytics = h.analytics,
		grid = h.grid,
		config = config,
		perks = function()
			return h.perks
		end,
		now = h.clock.now,
		position = function(player: any)
			return h.positions[player]
		end,
		notify = function(_player: any, text: string)
			table.insert(h.notices, text)
		end,
		dive = function(_player: any, phase, meter, capacity: number, climbEndsAt: number)
			table.insert(h.dives, {
				phase = phase,
				oil = meter.oil,
				rate = meter.rate,
				capacity = capacity,
				climbEndsAt = climbEndsAt,
			})
		end,
		ore = function(_player: any, blockId: string)
			table.insert(h.ores, blockId)
		end,
		lampOut = function(_player: any, kept: number, dropped: number, row: number)
			table.insert(h.lampOuts, { kept = kept, dropped = dropped, row = row })
		end,
		sold = function(_player: any, coins: number, pieces: number)
			table.insert(h.sales, { coins = coins, pieces = pieces })
		end,
		mineChanged = function(changes: MineGrid.Changes)
			h.changes.shown += #changes.shown
			h.changes.hidden += #changes.hidden
		end,
		damaged = function() end,
		climbing = function(_player: any, on: boolean)
			h.climbingNow = on
		end,
		rescue = function(player: any)
			h.rescues += 1
			h.positions[player] = { x = camp.x, y = 3, z = camp.z }
		end,
	})

	-- What CoreServer does on join, then the game's onPlayerReady.
	function h.join(player: any)
		local result = h.data:load(player, player.UserId)
		assert(result == "loaded", `load failed: {result}`)
		h.analytics:sessionStart(player, { firstJoinAt = 0, lastJoinAt = 0 }, h.clock.now())
		h.positions[player] = { x = camp.x, y = 3, z = camp.z }
		h.actions:join(player)
	end

	-- What CoreServer does on leave.
	function h.leave(player: any)
		h.actions:leave(player)
		h.analytics:sessionEnd(player, h.clock.now())
		h.data:release(player)
		h.positions[player] = nil
	end

	function h.get(player: any): { [string]: any }
		return h.data:get(player) :: any
	end

	function h.session(player: any): any
		return h.actions:session(player)
	end

	function h.oil(player: any): number
		return Lamp.oilAt(h.session(player).meter, h.clock.now())
	end

	-- Character placement. Standing on the mine's top face over column (x, z).
	function h.standOn(player: any, x: number, z: number)
		local c = Layout.blockCenter(mine, x, 1, z)
		h.positions[player] = { x = c.x, y = 3, z = c.z }
	end

	-- Standing inside the (mined-out) cell (x, y, z).
	function h.stand(player: any, x: number, y: number, z: number)
		local c = Layout.blockCenter(mine, x, y, z)
		h.positions[player] = { x = c.x, y = -y * mine.blockSize + 3, z = c.z }
	end

	function h.toCamp(player: any)
		h.positions[player] = { x = camp.x, y = 3, z = camp.z }
	end

	-- Moves the clock, stepping like the server does (every 0.2 s).
	function h.wait(player: any, seconds: number)
		local left = seconds
		while left > 1e-9 do
			local stepBy = math.min(left, 0.2)
			h.clock.advance(stepBy)
			left -= stepBy
			if h.session(player) then
				h.actions:step(player)
			end
		end
	end

	-- Swings at a block until it breaks (waiting a swing between hits).
	-- Returns true when it broke, or false and the refusal.
	function h.mine(player: any, x: number, y: number, z: number): (boolean, string?)
		for _ = 1, 200 do
			if not h.grid:isSolid(x, y, z) then
				return true, nil
			end
			local ok, err = h.actions:hit(player, x, y, z)
			if not ok then
				return false, err
			end
			h.wait(player, config.dive.swingSeconds)
		end
		error("block never broke")
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

	-- Finds a column whose top `rows` blocks include ore, for tests that need some.
	function h.columnWithOre(rows: number): (number, number)
		for z = 1, mine.length do
			for x = 1, mine.width do
				for y = 1, rows do
					if config.blocks[h.grid:blockAt(x, y, z)].value > 0 then
						return x, z
					end
				end
			end
		end
		error("no ore near the top")
	end

	return h
end

return Harness
