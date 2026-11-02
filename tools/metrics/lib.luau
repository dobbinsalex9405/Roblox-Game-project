--!strict
-- Pure helpers for tools/metrics/pull.luau, kept separate so they are unit-tested.
-- Reads the daily counters games write with packages/core/src/Metrics.luau
-- (one key per day per shard, "20261101-s3") and turns them into the studio
-- scoreboard: a Markdown issue body plus a machine-readable block the daily
-- Claude run reads (ops/METRICS.md, ops/DAILY_RUN.md).

local Metrics = require("@core/Metrics")

local lib = {}

local DEFAULT_BASE = "https://apis.roblox.com"
local GAME_PATTERN = "^[a-z][a-z0-9%-]*$"
local DAY = 86400

lib.STORE = Metrics.STORE
lib.ENVIRONMENTS = { "production", "staging" }
lib.CHALLENGE_START = "20261101"
lib.CREATOR_SHARE = 0.7 -- what the creator keeps of Robux spent inside an experience
lib.TABLE_DAYS = 14

-- Launch gate for the next wave (14 days after launch) and the early kill signal.
lib.GATE = { afterDays = 14, d1 = 0.25, avgMinutes = 10, risingDays = 3 }
lib.KILL = { afterDays = 7, d1 = 0.15 }

export type Target = { game: string, environment: string, universeId: number }

export type GameDays = { [string]: Metrics.Day } -- day key -> totals over every shard

local function checkBase(base: string?): string
	local root = base or DEFAULT_BASE
	assert(
		root == DEFAULT_BASE or string.match(root, "^http://127%.0%.0%.1:%d+$"),
		"the API base URL can only be Roblox or a local test server"
	)
	return root
end

local function encode(value: string): string
	return (
		string.gsub(value, "[^%w%-%._~]", function(c)
			return string.format("%%%02X", string.byte(c))
		end)
	)
end

-- Every game in ops/environments.json with a universe id for `environment`.
function lib.targets(environments: { [string]: any }, environment: string): { Target }
	assert(table.find(lib.ENVIRONMENTS, environment), "--env must be production or staging")
	local games = {}
	for game, entry in environments do
		if type(entry) == "table" and string.match(game, GAME_PATTERN) then
			table.insert(games, game)
		end
	end
	table.sort(games)
	local out: { Target } = {}
	for _, game in games do
		local env = environments[game][environment]
		local universeId = type(env) == "table" and env.universeId or 0
		if type(universeId) == "number" and universeId > 0 and universeId // 1 == universeId then
			table.insert(out, { game = game, environment = environment, universeId = universeId })
		end
	end
	return out
end

-- Every game folder named in ops/environments.json, configured or not.
function lib.allGames(environments: { [string]: any }): { string }
	local games = {}
	for game, entry in environments do
		if type(entry) == "table" and string.match(game, GAME_PATTERN) then
			table.insert(games, game)
		end
	end
	table.sort(games)
	return games
end

-- Open Cloud DataStores v1: list keys (all of them; a day has at most 8).
function lib.listUrl(universeId: number, cursor: string?, base: string?): string
	local url = `{checkBase(base)}/datastores/v1/universes/{universeId}/standard-datastores/datastore/entries`
		.. `?datastoreName={encode(lib.STORE)}&limit=100`
	if cursor and cursor ~= "" then
		url ..= `&cursor={encode(cursor)}`
	end
	return url
end

function lib.entryUrl(universeId: number, key: string, base: string?): string
	return `{checkBase(base)}/datastores/v1/universes/{universeId}/standard-datastores/datastore/entries/entry`
		.. `?datastoreName={encode(lib.STORE)}&entryKey={encode(key)}`
end

-- "20261101" -> whole days since 1970-01-01.
function lib.dayNumber(day: string): number
	local y, m, d = string.match(day, "^(%d%d%d%d)(%d%d)(%d%d)$")
	assert(y and m and d, `day keys look like 20261101, got {day}`)
	local year, month, date = tonumber(y) :: number, tonumber(m) :: number, tonumber(d) :: number
	local yy = if month <= 2 then year - 1 else year
	local era = yy // 400
	local yoe = yy - era * 400
	local mp = (month + 9) % 12
	local doy = (153 * mp + 2) // 5 + date - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

function lib.addDays(day: string, n: number): string
	return Metrics.dayKey((lib.dayNumber(day) + n) * DAY)
