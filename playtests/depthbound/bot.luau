--!strict
-- A Depthbound player bot driven in lockstep with other bots on one server.
-- It does what a real player can do: falls down its own shaft, takes the ore
-- it can see within reach, digs down while the pick allows, tunnels sideways
-- at the deepest layer it can mine, climbs out with a margin or a full pack,
-- sells, buys upgrades, and walks between camp stations (charged as time).
--
-- Run through Scheduler.run(h, bots, seconds), which advances the clock in
-- 0.1 s ticks and steps every player every 0.2 s like the server does.

local Harness = require("../../games/depthbound/tests/Harness")
local Log = require("../../packages/core/src/Log")
Log.setSink(function() end)
local Gear = require("../../games/depthbound/src/shared/Gear")
local Lamp = require("../../games/depthbound/src/shared/Lamp")
local Layout = require("../../games/depthbound/src/shared/Layout")
local Pack = require("../../games/depthbound/src/shared/Pack")

local config = Harness.config
local mine, blocks, gear, dive = config.mine, config.blocks, config.gear, config.dive

export type Strategy = {
	name: string,
	margin: number, -- climb when oil <= climbOil * margin + reserve
	reserve: number,
	reuseShaft: boolean, -- fall down the old shaft instead of digging a new column
	tunnel: boolean, -- tunnel sideways at the deepest allowed row instead of climbing early
	maxRow: number?, -- never dig below this row (shallow hopper)
	hopOut: boolean?, -- at rows 0-1 jump out to camp instead of climbing (free lamp refill)
	upgradeOrder: { string }, -- which gear kind to prefer when several are affordable
}

export type Bot = {
	player: any,
	strategy: Strategy,
	column: { x: number, z: number },
	freeAt: number,
	x: number,
	z: number,
	row: number,
	dir: { number },
	log: { string },
	milestones: { [string]: number },
	timeline: { { [string]: any } },
	idle: { camp: number, climb: number, walk: number },
	orePieces: number,
	oreValue: number,
	lastPhase: string,
	climbStarted: number,
	startedAt: number,
	sealed: number,
	walkedOpen: number?,
	refusals: { [string]: number },
	exhausted: number?,
	climbs: { oil: number, full: number, done: number, hop: number },
}

local Bot = {}

local CAMP_ACTION_SECONDS = 2 -- walking to a station and using its prompt
local WALK_TO_MINE_SECONDS = 3
local MOVE_SECONDS = 0.3 -- walking or dropping one block
local STEP_SECONDS = 0.2
local REGROW_CHECK_SECONDS = 15 -- the server's regrow loop
local TICK = 0.1

Bot.STRATEGIES = {
	greedy = {
		name = "greedy",
		margin = 1.1,
		reserve = 2,
		reuseShaft = true,
		tunnel = true,
		upgradeOrder = { "Pick", "Lamp", "Pack" },
	} :: Strategy,
	cautious = {
		name = "cautious",
		margin = 1.6,
		reserve = 6,
		reuseShaft = true,
		tunnel = true,
		upgradeOrder = { "Lamp", "Pack", "Pick" },
	} :: Strategy,
	fresh = {
		name = "fresh",
		margin = 1.2,
		reserve = 4,
		reuseShaft = false,
		tunnel = false,
		upgradeOrder = { "Pick", "Lamp", "Pack" },
	} :: Strategy,
	hopper = {
		name = "hopper",
		margin = 1.2,
		reserve = 4,
		reuseShaft = false,
		tunnel = true,
		maxRow = 1,
		hopOut = true,
		upgradeOrder = { "Pack", "Pick", "Lamp" },
	} :: Strategy,
}

function Bot.new(h: any, player: any, strategy: Strategy, column: { x: number, z: number }): Bot
	local b: Bot = {
		player = player,
		strategy = strategy,
		column = column,
		freeAt = h.clock.now(),
		x = column.x,
		z = column.z,
		row = 0,
		dir = { 1, 0 },
		log = {},
		milestones = {},
		timeline = {},
		idle = { camp = 0, climb = 0, walk = 0 },
		orePieces = 0,
		oreValue = 0,
		lastPhase = "Camp",
		climbStarted = 0,
		startedAt = h.clock.now(),
		sealed = 0,
		refusals = {},
		climbs = { oil = 0, full = 0, done = 0, hop = 0 },
	}
	return b
end

local function mark(b: Bot, h: any, name: string)
	if b.milestones[name] == nil then
		b.milestones[name] = h.clock.now() - b.startedAt
		table.insert(b.log, string.format("%6.1fs  %s", h.clock.now() - b.startedAt, name))
	end
