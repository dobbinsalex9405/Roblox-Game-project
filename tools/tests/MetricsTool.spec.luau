--!strict
local Metrics = require("@core/Metrics")
local lib = require("../metrics/lib")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local function day(name: string, fields: { [string]: any }): Metrics.Day
	local d = Metrics.empty(name) :: any
	for k, v in fields do
		d[k] = v
	end
	return d
end

-- Builds per-day totals for `n` days ending `through`, from a function of the day index.
local function series(through: string, n: number, make: (i: number) -> { [string]: any }): lib.GameDays
	local days: lib.GameDays = {}
	for i = 1, n do
		local name = lib.addDays(through, i - n)
		days[name] = day(name, make(i))
	end
	return days
end

describe("metrics tool", function()
	it("finds configured games for one environment", function()
		local envs = {
			["$comment"] = "ignored",
			["hatchery-heist"] = {
				production = { universeId = 11, placeId = 1 },
				staging = { universeId = 0 },
			},
			["depthbound"] = { production = { universeId = 0, placeId = 0 }, staging = { universeId = 22 } },
		}
		local prod = lib.targets(envs, "production")
		expect(#prod).toBe(1)
		expect(prod[1].game).toBe("hatchery-heist")
		expect(lib.targets(envs, "staging")[1].universeId).toBe(22)
		expect(lib.allGames(envs)).toEqual({ "depthbound", "hatchery-heist" })
		expect(function()
			lib.targets(envs, "dev")
		end).toThrow("production or staging")
	end)

	it("builds Open Cloud URLs and refuses other hosts", function()
		expect(lib.listUrl(5, nil)).toBe(
			"https://apis.roblox.com/datastores/v1/universes/5/standard-datastores/datastore/entries?datastoreName=Metrics&limit=100"
		)
		expect(lib.listUrl(5, "a/b")).toContain("&cursor=a%2Fb")
		expect(lib.entryUrl(5, "20261101-s3", "http://127.0.0.1:9000")).toBe(
			"http://127.0.0.1:9000/datastores/v1/universes/5/standard-datastores/datastore/entries/entry?datastoreName=Metrics&entryKey=20261101-s3"
		)
		expect(function()
			lib.listUrl(5, nil, "https://evil.example.com")
		end).toThrow("only be Roblox")
	end)

	it("does day arithmetic across months and years", function()
		expect(lib.dayNumber("19700101")).toBe(0)
		expect(lib.addDays("20261101", -1)).toBe("20261031")
		expect(lib.addDays("20261231", 1)).toBe("20270101")
		expect(lib.addDays("20280228", 1)).toBe("20280229")
		expect(lib.dayOfKey("20261101-s7")).toBe("20261101")
		expect(lib.dayOfKey("20261101")).toBeNil()
		expect(
			lib.keysToRead(
				{ "20261102-s1", "junk", "20261030-s0", "20261101-s0", "20261104-s2" },
				"20261031",
				"20261103"
			)
		).toEqual({
			"20261101-s0",
			"20261102-s1",
		})
	end)

	it("adds shards together and skips values it does not understand", function()
		local days: lib.GameDays = {}
		expect(
			lib.addShard(
				days,
				"20261101-s0",
				day("20261101", { players = 3, peakServerPlayers = 4, robux = { ["pass:Vip"] = 199 } })
			)
		).toBeNil()
		expect(
			lib.addShard(
				days,
				"20261101-s5",
				day("20261101", { players = 2, peakServerPlayers = 7, robux = { ["pass:Vip"] = 199 } })
			)
		).toBeNil()
		expect(days["20261101"].players).toBe(5)
		expect(days["20261101"].peakServerPlayers).toBe(7)
		expect(days["20261101"].robux["pass:Vip"]).toBe(398)
		expect(lib.addShard(days, "20261101-s1", { schema = 9, day = "20261101" })).toContain("schema 9")
		expect(lib.addShard(days, "20261101-s2", day("20261102", {}))).toContain("unexpected")
		expect(lib.addShard(days, "other", day("20261101", {}))).toBe("not a metrics key")
		expect(days["20261101"].players).toBe(5)
	end)

	it("reads shards written by schema 1 alongside schema 2", function()
		local days: lib.GameDays = {}
		local old = {
			schema = 1,
			day = "20261101",
			sessions = 4,
			players = 3,
			newPlayers = 1,
			returnedD1 = 0,
			returnedD7 = 0,
			playSeconds = 600,
			sessionsEnded = 2,
			peakServerPlayers = 2,
			robux = { ["pass:Vip"] = 199 },
			purchases = { ["pass:Vip"] = 1 },
			payers = 1,
			updatedAt = 1,
		}
		expect(lib.addShard(days, "20261101-s0", old)).toBeNil()
		expect(
			lib.addShard(
				days,
				"20261101-s1",
				day("20261101", { players = 2, friendJoins = 1, robuxBySource = { Shop = 49 } })
			)
		).toBeNil()
		expect(days["20261101"].players).toBe(5)
		expect(days["20261101"].friendJoins).toBe(1)
		expect(days["20261101"].robux["pass:Vip"]).toBe(199)
		expect(days["20261101"].robuxBySource.Shop).toBe(49)
	end)

	it("computes D1 from the day before's new players, and average session", function()
		local days: lib.GameDays = {
			["20261101"] = day("20261101", { newPlayers = 40 }),
			["20261102"] = day(
				"20261102",
				{ returnedD1 = 10, playSeconds = 3600, sessionsEnded = 6, players = 50 }
			),
		}
		local row = lib.row(days, "20261102")
		expect(row.d1).toBe(0.25)
		expect(row.avgSessionMin).toBe(10)
		local first = lib.row(days, "20261101")
		expect(first.d1).toBeNil()
		expect(first.avgSessionMin).toBeNil()
	end)

	it("passes the gate only after 14 days with D1, session length and rising players", function()
		local through = "20261120"
		local good = series(through, 20, function(i)
			return {
				players = 100 + i * 10, -- rising every day
				newPlayers = 40,
				returnedD1 = 12, -- 30%
				playSeconds = 12 * 60 * 50,
				sessionsEnded = 50, -- 12 minutes
				robux = { ["product:Coins"] = 100 },
				purchases = { ["product:Coins"] = 2 },
			}
		end)
		local r = lib.report("tidecatch-cove", true, good, through)
		expect(r.launchedOn).toBe("20261101")
		expect(r.daysLive).toBe(20)
		expect(r.d1Week).toBe(0.3)
		expect(r.avgMinWeek).toBe(12)
		expect(r.risingDays >= 3).toBe(true)
		expect(r.gate.pass).toBe(true)
		expect(r.kill).toBe(false)
		expect(r.robux7).toBe(700)
		expect(r.robuxTotal).toBe(2000)
		expect(#r.rows).toBe(14)
		expect(r.yesterday and r.yesterday.day).toBe(through)
		expect(r.best[1]).toEqual({ key = "product:Coins", robux = 700, purchases = 14 })

		-- Same numbers, only 10 days live: not eligible yet.
		local young = series(through, 10, function(i)
			return {
				players = 100 + i,
				newPlayers = 40,
				returnedD1 = 12,
				playSeconds = 7200,
				sessionsEnded = 10,
			}
		end)
		local y = lib.report("tidecatch-cove", true, young, through)
		expect(y.gate.eligible).toBe(false)
		expect(y.gate.pass).toBe(false)
	end)

	it("flags a kill signal and lists what misses the gate", function()
		local through = "20261115"
		local weak = series(through, 15, function(i)
			return {
				players = if i % 2 == 0 then 50 else 60, -- not rising
				newPlayers = 50,
				returnedD1 = 5, -- 10%
				playSeconds = 300 * 20,
				sessionsEnded = 20, -- 5 minutes
			}
		end)
		local r = lib.report("depthbound", true, weak, through)
		expect(r.kill).toBe(true)
		expect(r.gate.pass).toBe(false)
		expect(r.gate.misses).toEqual({ "D1", "session length", "rising players" })
	end)

	it("pools D1 only over days whose cohort was read", function()
		-- The first day read has returns but its cohort (the day before) is missing.
		local days: lib.GameDays = {
			["20261101"] = day("20261101", { players = 15, newPlayers = 10, returnedD1 = 4 }),
			["20261102"] = day("20261102", { players = 20, newPlayers = 5, returnedD1 = 2 }),
		}
		local r = lib.report("hatchery-heist", true, days, "20261102")
		expect(r.d1Week).toBe(0.2)
		expect(#r.rows).toBe(2)
	end)

	it("counts the challenge total only from the start date", function()
		local days = series("20261103", 5, function()
			return { players = 1, robux = { ["pass:Vip"] = 100 } }
		end) -- Oct 30 .. Nov 3
		local r = lib.report("hatchery-heist", true, days, "20261103")
		expect(r.robuxTotal).toBe(300)
	end)

	it("works out a week of analytics: returns, session lengths, friends, spending, onboarding", function()
		local through = "20261210"
		-- 40 days, so day-7 and day-30 cohorts exist for the last 7.
		local days = series(through, 40, function(i)
			return {
				players = 100,
				newPlayers = 20,
				returnedD7 = if i > 33 then 4 else 0, -- 20% of the cohort 7 days before
				returnedD30 = if i > 33 then 1 else 0, -- 5%
				sessionsEnded = 10,
				playSeconds = 10 * 600, -- 10 min
				sessionLengths = { m0 = 2, m5 = 4, m10 = 3, m40 = 1 },
				friendJoins = 6,
				friendNewPlayers = 5, -- 25% of new players
				friendSessions = 4,
				friendPlaySeconds = 4 * 1050, -- 17.5 min with a friend
				friendsBrought = 3,
				bringers = 2,
				payers = 5,
				newPayers = 1,
				robux = { ["product:OilRefill"] = 50, ["pass:Vip"] = 199 },
				purchases = { ["product:OilRefill"] = 2, ["pass:Vip"] = 1 },
				robuxBySource = { HudRefill = 50, Shop = 199 },
				purchasesBySource = { HudRefill = 2, Shop = 1 },
				prompts = { ["product:OilRefill"] = 8, ["pass:Vip"] = 4 },
				promptsBySource = { HudRefill = 8, Shop = 4 },
				events = {
					["Onboarding:01:Spawn"] = 20,
					["Onboarding:02:FirstDive"] = 15,
					["Dive:Start"] = 90,
				},
			}
		end)
		local w = lib.week(days, through)
		expect(w.playerDays).toBe(700)
		expect(w.returningShare).toBe(0.8)
		expect(w.newPlayers).toBe(140)
		expect(w.d7Week).toBe(0.2)
		expect(w.d30Week).toBe(0.05)
		expect(w.sessionsEnded).toBe(70)
		expect(w.longSessionShare).toBe(0.4)
		expect(w.sessionLengths.m5).toBe(28)
		expect(w.friendJoinShare).toBe(0.25)
		expect(w.friendShare).toBe(0.4)
		expect(w.friendAvgMin).toBe(17.5)
		expect(w.soloAvgMin).toBe(5) -- (6000 - 4200) / 6 sessions / 60
		expect(w.friendsBrought).toBe(21)
		expect(w.bringers).toBe(14)
		expect(w.payerRate).toBe(0.05)
		expect(w.newPayers).toBe(7)
		expect(w.arpdau).toBe(249 * 7 / 700)
		expect(w.robuxByItem["pass:Vip"]).toBe(1393)
		expect(w.robuxBySource.HudRefill).toBe(350)
		expect(w.prompts["product:OilRefill"]).toBe(56)
		expect(w.promptsBySource.Shop).toBe(28)
		expect(w.onboarding["01:Spawn"]).toBe(140)
		expect(w.onboarding["02:FirstDive"]).toBe(105)
		expect(w.events["Dive:Start"]).toBe(630)
		expect(w.events["Onboarding:01:Spawn"]).toBeNil()

		local r = lib.report("depthbound", true, days, through)
		local markdown, json = lib.scoreboard({ r }, through, "production", "now", {})
		expect(markdown).toContain("**Analytics, last 7 days**")
		expect(markdown).toContain("- Players: 700 player-days, 80% returning, 140 new. D1 0%")
		expect(markdown).toContain("D7 20% · D30 5%.")
		expect(markdown).toContain(
			"- Time played: 70 sessions, average 10.0 min, 40% ran 10+ min (<1 min 20% · 1-5 0% · 5-10 40% · 10-20 30% · 20-40 0% · 40+ 10%)."
		)
		expect(markdown).toContain(
			"- Friends: 25% of new players came with a friend; 40% of sessions had a friend on the server"
				.. " (average 17.5 min, solo 5.0); 21 friends brought in by 14 players."
		)
		expect(markdown).toContain(
			"- Spending: 5% of player-days paid, 7 first-time payers, 2.49 Robux per player-day."
		)
		expect(markdown).toContain("| pass:Vip | 1,393 | 7 | 28 | 25% |")
		expect(markdown).toContain("| product:OilRefill | 350 | 14 | 56 | 25% |")
		expect(markdown).toContain("| Shop | 1,393 | 7 | 28 |")
		expect(markdown).toContain("| HudRefill | 350 | 14 | 56 |")
		expect(markdown).toContain(
			"First minutes (onboarding steps reached): 01:Spawn 140 (100%) → 02:FirstDive 105 (75%)"
		)
		expect(markdown).toContain("Game events: Dive:Start 630")

		local g = json.games.depthbound
		-- v1 fields stay as they were.
		expect(json.version).toBe(1)
		expect(g.robux7).toBe(1743)
		expect(#g.days).toBe(14)
		expect(g.days[#g.days].d7).toBe(0.2)
		expect(g.days[#g.days].friendJoins).toBe(6)
		expect(g.days[#g.days].returning).toBe(80)
		-- New optional fields.
		expect(g.d7Week).toBe(0.2)
		expect(g.friendShare).toBe(0.4)
		expect(g.friendJoinShare).toBe(0.25)
		expect(g.payerRate7).toBe(0.05)
		expect(g.newPayers7).toBe(7)
		expect(g.robuxBySource7.Shop).toBe(1393)
		expect(g.robuxByItem7["product:OilRefill"]).toBe(350)
		expect(g.prompts7["pass:Vip"]).toBe(28)
		expect(g.onboarding7["02:FirstDive"]).toBe(105)
		expect(g.events7["Dive:Start"]).toBe(630)
		expect(g.longSessionShare7).toBe(0.4)
	end)

	it("leaves analytics fields out when there is nothing to report", function()
		local through = "20261103"
		local r = lib.report(
			"hatchery-heist",
			true,
			series(through, 3, function()
				return { players = 5, newPlayers = 5 }
			end),
			through
		)
		local markdown, json = lib.scoreboard({ r }, through, "production", "now", {})
		local g = json.games["hatchery-heist"]
		expect(g.robuxBySource7).toBeNil()
		expect(g.d7Week).toBeNil()
		expect(g.friendShare).toBeNil()
		expect(g.payerRate7).toBe(0)
		expect(markdown).toContain("D7 – · D30 –")
		expect(string.find(markdown, "| Where in the game", 1, true)).toBeNil()
		expect(string.find(markdown, "First minutes", 1, true)).toBeNil()
	end)

	it("keeps only the busiest entries of a map", function()
		local map = {}
		for i = 1, 40 do
			map[`k{i}`] = i
		end
		local top = lib.top(map, 3)
		expect(#top).toBe(3)
		expect(top[1]).toEqual({ key = "k40", value = 40 })
		expect(#lib.top(map)).toBe(lib.TOP)
		expect(lib.top({ b = 1, a = 1 })[1].key).toBe("a")
	end)

	it("writes a scoreboard for live and not-yet-live games with a parseable hidden block", function()
		local through = "20261103"
		local live = lib.report(
			"hatchery-heist",
			true,
			series(through, 3, function(i)
				return {
					players = 10 * i,
					newPlayers = 5,
					returnedD1 = 2,
					playSeconds = 6000,
					sessionsEnded = 10,
					robux = { ["pass:Vip"] = 1234 },
					purchases = { ["pass:Vip"] = 1 },
					payers = 1,
				}
			end),
			through
		)
		local waiting = lib.report("depthbound", false, {}, through)
		local markdown, json = lib.scoreboard(
			{ waiting, live },
			through,
			"production",
			"2026-11-04 06:47 UTC",
			{ "x: HTTP 500 <b>" }
		)
		expect(markdown).toContain("# Studio scoreboard")
		expect(markdown).toContain("Challenge total since 2026-11-01: 3,702 Robux paid, about 2,591 earned.")
		expect(markdown).toContain("| depthbound | – | – | – | – | – | – | – | not live |")
		expect(markdown).toContain(
			"| hatchery-heist | 30 | 5 | 40% | 10.0 | 1,234 | 3,702 | 1 | day 3 of 14;"
		)
		expect(markdown).toContain("## hatchery-heist: live since 2026-11-01")
		expect(markdown).toContain("Best sellers, 7 days: pass:Vip 3,702 (3)")
		expect(markdown).toContain("- x: HTTP 500  b ")
		expect(json.robuxTotal).toBe(3702)
		expect(json.games["depthbound"].live).toBe(false)
		expect(#json.games["hatchery-heist"].days).toBe(3) -- from launch on
		expect(#json.games["depthbound"].days).toBe(0)
		expect(waiting.yesterday).toBeNil()

		local serde = require("@lune/serde")
		local block = lib.hiddenBlock(serde.encode("json", json))
		expect(string.find(block, "--", 5, true) == string.len(block) - 3).toBe(true) -- only the closing -->
		local inner = string.match(block, "^<!%-%- loop%-lab%-metrics v1\n(.*)\n%-%->\n$")
		expect(inner ~= nil).toBe(true)
		local decoded = serde.decode("json", inner :: string)
		expect(decoded.through).toBe(through)
	end)
end)
