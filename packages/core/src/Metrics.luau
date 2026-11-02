--!strict
-- Module 14: Metrics.
-- Daily counters for each game: players, new players, day-1/7/30 returns,
-- play time (and how long sessions run), who came with or brought a friend,
-- Robux by product, pass and where in the game it was bought, purchase prompts,
-- and how often each game event and onboarding step happened. Every server adds up its
-- own numbers and merges them into the "Metrics" DataStore about once a
-- minute; tools/metrics/pull reads the stores once a day and writes the
-- studio scoreboard (ops/METRICS.md).
--
-- Roblox's own dashboards hold the same kind of numbers, but nothing outside
-- Roblox can read them without a signed-in account. These counters can be
-- read with a read-only Open Cloud key, so the daily Claude run can see how
-- every game is doing.
--
-- Days are UTC. Each server writes to one of `SHARDS` keys per day
-- ("20261101-s3"), so busy days spread writes over several keys instead of
-- queueing on one; the reader adds the shards back together.

local Analytics = require("./Analytics")

export type Day = {
	schema: number,
	day: string, -- "20261101" (UTC)
	sessions: number, -- joins
	players: number, -- distinct players (their first join of the day)
	newPlayers: number, -- first join ever
	returnedD1: number, -- first join of the day, one day after their first ever join
	returnedD7: number, -- same, seven days after
	returnedD30: number, -- same, thirty days after
	playSeconds: number, -- total session length of sessions that ended this day
	sessionsEnded: number,
	-- Ended sessions by length: "m0" under 1 minute, "m1" 1-5, "m5" 5-10,
	-- "m10" 10-20, "m20" 20-40, "m40" 40 minutes or more.
	sessionLengths: { [string]: number },
	peakServerPlayers: number, -- most players on any one server at once
	-- Friends. A "friend join" is a join that followed someone into the game
	-- or came from an invite (Player.FollowUserId / join data ReferredByPlayerId).
	friendJoins: number,
	friendNewPlayers: number, -- first ever joins among friendJoins
	friendSessions: number, -- ended sessions that had a friend on the same server
	friendPlaySeconds: number, -- their total length
	friendsBrought: number, -- friend joins whose friend was already on the server
	bringers: number, -- distinct players who brought someone that day
	robux: { [string]: number }, -- "product:CoinPack" / "pass:Vip" -> Robux paid
	purchases: { [string]: number }, -- same keys -> number of purchases
	-- Where in the game the purchase prompt was opened ("Shop", "OutOfOil"):
	-- source -> Robux and number of purchases. "Other" = not opened by our
	-- code in this session (website, a retried receipt, an expired prompt).
	robuxBySource: { [string]: number },
	purchasesBySource: { [string]: number },
	prompts: { [string]: number }, -- "product:CoinPack" -> purchase prompts opened
	promptsBySource: { [string]: number }, -- "Shop" -> purchase prompts opened there
	payers: number, -- distinct players who paid anything this day
	newPayers: number, -- players whose first payment ever was this day
	-- Game events by name: "Raid:Stolen" (custom events), "Onboarding:03:Hatch"
	-- (players reaching a step), "Progression:Rebirth:Complete", "Funnel:Name:02:Step".
	events: { [string]: number },
	updatedAt: number,
}

export type JoinInfo = {
	firstJoinAt: number, -- unix seconds of the first ever join (0 if this is it)
	lastJoinAt: number, -- unix seconds of the previous join (0 if none)
	viaFriend: boolean?, -- followed someone in, or came from an invite
}

export type Metrics = {
	join: (self: Metrics, info: JoinInfo, now: number) -> (),
	leave: (self: Metrics, sessionSeconds: number, now: number, withFriend: boolean?) -> (),
	purchase: (
		self: Metrics,
		kind: "product" | "pass",
		key: string,
		robux: number,
		firstToday: boolean,
		now: number,
		source: string?,
		firstEver: boolean?
	) -> (),
	-- A purchase prompt opened for an item, from `source` (see Metrics.source).
	prompt: (self: Metrics, kind: "product" | "pass", key: string, source: string?, now: number) -> (),
	-- A player on this server brought a friend in; `firstToday` is their
	-- first time today (see Metrics.isFirstToday), so `bringers` stays distinct.
	brought: (self: Metrics, firstToday: boolean, now: number) -> (),
	-- One game event (see Metrics.eventName for the names).
	event: (self: Metrics, name: string, now: number) -> (),
	serverPlayers: (self: Metrics, count: number, now: number) -> (),
	-- Removes and returns everything counted since the last take, one Day per
	-- UTC day, oldest first.
	take: (self: Metrics) -> { Day },
	-- Puts deltas back after a failed write, so they go out with the next one.
	restore: (self: Metrics, days: { Day }) -> (),
	pending: (self: Metrics) -> boolean,
}