end

-- The day part of a metrics key, or nil if the key is not one.
function lib.dayOfKey(key: string): string?
	return string.match(key, "^(%d%d%d%d%d%d%d%d)%-s%d+$")
end

-- Keys worth reading: well-formed and from `from` to `to` inclusive.
function lib.keysToRead(keys: { string }, from: string, to: string): { string }
	local out = {}
	for _, key in keys do
		local day = lib.dayOfKey(key)
		if day and day >= from and day <= to then
			table.insert(out, key)
		end
	end
	table.sort(out)
	return out
end

-- Adds one stored shard into a game's per-day totals. Unknown shapes are skipped.
function lib.addShard(days: GameDays, key: string, value: any): string?
	local day = lib.dayOfKey(key)
	if day == nil then
		return "not a metrics key"
	end
	-- Older schemas are read too (their missing fields count as zero).
	if
		type(value) ~= "table"
		or type(value.schema) ~= "number"
		or value.schema < 1
		or value.schema > Metrics.SCHEMA
		or value.day ~= day
	then
		return `unexpected value (schema {tostring(type(value) == "table" and value.schema or nil)})`
	end
	local merged = Metrics.merge(days[day] or Metrics.empty(day), value :: Metrics.Day, 0)
	if merged then
		-- Shards add up; the largest server is the largest of any shard.
		days[day] = merged
	end
	return nil
end

local function sum(map: { [string]: number }): number
	local total = 0
	for _, v in map do
		total += v
	end
	return total
end

export type DayRow = {
	day: string,
	players: number,
	newPlayers: number,
	returning: number, -- players - newPlayers
	sessions: number,
	d1: number?, -- returned on day 1 / new players the day before
	d7: number?, -- returned on day 7 / new players 7 days before
	avgSessionMin: number?,
	robux: number,
	purchases: number,
	payers: number,
	newPayers: number,
	friendJoins: number,
	friendSessions: number,
	peakServerPlayers: number,
}

-- Returns on day `n` / new players `n` days before, or nil without a cohort.
local function returnRate(days: GameDays, day: string, n: number, field: string): number?
	local d = days[day]
	local cohortDay = days[lib.addDays(day, -n)]
	local cohort = if cohortDay then cohortDay.newPlayers else 0
	if cohort <= 0 then
		return nil
	end
	return (if d then ((d :: any)[field] or 0) else 0) / cohort
end

function lib.row(days: GameDays, day: string): DayRow
	local d = days[day] or Metrics.empty(day)
	return {
		day = day,
		players = d.players,
		newPlayers = d.newPlayers,
		returning = math.max(0, d.players - d.newPlayers),
		sessions = d.sessions,
		d1 = returnRate(days, day, 1, "returnedD1"),
		d7 = returnRate(days, day, 7, "returnedD7"),
		avgSessionMin = if d.sessionsEnded > 0 then d.playSeconds / d.sessionsEnded / 60 else nil,
		robux = sum(d.robux),
		purchases = sum(d.purchases),
		payers = d.payers,
		newPayers = d.newPayers,
		friendJoins = d.friendJoins,
		friendSessions = d.friendSessions,
		peakServerPlayers = d.peakServerPlayers,
	}
end

lib.TOP = 25 -- entries kept per map in the report (the busiest first)

export type Entry = { key: string, value: number }

-- A map as a list, biggest value first (ties by key), at most `limit` long.
function lib.top(map: { [string]: number }, limit: number?): { Entry }
	local out = {}
	for key, value in map do
		table.insert(out, { key = key, value = value })
	end
	table.sort(out, function(a, b)
		if a.value ~= b.value then
			return a.value > b.value
		end
		return a.key < b.key
	end)
	while #out > (limit or lib.TOP) do
		table.remove(out)
	end
	return out
end

-- The same as a map again (for JSON), or nil when empty so it is left out.
local function topMap(map: { [string]: number }, limit: number?): { [string]: number }?
	local list = lib.top(map, limit)
	if #list == 0 then
		return nil
	end
	local out = {}
	for _, e in list do
		out[e.key] = e.value
	end
	return out
end

