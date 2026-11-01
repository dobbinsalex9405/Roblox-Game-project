--!strict
-- Pure helpers for tools/feedback/pull.luau, kept separate so they are unit-tested.
-- Reads the "Feedback" DataStore batches written by packages/core/src/Feedback.luau
-- (schema 1) and turns them into a Markdown digest for triage (ops/FEEDBACK.md).

local lib = {}

local DEFAULT_BASE = "https://apis.roblox.com"
local GAME_PATTERN = "^[a-z][a-z0-9%-]*$"
local DAY = 86400

lib.STORE = "Feedback"
lib.ENVIRONMENTS = { "staging", "production" }
lib.ISSUE_LIMIT = 60000 -- GitHub issue bodies stop at 65,536 characters

export type Target = { game: string, environment: string, universeId: number }

export type Report = {
	id: string,
	at: number,
	game: string,
	build: string,
	placeVersion: number,
	server: string,
	category: string,
	rating: number,
	text: string,
	userId: number,
	accountAgeDays: number,
	locale: string,
	sessionSeconds: number,
	pingMs: number,
	position: string,
	platform: string,
	screen: string,
	fps: number,
	context: { [string]: any },
	recentErrors: { { signature: string, message: string, secondsAgo: number } },
	environment: string?, -- added by the reader
}

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

-- Every game and environment in ops/environments.json that has a universe id.
function lib.targets(environments: { [string]: any }, only: string?): { Target }
	local out: { Target } = {}
	local games = {}
	for game, entry in environments do
		if type(entry) == "table" and string.match(game, GAME_PATTERN) then
			table.insert(games, game)
		end
	end
	table.sort(games)
	for _, game in games do
		for _, environment in lib.ENVIRONMENTS do
			if only == nil or only == "all" or only == environment then
				local env = environments[game][environment]
				local universeId = type(env) == "table" and env.universeId or 0
				if type(universeId) == "number" and universeId > 0 and universeId // 1 == universeId then
					table.insert(out, { game = game, environment = environment, universeId = universeId })
				end
			end
		end
	end
	return out
end

-- Open Cloud DataStores v1: list keys with a prefix (one UTC day).
function lib.listUrl(universeId: number, prefix: string, cursor: string?, base: string?): string
	local url = `{checkBase(base)}/datastores/v1/universes/{universeId}/standard-datastores/datastore/entries`
		.. `?datastoreName={encode(lib.STORE)}&prefix={encode(prefix)}&limit=100`
	if cursor and cursor ~= "" then
		url ..= `&cursor={encode(cursor)}`
	end
	return url
end

function lib.entryUrl(universeId: number, key: string, base: string?): string
	return `{checkBase(base)}/datastores/v1/universes/{universeId}/standard-datastores/datastore/entries/entry`
		.. `?datastoreName={encode(lib.STORE)}&entryKey={encode(key)}`
end