local DAY = 86400
local SCHEMA = 2 -- 1: no sessions lengths, friends, sources, prompts or events (read as zero)
local MAX_KEYS = 100 -- distinct product/pass/source keys kept per day (a game sells far fewer)
local MAX_EVENTS = 200 -- distinct event names kept per day
local MAX_NAME = 60 -- longest event name kept
local MAX_DAYS = 3 -- unsent days kept in memory if writes keep failing
local MAX_SESSION = 12 * 3600 -- a longer "session" is a stuck server clock, not play

local Metrics = {}

Metrics.SCHEMA = SCHEMA
Metrics.SHARDS = 8
Metrics.STORE = "Metrics"

-- "20261101" for a unix time, without os.date (Roblox's os.date has no formats).
function Metrics.dayKey(at: number): string
	-- Civil from days (Howard Hinnant), exact for the Gregorian calendar.
	local z = at // DAY + 719468
	local era = z // 146097
	local doe = z - era * 146097
	local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
	local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
	local mp = (5 * doy + 2) // 153
	local d = doy - (153 * mp + 2) // 5 + 1
	local m = if mp < 10 then mp + 3 else mp - 9
	local y = yoe + era * 400 + (if m <= 2 then 1 else 0)
	return string.format("%04d%02d%02d", y, m, d)
end

function Metrics.empty(day: string): Day
	return {
		schema = SCHEMA,
		day = day,
		sessions = 0,
		players = 0,
		newPlayers = 0,
		returnedD1 = 0,
		returnedD7 = 0,
		returnedD30 = 0,
		playSeconds = 0,
		sessionsEnded = 0,
		sessionLengths = {},
		peakServerPlayers = 0,
		friendJoins = 0,
		friendNewPlayers = 0,
		friendSessions = 0,
		friendPlaySeconds = 0,
		friendsBrought = 0,
		bringers = 0,
		robux = {},
		purchases = {},
		robuxBySource = {},
		purchasesBySource = {},
		prompts = {},
		promptsBySource = {},
		payers = 0,
		newPayers = 0,
		events = {},
		updatedAt = 0,
	}
end

-- Session length buckets, by lower bound in minutes.
Metrics.SESSION_BUCKETS = { 0, 1, 5, 10, 20, 40 }

function Metrics.sessionBucket(seconds: number): string
	local minutes = seconds / 60
	local key = 0
	for _, bound in Metrics.SESSION_BUCKETS do
		if minutes >= bound then
			key = bound
		end
	end
	return `m{key}`
end

-- A purchase source as games name it ("Shop", "OutOfOil"): PascalCase, at
-- most 24 characters. Anything else (or nothing) counts as "Other".
function Metrics.source(source: any): string
	if type(source) == "string" and #source <= 24 and string.match(source, "^%u%w*$") then
		return source
	end
	return "Other"
end

local COUNTERS = {
	"sessions",
	"players",
	"newPlayers",
	"returnedD1",
	"returnedD7",
	"returnedD30",
	"playSeconds",
	"sessionsEnded",
	"friendJoins",
	"friendNewPlayers",
	"friendSessions",
	"friendPlaySeconds",
	"friendsBrought",
	"bringers",
	"payers",
	"newPayers",
}

-- Maps of counts, and how many distinct keys each keeps per day.
local MAPS: { [string]: number } = {
	robux = MAX_KEYS,
	purchases = MAX_KEYS,
	robuxBySource = MAX_KEYS,
	purchasesBySource = MAX_KEYS,
	prompts = MAX_KEYS,
	promptsBySource = MAX_KEYS,
	sessionLengths = MAX_KEYS,
	events = MAX_EVENTS,
}

local function number(value: any): number
	return if type(value) == "number"
			and value == value
			and value >= 0
			and value < math.huge
		then value
		else 0
end

local function addMap(into: { [string]: number }, from: { [string]: number }?, max: number?)
	local limit = max or MAX_KEYS
	if type(from) ~= "table" then
		return
	end
	local count = 0
	for _ in into do
		count += 1
	end
	for key, value in from :: { [string]: number } do
		if type(key) == "string" then
			if into[key] ~= nil then
				into[key] += number(value)
			elseif count < limit then
				into[key] = number(value)
				count += 1
			end
		end
	end
end

-- Adds `delta` to what is stored under that day's key. Returns nil (leave the
-- stored value alone) if the stored value is from a newer schema, so an older
-- server never rewrites numbers it does not understand. A value from an older
-- schema is upgraded: the fields it did not have start at zero.
function Metrics.merge(stored: any, delta: Day, now: number): Day?
	local out = Metrics.empty(delta.day)
	local into, from = out :: any, delta :: any
	if
		type(stored) == "table"
		and type(stored.schema) == "number"
		and stored.schema >= 1
		and stored.schema <= SCHEMA
		and stored.day == delta.day
	then
		for _, field in COUNTERS do
			into[field] = number(stored[field])
		end
		out.peakServerPlayers = number(stored.peakServerPlayers)
		for field, max in MAPS do
			addMap(into[field], stored[field], max)
		end
	elseif type(stored) == "table" and type(stored.schema) == "number" and stored.schema > SCHEMA then
		return nil
	end
	-- Otherwise nothing is stored yet, or something unreadable: start afresh.
	for _, field in COUNTERS do
		into[field] += number(from[field])
	end
	out.peakServerPlayers = math.max(out.peakServerPlayers, number(delta.peakServerPlayers))
	for field, max in MAPS do
		addMap(into[field], from[field], max)
	end
	out.updatedAt = now
	return out
