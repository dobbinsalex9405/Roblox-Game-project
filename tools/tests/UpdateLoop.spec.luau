--!strict
local serde = require("@lune/serde")
local Metrics = require("@core/Metrics")
local metricsLib = require("../metrics/lib")
local lib = require("../loop/lib")
local config = require("../loop/config")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local GAMES = { "depthbound", "hatchery-heist", "street-food-empire", "tidecatch-cove" }
local THROUGH = "20261130"

local function decode(text: string): any
	return serde.decode("json", text)
end

-- Per-day counters for `n` days ending `through`, from a function of the day index (1 = oldest).
local function series(
	n: number,
	make: (i: number) -> { [string]: any },
	through: string?
): metricsLib.GameDays
	local last = through or THROUGH
	local days: metricsLib.GameDays = {}
	for i = 1, n do
		local name = metricsLib.addDays(last, i - n)
		local d = Metrics.empty(name) :: any
		for k, v in make(i) do
			d[k] = v
		end
		d.sessions = d.sessions ~= 0 and d.sessions or d.sessionsEnded
		days[name] = d
	end
	return days
end

-- A steady day: `players` players, `newPlayers` new, D1 `d1`, D7 `d7`, `minutes` per session,
-- a share `friends` of sessions with a friend on the server, `robux` a day.
local function steady(o: { [string]: number }): (i: number) -> { [string]: any }
	return function(i: number)
		local players = o.players or 100
		local sessions = o.sessions or players
		local friendSessions = math.floor(sessions * (o.friends or 0.2) + 0.5)
		return {
			players = players + (o.growth or 0) * i,
			newPlayers = o.newPlayers or 40,
			returnedD1 = math.floor((o.newPlayers or 40) * (o.d1 or 0.3) + 0.5),
			returnedD7 = math.floor((o.newPlayers or 40) * (o.d7 or 0.12) + 0.5),
			friendSessions = friendSessions,
			friendPlaySeconds = friendSessions * (o.minutes or 12) * 60,
			sessionsEnded = sessions,
			sessions = sessions,
			playSeconds = sessions * (o.minutes or 12) * 60,
			robux = { ["product:Coins"] = o.robux or 300 },
			purchases = { ["product:Coins"] = math.floor((o.robux or 300) / 25) },
			payers = o.payers or 3,
		}
	end
end

-- Runs the real scoreboard code and returns the JSON the loop reads, through the issue body.
local function scoreboard(
	games: { [string]: metricsLib.GameDays? },
	extra: { [string]: { [string]: any } }?
): any
	local reports = {}
	for _, game in GAMES do
		local days = games[game]
		table.insert(reports, metricsLib.report(game, days ~= nil, days or {}, THROUGH))
	end
	local markdown, json = metricsLib.scoreboard(reports, THROUGH, "production", "now", {})
	for game, fields in extra or {} :: { [string]: { [string]: any } } do
		for k, v in fields do
			json.games[game][k] = v
		end
	end
	local body = markdown .. "\n" .. metricsLib.hiddenBlock(serde.encode("json", json))
	local metrics, problem = lib.extractMetrics(body, decode)
	assert(metrics, problem)
	return metrics
end

local function planFor(
	days: metricsLib.GameDays,
	extra: { [string]: any }?,
	releases: { lib.Release }?,
	bugs: any?
)
	local metrics =
		scoreboard({ ["tidecatch-cove"] = days }, if extra then { ["tidecatch-cove"] = extra } else nil)
	return lib.plan(metrics, GAMES, releases or {}, bugs or {}, "20261201").games["tidecatch-cove"]
end

-- The text between the plan block's markers.
local function inner0(block: string): string
	return string.match(block, "<!%-%- loop%-lab%-plan v1\n(.-)\n%-%->") :: string
end

local function kinds(g: lib.GamePlan): { string }
	local out = {}
	for _, s in g.signals do
		table.insert(out, `{s.level}:{s.kind}`)
	end
	return out
end