-- Seven days of the analytics numbers (ops/METRICS.md, "Analytics").
export type Week = {
	playerDays: number, -- sum of daily players (a player counts once per day played)
	returningShare: number?, -- returning player-days / player-days
	newPlayers: number,
	d7Week: number?, -- pooled D7 return over days whose cohort was read
	d30Week: number?,
	sessionsEnded: number,
	longSessionShare: number?, -- sessions of 10+ minutes / sessions ended
	sessionLengths: { [string]: number }, -- "m0".."m40" -> sessions
	friendJoins: number,
	friendNewPlayers: number,
	friendJoinShare: number?, -- new players who came with a friend / new players
	friendShare: number?, -- sessions with a friend on the server / sessions ended
	friendAvgMin: number?,
	soloAvgMin: number?,
	friendsBrought: number,
	bringers: number, -- summed daily distinct bringers
	payers: number, -- summed daily payers
	payerRate: number?, -- payers / player-days
	newPayers: number,
	arpdau: number?, -- Robux / player-days
	robuxByItem: { [string]: number },
	purchasesByItem: { [string]: number },
	robuxBySource: { [string]: number },
	purchasesBySource: { [string]: number },
	prompts: { [string]: number },
	promptsBySource: { [string]: number },
	onboarding: { [string]: number }, -- "01:StepName" -> times reached
	events: { [string]: number }, -- other game events
}

local function addInto(into: { [string]: number }, from: { [string]: number }?)
	if type(from) == "table" then
		for key, value in from do
			into[key] = (into[key] or 0) + value
		end
	end
end

-- The analytics numbers for the 7 days ending `through`.
function lib.week(days: GameDays, through: string): Week
	local w = {
		playerDays = 0,
		newPlayers = 0,
		sessionsEnded = 0,
		sessionLengths = {},
		friendJoins = 0,
		friendNewPlayers = 0,
		friendsBrought = 0,
		bringers = 0,
		payers = 0,
		newPayers = 0,
		robuxByItem = {},
		purchasesByItem = {},
		robuxBySource = {},
		purchasesBySource = {},
		prompts = {},
		promptsBySource = {},
		onboarding = {},
		events = {},
	} :: Week
	local returning, d7, cohort7, d30, cohort30 = 0, 0, 0, 0, 0
	local play, friendPlay, friendSessions, long = 0, 0, 0, 0
	for i = 0, 6 do
		local day = lib.addDays(through, -i)
		local d = days[day]
		if d then
			w.playerDays += d.players
			returning += math.max(0, d.players - d.newPlayers)
			w.newPlayers += d.newPlayers
			w.sessionsEnded += d.sessionsEnded
			play += d.playSeconds
			friendPlay += d.friendPlaySeconds
			friendSessions += d.friendSessions
			w.friendJoins += d.friendJoins
			w.friendNewPlayers += d.friendNewPlayers
			w.friendsBrought += d.friendsBrought
			w.bringers += d.bringers
			w.payers += d.payers
			w.newPayers += d.newPayers
			addInto(w.sessionLengths, d.sessionLengths)
			addInto(w.robuxByItem, d.robux)
			addInto(w.purchasesByItem, d.purchases)
			addInto(w.robuxBySource, d.robuxBySource)
			addInto(w.purchasesBySource, d.purchasesBySource)
			addInto(w.prompts, d.prompts)
			addInto(w.promptsBySource, d.promptsBySource)
			for name, count in d.events do
				local step = string.match(name, "^Onboarding:(%d%d:.+)$")
				if step then
					w.onboarding[step] = (w.onboarding[step] or 0) + count
				else
					w.events[name] = (w.events[name] or 0) + count
				end
			end
		end
		local c7 = days[lib.addDays(day, -7)]
		if c7 and c7.newPlayers > 0 then
			d7 += if d then d.returnedD7 else 0
			cohort7 += c7.newPlayers
		end
		local c30 = days[lib.addDays(day, -30)]
		if c30 and c30.newPlayers > 0 then
			d30 += if d then d.returnedD30 else 0
			cohort30 += c30.newPlayers
		end
	end
	for key, count in w.sessionLengths do
		local bound = tonumber(string.match(key, "^m(%d+)$"))
		if bound and bound >= 10 then
			long += count
		end
	end
	local robux = sum(w.robuxByItem)
	local solo = w.sessionsEnded - friendSessions
	w.returningShare = if w.playerDays > 0 then returning / w.playerDays else nil
	w.d7Week = if cohort7 > 0 then d7 / cohort7 else nil
	w.d30Week = if cohort30 > 0 then d30 / cohort30 else nil
	w.longSessionShare = if w.sessionsEnded > 0 then long / w.sessionsEnded else nil
	w.friendJoinShare = if w.newPlayers > 0 then w.friendNewPlayers / w.newPlayers else nil
	w.friendShare = if w.sessionsEnded > 0 then friendSessions / w.sessionsEnded else nil
	w.friendAvgMin = if friendSessions > 0 then friendPlay / friendSessions / 60 else nil
	w.soloAvgMin = if solo > 0 then (play - friendPlay) / solo / 60 else nil
	w.payerRate = if w.playerDays > 0 then w.payers / w.playerDays else nil
	w.arpdau = if w.playerDays > 0 then robux / w.playerDays else nil
	return w
