--!strict
-- Plain-code prefilter for the daily feedback digest. It runs before any
-- Claude triage, so the scheduled run reads a short, ranked list instead of
-- every report. It is tuned to over-escalate: when in doubt a report goes on
-- the "Needs triage" list, because a missed bug costs more than a wasted look.
--
--   1. Rate caps: at most `maxPerReporter` reports from one player per run
--      count (the rest are dropped as spam), and at most `maxPerGame` groups
--      per game are listed (the rest are counted, never silently lost).
--   2. Dedupe: reports with the same newest client error, or the same text
--      once lower-cased and stripped of punctuation, become one group.
--   3. Keyword tags decide the priority of each group:
--        sev1  lost progress or items, Robux / purchases, exploits, crashes
--        sev2  stuck, broken, can't, won't load, glitches; also every report
--              filed as Bug and every report with a client error attached
--        perf  lag, low frame rate
--        check a fun rating of 1 or 2 with no other signal
--      Ideas and praise with none of these stay off the list (they are still
--      in the digest below it).

local Prefilter = {}

export type Priority = "sev1" | "sev2" | "perf" | "check"

export type Item = {
	key: string,
	fingerprint: string, -- stable across days: hash of game + error signature, or game + normalized text
	game: string,
	priority: Priority,
	tags: { string },
	reports: number,
	players: number,
	categories: { string },
	reportIds: { string },
	errors: { string },
	lowestRating: number, -- 0 when nobody rated
	sample: string,
	firstAt: number,
	lastAt: number,
}

export type Result = {
	items: { Item },
	quiet: number, -- reports that needed no triage
	cappedReporters: number, -- reports dropped by the per-reporter cap
	cappedGroups: { [string]: number }, -- per game, groups beyond maxPerGame
	overflow: { Item }, -- those groups, for triage.json
}

export type Options = {
	maxPerGame: number?, -- default 40
	maxPerReporter: number?, -- default 5
	maxIdsPerItem: number?, -- default 20
}

-- FNV-1a, 32 bit, as 8 hex characters (exact: the multiply is split so it never passes 2^53).
local function mul32(a: number, b: number): number
	local high = (bit32.rshift(a, 16) * b) % 65536
	return (high * 65536 + bit32.band(a, 0xFFFF) * b) % 4294967296
end

function Prefilter.fingerprint(key: string): string
	local h = 2166136261
	for i = 1, #key do
		h = mul32(bit32.bxor(h, string.byte(key, i)), 16777619)
	end
	return string.format("%08x", h)
end

local RANK: { [string]: number } = { sev1 = 1, sev2 = 2, perf = 3, check = 4 }

-- Words and phrases, matched on whole words of the normalized text.
local KEYWORDS: { [string]: { string } } = {
	sev1 = {
		"lost",
		"lose",
		"losing",
		"gone",
		"disappeared",
		"disappear",
		"disappears",
		"vanished",
		"wiped",
		"reset",
		"deleted",
		"rollback",
		"rolled back",
		"robux",
		"purchase",
		"purchased",
		"bought",
		"buy",
		"paid",
		"pay",
		"refund",
		"charged",
		"scam",
		"scammed",
		"dupe",
		"duped",
		"duplicate",
		"exploit",
		"exploiter",
		"exploiters",
		"exploiting",
		"hack",
		"hacker",
		"hackers",
		"hacking",
		"hacked",
		"cheat",
		"cheater",
		"cheaters",
		"cheating",
		"crash",
		"crashed",
		"crashes",
		"crashing",
		"kicked",
		"data",
		"save",
		"saved",
		"progress",
		"didnt get",
		"never got",
		"not get",
		"took my",
		"stole my",
	},
	sev2 = {
		"stuck",
		"cant",
		"cannot",
		"wont",
		"couldnt",
		"doesnt work",
		"dont work",
		"didnt work",
		"not working",
		"isnt working",
		"broken",
		"broke",
		"freeze",
		"freezes",
		"frozen",
		"froze",
		"black screen",
		"not loading",
		"loading",
		"nothing happens",
		"nothing happened",
		"softlock",
		"fell through",
		"fall through",
		"bug",
		"bugs",
		"bugged",
		"buggy",
		"glitch",
		"glitches",
		"glitched",
		"glitchy",
		"error",
		"invisible",
		"missing",
		"doesnt let",
		"wont let",
		"teleported",
		"respawn",
	},
	perf = {
		"lag",
		"laggy",
		"lagging",
		"lags",
		"fps",
		"slow",
		"stutter",
		"stuttering",
		"ping",
		"delay",
		"delayed",
	},
}

