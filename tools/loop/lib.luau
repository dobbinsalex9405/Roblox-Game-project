--!strict
-- The update loop's rules engine (ops/UPDATE_LOOP.md). Pure, so it is unit-tested.
--
-- In: the scoreboard's `loop-lab-metrics v1` JSON (tools/metrics/lib.luau, plus the
-- optional fields the analytics work adds), the Production release tags
-- (`<game>/production/v<n>` with the UTC day they were made) and the open `bug`
-- issues. Out: per game, the signals the numbers raise, the one focus for this
-- week's update, a check on the latest release, and the questions only Alex can
-- answer. The daily Claude run acts on it; nothing here changes a game.

local config = require("./config")
local metricsLib = require("../metrics/lib")

local lib = {}

lib.config = config
lib.PLAN_VERSION = 1

-- Focus kinds, in the order the week takes them when levels tie: stop the
-- damage, then get players in, then keep them (first day, then each session,
-- then the week), then earn, then grow through friends, then feed engaged players.
lib.KINDS = { "fix", "discovery", "onboarding", "depth", "return", "monetization", "social", "content" }
lib.LEVELS = { "urgent", "high", "normal" }

-- What each focus means for the update brief (the full playbook is in ops/UPDATE_LOOP.md).
lib.KIND_TEXT = {
	fix = "fix what broke: bugs, errors, a bad release",
	discovery = "get players in: icon, thumbnails, title, description",
	onboarding = "first session: tutorial, first reward, first goal",
	depth = "session length: goals, pacing, reasons to stay",
	["return"] = "come back tomorrow: daily rewards, streaks, timers",
	monetization = "shop and prices: offers, placement, the price ladder",
	social = "play with friends: invites, co-op, friend bonuses",
	content = "new content for engaged players",
	launch = "not live yet: get it on Production",
}

local GAME_PATTERN = "^[a-z][a-z0-9%-]*$"
local LAUNCH_WHY = "not live on Production yet: the update is the launch itself"

export type Signal = {
	kind: string,
	level: string,
	rule: string,
	why: string,
}

export type Release = { game: string, version: number, day: string, tag: string }

export type BugCounts = { sev1: number, sev2: number, sev3: number, total: number, numbers: { number } }

export type Window = {
	days: number,
	players: number, -- player-days
	playersPerDay: number?,
	newPlayers: number,
	sessions: number,
	avgMin: number?,
	robux: number,
	robuxPerPlayer: number?,
	payers: number,
	payerRate: number?,
	d1: number?,
	d1Cohort: number,
}

export type Review = {
	tag: string,
	day: string,
	previous: string?,
	postDays: number,
	verdict: string, -- "worse so far" (1 day) | "too early" | "too few players" | "worse" | "mixed" | "better" | "softer" | "flat"
	changes: { [string]: number }, -- relative change (d1: absolute points)
	worse: { string },
}

export type GamePlan = {
	game: string,
	stage: string,
	daysLive: number,
	focus: string,
	focusWhy: string,
	signals: { Signal },
	alex: { string },
	unjudged: { string },
	numbers: { [string]: any },
	bugs: BugCounts,
	release: Review?,
}

export type Plan = {
	version: number,
	today: string,
	through: string?,
	metricsVersion: number?,
	games: { [string]: GamePlan },
	order: { string },
	problems: { string },
	alex: { string }, -- studio-wide questions for Alex, before the per-game ones
	audience: { [string]: string }, -- game -> "16+" | "all"
}

local function num(v: any): number?
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then
		return v
	end
	return nil
end

local function clean(s: string): string
	return (string.gsub(s, "[\r\n`<>|]", " "))
end

local function pct(x: number?): string
	return if x == nil then "–" else string.format("%d%%", math.floor(x * 100 + 0.5))
end

local function signedPct(x: number): string
	local v = math.floor(math.abs(x) * 100 + 0.5)
	return if x < 0 then `-{v}%` else `+{v}%`
end

local function minutes(x: number?): string
	return if x == nil then "–" else string.format("%.1f min", x)
end

local function rank(list: { string }, value: string): number
	return table.find(list, value) or #list + 1
end