-- "2026-11-01" -> unix seconds at 00:00 UTC.
function lib.parseDate(date: string): number
	local y, m, d = string.match(date, "^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
	assert(y and m and d, `dates look like 2026-11-01, got {date}`)
	local year, month, day = tonumber(y) :: number, tonumber(m) :: number, tonumber(d) :: number
	assert(month >= 1 and month <= 12 and day >= 1 and day <= 31, `not a date: {date}`)
	-- Days from civil (Howard Hinnant), exact for the Gregorian calendar.
	local yy = if month <= 2 then year - 1 else year
	local era = yy // 400
	local yoe = yy - era * 400
	local mp = (month + 9) % 12
	local doy = (153 * mp + 2) // 5 + day - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return (era * 146097 + doe - 719468) * DAY
end

-- The DataStore key prefixes ("20261101") for every day from..to, inclusive.
function lib.dayPrefixes(from: string, to: string): { string }
	local first, last = lib.parseDate(from), lib.parseDate(to)
	assert(last >= first, "--to is before --from")
	assert((last - first) / DAY < 62, "pull at most 62 days at a time")
	local out = {}
	local at = first
	while at <= last do
		table.insert(out, os.date("!%Y%m%d", at))
		at += DAY
	end
	return out
end

function lib.dateOf(at: number): string
	return os.date("!%Y-%m-%d", at)
end

-- Checks one stored batch and returns its reports (bad entries are skipped
-- with a reason, never crash the run).
function lib.reportsFrom(batch: any): ({ Report }, string?)
	if type(batch) ~= "table" or type(batch.reports) ~= "table" then
		return {}, "not a feedback batch"
	end
	if batch.schema ~= 1 then
		return {}, `unknown schema {tostring(batch.schema)}`
	end
	local out: { Report } = {}
	for _, report in batch.reports do
		if
			type(report) == "table"
			and type(report.id) == "string"
			and type(report.text) == "string"
			and type(report.category) == "string"
			and type(report.at) == "number"
		then
			report.context = if type(report.context) == "table" then report.context else {}
			report.recentErrors = if type(report.recentErrors) == "table" then report.recentErrors else {}
			table.insert(out, report :: Report)
		end
	end
	return out, nil
end

-- Player text can never ping anyone, link an issue, or break the layout.
function lib.escape(text: string): string
	local out = string.gsub(text, "[\\`*_%[%]<>|#~]", "\\%0")
	out = string.gsub(out, "@", "@\u{200B}")
	out = string.gsub(out, "\n", " / ")
	return out
end

-- A short stable tag for a reporter, so "same player reported twice" is
-- visible without putting user ids in an issue.
-- Exact 32-bit multiply (a plain product can pass 2^53 and lose bits).
local function mul32(a: number, b: number): number
	local high = (bit32.rshift(a, 16) * b) % 65536
	return (high * 65536 + bit32.band(a, 0xFFFF) * b) % 4294967296
end

function lib.reporterTag(userId: number): string
	-- MurmurHash3's 32-bit finalizer over the id, so neighbouring ids look unrelated.
	local h = bit32.bxor(userId % 4294967296, (userId // 4294967296) % 4294967296)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = mul32(h, 0x85EBCA6B)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = mul32(h, 0xC2B2AE35)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return string.format("p%06x", h % 16777216)
end

local function contextLine(context: { [string]: any }): string
	local keys = {}
	for key in context do
		table.insert(keys, key)
	end
	table.sort(keys)
	local parts = {}
	for _, key in keys do
		table.insert(parts, `{key}={lib.escape(tostring(context[key]))}`)
	end
	return table.concat(parts, ", ")
end

local function plural(n: number, word: string): string
	return if n == 1 then `1 {word}` else `{n} {word}s`
end

local function minutes(seconds: number): string
	return `{math.floor(seconds / 60)}m`
end

local function reportLine(report: Report): string
	local rating = if report.rating > 0 then ` · fun {report.rating}/5` else ""
	local head = `- **{os.date("!%H:%M", report.at)}** {report.environment or "?"} · v{report.placeVersion}`
		.. ` · {string.sub(report.build, 1, 7)} · {report.platform} {report.screen} · {report.fps} fps`
		.. ` · {report.pingMs} ms · {minutes(report.sessionSeconds)} in{rating} · {lib.reporterTag(
			report.userId
		)}`
	local lines = { head, `  > {lib.escape(report.text)}` }
	local context = contextLine(report.context)
	if context ~= "" then
		table.insert(
			lines,
			`  - state: {context}` .. (if report.position ~= "" then ` · at {report.position}` else "")
		)
	end
	for _, err in report.recentErrors do
		table.insert(
			lines,
			`  - error \`{err.signature}\` {err.secondsAgo}s before: {lib.escape(err.message)}`
		)
	end
	return table.concat(lines, "\n")
end

export type Digest = {
	markdown: string,
	total: number,
	bugs: number,
	ideas: number,
	other: number,
}

-- One Markdown digest for a set of reports, grouped by game then category.
-- Bugs that share a client error signature are listed together.
function lib.digest(reports: { Report }, title: string, limit: number?): Digest
	local byGame: { [string]: { Report } } = {}
	local counts = { bug = 0, idea = 0, other = 0 }
	for _, report in reports do
		byGame[report.game] = byGame[report.game] or {}
		table.insert(byGame[report.game], report)
		if counts[report.category] ~= nil then
			counts[report.category] += 1
		end
	end
	local games = {}
	for game in byGame do
		table.insert(games, game)
	end
	table.sort(games)

	local out = {
		`# {title}`,
		"",
		`{#reports} reports: {plural(counts.bug, "bug")}, {plural(counts.idea, "idea")}, {counts.other} other.`
			.. " Player text is shown after Roblox's filter. Triage rules: ops/FEEDBACK.md.",
	}
	if #reports == 0 then
		table.insert(out, "")
		table.insert(out, "No feedback in this window.")
	end

	for _, game in games do
		local list = byGame[game]
		table.sort(list, function(a, b)
			return a.at < b.at
		end)
		local ratingSum, ratingCount = 0, 0
		local players: { [number]: boolean } = {}
		local playerCount = 0
		for _, report in list do
			if report.rating > 0 then
				ratingSum += report.rating
				ratingCount += 1
			end
			if not players[report.userId] then
				players[report.userId] = true
				playerCount += 1
			end
		end
		table.insert(out, "")
		table.insert(out, `## {game}`)
		table.insert(out, "")
		local fun = if ratingCount > 0
			then string.format("average fun %.1f/5 from %d ratings", ratingSum / ratingCount, ratingCount)
			else "no fun ratings"
		table.insert(out, `{plural(#list, "report")} from {plural(playerCount, "player")}, {fun}.`)

		for _, category in { "bug", "idea", "other" } do
			local section = {}
			for _, report in list do
				if report.category == category then
					table.insert(section, report)
				end
			end
			if #section > 0 then
				local heading = if category == "bug"
					then "Bugs"
					elseif category == "idea" then "Ideas"
					else "Other"
				table.insert(out, "")
				table.insert(out, `### {heading} ({#section})`)
				if category == "bug" then
					-- Group bugs by their newest client error, then the rest.
					local groups: { [string]: { Report } } = {}
					local order: { string } = {}
					local loose: { Report } = {}
					for _, report in section do
						local first = report.recentErrors[1]
						if first then
							if groups[first.signature] == nil then
								groups[first.signature] = {}
								table.insert(order, first.signature)
							end
							table.insert(groups[first.signature], report)
						else
							table.insert(loose, report)
						end
					end
					for _, signature in order do
						local group = groups[signature]
						table.insert(out, "")
						table.insert(
							out,
							`**Error \`{signature}\`** ({#group} reports): {lib.escape(
								group[1].recentErrors[1].message
							)}`
						)
						for _, report in group do
							table.insert(out, reportLine(report))
						end
					end
					if #loose > 0 then
						table.insert(out, "")
						if #order > 0 then
							table.insert(out, "**No client error attached**")
						end
						for _, report in loose do
							table.insert(out, reportLine(report))
						end
					end
				else
					table.insert(out, "")
					for _, report in section do
						table.insert(out, reportLine(report))
					end
				end
			end
		end
	end

	local markdown = table.concat(out, "\n") .. "\n"
	local cap = limit or lib.ISSUE_LIMIT
	if #markdown > cap then
		local note = "\n\n_Cut to fit a GitHub issue. The full list is in the run's feedback artifact._\n"
		local cut = string.sub(markdown, 1, cap - #note)
		-- Do not end inside a UTF-8 character.
		while #cut > 0 and utf8.len(cut) == nil do
			cut = string.sub(cut, 1, #cut - 1)
		end
		markdown = cut .. note
	end
	return {
		markdown = markdown,
		total = #reports,
		bugs = counts.bug,
		ideas = counts.idea,
		other = counts.other,
	}
end

return lib
