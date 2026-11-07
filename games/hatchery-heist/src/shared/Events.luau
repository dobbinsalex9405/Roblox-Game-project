--!strict
-- Timed events and the Giant Legendary Egg's daily pick, as pure functions of
-- the clock and config/events.luau (Alex, Nov 7 2026).
--
-- Time is cut into 24-hour cycles starting at `cycleStartHourUtc`. Each cycle
-- has one event window at a time and of a kind picked by a hash of the cycle
-- number and the config's seed, so every server and every client computes the
-- same schedule from the clock alone: nothing has to be sent between servers.
-- The server decides every effect (src/server/EventService); clients use this
-- module only to draw the countdown.
--
-- A Studio test can start an event early (`Override`): it replaces the
-- schedule for its own span and nothing else.

local Events = {}

Events.DAY = 86400
local TWO32 = 4294967296

export type Window = {
	cycle: number,
	kind: string,
	startsAt: number, -- unix seconds
	endsAt: number,
}

-- An event started by hand (Studio test panel), in place of the schedule.
export type Override = { kind: string, startsAt: number, endsAt: number }

export type State = {
	active: Window?, -- running now
	nextWindow: Window, -- the next one to start (after `active`, if any)
}

-- What the running event (if any) changes. 1 means no change.
export type Effects = {
	kind: string?,
	priceFactor: number, -- market egg prices
	hatchFactor: number, -- hatch time of eggs bought now
	incomeFactor: number, -- coins per second of placed creatures
	rarityMultipliers: { [string]: number }?, -- odds of eggs bought now
}

-- 32-bit multiply, exact in a double.
local function mul32(a: number, b: number): number
	local lo = b % 65536
	local hi = (b - lo) / 65536
	return (a * lo + ((a * hi) % 65536) * 65536) % TWO32
end

-- MurmurHash3's finaliser: every input bit changes about half the output bits.
local function fmix(h: number): number
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = mul32(h, 0x85EBCA6B)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = mul32(h, 0xC2B2AE35)
	return bit32.bxor(h, bit32.rshift(h, 16))
end

-- A well-mixed whole number in [0, 2^32) from the seed and any whole numbers.
function Events.hash(seed: number, ...: number): number
	local h = fmix(bit32.bxor(seed % TWO32, 0x9E3779B9))
	for i = 1, select("#", ...) do
		local v = (select(i, ...) :: number) % TWO32
		h = fmix(bit32.bxor(mul32(h, 0x01000193), v))
	end
	return h
end

-- The cycle a moment falls in, and when that cycle started.
function Events.cycleOf(t: number, config: any): (number, number)
	local offset = config.cycleStartHourUtc * 3600
	local cycle = (t - offset) // Events.DAY
	return cycle, cycle * Events.DAY + offset
end

-- `list` in the order of rotation round `round` (Fisher-Yates driven by the hash).
local function shuffled(list: { string }, seed: number, salt: number, round: number): { string }
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = Events.hash(seed, salt, round, i) % i + 1
		out[i], out[j] = out[j], out[i]
	end
	return out
end

-- The entry of `list` for cycle `cycle`: each round of #list cycles uses every
-- entry once in a shuffled order, and no entry comes twice in a row, even
-- across rounds. `salt` keeps different rotations independent.
function Events.rotationPick(list: { string }, cycle: number, seed: number, salt: number): string
	local n = #list
	assert(n > 0, "a rotation needs at least one entry")
	if n == 1 then
		return list[1]
	elseif n == 2 then
		-- Shuffling two would repeat across rounds; alternate instead.
		return list[(cycle + Events.hash(seed, salt) % 2) % 2 + 1]
	end
	local round = cycle // n
	local order = shuffled(list, seed, salt, round)
	-- A round's last entry never moves (only the first two can swap), so
	-- the previous round's last is known without looking further back.
	if order[1] == shuffled(list, seed, salt, round - 1)[n] then
		order[1], order[2] = order[2], order[1]
	end
	return order[cycle % n + 1]
end

-- The scheduled event window of cycle `cycle`.
function Events.window(cycle: number, config: any): Window
	local cycleStart = cycle * Events.DAY + config.cycleStartHourUtc * 3600
	local step = config.startStepMinutes * 60
	local span = (config.latestHour - config.earliestHour) * 3600
	local slots = span // step + 1
	local startsAt = cycleStart
		+ config.earliestHour * 3600
		+ (Events.hash(config.seed, 1, cycle) % slots) * step
	return {
		cycle = cycle,
		kind = Events.rotationPick(config.rotation, cycle, config.seed, 2),
		startsAt = startsAt,
		endsAt = startsAt + config.windowMinutes * 60,
	}
end

-- What is running at `t` and what comes next. An override in force replaces
-- the schedule while it lasts.
function Events.state(t: number, config: any, override: Override?): State
	local cycle = Events.cycleOf(t, config)
	local current = Events.window(cycle, config)
	local active: Window? = nil
	local nextWindow = current
	if t >= current.endsAt then
		nextWindow = Events.window(cycle + 1, config)
	elseif t >= current.startsAt then
		active = current
		nextWindow = Events.window(cycle + 1, config)
	end
	if override and t >= override.startsAt and t < override.endsAt then
		active =
			{ cycle = cycle, kind = override.kind, startsAt = override.startsAt, endsAt = override.endsAt }
		if nextWindow.startsAt < override.endsAt then
			nextWindow = Events.window(Events.cycleOf(nextWindow.startsAt, config) + 1, config)
		end
	elseif override and t < override.startsAt and override.startsAt < nextWindow.startsAt then
		-- An override still to come is announced like the schedule's next.
		nextWindow = {
			cycle = cycle,
			kind = override.kind,
			startsAt = override.startsAt,
			endsAt = override.endsAt,
		}
	end
	return { active = active, nextWindow = nextWindow }