end

local function rootAt(x: number, row: number, z: number): Layout.Point
	local c = Layout.blockCenter(mine, x, math.max(row, 1), z)
	return { x = c.x, y = if row == 0 then 3 else -row * mine.blockSize + 3, z = c.z }
end

local function place(h: any, b: Bot, x: number, row: number, z: number)
	b.x, b.z, b.row = x, z, row
	h.positions[b.player] = rootAt(x, row, z)
end

-- Deepest row a player can fall to down column (x, z): the open run from row 1.
local function openDepth(h: any, x: number, z: number): number
	local depth = 0
	for y = 1, h.grid.rows do
		if h.grid:isSolid(x, y, z) then
			break
		end
		depth = y
	end
	return depth
end

local function pickTier(d: any): number
	return Gear.tier(d, "Pick")
end

local function canMineRow(d: any, row: number): boolean
	if row < 1 or row > Layout.totalRows(mine) then
		return false
	end
	return pickTier(d) >= mine.layers[Layout.layerOf(mine, row)].minPickTier
end

-- Exposed blocks the player can hit from where it stands, with their worth.
local function reachable(h: any, b: Bot, d: any): { { x: number, y: number, z: number, value: number } }
	local out = {}
	local root = h.positions[b.player]
	for dx = -2, 2 do
		for dz = -2, 2 do
			for dy = -2, 2 do
				local x, y, z = b.x + dx, b.row + dy, b.z + dz
				if y >= 1 and h.grid:isExposed(x, y, z) and canMineRow(d, y) then
					if Layout.distance(root, Layout.blockCenter(mine, x, y, z)) <= dive.reach then
						table.insert(out, { x = x, y = y, z = z, value = blocks[h.grid:blockAt(x, y, z)].value })
					end
				end
			end
		end
	end
	return out
end

local function swing(h: any, b: Bot, x: number, y: number, z: number): (boolean, string?)
	local ok, err = h.actions:hit(b.player, x, y, z)
	b.freeAt = h.clock.now() + dive.swingSeconds
	if not ok then
		b.refusals[err or "?"] = (b.refusals[err or "?"] or 0) + 1
	end
	return ok, err
end

local function buyUpgrades(h: any, b: Bot): number
	local bought = 0
	while true do
		local d = h.get(b.player)
		local choice: string? = nil
		-- The strategy's order first, but a pick that unlocks the next layer wins.
		for _, kind in b.strategy.upgradeOrder do
			local nextTier = Gear.nextTier(d, gear, kind)
			if nextTier and d.coins >= nextTier.cost then
				choice = kind
				break
			end
		end
		if choice == nil then
			break
		end
		local ok = h.actions:upgrade(b.player, choice)
		if not ok then
			break
		end
		bought += 1
		b.freeAt += CAMP_ACTION_SECONDS
		b.idle.camp += CAMP_ACTION_SECONDS
		local tier = Gear.tier(h.get(b.player), choice)
		mark(b, h, `Upgrade:{choice}{tier}`)
		mark(b, h, "FirstUpgrade")
		local dd = h.get(b.player)
		if dd.gear.pick == #gear.pick and dd.gear.pack == #gear.pack and dd.gear.lamp == #gear.lamp then
			mark(b, h, "AllGearMaxed")
		end
	end
	return bought
end