-- The JSON in a scoreboard issue body (the hidden block), or a bare JSON document.
-- Returns nil and a reason when there is none.
function lib.extractMetrics(raw: string, decode: (string) -> any): (any, string?)
	-- An issue edited in the GitHub web page comes back with CRLF line ends.
	local text = string.gsub(raw, "\r", "")
	local inner = string.match(text, "<!%-%- loop%-lab%-metrics v1\n(.-)\n%-%->")
	local source = inner or text
	if inner then
		-- lib.hiddenBlock wrote every "--" as "- -" so the comment could not end early.
		source = string.gsub(inner, "%- %-", "--")
	elseif not string.match(text, "^%s*{") then
		return nil, "no loop-lab-metrics block in the scoreboard issue"
	end
	local ok, value = pcall(decode, source)
	if not ok or type(value) ~= "table" then
		return nil, "the metrics block is not valid JSON"
	end
	if value.version ~= 1 or type(value.games) ~= "table" then
		return nil, `unexpected metrics version {tostring(value.version)}`
	end
	return value, nil
end

-- `git for-each-ref` lines "<game>/production/v<n>|YYYYMMDD" -> releases, oldest first.
function lib.parseReleases(text: string): { Release }
	local out: { Release } = {}
	for line in string.gmatch(text, "[^\n]+") do
		local game, version, day =
			string.match(line, "^%s*([%w%-]+)/production/v(%d+)|(%d%d%d%d%d%d%d%d)%s*$")
		if game and version and day and string.match(game, GAME_PATTERN) then
			table.insert(out, {
				game = game,
				version = tonumber(version) :: number,
				day = day,
				tag = `{game}/production/v{version}`,
			})
		end
	end
	table.sort(out, function(a, b)
		if a.game ~= b.game then
			return a.game < b.game
		end
		return a.version < b.version
	end)
	return out
end

-- Open `bug` issues (gh issue list --json number,labels) -> counts per game label.
-- Issues without a game label count under "studio".
function lib.bugCounts(issues: any, games: { string }): { [string]: BugCounts }
	local out: { [string]: BugCounts } = {}
	local function counts(game: string): BugCounts
		local c = out[game]
		if c == nil then
			c = { sev1 = 0, sev2 = 0, sev3 = 0, total = 0, numbers = {} }
			out[game] = c
		end
		return c
	end
	if type(issues) ~= "table" then
		return out
	end
	for _, issue in issues do
		if type(issue) == "table" and type(issue.labels) == "table" then
			local game, sev = "studio", nil
			for _, label in issue.labels do
				local name = if type(label) == "table" then label.name else label
				if type(name) == "string" then
					if table.find(games, name) then
						game = name
					elseif string.match(name, "^sev[123]$") then
						sev = name
					end
				end
			end
			local c = counts(game)
			c.total += 1
			if sev == "sev1" then
				c.sev1 += 1
			elseif sev == "sev2" then
				c.sev2 += 1
			elseif sev == "sev3" then
				c.sev3 += 1
			end
			local n = num(issue.number)
			if n then
				table.insert(c.numbers, n)
			end
		end
	end
	for _, c in out do
		table.sort(c.numbers)
	end
	return out
end

-- Pooled numbers over the scoreboard's day rows from `from` to `to` inclusive.
function lib.window(rows: { any }, from: string, to: string): Window
	local byDay: { [string]: any } = {}
	for _, row in rows do
		if type(row) == "table" and type(row.day) == "string" then
			byDay[row.day] = row
		end
	end
	local w = {
		days = 0,
		players = 0,
		newPlayers = 0,
		sessions = 0,
		robux = 0,
		payers = 0,
		d1Cohort = 0,
	}
	local minuteWeight, minuteSum, returned = 0, 0, 0
	local day = from
	while day <= to do
		local row = byDay[day]
		if row then
			w.days += 1
			w.players += num(row.players) or 0
			w.newPlayers += num(row.newPlayers) or 0
			local sessions = num(row.sessions) or 0
			w.sessions += sessions
			w.robux += num(row.robux) or 0
			w.payers += num(row.payers) or 0
			local avg = num(row.avgSessionMin)
			if avg and sessions > 0 then
				minuteSum += avg * sessions
				minuteWeight += sessions
			end
			-- D1 of a day = returned / the day before's new players; pool the counts.
			local d1 = num(row.d1)
			local prior = byDay[metricsLib.addDays(day, -1)]
			local cohort = if prior then num(prior.newPlayers) or 0 else 0
			if d1 and cohort > 0 then
				returned += d1 * cohort
				w.d1Cohort += cohort
			end
		end
		day = metricsLib.addDays(day, 1)
	end
	local out: Window = w :: any
	out.playersPerDay = if w.days > 0 then w.players / w.days else nil
	out.avgMin = if minuteWeight > 0 then minuteSum / minuteWeight else nil
	out.robuxPerPlayer = if w.players > 0 then w.robux / w.players else nil
	out.payerRate = if w.players > 0 then w.payers / w.players else nil
	out.d1 = if w.d1Cohort > 0 then returned / w.d1Cohort else nil
	return out