end

export type GameReport = {
	game: string,
	live: boolean,
	launchedOn: string?, -- first day with players
	daysLive: number,
	rows: { DayRow }, -- the last TABLE_DAYS days, oldest first
	yesterday: DayRow?,
	robux7: number,
	robuxTotal: number, -- since the challenge start
	d1Week: number?, -- 7-day pooled D1
	avgMinWeek: number?, -- 7-day average session
	risingDays: number, -- consecutive days of more players than the day before, ending yesterday
	gate: { eligible: boolean, pass: boolean, misses: { string } },
	kill: boolean,
	best: { { key: string, robux: number, purchases: number } }, -- top sellers, 7 days
	week: Week, -- the analytics numbers, last 7 days
}

-- One game's numbers through `through` (the last full UTC day).
-- `yesterday` is the `through` day's row; nil until the game has players.
function lib.report(game: string, live: boolean, days: GameDays, through: string): GameReport
	local launchedOn: string? = nil
	for day, d in days do
		if d.players > 0 and day <= through and (launchedOn == nil or day < launchedOn) then
			launchedOn = day
		end
	end
	local daysLive = if launchedOn then lib.dayNumber(through) - lib.dayNumber(launchedOn) + 1 else 0

	-- The last TABLE_DAYS days, from launch on (no rows of zeros before it).
	local rows = {}
	for i = lib.TABLE_DAYS - 1, 0, -1 do
		local day = lib.addDays(through, -i)
		if launchedOn and day >= launchedOn then
			table.insert(rows, lib.row(days, day))
		end
	end

	local robux7, returned, cohort, play, ended = 0, 0, 0, 0, 0
	local sellers: { [string]: { robux: number, purchases: number } } = {}
	for i = 0, 6 do
		local day = lib.addDays(through, -i)
		local d = days[day]
		local prior = days[lib.addDays(day, -1)]
		if d then
			robux7 += sum(d.robux)
			-- D1 pools only days whose cohort (the day before) was read too.
			if prior and prior.newPlayers > 0 then
				returned += d.returnedD1
				cohort += prior.newPlayers
			end
			play += d.playSeconds
			ended += d.sessionsEnded
			for key, robux in d.robux do
				local s = sellers[key] or { robux = 0, purchases = 0 }
				s.robux += robux
				s.purchases += d.purchases[key] or 0
				sellers[key] = s
			end
		end
	end
	local best = {}
	for key, s in sellers do
		table.insert(best, { key = key, robux = s.robux, purchases = s.purchases })
	end
	table.sort(best, function(a, b)
		if a.robux ~= b.robux then
			return a.robux > b.robux
		end
		return a.key < b.key
	end)
	while #best > 5 do
		table.remove(best)
	end

	local robuxTotal = 0
	for day, d in days do
		if day >= lib.CHALLENGE_START and day <= through then
			robuxTotal += sum(d.robux)
		end
	end

	local rising = 0
	for i = 0, lib.TABLE_DAYS - 2 do
		local today = days[lib.addDays(through, -i)]
		local before = days[lib.addDays(through, -i - 1)]
		local a = if today then today.players else 0
		local b = if before then before.players else 0
		if a > b then
			rising += 1
		else
			break
		end
	end

	local d1Week = if cohort > 0 then returned / cohort else nil
	local avgMinWeek = if ended > 0 then play / ended / 60 else nil
	local misses = {}
	if d1Week == nil or d1Week < lib.GATE.d1 then
		table.insert(misses, "D1")
	end
	if avgMinWeek == nil or avgMinWeek < lib.GATE.avgMinutes then
		table.insert(misses, "session length")
	end
	if rising < lib.GATE.risingDays then
		table.insert(misses, "rising players")
	end
	local eligible = daysLive >= lib.GATE.afterDays
	return {
		game = game,
		live = live,
		launchedOn = launchedOn,
		daysLive = daysLive,
		rows = rows,
		yesterday = if launchedOn then rows[#rows] else nil,
		robux7 = robux7,
		robuxTotal = robuxTotal,
		d1Week = d1Week,
		avgMinWeek = avgMinWeek,
		risingDays = rising,
		gate = { eligible = eligible, pass = eligible and #misses == 0, misses = misses },
		kill = daysLive >= lib.KILL.afterDays and d1Week ~= nil and d1Week < lib.KILL.d1,
		best = best,
		week = lib.week(days, through),
	}
end

local function pct(x: number?): string
	return if x == nil then "–" else string.format("%d%%", math.floor(x * 100 + 0.5))
end

local function minutes(x: number?): string
	return if x == nil then "–" else string.format("%.1f", x)
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	return (string.gsub(out, "^(%-?),", "%1"))
end

local function gateText(r: GameReport): string
	if not r.live then
		return "not live"
	elseif r.launchedOn == nil then
		return "no players yet"
	elseif r.kill then
		return `**kill signal**: D1 {pct(r.d1Week)} after {r.daysLive} days`
	elseif r.gate.pass then
		return "**passes the gate**"
	elseif not r.gate.eligible then
		return `day {r.daysLive} of {lib.GATE.afterDays}; short on {table.concat(r.gate.misses, ", ")}`
	else
		return `short on {table.concat(r.gate.misses, ", ")}`
	end
end

local function cell(text: string): string
	return (string.gsub(text, "[\r\n`<>|]", " "))
end

local BUCKET_NAMES = {
	m0 = "<1 min",
	m1 = "1-5",
	m5 = "5-10",
	m10 = "10-20",
	m20 = "20-40",
	m40 = "40+",
}

-- The "Analytics, last 7 days" lines for one live game.
function lib.analyticsLines(r: GameReport): { string }
	local w = r.week
	local out = { "", "**Analytics, last 7 days**", "" }
	table.insert(
		out,
		`- Players: {commas(w.playerDays)} player-days, {pct(w.returningShare)} returning,`
			.. ` {commas(w.newPlayers)} new. D1 {pct(r.d1Week)} · D7 {pct(w.d7Week)} · D30 {pct(w.d30Week)}.`
	)
	local buckets = {}
	for _, bound in Metrics.SESSION_BUCKETS do
		local key = `m{bound}`
		local share = if w.sessionsEnded > 0 then (w.sessionLengths[key] or 0) / w.sessionsEnded else nil
		table.insert(buckets, `{BUCKET_NAMES[key]} {pct(share)}`)
	end
	table.insert(
		out,
		`- Time played: {commas(w.sessionsEnded)} sessions, average {minutes(r.avgMinWeek)} min,`
			.. ` {pct(w.longSessionShare)} ran 10+ min ({table.concat(buckets, " · ")}).`
	)
	table.insert(
		out,
		`- Friends: {pct(w.friendJoinShare)} of new players came with a friend; {pct(w.friendShare)} of sessions`
			.. ` had a friend on the server (average {minutes(w.friendAvgMin)} min, solo {minutes(
				w.soloAvgMin
			)});`
			.. ` {commas(w.friendsBrought)} friends brought in by {commas(w.bringers)} players.`
	)
	table.insert(
		out,
		`- Spending: {pct(w.payerRate)} of player-days paid, {commas(w.newPayers)} first-time payers,`
			.. ` {if w.arpdau then string.format("%.2f", w.arpdau) else "–"} Robux per player-day.`
	)
	local items = lib.top(w.robuxByItem, 10)
	local prompted = lib.top(w.prompts, 10)
	if #items > 0 or #prompted > 0 then
		local keys, seen = {}, {}
		for _, list in { items, prompted } do
			for _, e in list do
				if not seen[e.key] then
					seen[e.key] = true
					table.insert(keys, e.key)
				end
			end
		end
		table.insert(out, "")
		table.insert(out, "| Item | Robux | Bought | Prompts | Bought per prompt |")
		table.insert(out, "|---|---:|---:|---:|---:|")
		for _, key in keys do
			local bought = w.purchasesByItem[key] or 0
			local prompts = w.prompts[key] or 0
			table.insert(
				out,
				`| {cell(key)} | {commas(w.robuxByItem[key] or 0)} | {commas(bought)} | {commas(prompts)} | {pct(
					if prompts > 0 then bought / prompts else nil
				)} |`
			)
		end
	end
	local sources = lib.top(w.robuxBySource, 10)
	local promptedFrom = lib.top(w.promptsBySource, 10)
	if #sources > 0 or #promptedFrom > 0 then
		local keys, seen = {}, {}
		for _, list in { sources, promptedFrom } do
			for _, e in list do
				if not seen[e.key] then
					seen[e.key] = true
					table.insert(keys, e.key)
				end
			end
		end
		table.insert(out, "")
		table.insert(out, "| Where in the game | Robux | Bought | Prompts |")
		table.insert(out, "|---|---:|---:|---:|")
		for _, key in keys do
			table.insert(
				out,
				`| {cell(key)} | {commas(w.robuxBySource[key] or 0)} | {commas(w.purchasesBySource[key] or 0)} | {commas(
					w.promptsBySource[key] or 0
				)} |`
			)
		end
	end
	local steps = {}
	for key in w.onboarding do
		table.insert(steps, key)
	end
	table.sort(steps)
	if #steps > 0 then
		local first = w.onboarding[steps[1]]
		local parts = {}
		for _, key in steps do
			local count = w.onboarding[key]
			table.insert(
				parts,
				`{cell(key)} {commas(count)} ({pct(if first > 0 then count / first else nil)})`
			)
		end
		table.insert(out, "")
		table.insert(out, `First minutes (onboarding steps reached): {table.concat(parts, " → ")}`)
	end
	local events = lib.top(w.events, 12)
	if #events > 0 then
		local parts = {}
		for _, e in events do
			table.insert(parts, `{cell(e.key)} {commas(e.value)}`)
		end
		table.insert(out, "")
		table.insert(out, `Game events: {table.concat(parts, " · ")}`)
	end
	return out
end

-- The scoreboard issue body. `json` is the machine-readable block's payload.
function lib.scoreboard(
	reports: { GameReport },
	through: string,
	environment: string,
	updatedAt: string,
	problems: { string }
): (string, { [string]: any })
	local function day(d: string): string
		return `{string.sub(d, 1, 4)}-{string.sub(d, 5, 6)}-{string.sub(d, 7, 8)}`
	end
	local total, total7, yday = 0, 0, 0
	for _, r in reports do
		total += r.robuxTotal
		total7 += r.robux7
		yday += if r.yesterday then r.yesterday.robux else 0
	end
	local out = {
		"# Studio scoreboard",
		"",
		`{environment} counters through {day(through)} (UTC), updated {updatedAt}. Robux are what players paid`
			.. ` in game; earnings are an estimate at {math.floor(lib.CREATOR_SHARE * 100)}% (Premium payouts and`
			.. " website pass sales are not counted). How it works: ops/METRICS.md.",
		"",
		`**Challenge total since {day(lib.CHALLENGE_START)}: {commas(total)} Robux paid, about {commas(
			total * lib.CREATOR_SHARE
		)} earned.** Last 7 days: {commas(total7)}. Yesterday: {commas(yday)}.`,
		"",
		"| Game | Players | New | D1 | Avg min | Robux | Robux 7d | Payers | Next-wave gate |",
		"|---|---:|---:|---:|---:|---:|---:|---:|---|",
	}
	for _, r in reports do
		local y = r.yesterday
		if r.live and y then
			table.insert(
				out,
				`| {r.game} | {y.players} | {y.newPlayers} | {pct(y.d1)} | {minutes(y.avgSessionMin)} | {commas(
					y.robux
				)} | {commas(r.robux7)} | {y.payers} | {gateText(r)} |`
			)
		else
			table.insert(out, `| {r.game} | – | – | – | – | – | – | – | {gateText(r)} |`)
		end
	end
	table.insert(out, "")
	table.insert(
		out,
		`Gate: {lib.GATE.afterDays} days after launch, 7-day D1 at least {pct(lib.GATE.d1)}, average session`
			.. ` {lib.GATE.avgMinutes}+ minutes, players up {lib.GATE.risingDays} days in a row. Kill signal: 7-day D1`
			.. ` under {pct(lib.KILL.d1)} after {lib.KILL.afterDays} days (stopping a game is Alex's call).`
	)

	for _, r in reports do
		if r.live and r.launchedOn then
			table.insert(out, "")
			table.insert(
				out,
				`## {r.game}: live since {day(r.launchedOn)}, 7-day D1 {pct(r.d1Week)}, average session {minutes(
					r.avgMinWeek
				)} min`
			)
			table.insert(out, "")
			table.insert(
				out,
				"| Day | Players | New | D1 | Avg min | Sessions | Robux | Payers | Biggest server |"
			)
			table.insert(out, "|---|---:|---:|---:|---:|---:|---:|---:|---:|")
			for i = #r.rows, 1, -1 do
				local row = r.rows[i]
				table.insert(
					out,
					`| {day(row.day)} | {row.players} | {row.newPlayers} | {pct(row.d1)} | {minutes(
						row.avgSessionMin
					)} | {row.sessions} | {commas(row.robux)} | {row.payers} | {row.peakServerPlayers} |`
				)
			end
			if #r.best > 0 then
				local parts = {}
				for _, b in r.best do
					table.insert(parts, `{b.key} {commas(b.robux)} ({b.purchases})`)
				end
				table.insert(out, "")
				table.insert(out, `Best sellers, 7 days: {table.concat(parts, " · ")}`)
			end
			for _, line in lib.analyticsLines(r) do
				table.insert(out, line)
			end
		end
	end

	if #problems > 0 then
		table.insert(out, "")
		table.insert(out, "## Problems reading metrics")
		table.insert(out, "")
		for _, p in problems do
			table.insert(out, `- {(string.gsub(p, "[\r\n`<>|]", " "))}`)
		end
	end

	local games = {}
	for _, r in reports do
		local rows = {}
		for _, row in r.rows do
			table.insert(rows, row)
		end
		games[r.game] = {
			live = r.live,
			launchedOn = r.launchedOn,
			daysLive = r.daysLive,
			robuxTotal = r.robuxTotal,
			robux7 = r.robux7,
			d1Week = r.d1Week,
			avgMinWeek = r.avgMinWeek,
			risingDays = r.risingDays,
			gate = r.gate,
			kill = r.kill,
			best = r.best,
			days = rows,
			-- Analytics, last 7 days (ops/METRICS.md). Optional: nil = no data.
			d7Week = r.week.d7Week,
			d30Week = r.week.d30Week,
			returningShare7 = r.week.returningShare,
			playerDays7 = r.week.playerDays,
			longSessionShare7 = r.week.longSessionShare,
			sessionLengths7 = topMap(r.week.sessionLengths),
			friendShare = r.week.friendShare,
			friendJoinShare = r.week.friendJoinShare,
			friendAvgMinWeek = r.week.friendAvgMin,
			soloAvgMinWeek = r.week.soloAvgMin,
			friendsBrought7 = r.week.friendsBrought,
			bringers7 = r.week.bringers,
			payerRate7 = r.week.payerRate,
			newPayers7 = r.week.newPayers,
			arpdau7 = r.week.arpdau,
			robuxByItem7 = topMap(r.week.robuxByItem),
			purchasesByItem7 = topMap(r.week.purchasesByItem),
			robuxBySource7 = topMap(r.week.robuxBySource),
			purchasesBySource7 = topMap(r.week.purchasesBySource),
			prompts7 = topMap(r.week.prompts),
			promptsBySource7 = topMap(r.week.promptsBySource),
			onboarding7 = topMap(r.week.onboarding, 40),
			events7 = topMap(r.week.events),
		}
	end
	local json = {
		version = 1,
		environment = environment,
		through = through,
		since = lib.CHALLENGE_START,
		robuxTotal = total,
		robux7 = total7,
		creatorShare = lib.CREATOR_SHARE,
		problems = #problems,
		games = games,
	}
	return table.concat(out, "\n") .. "\n", json
end

-- Wraps the JSON so it can sit in an issue body: "--" never appears inside.
function lib.hiddenBlock(encoded: string): string
	return `<!-- loop-lab-metrics v1\n{(string.gsub(encoded, "%-%-", "- -"))}\n-->\n`
end

return lib
