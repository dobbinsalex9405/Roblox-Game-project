--!strict
-- Module 14: Metrics.
-- Daily counters for each game: players, new players, day-1 and day-7
-- returns, play time, and Robux by product and pass. Every server adds up its
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
	playSeconds: number, -- total session length of sessions that ended this day
	sessionsEnded: number,
	peakServerPlayers: number, -- most players on any one server at once
	robux: { [string]: number }, -- "product:CoinPack" / "pass:Vip" -> Robux paid
	purchases: { [string]: number }, -- same keys -> number of purchases
	payers: number, -- distinct players who paid anything this day
	updatedAt: number,
}

export type JoinInfo = {
	firstJoinAt: number, -- unix seconds of the first ever join (0 if this is it)
	lastJoinAt: number, -- unix seconds of the previous join (0 if none)
}

export type Metrics = {
	join: (self: Metrics, info: JoinInfo, now: number) -> (),
	leave: (self: Metrics, sessionSeconds: number, now: number) -> (),
	purchase: (
		self: Metrics,
		kind: "product" | "pass",
		key: string,
		robux: number,
		firstToday: boolean,
		now: number
	) -> (),
	serverPlayers: (self: Metrics, count: number, now: number) -> (),
	-- Removes and returns everything counted since the last take, one Day per
	-- UTC day, oldest first.
	take: (self: Metrics) -> { Day },
	-- Puts deltas back after a failed write, so they go out with the next one.
	restore: (self: Metrics, days: { Day }) -> (),
	pending: (self: Metrics) -> boolean,
}

local DAY = 86400
local SCHEMA = 1
local MAX_KEYS = 100 -- distinct product/pass keys kept per day (a game sells far fewer)
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
		playSeconds = 0,
		sessionsEnded = 0,
		peakServerPlayers = 0,
		robux = {},
		purchases = {},
		payers = 0,
		updatedAt = 0,
	}
end

local COUNTERS = {
	"sessions",
	"players",
	"newPlayers",
	"returnedD1",
	"returnedD7",
	"playSeconds",
	"sessionsEnded",
	"payers",
}

local function number(value: any): number
	return if type(value) == "number"
			and value == value
			and value >= 0
			and value < math.huge
		then value
		else 0
end

local function addMap(into: { [string]: number }, from: { [string]: number }?)
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
			elseif count < MAX_KEYS then
				into[key] = number(value)
				count += 1
			end
		end
	end
end

-- Adds `delta` to what is stored under that day's key. Returns nil (leave the
-- stored value alone) if the stored value is from a newer schema, so an older
-- server never rewrites numbers it does not understand.
function Metrics.merge(stored: any, delta: Day, now: number): Day?
	local out: Day
	if type(stored) == "table" and stored.schema == SCHEMA and stored.day == delta.day then
		out = Metrics.empty(delta.day)
		local counters = out :: any
		for _, field in COUNTERS do
			counters[field] = number(stored[field])
		end
		out.peakServerPlayers = number(stored.peakServerPlayers)
		addMap(out.robux, stored.robux)
		addMap(out.purchases, stored.purchases)
	elseif type(stored) == "table" and type(stored.schema) == "number" and stored.schema > SCHEMA then
		return nil
	else
		-- Nothing stored yet, or something unreadable: start this key afresh.
		out = Metrics.empty(delta.day)
	end
	local into, from = out :: any, delta :: any
	for _, field in COUNTERS do
		into[field] += number(from[field])
	end
	out.peakServerPlayers = math.max(out.peakServerPlayers, number(delta.peakServerPlayers))
	addMap(out.robux, delta.robux)
	addMap(out.purchases, delta.purchases)
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
			end
		end
	end

	function metrics.leave(_self: Metrics, sessionSeconds: number, now: number)
		local day = today(now)
		day.sessionsEnded += 1
		day.playSeconds += math.clamp(math.floor(number(sessionSeconds)), 0, MAX_SESSION)
	end

	function metrics.purchase(
		_self: Metrics,
		kind: "product" | "pass",
		key: string,
		robux: number,
		firstToday: boolean,
		now: number
	)
		local day = today(now)
		local name = `{kind}:{key}`
		addMap(day.robux, { [name] = math.floor(number(robux)) })
		addMap(day.purchases, { [name] = 1 })
		if firstToday then
			day.payers += 1
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

return Metrics