end

local function change(after: number?, before: number?): number?
	if after == nil or before == nil or before <= 0 then
		return nil
	end
	return after / before - 1
end

-- Compares the days after a release with the days before it.
-- `fast` uses only the first days after (a rollback question); otherwise a full review.
function lib.review(rows: { any }, release: Release, previous: Release?, through: string): Review
	local R = config.release
	local gap = metricsLib.dayNumber(through) - metricsLib.dayNumber(release.day)
	local postDays = math.max(0, math.min(gap, R.reviewDays))
	local review: Review = {
		tag = release.tag,
		day = release.day,
		previous = if previous then previous.tag else nil,
		postDays = postDays,
		verdict = "too early",
		changes = {},
		worse = {},
	}
	if postDays < 1 then
		return review
	end
	-- The release day itself is mixed, so it belongs to neither side.
	local before =
		lib.window(rows, metricsLib.addDays(release.day, -R.reviewDays), metricsLib.addDays(release.day, -1))
	local after =
		lib.window(rows, metricsLib.addDays(release.day, 1), metricsLib.addDays(release.day, postDays))
	if (before.playersPerDay or 0) < config.sample.baselinePlayers or after.days == 0 then
		review.verdict = "too few players"
		return review
	end

	local players = change(after.playersPerDay, before.playersPerDay)
	local session = change(after.avgMin, before.avgMin)
	local rpp = change(after.robuxPerPlayer, before.robuxPerPlayer)
	local d1 = if after.d1 ~= nil
			and before.d1 ~= nil
			and after.d1Cohort >= 10
		then after.d1 - before.d1
		else nil
	-- Each metric is worse (past its rollback line), up (better), down (by `better` or more) or steady.
	local up, down = false, false
	local function judge(name: string, value: number?, worseAt: number, text: string)
		if value == nil then
			return
		end
		review.changes[name] = value
		if value <= -worseAt then
			table.insert(review.worse, text)
		elseif value >= R.better then
			up = true
		elseif value <= -R.better then
			down = true
		end
	end
	judge("players", players, R.playersDrop, `players {signedPct(players or 0)}`)
	judge("avgSession", session, R.sessionDrop, `average session {signedPct(session or 0)}`)
	if before.robux >= config.sample.baselineRobux * before.days then
		judge("robuxPerPlayer", rpp, R.robuxPerPlayerDrop, `Robux per player {signedPct(rpp or 0)}`)
	end
	if d1 then
		review.changes.d1Points = d1
		if d1 <= -R.d1DropPoints then
			table.insert(review.worse, `D1 -{math.floor(math.abs(d1) * 100 + 0.5)} points`)
		elseif d1 >= 0.02 then
			up = true
		elseif d1 <= -0.02 then
			down = true
		end
	end
	if #review.worse > 0 then
		review.verdict = "worse"
	elseif postDays < R.reviewAfterDays then
		review.verdict = "too early"
	elseif up and down then
		review.verdict = "mixed"
	elseif up then
		review.verdict = "better"
	elseif down then
		review.verdict = "softer"
	else
		review.verdict = "flat"
	end
	return review
end