end

-- What an event kind changes.
function Events.effectsOf(kind: string?, config: any): Effects
	local def = kind and config.kinds[kind]
	if def == nil then
		return { kind = nil, priceFactor = 1, hatchFactor = 1, incomeFactor = 1, rarityMultipliers = nil }
	end
	return {
		kind = kind,
		priceFactor = def.priceFactor or 1,
		hatchFactor = def.hatchFactor or 1,
		incomeFactor = def.incomeFactor or 1,
		rarityMultipliers = def.rarityMultipliers,
	}
end

function Events.effects(t: number, config: any, override: Override?): Effects
	local active = Events.state(t, config, override).active
	return Events.effectsOf(active and active.kind, config)
end

-- An egg's coin price during the event (whole coins, at least 1).
function Events.price(priceCoins: number, effects: Effects): number
	if effects.priceFactor == 1 then
		return priceCoins
	end
	return math.max(1, math.floor(priceCoins * effects.priceFactor + 0.5))
end

-- An egg's hatch time when bought during the event (whole seconds, at least 1).
function Events.hatchSeconds(seconds: number, effects: Effects): number
	if effects.hatchFactor == 1 then
		return seconds
	end
	return math.max(1, math.ceil(seconds * effects.hatchFactor))
end

local function overlap(a0: number, a1: number, b0: number, b1: number): number
	return math.max(0, math.min(a1, b1) - math.max(a0, b0))
end

-- Income-weighted seconds between `from` and `to`: the plain seconds plus
-- the extra a Money Rush (or any incomeFactor) adds for the part of the span
-- it covers. Exact at the window's edges, however the span falls.
function Events.incomeSeconds(from: number, to: number, config: any, override: Override?): number
	if to <= from then
		return 0
	end
	local seconds = to - from
	local first = Events.cycleOf(from, config)
	local last = Events.cycleOf(to, config)
	-- A span longer than a few days only happens with a broken clock; pay
	-- it plainly rather than walk it.
	if last - first > 8 then
		return seconds
	end
	local o0 = if override then override.startsAt else 0
	local o1 = if override then override.endsAt else 0
	for cycle = first, last do
		local w = Events.window(cycle, config)
		local factor = config.kinds[w.kind] and config.kinds[w.kind].incomeFactor or 1
		if factor ~= 1 then
			local covered = overlap(from, to, w.startsAt, w.endsAt)
			-- The override replaces the schedule while it lasts.
			local hidden = if override
				then overlap(math.max(from, w.startsAt), math.min(to, w.endsAt), o0, o1)
				else 0
			seconds += (covered - hidden) * (factor - 1)
		end
	end
	if override then
		local factor = config.kinds[override.kind] and config.kinds[override.kind].incomeFactor or 1
		seconds += overlap(from, to, o0, o1) * (factor - 1)
	end
	return seconds
end

-- The Legendary on the Giant Egg in cycle `cycle`: every Legendary in turn,
-- in a shuffled order, never the same two days running. Nil if none exist.
function Events.giantSpecies(cycle: number, config: any, species: { [string]: any }): string?
	local ids = {}
	for id, s in species do
		if s.rarity == "Legendary" then
			table.insert(ids, id)
		end
	end
	if #ids == 0 then
		return nil
	end
	table.sort(ids)
	return Events.rotationPick(ids, cycle, config.seed, 3)
end

-- "2h 05m", "45:09" (under an hour), "0:07".
function Events.countdown(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	local h = s // 3600
	local m = (s % 3600) // 60
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	end
	return string.format("%d:%02d", m, s % 60)
end

export type Banner = {
	active: boolean,
	kind: string,
	title: string, -- big line
	line: string, -- small line: the time
	seconds: number, -- until it ends (running) or starts (next)
	blurb: string, -- what the event does
	color: { number },
}

-- What the event banner says at `t`.
function Events.banner(t: number, config: any, override: Override?): Banner
	local state = Events.state(t, config, override)
	local active = state.active
	if active then
		local def = config.kinds[active.kind]
		return {
			active = true,
			kind = active.kind,
			title = def.title,
			line = `Now! {Events.countdown(active.endsAt - t)} left`,
			seconds = active.endsAt - t,
			blurb = def.blurb,
			color = def.color,
		}
	end
	local nextWindow = state.nextWindow
	local def = config.kinds[nextWindow.kind]
	local wait = nextWindow.startsAt - t
	return {
		active = false,
		kind = nextWindow.kind,
		title = def.title,
		line = if wait <= config.announceMinutes * 60
			then `Starts in {Events.countdown(wait)}!`
			else `Next event in {Events.countdown(wait)}`,
		seconds = wait,
		blurb = def.blurb,
		color = def.color,
	}
end

return Events
