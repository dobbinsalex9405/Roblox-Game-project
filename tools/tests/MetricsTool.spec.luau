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