-- The step of an onboarding funnel ("01:Name" -> players) that loses the most players.
function lib.worstStep(funnel: any): (string?, number?)
	if type(funnel) ~= "table" then
		return nil, nil
	end
	local steps = {}
	for key, count in funnel do
		if type(key) == "string" and num(count) then
			table.insert(steps, key)
		end
	end
	table.sort(steps)
	local worst, worstLoss = nil, 0
	for i = 2, #steps do
		local before = funnel[steps[i - 1]] :: number
		local after = funnel[steps[i]] :: number
		if before >= 10 then
			local loss = 1 - after / before
			if loss > worstLoss then
				worst, worstLoss = `{steps[i - 1]} to {steps[i]}`, loss
			end
		end
	end
	return worst, if worst then worstLoss else nil
end

-- Items whose purchase prompt opens often but rarely ends in a purchase.
-- `purchases` (purchasesByItem7) is exact when the analytics have it; otherwise the
-- scoreboard's best sellers (the top 5 by Robux) stand in, and an item missing from a
-- full list of 5 may still sell, so it is not judged.
function lib.weakItems(prompts: any, best: any, purchases: any?): { string }
	if type(prompts) ~= "table" then
		return {}
	end
	local bought: { [string]: number } = {}
	local listed = 0
	if type(purchases) == "table" then
		for key, n in purchases do
			if type(key) == "string" and num(n) then
				bought[key] = n
			end
		end
		listed = 0 -- an item absent from the exact map sold nothing
	elseif type(best) == "table" then
		for _, b in best do
			if type(b) == "table" and type(b.key) == "string" then
				bought[b.key] = num(b.purchases) or 0
				listed += 1
			end
		end
	end
	local complete = listed < 5
	local out = {}
	for key, count in prompts do
		local n = num(count)
		if
			type(key) == "string"
			and n
			and n >= config.sample.prompts
			and (complete or bought[key] ~= nil)
		then
			local rate = (bought[key] or 0) / n
			if rate < config.targets.conversion then
				table.insert(out, { key = key, rate = rate, prompts = n })
			end
		end
	end
	table.sort(out, function(a, b)
		if a.prompts ~= b.prompts then
			return a.prompts > b.prompts
		end
		return a.key < b.key
	end)
	local text = {}
	for i, item in out do
		if i > 3 then
			break
		end
		table.insert(text, `{clean(item.key)} {pct(item.rate)} of {item.prompts} prompts`)
	end
	return text
end

local function stageOf(daysLive: number): string
	if daysLive <= 7 then
		return "launch week"
	elseif daysLive <= 14 then
		return "first fortnight"
	end
	return "steady"
end