end

-- Which shard key this server writes: a stable hash of its JobId (FNV-1a).
function Metrics.shard(jobId: string, shards: number?): number
	local h = 2166136261
	for i = 1, #jobId do
		h = bit32.bxor(h, string.byte(jobId, i))
		-- h * 16777619 mod 2^32, split so the product stays exact in a double.
		h = (bit32.band(h, 0xFFFF) * 16777619 + bit32.rshift(h, 16) * 16777619 % 65536 * 65536) % 4294967296
	end
	return h % (shards or Metrics.SHARDS)
end

function Metrics.key(day: string, shard: number): string
	return `{day}-s{shard}`
end

function Metrics.new(): Metrics
	local days: { [string]: Day } = {}

	local function today(now: number): Day
		local key = Metrics.dayKey(now)
		local day = days[key]
		if day == nil then
			day = Metrics.empty(key)
			days[key] = day
			-- Never hold more than MAX_DAYS of unsent days.
			local keys = {}
			for k in days do
				table.insert(keys, k)
			end
			table.sort(keys)
			for i = 1, #keys - MAX_DAYS do
				days[keys[i]] = nil
			end
		end
		return day :: Day
	end

	local metrics = {}

	function metrics.join(_self: Metrics, info: JoinInfo, now: number)
		local day = today(now)
		day.sessions += 1
		local firstJoin = info.firstJoinAt <= 0
		local firstToday = firstJoin or info.lastJoinAt // DAY < now // DAY
		if firstJoin then
			day.newPlayers += 1
		end
		if firstToday then
			day.players += 1
		end
		for _, marker in Analytics.retentionMarkers(info.firstJoinAt, info.lastJoinAt, now) do
			if marker == "Retention:D1" then
				day.returnedD1 += 1
			elseif marker == "Retention:D7" then
				day.returnedD7 += 1
			elseif marker == "Retention:D30" then
				day.returnedD30 += 1
			end
		end
		if info.viaFriend then
			day.friendJoins += 1
			if firstJoin then
				day.friendNewPlayers += 1
			end
		end
	end

	function metrics.leave(_self: Metrics, sessionSeconds: number, now: number, withFriend: boolean?)
		local day = today(now)
		local seconds = math.clamp(math.floor(number(sessionSeconds)), 0, MAX_SESSION)
		day.sessionsEnded += 1
		day.playSeconds += seconds
		addMap(day.sessionLengths, { [Metrics.sessionBucket(seconds)] = 1 })
		if withFriend then
			day.friendSessions += 1
			day.friendPlaySeconds += seconds
		end
	end

	function metrics.purchase(
		_self: Metrics,
		kind: "product" | "pass",
		key: string,
		robux: number,
		firstToday: boolean,
		now: number,
		source: string?,
		firstEver: boolean?
	)
		local day = today(now)
		local name = `{kind}:{key}`
		local paid = math.floor(number(robux))
		local from = Metrics.source(source)
		addMap(day.robux, { [name] = paid })
		addMap(day.purchases, { [name] = 1 })
		addMap(day.robuxBySource, { [from] = paid })
		addMap(day.purchasesBySource, { [from] = 1 })
		if firstToday then
			day.payers += 1
		end
		if firstEver then
			day.newPayers += 1
		end
	end

	function metrics.prompt(
		_self: Metrics,
		kind: "product" | "pass",
		key: string,
		source: string?,
		now: number
	)
		local day = today(now)
		addMap(day.prompts, { [`{kind}:{key}`] = 1 })
		addMap(day.promptsBySource, { [Metrics.source(source)] = 1 })
	end

	function metrics.brought(_self: Metrics, firstToday: boolean, now: number)
		local day = today(now)
		day.friendsBrought += 1
		if firstToday then
			day.bringers += 1
		end
	end

	function metrics.event(_self: Metrics, name: string, now: number)
		if type(name) == "string" and #name > 0 and #name <= MAX_NAME then
			addMap(today(now).events, { [name] = 1 }, MAX_EVENTS)
		end
	end

	function metrics.serverPlayers(_self: Metrics, count: number, now: number)
		local day = today(now)
		day.peakServerPlayers = math.max(day.peakServerPlayers, number(count))
	end

	function metrics.take(_self: Metrics): { Day }
		local out = {}
		for _, day in days do
			table.insert(out, day)
		end
		table.sort(out, function(a, b)
			return a.day < b.day
		end)
		days = {}
		return out
	end

	function metrics.restore(_self: Metrics, failed: { Day })
		for _, delta in failed do
			local merged = Metrics.merge(days[delta.day], delta, delta.updatedAt)
			if merged then
				days[delta.day] = merged
			end
		end
		local keys = {}
		for k in days do
			table.insert(keys, k)
		end
		table.sort(keys)
		for i = 1, #keys - MAX_DAYS do
			days[keys[i]] = nil
		end
	end

	function metrics.pending(_self: Metrics): boolean
		return next(days) ~= nil
	end

	return (metrics :: any) :: Metrics
