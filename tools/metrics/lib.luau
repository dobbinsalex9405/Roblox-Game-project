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
	if type(value) ~= "table" or value.schema ~= Metrics.SCHEMA or value.day ~= day then
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
	sessions: number,
	d1: number?, -- returned on day 1 / new players the day before
	avgSessionMin: number?,
	robux: number,
	purchases: number,
	payers: number,
	peakServerPlayers: number,
}

function lib.row(days: GameDays, day: string): DayRow
	local d = days[day] or Metrics.empty(day)
	local before = days[lib.addDays(day, -1)]
	local cohort = if before then before.newPlayers else 0
	return {
		day = day,
		players = d.players,
		newPlayers = d.newPlayers,
		sessions = d.sessions,
		d1 = if cohort > 0 then d.returnedD1 / cohort else nil,
		avgSessionMin = if d.sessionsEnded > 0 then d.playSeconds / d.sessionsEnded / 60 else nil,
		robux = sum(d.robux),
		purchases = sum(d.purchases),
		payers = d.payers,
		peakServerPlayers = d.peakServerPlayers,
	}
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