-- One game's plan.
function lib.planGame(
	game: string,
	m: any,
	through: string,
	releases: { Release },
	bugs: BugCounts?
): GamePlan
	local T, S = config.targets, config.sample
	local signals: { Signal } = {}
	local alex: { string } = {}
	local unjudged: { string } = {}
	local counts: BugCounts = bugs or { sev1 = 0, sev2 = 0, sev3 = 0, total = 0, numbers = {} }
	local function signal(kind: string, level: string, rule: string, why: string)
		table.insert(signals, { kind = kind, level = level, rule = rule, why = why })
	end

	-- Bugs come first whether or not the game is live.
	if counts.sev1 > 0 then
		signal("fix", "urgent", "open sev1", `{counts.sev1} open sev1 bug(s): fix today, hotfix lane`)
	end
	if counts.sev2 >= config.bugs.sev2 then
		signal("fix", "high", "sev2 pile", `{counts.sev2} open sev2 bugs (limit {config.bugs.sev2})`)
	end

	local live = type(m) == "table" and m.live == true and type(m.launchedOn) == "string"
	local daysLive = if live then num(m.daysLive) or 0 else 0
	local plan: GamePlan = {
		game = game,
		stage = if live then stageOf(daysLive) else "not live",
		daysLive = daysLive,
		focus = "launch",
		focusWhy = LAUNCH_WHY,
		signals = signals,
		alex = alex,
		unjudged = unjudged,
		numbers = {},
		bugs = counts,
		release = nil,
	}

	if live then
		local rows = if type(m.days) == "table" then m.days else {}
		local w7 = lib.window(rows, metricsLib.addDays(through, -6), through)
		local prev7 = lib.window(rows, metricsLib.addDays(through, -13), metricsLib.addDays(through, -7))
		local d1 = num(m.d1Week) or w7.d1
		local avgMin = num(m.avgMinWeek) or w7.avgMin
		local payerRate = num(m.payerRate7) or w7.payerRate
		local d7 = num(m.d7Week)
		local friendShare = num(m.friendShare)
		local trend = if prev7.days >= 7 then change(w7.players, prev7.players) else nil
		local numbers = plan.numbers
		numbers.d1Week = d1
		numbers.avgMinWeek = avgMin
		numbers.d7Week = d7
		numbers.newPlayers7 = w7.newPlayers
		numbers.sessions7 = w7.sessions
		numbers.playersPerDay = w7.playersPerDay
		numbers.playersTrend = trend
		numbers.robux7 = num(m.robux7) or w7.robux
		numbers.robuxPerPlayer = w7.robuxPerPlayer
		numbers.payerRate = payerRate
		numbers.friendShare = friendShare
		numbers.risingDays = num(m.risingDays) or 0

		local enoughNew = w7.newPlayers >= S.newPlayers7
		local enoughSessions = w7.sessions >= S.sessions7
		local enoughPlayers = w7.players >= S.playerDays7
		if not enoughNew then
			table.insert(unjudged, `D1 (needs {S.newPlayers7} new players a week, has {w7.newPlayers})`)
		end
		if not enoughSessions then
			table.insert(unjudged, `session length (needs {S.sessions7} sessions a week, has {w7.sessions})`)
		end
		if not enoughPlayers then
			table.insert(unjudged, `spending (needs {S.playerDays7} player-days a week, has {w7.players})`)
		end

		-- The latest release: a rollback question in its first days, a review after.
		local latest, previous = nil, nil
		for _, r in releases do
			if r.game == game and r.day <= through then
				previous = latest
				latest = r
			end
		end
		local releaseGap = if latest
			then metricsLib.dayNumber(through) - metricsLib.dayNumber(latest.day)
			else nil
		if latest and releaseGap and releaseGap <= 13 then
			local review = lib.review(rows, latest, previous, through)
			plan.release = review
			if review.verdict == "worse" then
				local what = table.concat(review.worse, ", ")
				if
					releaseGap <= config.release.fastWindowDays
					and review.postDays < config.release.fastMinDays
				then
					-- One day after a release is too thin for a rollback question; the plan shows it.
					review.verdict = "worse so far"
				elseif releaseGap <= config.release.fastWindowDays then
					signal("fix", "urgent", "release drop", `since {review.tag}: {what}`)
					table.insert(
						alex,
						if review.previous
							then `Roll {game} back to {review.previous}? Since {review.tag}: {what}. Rolling back is a Production publish, so it needs your click.`
							else `{game} dropped right after its first release {review.tag} ({what}); there is no earlier release to roll back to, so the fix goes forward.`
					)
				else
					signal("fix", "high", "release review", `{review.tag} reviewed worse: {what}`)
				end
			end
		end

		-- Yesterday against the 7 days before, unless a release check already explains it.
		local explained = releaseGap ~= nil and releaseGap <= config.release.fastWindowDays
		if not explained then
			local yesterday = lib.window(rows, through, through)
			local base = lib.window(rows, metricsLib.addDays(through, -7), metricsLib.addDays(through, -1))
			if yesterday.days == 1 and (base.playersPerDay or 0) >= S.baselinePlayers then
				local drops = {}
				local players = change(yesterday.playersPerDay, base.playersPerDay)
				if players and players <= -config.regression.drop then
					table.insert(drops, `players {signedPct(players)}`)
				end
				local session = change(yesterday.avgMin, base.avgMin)
				if session and session <= -config.regression.drop then
					table.insert(drops, `average session {signedPct(session)}`)
				end
				local robuxBase = if base.days > 0 then base.robux / base.days else 0
				local robux = change(yesterday.robux, robuxBase)
				if robuxBase >= S.baselineRobux and robux and robux <= -config.regression.drop then
					table.insert(drops, `Robux {signedPct(robux)}`)
				end
				if #drops > 0 then
					signal(
						"fix",
						"urgent",
						"regression",
						`yesterday against the 7 days before: {table.concat(drops, ", ")}`
					)
				end
			end
		end

		if m.kill == true then
			table.insert(
				alex,
				`{game} shows the kill signal: 7-day D1 {pct(d1)} after {daysLive} days. Keep it, or stop work on it? Your call.`
			)
		end
		if type(m.gate) == "table" and m.gate.pass == true then
			table.insert(alex, `{game} passes the launch gate: the next wave of games can start.`)
		end

		-- Not enough players to judge anything else: the store page is the first problem.
		if daysLive >= config.discoveryAfterDays and not enoughNew then
			signal(
				"discovery",
				"high",
				"few new players",
				`{w7.newPlayers} new players in 7 days (needs {S.newPlayers7} to judge the game at all)`
			)
		end

		if enoughNew and d1 and d1 < T.d1 then
			local step, loss = lib.worstStep(m.onboarding7)
			local detail = if step then `; most players lost at {clean(step)} ({pct(loss)})` else ""
			signal(
				"onboarding",
				if d1 < config.severe.d1 then "high" else "normal",
				"low D1",
				`7-day D1 {pct(d1)}, target {pct(T.d1)}{detail}`
			)
		end

		if enoughSessions and avgMin and avgMin < T.avgMinutes then
			local long = num(m.longSessionShare7)
			local detail = if long then `; {pct(long)} of sessions reach 10 min` else ""
			signal(
				"depth",
				if avgMin < config.severe.avgMinutes then "high" else "normal",
				"short sessions",
				`average session {minutes(avgMin)}, target {T.avgMinutes} min{detail}`
			)
		end

		local retained = enoughNew
			and enoughSessions
			and d1 ~= nil
			and avgMin ~= nil
			and d1 >= config.retained.d1
			and avgMin >= config.retained.avgMinutes

		-- D7 needs a full week of cohorts behind it: a young game reads 0% D7 by construction.
		if
			daysLive >= config.returnAfterDays
			and enoughNew
			and d7
			and d1
			and d1 >= config.retained.d1
			and d7 < T.d7
		then
			signal(
				"return",
				"normal",
				"low D7",
				`7-day D7 {pct(d7)}, target {pct(T.d7)}, while D1 holds at {pct(d1)}`
			)
		end

		if retained and enoughPlayers then
			local rpp = num(m.arpdau7) or w7.robuxPerPlayer or 0
			local low = {}
			if payerRate and payerRate < T.payerRate then
				table.insert(low, `{string.format("%.1f%%", payerRate * 100)} of players pay`)
			end
			if rpp < T.robuxPerPlayer then
				table.insert(low, `{string.format("%.2f", rpp)} Robux per player a day`)
			end
			if #low > 0 then
				local weak = lib.weakItems(m.prompts7, m.best, m.purchasesByItem7)
				local detail = if #weak > 0
					then `; prompts that rarely sell: {table.concat(weak, ", ")}`
					else ""
				signal(
					"monetization",
					"normal",
					"low spend",
					`{table.concat(low, " and ")} (targets {pct(T.payerRate)} and {T.robuxPerPlayer}){detail}`
				)
			end
		end

		if
			enoughSessions
			and friendShare
			and friendShare < T.friendShare
			and (d1 == nil or d1 >= config.retained.d1)
		then
			local friend, solo = num(m.friendAvgMinWeek), num(m.soloAvgMinWeek)
			local detail = if friend and solo
				then `; sessions with a friend {minutes(friend)} against {minutes(solo)} alone`
				else ""
			signal(
				"social",
				"normal",
				"little friend play",
				`{pct(friendShare)} of sessions have a friend on the server, target {pct(T.friendShare)}{detail}`
			)
		end

		if
			enoughNew
			and enoughSessions
			and d1
			and avgMin
			and d1 >= T.d1
			and avgMin >= T.avgMinutes
			and trend ~= nil
			and trend <= config.flatTrend
		then
			signal(
				"content",
				"normal",
				"retained but flat",
				`players {signedPct(trend)} week over week while D1 {pct(d1)} and sessions {minutes(avgMin)} meet the targets`
			)
		end
	end

	table.sort(signals, function(a, b)
		local la, lb = rank(lib.LEVELS, a.level), rank(lib.LEVELS, b.level)
		if la ~= lb then
			return la < lb
		end
		return rank(lib.KINDS, a.kind) < rank(lib.KINDS, b.kind)
	end)

	if #signals > 0 then
		plan.focus = signals[1].kind
		plan.focusWhy = signals[1].why
	elseif live then
		plan.focus = "content"
		plan.focusWhy = if #unjudged > 0
			then "nothing flagged yet (too few players for some checks): ship the next content item from the Update backlog in SPEC.md"
			else "every check is on target: ship the next content item from the Update backlog in SPEC.md"
	end
	return plan