-- Lower-case words only: apostrophes dropped ("can't" -> "cant"), everything
-- else that is not a letter or digit becomes a single space.
function Prefilter.normalize(text: string): string
	local lower = string.lower(text)
	local pieces = {}
	local ok = pcall(function()
		for _, code in utf8.codes(lower) do
			local keep = (code >= 48 and code <= 57) -- digits
				or (code >= 97 and code <= 122) -- a-z
				or (code >= 0xC0 and code < 0x2000) -- accented and non-Latin letters
				or (code >= 0x3040 and code < 0xFE00) -- CJK and other scripts
			-- Apostrophes vanish ("can't" -> "cant"); anything else that is not a letter is a space.
			if code ~= 39 and code ~= 0x2019 then
				table.insert(pieces, if keep then utf8.char(code) else " ")
			end
		end
	end)
	local out = if ok then table.concat(pieces) else string.gsub(string.gsub(lower, "'", ""), "[^%w]", " ")
	out = string.gsub(out, "%s+", " ")
	return string.match(out, "^%s*(.-)%s*$") or ""
end

-- Every keyword tag found in the text, sorted.
function Prefilter.tags(text: string): { [string]: { string } }
	local padded = ` {Prefilter.normalize(text)} `
	local found: { [string]: { string } } = {}
	for level, words in KEYWORDS do
		for _, word in words do
			if string.find(padded, ` {word} `, 1, true) then
				found[level] = found[level] or {}
				table.insert(found[level], word)
			end
		end
	end
	for _, list in found do
		table.sort(list)
	end
	return found
end

-- The priority of one report, or nil when it needs no triage.
function Prefilter.priority(report: { [string]: any }): (Priority?, { string })
	local found = Prefilter.tags(report.text or "")
	local tags: { string } = {}
	for _, level in { "sev1", "sev2", "perf" } do
		for _, word in found[level] or {} do
			table.insert(tags, word)
		end
	end
	local hasError = type(report.recentErrors) == "table" and #report.recentErrors > 0
	if hasError then
		table.insert(tags, "client-error")
	end
	if found.sev1 then
		return "sev1", tags
	elseif found.sev2 or report.category == "bug" or hasError then
		return "sev2", tags
	elseif found.perf then
		return "perf", tags
	elseif type(report.rating) == "number" and report.rating >= 1 and report.rating <= 2 then
		table.insert(tags, "low-rating")
		return "check", tags
	end
	return nil, tags
end

local function addUnique(list: { string }, value: string)
	if not table.find(list, value) then
		table.insert(list, value)
	end
end

function Prefilter.run(reports: { { [string]: any } }, options: Options?): Result
	local maxPerGame = options and options.maxPerGame or 40
	local maxPerReporter = options and options.maxPerReporter or 5
	local maxIds = options and options.maxIdsPerItem or 20

	local sorted = table.clone(reports)
	table.sort(sorted, function(a, b)
		return (a.at or 0) < (b.at or 0)
	end)

	local perReporter: { [any]: number } = {}
	local groups: { [string]: Item } = {}
	local groupPlayers: { [string]: { [any]: boolean } } = {}
	local order: { string } = {}
	local quiet, capped = 0, 0

	for _, report in sorted do
		local reporter = report.userId or "?"
		perReporter[reporter] = (perReporter[reporter] or 0) + 1
		if perReporter[reporter] > maxPerReporter then
			capped += 1
			continue
		end
		local priority, tags = Prefilter.priority(report)
		if priority == nil then
			quiet += 1
			continue
		end
		local game = tostring(report.game or "?")
		local firstError = type(report.recentErrors) == "table" and report.recentErrors[1]
		local key = if firstError
			then `{game}|error:{firstError.signature}`
			else `{game}|text:{Prefilter.normalize(report.text or "")}`
		local item = groups[key]
		if item == nil then
			item = {
				key = key,
				fingerprint = Prefilter.fingerprint(key),
				game = game,
				priority = priority,
				tags = {},
				reports = 0,
				players = 0,
				categories = {},
				reportIds = {},
				errors = {},
				lowestRating = 0,
				sample = report.text or "",
				firstAt = report.at or 0,
				lastAt = report.at or 0,
			}
			groups[key] = item
			groupPlayers[key] = {}
			table.insert(order, key)
		end
		local it = item :: Item
		if RANK[priority] < RANK[it.priority] then
			it.priority = priority
		end
		for _, tag in tags do
			addUnique(it.tags, tag)
		end
		it.reports += 1
		if not groupPlayers[key][reporter] then
			groupPlayers[key][reporter] = true
			it.players += 1
		end
		addUnique(it.categories, tostring(report.category))
		if #it.reportIds < maxIds and type(report.id) == "string" then
			table.insert(it.reportIds, report.id)
		end
		if type(report.recentErrors) == "table" then
			for _, err in report.recentErrors do
				addUnique(it.errors, tostring(err.signature))
			end
		end
		local rating = report.rating
		if type(rating) == "number" and rating > 0 and (it.lowestRating == 0 or rating < it.lowestRating) then
			it.lowestRating = rating
		end
		it.lastAt = math.max(it.lastAt, report.at or 0)
	end

	local all: { Item } = {}
	for _, key in order do
		table.sort(groups[key].tags)
		table.sort(groups[key].categories)
		table.insert(all, groups[key])
	end
	table.sort(all, function(a, b)
		if RANK[a.priority] ~= RANK[b.priority] then
			return RANK[a.priority] < RANK[b.priority]
		end
		if a.players ~= b.players then
			return a.players > b.players
		end
		if a.reports ~= b.reports then
			return a.reports > b.reports
		end
		return a.firstAt < b.firstAt
	end)

	local items: { Item } = {}
	local perGame: { [string]: number } = {}
	local cappedGroups: { [string]: number } = {}
	local overflow: { Item } = {}
	for _, item in all do
		perGame[item.game] = (perGame[item.game] or 0) + 1
		if perGame[item.game] <= maxPerGame then
			table.insert(items, item)
		else
			cappedGroups[item.game] = (cappedGroups[item.game] or 0) + 1
			table.insert(overflow, item)
		end
	end

	return {
		items = items,
		quiet = quiet,
		cappedReporters = capped,
		cappedGroups = cappedGroups,
		overflow = overflow,
	}