-- One decision. Sets b.freeAt to when the bot can act again.
local function act(h: any, b: Bot)
	local s = h.session(b.player)
	local d = h.get(b.player)
	local now = h.clock.now()
	local strategy = b.strategy

	if s.phase == "Camp" then
		if b.lastPhase ~= "Camp" then
			b.lastPhase = "Camp"
		end
		h.toCamp(b.player)
		h.actions:step(b.player)
		b.freeAt = now
		if Pack.count(d.pack) > 0 then
			h.actions:sell(b.player)
			b.freeAt += CAMP_ACTION_SECONDS
			b.idle.camp += CAMP_ACTION_SECONDS
			mark(b, h, "FirstSale")
		end
		buyUpgrades(h, b)
		-- Back to the mine.
		b.freeAt += WALK_TO_MINE_SECONDS
		b.idle.camp += WALK_TO_MINE_SECONDS
		local x, z = b.column.x, b.column.z
		local depth = 0
		if strategy.reuseShaft then
			depth = openDepth(h, x, z)
		else
			-- A fresh column each dive, like the M2 test bot.
			b.column.x = b.column.x % mine.width + 1
			b.column.z = (b.column.z + 3) % mine.length + 1
			x, z = b.column.x, b.column.z
		end
		b.dir = { 1, 0 }
		place(h, b, x, depth, z)
		-- The server's next step lights the lamp; the first swing may come right after.
		return
	end

	if s.phase == "Climbing" then
		b.freeAt = s.climbEndsAt + STEP_SECONDS
		return
	end

	-- Diving.
	b.lastPhase = "Diving"
	local capacity = Gear.packCapacity(d, gear, h.perks)
	local full = Pack.count(d.pack) >= capacity
	local need = Lamp.climbOil(dive, b.row) * strategy.margin + strategy.reserve
	local oil = h.oil(b.player)
	local lowOil = oil <= need

	if lowOil or full then
		if full then
			b.climbs.full += 1
		else
			b.climbs.oil += 1
		end
		if strategy.hopOut and b.row <= 1 then
			b.climbs.hop += 1
			-- Jump out onto the camp ground: a walk-out, the lamp refills at once.
			b.idle.walk += MOVE_SECONDS
			h.toCamp(b.player)
			b.freeAt = now + MOVE_SECONDS
			return
		end
		local ok = h.actions:climb(b.player)
		if ok then
			b.climbStarted = now
			local sess = h.session(b.player)
			b.idle.climb += sess.climbEndsAt - now
			b.freeAt = sess.climbEndsAt + STEP_SECONDS
		else
			b.freeAt = now + STEP_SECONDS
		end
		return
	end

	-- Ore in reach first (the player can see it: exposed blocks are drawn in their colour).
	local best = nil
	for _, c in reachable(h, b, d) do
		if c.value > 0 and (best == nil or c.value > best.value) then
			best = c
		end
	end
	if best then
		swing(h, b, best.x, best.y, best.z)
		return
	end

	-- Then down, while the pick allows and the strategy wants to.
	local below = b.row + 1
	local maxRow = strategy.maxRow or Layout.totalRows(mine)
	if below <= maxRow and canMineRow(d, below) then
		if h.grid:isSolid(b.x, below, b.z) then
			local ok = swing(h, b, b.x, below, b.z)
			if not ok then
				b.freeAt = now + STEP_SECONDS
			end
			return
		end
		-- Already open: drop down.
		place(h, b, b.x, below, b.z)
		b.idle.walk += MOVE_SECONDS
		b.freeAt = now + MOVE_SECONDS
		return
	end

	-- At the deepest row this pick (or the strategy) allows: tunnel sideways.
	-- Prefer a direction with solid rock ahead (new ground); keep the heading
	-- when possible; otherwise walk through open cells towards new ground.
	if strategy.tunnel and b.row >= 1 then
		local dirs = { b.dir, { 0, 1 }, { -1, 0 }, { 0, -1 }, { 1, 0 } }
		local solidDir: { number }? = nil
		local openDir: { number }? = nil
		for _, t in dirs do
			local nx, nz = b.x + t[1], b.z + t[2]
			if h.grid:inBounds(nx, b.row, nz) then
				if h.grid:isSolid(nx, b.row, nz) then
					solidDir = solidDir or t
				else
					openDir = openDir or t
				end
			end
		end
		if solidDir then
			b.dir = solidDir
			local nx, nz = b.x + solidDir[1], b.z + solidDir[2]
			local ok, err = swing(h, b, nx, b.row, nz)
			if not ok and err ~= "swing too fast" then
				b.freeAt = now + STEP_SECONDS
			end
			return
		end
		if openDir then
			-- Walk (through open cells on this row) towards the nearest cell that
			-- has solid rock beside it: breadth-first over the row.
			local function key(x: number, z: number): number
				return x + z * 1000
			end
			local startKey = key(b.x, b.z)
			local queue = { { x = b.x, z = b.z } }
			local cameFrom: { [number]: number? } = { [startKey] = nil }
			local seen: { [number]: true } = { [startKey] = true }
			local target: { x: number, z: number }? = nil
			local head = 1
			while head <= #queue do
				local c = queue[head]
				head += 1
				local hasSolid = false
				for _, t in dirs do
					local nx, nz = c.x + t[1], c.z + t[2]
					if h.grid:inBounds(nx, b.row, nz) and h.grid:isSolid(nx, b.row, nz) then
						hasSolid = true
					end
				end
				if hasSolid and (c.x ~= b.x or c.z ~= b.z) then
					target = c
					break
				end
				for _, t in dirs do
					local nx, nz = c.x + t[1], c.z + t[2]
					local k = key(nx, nz)
					if h.grid:inBounds(nx, b.row, nz) and not h.grid:isSolid(nx, b.row, nz) and not seen[k] then
						seen[k] = true
						cameFrom[k] = key(c.x, c.z)
						table.insert(queue, { x = nx, z = nz })
					end
				end
			end
			if target then
				-- First step along the path back from the target.
				local k = key(target.x, target.z)
				while cameFrom[k] ~= nil and cameFrom[k] ~= startKey do
					k = cameFrom[k] :: number
				end
				local nx, nz = k % 1000, k // 1000
				b.walkedOpen = (b.walkedOpen or 0) + 1
				place(h, b, nx, b.row, nz)
				b.idle.walk += MOVE_SECONDS
				b.freeAt = now + MOVE_SECONDS
				return
			end
			-- This row is mined out everywhere we can walk: move to another column.
			b.column.x = (b.column.x + 5 - 1) % mine.width + 1
			b.column.z = (b.column.z + 7 - 1) % mine.length + 1
			b.exhausted = (b.exhausted or 0) + 1
		end
	end

	-- Nothing left to do down here: climb.
	b.climbs.done += 1
	local ok = h.actions:climb(b.player)
	if ok then
		local sess = h.session(b.player)
		b.idle.climb += sess.climbEndsAt - now
		b.freeAt = sess.climbEndsAt + STEP_SECONDS
	else
		b.freeAt = now + STEP_SECONDS
	end