end

-- The whole plan. `metrics` may be nil (no scoreboard yet): every game is "not live".
function lib.plan(metrics: any, games: { string }, releases: { Release }, issues: any, today: string): Plan
	local problems = {}
	local through: string? = nil
	local gamesData: any = {}
	if type(metrics) == "table" then
		through = if type(metrics.through) == "string" then metrics.through else nil
		gamesData = metrics.games
	else
		table.insert(problems, "no scoreboard numbers yet; every game is treated as not live")
	end
	local names = table.clone(games)
	if type(gamesData) == "table" then
		for name in gamesData do
			if
				type(name) == "string"
				and string.match(name, GAME_PATTERN)
				and not table.find(names, name)
			then
				table.insert(names, name)
			end
		end
	end
	table.sort(names)
	local bugs = lib.bugCounts(issues, names)
	local plan: Plan = {
		version = lib.PLAN_VERSION,
		today = today,
		through = through,
		metricsVersion = if type(metrics) == "table" then num(metrics.version) else nil,
		games = {},
		order = names,
		problems = problems,
		alex = {},
		audience = {},
	}
	local limited = {}
	for _, game in names do
		local audience = config.audience.games[game] or config.audience.default
		plan.audience[game] = audience
		if audience ~= "all" then
			table.insert(limited, game)
		end
	end
	if #limited > 0 then
		table.insert(
			plan.alex,
			`{table.concat(limited, ", ")} {if #limited == 1 then "is" else "are"} shown to Ages 16+ only.`
				.. " Opening a game to under-16 players needs your account steps: ID verification and 2-step"
				.. " verification, then per game either 250 highly engaged players or a refundable 1,000 Robux fee"
				.. " (spending Robux is your call)."
		)
	end
	for _, game in names do
		local m = if type(gamesData) == "table" then gamesData[game] else nil
		plan.games[game] = lib.planGame(game, m, through or today, releases, bugs[game])
	end
	if bugs.studio and bugs.studio.sev1 > 0 then
		table.insert(problems, `{bugs.studio.sev1} open sev1 bug(s) without a game label (studio-wide)`)
	end
	return plan