end

-- A machine-readable copy of the list for the scheduled Claude run, as an
-- HTML comment GitHub does not render. It carries no player text (only ids,
-- tags and counts), so nothing a player typed can end the comment early.
-- `extra` adds top-level fields (the error sweep's `errors` and `stop`).
function Prefilter.block(result: Result, encodeJson: (any) -> string, extra: { [string]: any }?): string
	local items = {}
	for _, item in result.items do
		table.insert(items, {
			fp = item.fingerprint,
			game = item.game,
			priority = item.priority,
			tags = item.tags,
			reports = item.reports,
			players = item.players,
			categories = item.categories,
			reportIds = item.reportIds,
			errors = item.errors,
			lowestRating = item.lowestRating,
		})
	end
	local doc: { [string]: any } = { version = 1, items = items, overflowGroups = #result.overflow }
	for k, v in extra or {} do
		doc[k] = v
	end
	local json = encodeJson(doc)
	json = string.gsub(json, "%-%-", "- -") -- belt and braces: "--" can never appear inside the comment
	return `<!-- loop-lab-triage v1\n{json}\n-->`
end

-- The "Needs triage" section at the top of the digest issue. `escape` is
-- tools/feedback/lib's escape, passed in to keep this module standalone.
function Prefilter.markdown(result: Result, escape: (string) -> string): string
	local out = { "## Needs triage", "" }
	if #result.items == 0 then
		table.insert(out, "Nothing escalated by the prefilter.")
	else
		table.insert(
			out,
			"Ranked by the plain-code prefilter (ops/FEEDBACK.md). Same text or same client error = one line."
		)
		table.insert(out, "")
		for index, item in result.items do
			local who = `{item.players} player{if item.players == 1 then "" else "s"}`
			local how = `{item.reports} report{if item.reports == 1 then "" else "s"}`
			local tags = if #item.tags > 0 then ` · {table.concat(item.tags, ", ")}` else ""
			local errors = if #item.errors > 0 then ` · errors {table.concat(item.errors, ", ")}` else ""
			local rating = if item.lowestRating > 0 then ` · lowest fun {item.lowestRating}/5` else ""
			table.insert(
				out,
				`{index}. **{item.priority}** {item.game} · fp:{item.fingerprint} · {who}, {how} · {table.concat(
					item.categories,
					"/"
				)}{tags}{errors}{rating}`
			)
			table.insert(out, `   > {escape(item.sample)}`)
			table.insert(out, `   ids: {table.concat(item.reportIds, " ")}`)
		end
	end
	local notes = {}
	if result.cappedReporters > 0 then
		table.insert(
			notes,
			`{result.cappedReporters} reports over the per-player cap were dropped as likely spam`
		)
	end
	local games = {}
	for game in result.cappedGroups do
		table.insert(games, game)
	end
	table.sort(games)
	for _, game in games do
		table.insert(
			notes,
			`{result.cappedGroups[game]} more {game} groups did not fit; see the artifact's triage.json`
		)
	end
	table.insert(notes, `{result.quiet} reports needed no triage (ideas and praise without warning words)`)
	table.insert(out, "")
	table.insert(out, `_{table.concat(notes, "; ")}._`)
	return table.concat(out, "\n") .. "\n"
end

return Prefilter