end

-- The day a payment counts as a player's first of that day, from the day
-- number saved in their data (`meta.lastPaidDay`, whole days since 1970).
function Metrics.isFirstPaymentToday(lastPaidDay: number?, now: number): boolean
	return (lastPaidDay or -1) < now // DAY
end

-- Same rule for any once-a-day marker saved as a day number (`meta.lastBroughtDay`).
Metrics.isFirstToday = Metrics.isFirstPaymentToday

-- Wraps an Analytics sink so every game event is also counted in `metrics`
-- (custom events, onboarding steps, progression and funnel steps). Counting
-- happens before the wrapped sink runs, so a failing Roblox sink never stops it.
function Metrics.countingSink(sink: Analytics.Sink, metrics: Metrics, clock: () -> number): Analytics.Sink
	local function count(name: string?)
		if name then
			metrics:event(name, clock())
		end
	end
	return {
		economy = sink.economy,
		onboarding = function(player, step, stepName)
			count(Metrics.eventName("onboarding", stepName, nil, step))
			sink.onboarding(player, step, stepName)
		end,
		funnel = function(player, funnelName, funnelSessionId, step, stepName)
			count(Metrics.eventName("funnel", funnelName, stepName, step))
			sink.funnel(player, funnelName, funnelSessionId, step, stepName)
		end,
		progression = function(player, path, status, level)
			count(Metrics.eventName("progression", path, status))
			sink.progression(player, path, status, level)
		end,
		custom = function(player, name, value, fields)
			count(Metrics.eventName("custom", name))
			sink.custom(player, name, value, fields)
		end,
	}
end

-- The event name counted for an Analytics call, or nil for events Metrics
-- already counts another way (sessions, retention markers, purchases).
function Metrics.eventName(kind: string, name: string, extra: string?, step: number?): string?
	if kind == "custom" then
		local area = string.match(name, "^(%u%w*):")
		if area == "Session" or area == "Retention" or area == "Purchase" then
			return nil
		end
		return name
	elseif kind == "onboarding" then
		return string.format("Onboarding:%02d:%s", step or 0, name)
	elseif kind == "progression" then
		return `Progression:{name}:{extra or ""}`
	elseif kind == "funnel" then
		return string.format("Funnel:%s:%02d:%s", name, step or 0, extra or "")
	end
	return nil
end

return Metrics