end

local function day(d: string?): string
	if d == nil then
		return "–"
	end
	return `{string.sub(d, 1, 4)}-{string.sub(d, 5, 6)}-{string.sub(d, 7, 8)}`
end

local function releaseText(r: Review?): string
	if r == nil then
		return "–"
	end
	local text = `{r.tag}: {r.verdict}`
	if r.verdict == "worse" or r.verdict == "worse so far" then
		text ..= ` ({table.concat(r.worse, ", ")})`
	end
	return text
end

-- The "Update plan" issue body (without the hidden block).
function lib.markdown(plan: Plan, updatedAt: string): string
	local out = {
		"# Update plan",
		"",
		`What each game's next update should be, from the scoreboard through {day(plan.through)} (UTC),`
			.. ` open bugs and Production releases. Updated {updatedAt}. How it works: ops/UPDATE_LOOP.md.`,
		"",
		"| Game | Stage | This week's focus | Why | Latest release | Bugs open (sev1/2/3) |",
		"|---|---|---|---|---|---|",
	}
	local asks = {}
	for _, a in plan.alex do
		table.insert(asks, `- {clean(a)}`)
	end
	for _, name in plan.order do
		local g = plan.games[name]
		table.insert(
			out,
			`| {g.game} | {g.stage}{if g.daysLive > 0 then ` (day {g.daysLive})` else ""} | **{g.focus}** | {clean(
				g.focusWhy
			)} | {clean(releaseText(g.release))} | {g.bugs.sev1}/{g.bugs.sev2}/{g.bugs.sev3} |`
		)
		for _, a in g.alex do
			table.insert(asks, `- {clean(a)}`)
		end
	end
	if #asks > 0 then
		table.insert(out, "")
		table.insert(out, "## For Alex")
		table.insert(out, "")
		for _, a in asks do
			table.insert(out, a)
		end
	end
	for _, name in plan.order do
		local g = plan.games[name]
		table.insert(out, "")
		table.insert(out, `## {g.game}: {g.focus} ({lib.KIND_TEXT[g.focus] or g.focus})`)
		table.insert(out, "")
		if #g.signals == 0 then
			table.insert(out, `- {clean(g.focusWhy)}`)
		end
		for _, s in g.signals do
			table.insert(out, `- **{s.level}** {s.kind}: {clean(s.why)} (rule: {s.rule})`)
		end
		local n = g.numbers
		if g.stage ~= "not live" then
			table.insert(
				out,
				`- 7 days: D1 {pct(n.d1Week)}, D7 {pct(n.d7Week)}, average session {minutes(n.avgMinWeek)},`
					.. ` {n.newPlayers7} new players, {string.format("%.0f", n.playersPerDay or 0)} players a day`
					.. ` ({if n.playersTrend then signedPct(n.playersTrend) else "–"} week over week),`
					.. ` {n.robux7 or 0} Robux, {string.format("%.2f", n.robuxPerPlayer or 0)} per player,`
					.. ` {pct(n.payerRate)} pay, {pct(n.friendShare)} with friends`
			)
		end
		local audience = plan.audience[name]
		if audience and audience ~= "all" then
			table.insert(
				out,
				`- Audience: Ages {audience} only, so numbers are read against that smaller pool`
			)
		end
		if #g.unjudged > 0 then
			table.insert(out, `- Too few players to judge: {table.concat(g.unjudged, "; ")}`)
		end
		if g.release and g.release.verdict ~= "too early" then
			local parts = {}
			for _, key in { "players", "avgSession", "robuxPerPlayer" } do
				local v = g.release.changes[key]
				if v then
					table.insert(parts, `{key} {signedPct(v)}`)
				end
			end
			local d1 = g.release.changes.d1Points
			if d1 then
				table.insert(
					parts,
					`D1 {if d1 < 0 then "-" else "+"}{math.floor(math.abs(d1) * 100 + 0.5)} pts`
				)
			end
			table.insert(
				out,
				`- Release {g.release.tag} ({day(g.release.day)}), {g.release.postDays} days after: {g.release.verdict}`
					.. (if #parts > 0 then ` ({table.concat(parts, ", ")})` else "")
			)
		end
		if g.bugs.total > 0 then
			local refs = {}
			for _, number in g.bugs.numbers do
				table.insert(refs, `#{number}`)
			end
			table.insert(out, `- Open bugs: {table.concat(refs, " ")}`)
		end
	end
	if #plan.problems > 0 then
		table.insert(out, "")
		table.insert(out, "## Problems")
		table.insert(out, "")
		for _, p in plan.problems do
			table.insert(out, `- {clean(p)}`)
		end
	end
	local T, S = config.targets, config.sample
	table.insert(out, "")
	table.insert(out, "## Rules in force (tools/loop/config.luau)")
	table.insert(out, "")
	table.insert(
		out,
		`Targets: D1 {pct(T.d1)}, average session {T.avgMinutes} min, D7 {pct(T.d7)}, {pct(T.payerRate)} of players paying,`
			.. ` {T.robuxPerPlayer} Robux per player a day, {pct(T.friendShare)} of sessions with a friend,`
			.. ` {pct(T.conversion)} prompt conversion. Judged only with {S.newPlayers7}+ new players,`
			.. ` {S.sessions7}+ sessions and {S.playerDays7}+ player-days a week. Rollback question: average session`
			.. ` -{pct(config.release.sessionDrop)}, Robux per player -{pct(config.release.robuxPerPlayerDrop)},`
			.. ` players -{pct(config.release.playersDrop)} or D1 -{math.floor(
				config.release.d1DropPoints * 100
			)} points`
			.. ` within {config.release.fastWindowDays} days of a release.`
	)
	return table.concat(out, "\n") .. "\n"
end

-- Wraps the plan JSON for the issue body; "--" never appears inside the comment.
function lib.hiddenBlock(encoded: string): string
	return `<!-- loop-lab-plan v1\n{(string.gsub(encoded, "%-%-", "- -"))}\n-->\n`
end

return lib