describe("update loop", function()
	it("keeps the launch gate in step with the scoreboard", function()
		expect(config.targets.d1).toBe(metricsLib.GATE.d1)
		expect(config.targets.avgMinutes).toBe(metricsLib.GATE.avgMinutes)
		expect(config.targets.risingDays).toBe(metricsLib.GATE.risingDays)
	end)

	it("reads the scoreboard's hidden block, or bare JSON, and refuses anything else", function()
		local json = { version = 1, through = THROUGH, games = { ["a-b--c"] = { live = false } } }
		local body = "# Studio scoreboard\n\n" .. metricsLib.hiddenBlock(serde.encode("json", json))
		local metrics = lib.extractMetrics(body, decode)
		expect(metrics.games["a-b--c"].live).toBe(false)
		expect(lib.extractMetrics(serde.encode("json", json), decode).through).toBe(THROUGH)
		-- An issue edited in the web page comes back with CRLF line ends.
		local crlf = string.gsub(body, "\n", "\r\n")
		expect(lib.extractMetrics(crlf, decode).games["a-b--c"].live).toBe(false)
		local none, why = lib.extractMetrics("# Studio scoreboard\nno block", decode)
		expect(none).toBeNil()
		expect(why).toContain("no loop-lab-metrics block")
		local _, bad = lib.extractMetrics("<!-- loop-lab-metrics v1\n{nope\n-->", decode)
		expect(bad).toContain("not valid JSON")
		local _, v2 = lib.extractMetrics(serde.encode("json", { version = 2, games = {} }), decode)
		expect(v2).toContain("version 2")
	end)

	it("parses release tags and ignores anything else", function()
		local releases = lib.parseReleases(table.concat({
			"tidecatch-cove/production/v12|20261120",
			"tidecatch-cove/production/v3|20261110",
			"hatchery-heist/production/v1|20261105",
			"Evil/production/v1|20261105",
			"tidecatch-cove/staging/v4|20261105",
			"tidecatch-cove/production/v5|2026-11-05",
			"",
		}, "\n"))
		expect(#releases).toBe(3)
		expect(releases[1].tag).toBe("hatchery-heist/production/v1")
		expect(releases[2].version).toBe(3)
		expect(releases[3]).toEqual({
			game = "tidecatch-cove",
			version = 12,
			day = "20261120",
			tag = "tidecatch-cove/production/v12",
		})
	end)

	it("counts open bugs by game and severity", function()
		local counts = lib.bugCounts(
			{
				{ number = 7, labels = { { name = "bug" }, { name = "depthbound" }, { name = "sev1" } } },
				{ number = 3, labels = { { name = "bug" }, { name = "depthbound" }, { name = "sev2" } } },
				{ number = 9, labels = { { name = "bug" }, { name = "ci" }, { name = "sev1" } } },
				"junk",
			} :: { any },
			GAMES
		)
		expect(counts.depthbound.sev1).toBe(1)
		expect(counts.depthbound.sev2).toBe(1)
		expect(counts.depthbound.numbers).toEqual({ 3, 7 })
		expect(counts.studio.sev1).toBe(1)
	end)

	it("plans the launch for games that are not live, but still puts sev1 bugs first", function()
		local plan = lib.plan(nil, GAMES, {}, {
			{ number = 4, labels = { { name = "hatchery-heist" }, { name = "sev1" } } },
		}, "20261102")
		expect(plan.problems[1]).toContain("no scoreboard")
		expect(plan.games.depthbound.stage).toBe("not live")
		expect(plan.games.depthbound.focus).toBe("launch")
		expect(plan.games["hatchery-heist"].focus).toBe("fix")
		expect(plan.games["hatchery-heist"].signals[1].level).toBe("urgent")
	end)

	it("ships content when every check is on target, and says so", function()
		local g = planFor(series(20, steady({ growth = 2 })))
		expect(g.stage).toBe("steady")
		expect(#g.signals).toBe(0)
		expect(g.focus).toBe("content")
		expect(g.focusWhy).toContain("on target")
		expect(g.numbers.d1Week).toBeCloseTo(0.3, 3)
	end)

	it("feeds retained players new content when the player count stops growing", function()
		local g = planFor(series(20, steady({ growth = -1 })))
		expect(kinds(g)).toEqual({ "normal:content" })
		expect(g.focusWhy).toContain("week over week")
	end)

	it("fixes the first session when D1 is low, naming the step that loses players", function()
		local g = planFor(
			series(20, steady({ d1 = 0.15 })),
			{ onboarding7 = { ["01:Joined"] = 200, ["02:FirstCast"] = 180, ["03:FirstSale"] = 60 } }
		)
		expect(g.focus).toBe("onboarding")
		expect(g.signals[1].level).toBe("high")
		expect(g.focusWhy).toContain("02:FirstCast to 03:FirstSale (67%)")

		local mild = planFor(series(20, steady({ d1 = 0.22 })))
		expect(kinds(mild)).toEqual({ "normal:onboarding" })
	end)

	it("works on session length when sessions are short; a severe problem outranks a mild one", function()
		local short = planFor(series(20, steady({ minutes = 8 })), { longSessionShare7 = 0.2 })
		expect(kinds(short)).toEqual({ "normal:depth" })
		expect(short.focusWhy).toContain("20% of sessions reach 10 min")

		local both = planFor(series(20, steady({ minutes = 5, d1 = 0.22 })))
		expect(kinds(both)).toEqual({ "high:depth", "normal:onboarding" })
		local tie = planFor(series(20, steady({ minutes = 8, d1 = 0.22 })))
		expect(tie.focus).toBe("onboarding")
	end)

	it("judges nothing on too few players and points at the store page instead", function()
		local g = planFor(series(10, steady({ players = 6, newPlayers = 2, sessions = 5, robux = 0 })))
		expect(g.focus).toBe("discovery")
		expect(g.signals[1].level).toBe("high")
		expect(#g.unjudged).toBe(3)
		local young = planFor(series(2, steady({ players = 6, newPlayers = 2, sessions = 5 })))
		expect(young.stage).toBe("launch week")
		expect(young.focus).toBe("content")
		expect(young.focusWhy).toContain("too few players")
	end)

	it("tunes the shop when players stay but rarely pay, naming prompts that do not sell", function()
		local g = planFor(series(20, steady({ robux = 50, payers = 0, growth = 2 })), {
			prompts7 = {
				["pass:Vip"] = 120,
				["product:Coins"] = 30,
				["pass:Rare"] = 5,
				["pass:A|B`<x>"] = 25,
			},
		})
		expect(kinds(g)).toEqual({ "normal:monetization" })
		expect(g.focusWhy).toContain("0.0% of players pay")
		expect(g.focusWhy).toContain("pass:Vip 0% of 120 prompts")
		expect((string.find(g.focusWhy, "pass:Rare", 1, true))).toBeNil()
		-- Item keys come from game data: nothing in them can break the issue's table.
		expect(g.focusWhy).toContain("pass:A B  x  0% of 25 prompts")

		-- With a full top 5 of sellers, an item missing from it is not judged.
		local best = {}
		for i = 1, 5 do
			table.insert(best, { key = `product:P{i}`, robux = 100, purchases = 4 })
		end
		expect(lib.weakItems({ ["pass:Vip"] = 120, ["product:P1"] = 200 }, best)).toEqual({
			"product:P1 2% of 200 prompts",
		})

		-- Exact purchase counts from the analytics win over the best-seller list.
		expect(lib.weakItems({ ["pass:Vip"] = 120, ["product:P1"] = 200 }, best, { ["product:P1"] = 40 })).toEqual({
			"pass:Vip 0% of 120 prompts",
		})

		-- Poor retention first: spending is not judged while D1 is far off.
		local leaky = planFor(series(20, steady({ robux = 50, payers = 0, d1 = 0.15 })))
		expect(kinds(leaky)).toEqual({ "high:onboarding" })
	end)

	it("adds return hooks for a weak D7 and friend features for solo play", function()
		local g = planFor(series(20, steady({ growth = 2 })), {
			d7Week = 0.04,
			friendShare = 0.05,
			friendAvgMinWeek = 20,
			soloAvgMinWeek = 11,
		})
		expect(kinds(g)).toEqual({ "normal:return", "normal:social" })
		expect(g.focus).toBe("return")
		expect(g.signals[2].why).toContain("20.0 min against 11.0 min alone")

		-- A young game has no full D7 cohort yet: 0% D7 is not judged.
		local young = planFor(series(10, steady({ growth = 2 })), { d7Week = 0 })
		for _, s in young.signals do
			expect(s.kind ~= "return").toBe(true)
		end
	end)

	it("asks Alex about a rollback when a release drops the numbers within 3 days", function()
		local days = series(20, function(i)
			local f = steady({})(i)
			if i >= 19 then -- the two days after a release on day 18
				f.playSeconds = f.sessionsEnded * 5 * 60
			end
			return f
		end)
		local releases =
			lib.parseReleases("tidecatch-cove/production/v4|20261120\ntidecatch-cove/production/v7|20261128")
		local g = planFor(days, nil, releases)
		expect(g.focus).toBe("fix")
		expect(g.signals[1].rule).toBe("release drop")
		expect(g.release and g.release.verdict).toBe("worse")
		expect(g.alex[1]).toContain("Roll tidecatch-cove back to tidecatch-cove/production/v4?")
		expect(g.alex[1]).toContain("average session -58%")
		-- The day-over-day check stays quiet: the release already explains it.
		for _, s in g.signals do
			expect(s.rule ~= "regression").toBe(true)
		end

		-- One day after a release is too thin to ask: the plan shows it, nobody is asked.
		local early = planFor(days, nil, lib.parseReleases("tidecatch-cove/production/v7|20261129"))
		expect(early.release and early.release.verdict).toBe("worse so far")
		expect(#early.alex).toBe(0)
		for _, s in early.signals do
			expect(s.rule ~= "release drop").toBe(true)
		end

		local first = planFor(days, nil, lib.parseReleases("tidecatch-cove/production/v7|20261128"))
		expect(first.alex[1]).toContain("no earlier release")
	end)

	it("reviews a release a week on: better, flat, or too few players", function()
		local better = series(20, function(i)
			local f = steady({})(i)
			if i > 12 then
				f.playSeconds = f.sessionsEnded * 15 * 60
			end
			return f
		end)
		local releases = lib.parseReleases("tidecatch-cove/production/v9|20261123")
		local g = planFor(better, nil, releases)
		expect(g.release and g.release.verdict).toBe("better")
		expect(g.release and g.release.postDays).toBe(7)
		expect(g.release and g.release.changes.avgSession).toBeCloseTo(0.25, 3)
		expect(kinds(g)).toEqual({ "normal:content" }) -- players flat: content, not a fix

		local flat = planFor(series(20, steady({})), nil, releases).release
		expect(flat and flat.verdict).toBe("flat")
		-- Players up but sessions shorter: mixed. Only shorter: softer.
		local function after(o: { [string]: number }, players: number)
			return series(20, function(i)
				local f = steady(if i > 12 then o else {})(i)
				f.players = if i > 12 then players else 100
				return f
			end)
		end
		local mixed = planFor(after({ minutes = 10 }, 120), nil, releases).release
		expect(mixed and mixed.verdict).toBe("mixed")
		local softer = planFor(after({ minutes = 10 }, 100), nil, releases).release
		expect(softer and softer.verdict).toBe("softer")
		-- Robux per player is judged only on 100+ Robux a day before the release.
		local poor = planFor(series(20, steady({ robux = 99 })), nil, releases).release
		expect(poor and poor.changes.robuxPerPlayer).toBeNil()
		local tiny = planFor(series(20, steady({ players = 5 })), nil, releases)
		expect(tiny.release and tiny.release.verdict).toBe("too few players")
		-- Older than two weeks: no longer reviewed.
		local old =
			planFor(series(20, steady({})), nil, lib.parseReleases("tidecatch-cove/production/v2|20261110"))
		expect(old.release).toBeNil()
	end)

	it("flags a day-over-day drop with no release behind it", function()
		local days = series(20, function(i)
			local f = steady({ robux = 400 })(i)
			if i == 20 then
				f.players = 40
				f.robux = { ["product:Coins"] = 100 }
			end
			return f
		end)
		local g = planFor(days)
		expect(g.signals[1].rule).toBe("regression")
		expect(g.signals[1].level).toBe("urgent")
		expect(g.focusWhy).toContain("players -60%")
		expect(g.focusWhy).toContain("Robux -75%")
	end)

	it("passes the gate and the kill signal to Alex", function()
		local good = planFor(series(20, steady({ growth = 3 })))
		expect(good.alex[1]).toContain("passes the launch gate")
		local weak = planFor(series(10, steady({ d1 = 0.1 })))
		expect(weak.alex[1]).toContain("kill signal")
		expect(weak.focus).toBe("onboarding")
	end)

	it("writes an issue body with a table, asks for Alex, and a parseable plan block", function()
		local metrics = scoreboard({
			["tidecatch-cove"] = series(20, steady({ growth = 3 })),
			["depthbound"] = series(20, steady({ d1 = 0.12 })),
		}, { depthbound = { prompts7 = { ["pass:A|B<x>"] = 100 } } })
		local plan = lib.plan(metrics, GAMES, {}, {}, "20261201")
		local md = lib.markdown(plan, "2026-12-01 07:05 UTC")
		expect(md).toContain("| tidecatch-cove | steady (day 20) | **content** |")
		expect(md).toContain("| depthbound | steady (day 20) | **onboarding** |")
		expect(md).toContain("| hatchery-heist | not live | **launch** |")
		expect(md).toContain("## For Alex")
		expect(md).toContain("## Rules in force")
		local block = lib.hiddenBlock(serde.encode("json", plan))
		expect((string.find(inner0(block), "--", 1, true))).toBeNil()
		local inner = inner0(block)
		local decoded = decode((string.gsub(inner, "%- %-", "--")))
		expect(decoded.games.depthbound.focus).toBe("onboarding")
		expect(decoded.version).toBe(1)
	end)
end)