end

local function snapshot(h: any, b: Bot, minute: number)
	local d = h.get(b.player)
	table.insert(b.timeline, {
		minute = minute,
		coins = d.coins,
		earned = d.stats.coinsEarned,
		pick = d.gear.pick,
		pack = d.gear.pack,
		lamp = d.gear.lamp,
		deepest = d.deepestRow,
		layer = d.layersReached,
		dives = d.stats.dives,
		lampOuts = d.stats.lampOuts,
		blocks = d.stats.blocksMined,
		ore = d.stats.oreSold + Pack.count(d.pack),
		exposed = h.grid.exposedCount,
	})
end

-- Watches the harness's effect lists to credit ore and milestones to bots.
local function watch(h: any, bots: { Bot }, state: any)
	while state.ores < #h.ores do
		state.ores += 1
		-- The harness does not say whose ore it was; attribute by the player who last swung.
		local b = state.lastSwinger
		if b then
			b.orePieces += 1
			b.oreValue += blocks[h.ores[state.ores]].value
			mark(b, h, "FirstOre")
		end
	end
	for _, b in bots do
		local d = h.get(b.player)
		if d.layersReached >= 2 then
			mark(b, h, "Layer2")
		end
		if d.layersReached >= 3 then
			mark(b, h, "Layer3")
		end
		if d.stats.lampOuts >= 1 then
			mark(b, h, "FirstLampOut")
		end
		if d.deepestRow >= Layout.totalRows(mine) then
			mark(b, h, "Bedrock")
		end
	end
end

local Scheduler = {}

-- Plays every bot for `seconds` of server time. Steps all players every 0.2 s.
function Scheduler.run(h: any, bots: { Bot }, seconds: number, onMinute: ((minute: number) -> ())?)
	local start = h.clock.now()
	local stopAt = start + seconds
	local state = { ores = #h.ores, lastSwinger = nil :: Bot? }
	local sinceStep = 0
	local sinceRegrow = 0
	local nextMinute = 1
	-- Wrap hit so we know who swung last (for ore attribution).
	local rawHit = h.actions.hit
	h.actions.hit = function(self: any, player: any, x: number, y: number, z: number)
		for _, b in bots do
			if b.player == player then
				state.lastSwinger = b
			end
		end
		return rawHit(self, player, x, y, z)
	end
	while h.clock.now() < stopAt - 1e-9 do
		local now = h.clock.now()
		for _, b in bots do
			if b.freeAt <= now + 1e-9 and h.session(b.player) then
				act(h, b)
				watch(h, bots, state)
			end
		end
		h.clock.advance(TICK)
		sinceStep += TICK
		if sinceStep >= STEP_SECONDS - 1e-9 then
			sinceStep = 0
			for _, b in bots do
				if h.session(b.player) then
					h.actions:step(b.player)
				end
			end
			watch(h, bots, state)
		end
		sinceRegrow += TICK
		if sinceRegrow >= REGROW_CHECK_SECONDS - 1e-9 then
			sinceRegrow = 0
			h.actions:regrowMine()
		end
		if h.clock.now() - start >= nextMinute * 60 - 1e-9 then
			for _, b in bots do
				snapshot(h, b, nextMinute)
			end
			if onMinute then
				onMinute(nextMinute)
			end
			nextMinute += 1
		end
	end
	h.actions.hit = rawHit
end

Bot.Scheduler = Scheduler
Bot.config = config
return Bot
