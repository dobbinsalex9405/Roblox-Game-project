--!strict
local Metrics = require("@core/Metrics")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local DAY = 86400
local NOV1 = 1793491200 -- 2026-11-01 00:00:00 UTC

describe("Metrics", function()
	it("names UTC days without os.date", function()
		expect(Metrics.dayKey(NOV1)).toBe("20261101")
		expect(Metrics.dayKey(NOV1 + DAY - 1)).toBe("20261101")
		expect(Metrics.dayKey(NOV1 + DAY)).toBe("20261102")
		expect(Metrics.dayKey(0)).toBe("19700101")
		expect(Metrics.dayKey(951782400)).toBe("20000229") -- leap day
		expect(Metrics.dayKey(1798761600)).toBe("20270101")
		-- Every day for 3 years matches Lune's os.date.
		for i = 0, 3 * 366 do
			local at = NOV1 + i * DAY + 4321
			expect(Metrics.dayKey(at)).toBe(os.date("!%Y%m%d", at))
		end
	end)

	it("counts sessions, distinct players, new players and day-1/day-7 returns", function()
		local m = Metrics.new()
		local now = NOV1 + 3600
		-- A brand new player, then the same player again later today.
		m:join({ firstJoinAt = 0, lastJoinAt = 0 }, now)
		m:join({ firstJoinAt = now, lastJoinAt = now }, now + 600)
		-- A player who first joined yesterday, back for the first time today.
		m:join({ firstJoinAt = now - DAY, lastJoinAt = now - DAY }, now + 700)
		-- A player who first joined 7 days ago and last played 3 days ago.
		m:join({ firstJoinAt = now - 7 * DAY, lastJoinAt = now - 3 * DAY }, now + 800)
		-- A player who already played today.
		m:join({ firstJoinAt = now - 30 * DAY, lastJoinAt = now - 60 }, now + 900)
		local days = m:take()
		expect(#days).toBe(1)
		local d = days[1]
		expect(d.day).toBe("20261101")
		expect(d.sessions).toBe(5)
		expect(d.players).toBe(3)
		expect(d.newPlayers).toBe(1)
		expect(d.returnedD1).toBe(1)
		expect(d.returnedD7).toBe(1)
	end)

	it("adds play time on the day the session ends and ignores absurd lengths", function()
		local m = Metrics.new()
		m:leave(600, NOV1 + 100)
		m:leave(900.7, NOV1 + 200)
		m:leave(-5, NOV1 + 300)
		m:leave(10 * DAY, NOV1 + 400)
		local d = m:take()[1]
		expect(d.sessionsEnded).toBe(4)
		expect(d.playSeconds).toBe(600 + 900 + 0 + 12 * 3600)
	end)

	it("sums Robux and purchases by product and pass, and counts payers once", function()
		local m = Metrics.new()
		m:purchase("product", "CoinPack", 49, true, NOV1)
		m:purchase("product", "CoinPack", 49, false, NOV1 + 1)
		m:purchase("pass", "Vip", 199, true, NOV1 + 2)
		local d = m:take()[1]
		expect(d.robux["product:CoinPack"]).toBe(98)
		expect(d.purchases["product:CoinPack"]).toBe(2)
		expect(d.robux["pass:Vip"]).toBe(199)
		expect(d.purchases["pass:Vip"]).toBe(1)
		expect(d.payers).toBe(2)
	end)

	it("knows a player's first payment of the day from the saved day number", function()
		expect(Metrics.isFirstPaymentToday(nil, NOV1)).toBe(true)
		expect(Metrics.isFirstPaymentToday(NOV1 // DAY - 1, NOV1)).toBe(true)
		expect(Metrics.isFirstPaymentToday(NOV1 // DAY, NOV1 + 5000)).toBe(false)
	end)

	it("keeps the largest server size seen", function()
		local m = Metrics.new()
		m:serverPlayers(3, NOV1)
		m:serverPlayers(8, NOV1 + 1)
		m:serverPlayers(5, NOV1 + 2)
		expect(m:take()[1].peakServerPlayers).toBe(8)
	end)

	it("splits counts across UTC midnight and take empties the buffer", function()
		local m = Metrics.new()
		m:join({ firstJoinAt = 0, lastJoinAt = 0 }, NOV1 + DAY - 1)
		m:join({ firstJoinAt = 0, lastJoinAt = 0 }, NOV1 + DAY)
		expect(m:pending()).toBe(true)
		local days = m:take()
		expect(#days).toBe(2)
		expect(days[1].day).toBe("20261101")
		expect(days[2].day).toBe("20261102")
		expect(m:pending()).toBe(false)
		expect(#m:take()).toBe(0)
	end)

	it("merges a server's delta into the stored day", function()
		local stored = Metrics.empty("20261101")
		stored.sessions = 10
		stored.players = 7
		stored.peakServerPlayers = 6
		stored.robux = { ["product:CoinPack"] = 49 }
		stored.purchases = { ["product:CoinPack"] = 1 }
		local delta = Metrics.empty("20261101")
		delta.sessions = 3
		delta.players = 2
		delta.peakServerPlayers = 8
		delta.robux = { ["product:CoinPack"] = 49, ["pass:Vip"] = 199 }
		delta.purchases = { ["product:CoinPack"] = 1, ["pass:Vip"] = 1 }
		local merged = Metrics.merge(stored, delta, 123) :: Metrics.Day
		expect(merged.sessions).toBe(13)
		expect(merged.players).toBe(9)
		expect(merged.peakServerPlayers).toBe(8)
		expect(merged.robux["product:CoinPack"]).toBe(98)
		expect(merged.robux["pass:Vip"]).toBe(199)
		expect(merged.purchases["product:CoinPack"]).toBe(2)
		expect(merged.updatedAt).toBe(123)
		-- The stored table is not changed in place (UpdateAsync may retry).
		expect(stored.sessions).toBe(10)
	end)

	it("starts afresh from nothing or junk, and never rewrites a newer schema", function()
		local delta = Metrics.empty("20261101")
		delta.sessions = 2
		expect((Metrics.merge(nil, delta, 1) :: Metrics.Day).sessions).toBe(2)
		expect((Metrics.merge("junk", delta, 1) :: Metrics.Day).sessions).toBe(2)
		local bad = Metrics.empty("20261101") :: any
		bad.sessions = -4
		bad.players = 0 / 0
		bad.robux = { x = "lots" }
		local cleaned = Metrics.merge(bad, delta, 1) :: Metrics.Day
		expect(cleaned.sessions).toBe(2)
		expect(cleaned.players).toBe(0)
		expect(cleaned.robux.x).toBe(0)
		expect(Metrics.merge({ schema = 3, day = "20261101" }, delta, 1)).toBeNil()
	end)

	it("upgrades a day stored by schema 1 without losing its numbers", function()
		local old = {
			schema = 1,
			day = "20261101",
			sessions = 5,
			players = 4,
			newPlayers = 2,
			returnedD1 = 1,
			returnedD7 = 0,
			playSeconds = 1200,
			sessionsEnded = 3,
			peakServerPlayers = 3,
			robux = { ["product:CoinPack"] = 49 },
			purchases = { ["product:CoinPack"] = 1 },
			payers = 1,
			updatedAt = 10,
		}
		local delta = Metrics.empty("20261101")
		delta.sessions = 1
		delta.friendJoins = 1
		delta.events = { ["Raid:Stolen"] = 2 }
		local merged = Metrics.merge(old, delta, 20) :: Metrics.Day
		expect(merged.schema).toBe(Metrics.SCHEMA)
		expect(merged.sessions).toBe(6)
		expect(merged.playSeconds).toBe(1200)
		expect(merged.robux["product:CoinPack"]).toBe(49)
		expect(merged.payers).toBe(1)
		expect(merged.friendJoins).toBe(1)
		expect(merged.returnedD30).toBe(0)
		expect(merged.events["Raid:Stolen"]).toBe(2)
	end)

	it("buckets session lengths by minutes", function()
		expect(Metrics.sessionBucket(0)).toBe("m0")
		expect(Metrics.sessionBucket(59)).toBe("m0")
		expect(Metrics.sessionBucket(60)).toBe("m1")
		expect(Metrics.sessionBucket(299)).toBe("m1")
		expect(Metrics.sessionBucket(300)).toBe("m5")
		expect(Metrics.sessionBucket(600)).toBe("m10")
		expect(Metrics.sessionBucket(1199)).toBe("m10")
		expect(Metrics.sessionBucket(1200)).toBe("m20")
		expect(Metrics.sessionBucket(2400)).toBe("m40")
		expect(Metrics.sessionBucket(12 * 3600)).toBe("m40")
		local m = Metrics.new()
		m:leave(30, NOV1)
		m:leave(700, NOV1)
		m:leave(800, NOV1)
		m:leave(-5, NOV1)
		local d = m:take()[1]
		expect(d.sessionLengths.m0).toBe(2)
		expect(d.sessionLengths.m10).toBe(2)
		expect(d.sessionLengths.m1).toBeNil()
	end)

	it("counts day-30 returns", function()
		local m = Metrics.new()
		local now = NOV1 + 3600
		m:join({ firstJoinAt = now - 30 * DAY, lastJoinAt = now - 2 * DAY }, now)
		local d = m:take()[1]
		expect(d.returnedD30).toBe(1)
		expect(d.returnedD7).toBe(0)
	end)

	it("counts friend joins, sessions with a friend, and players who bring friends", function()
		local m = Metrics.new()
		m:join({ firstJoinAt = 0, lastJoinAt = 0, viaFriend = true }, NOV1)
		m:join({ firstJoinAt = NOV1 - DAY, lastJoinAt = NOV1 - DAY, viaFriend = true }, NOV1)
		m:join({ firstJoinAt = 0, lastJoinAt = 0 }, NOV1)
		m:leave(600, NOV1 + 600, true)
		m:leave(300, NOV1 + 600, false)
		m:leave(120, NOV1 + 600)
		m:brought(true, NOV1)
		m:brought(false, NOV1 + 5)
		local d = m:take()[1]
		expect(d.friendJoins).toBe(2)
		expect(d.friendNewPlayers).toBe(1)
		expect(d.newPlayers).toBe(2)
		expect(d.friendSessions).toBe(1)
		expect(d.friendPlaySeconds).toBe(600)
		expect(d.sessionsEnded).toBe(3)
		expect(d.playSeconds).toBe(1020)
		expect(d.friendsBrought).toBe(2)
		expect(d.bringers).toBe(1)
	end)

	it("counts Robux by where the prompt opened, prompts, and first-ever payers", function()
		local m = Metrics.new()
		m:prompt("product", "OilRefill", "HudRefill", NOV1)
		m:prompt("product", "OilRefill", "HudRefill", NOV1 + 1)
		m:prompt("pass", "Vip", "Shop", NOV1 + 2)
		m:prompt("product", "OilRefill", nil, NOV1 + 3)
		m:purchase("product", "OilRefill", 25, true, NOV1 + 4, "HudRefill", true)
		m:purchase("pass", "Vip", 199, false, NOV1 + 5, "Shop", false)
		m:purchase("product", "OilRefill", 25, false, NOV1 + 6, nil, false)
		m:purchase("product", "OilRefill", 25, false, NOV1 + 7, "not a source!", false)
		local d = m:take()[1]
		expect(d.prompts["product:OilRefill"]).toBe(3)
		expect(d.prompts["pass:Vip"]).toBe(1)
		expect(d.promptsBySource.HudRefill).toBe(2)
		expect(d.promptsBySource.Shop).toBe(1)
		expect(d.promptsBySource.Other).toBe(1)
		expect(d.robuxBySource.HudRefill).toBe(25)
		expect(d.robuxBySource.Shop).toBe(199)
		expect(d.robuxBySource.Other).toBe(50)
		expect(d.purchasesBySource.Other).toBe(2)
		expect(d.robux["product:OilRefill"]).toBe(75)
		expect(d.payers).toBe(1)
		expect(d.newPayers).toBe(1)
	end)

	it("only takes PascalCase sources of 24 characters or fewer", function()
		expect(Metrics.source("Shop")).toBe("Shop")
		expect(Metrics.source("HudRefill2")).toBe("HudRefill2")
		expect(Metrics.source("shop")).toBe("Other")
		expect(Metrics.source("Shop Button")).toBe("Other")
		expect(Metrics.source(string.rep("A", 25))).toBe("Other")
		expect(Metrics.source(nil)).toBe("Other")
		expect(Metrics.source(7)).toBe("Other")
	end)

	it("names and counts game events, skipping what is counted elsewhere", function()
		expect(Metrics.eventName("custom", "Raid:Stolen")).toBe("Raid:Stolen")
		expect(Metrics.eventName("custom", "Session:Length")).toBeNil()
		expect(Metrics.eventName("custom", "Retention:D1")).toBeNil()
		expect(Metrics.eventName("custom", "Purchase:Product")).toBeNil()
		expect(Metrics.eventName("onboarding", "HatchEgg", nil, 3)).toBe("Onboarding:03:HatchEgg")
		expect(Metrics.eventName("progression", "Rebirth", "Complete")).toBe("Progression:Rebirth:Complete")
		expect(Metrics.eventName("funnel", "Shop", "Viewed", 2)).toBe("Funnel:Shop:02:Viewed")
		expect(Metrics.eventName("economy", "Coins")).toBeNil()

		local m = Metrics.new()
		m:event("Raid:Stolen", NOV1)
		m:event("Raid:Stolen", NOV1)
		m:event("", NOV1)
		m:event(string.rep("x", 61), NOV1)
		for i = 1, 250 do
			m:event(`Spam:E{i}`, NOV1)
		end
		local d = m:take()[1]
		expect(d.events["Raid:Stolen"]).toBe(2)
		local count = 0
		for _ in d.events do
			count += 1
		end
		expect(count).toBe(200)
	end)

	it("counts events passing through an Analytics sink, even when the sink fails", function()
		local m = Metrics.new()
		local seen = {}
		local sink = {
			economy = function() end,
			onboarding = function(_p, step)
				table.insert(seen, step)
			end,
			funnel = function() end,
			progression = function() end,
			custom = function(_p, name)
				if name == "Bad:Event" then
					error("roblox said no")
				end
			end,
		}
		local wrapped = Metrics.countingSink(sink :: any, m, function()
			return NOV1
		end)
		wrapped.onboarding("p", 2, "PickEgg")
		wrapped.custom("p", "Raid:Stolen", 1, nil)
		wrapped.custom("p", "Session:Start", 1, nil)
		wrapped.progression("p", "Rebirth", "Complete", 3)
		wrapped.funnel("p", "Shop", "id", 1, "Opened")
		expect(pcall(wrapped.custom, "p", "Bad:Event", 1, nil)).toBe(false)
		expect(seen[1]).toBe(2)
		local d = m:take()[1]
		expect(d.events["Onboarding:02:PickEgg"]).toBe(1)
		expect(d.events["Raid:Stolen"]).toBe(1)
		expect(d.events["Session:Start"]).toBeNil()
		expect(d.events["Progression:Rebirth:Complete"]).toBe(1)
		expect(d.events["Funnel:Shop:01:Opened"]).toBe(1)
		expect(d.events["Bad:Event"]).toBe(1)
	end)

	it("caps the number of distinct product keys", function()
		local m = Metrics.new()
		for i = 1, 150 do
			m:purchase("product", `P{i}`, 1, false, NOV1)
		end
		local count = 0
		for _ in m:take()[1].robux do
			count += 1
		end
		expect(count).toBe(100)
	end)

	it("puts failed writes back and keeps at most three unsent days", function()
		local m = Metrics.new()
		m:join({ firstJoinAt = 0, lastJoinAt = 0 }, NOV1)
		local failed = m:take()
		m:join({ firstJoinAt = 0, lastJoinAt = 0 }, NOV1 + 60)
		m:restore(failed)
		local again = m:take()
		expect(#again).toBe(1)
		expect(again[1].sessions).toBe(2)
		expect(again[1].newPlayers).toBe(2)

		for i = 0, 4 do
			m:join({ firstJoinAt = 0, lastJoinAt = 0 }, NOV1 + i * DAY)
		end
		local kept = m:take()
		expect(#kept).toBe(3)
		expect(kept[1].day).toBe("20261103")
	end)

	it("hashes a JobId to a stable shard", function()
		local a = Metrics.shard("8f2c1a4e-0000-4b7e-9a51-2d0f6c3e1b77")
		expect(a).toBe(Metrics.shard("8f2c1a4e-0000-4b7e-9a51-2d0f6c3e1b77"))
		expect(a >= 0 and a < Metrics.SHARDS).toBe(true)
		-- FNV-1a 32 of "a" is 0xE40C292C.
		expect(Metrics.shard("a", 4294967296)).toBe(0xE40C292C)
		local seen: { [number]: boolean } = {}
		for i = 1, 200 do
			seen[Metrics.shard(`job-{i}`)] = true
		end
		for s = 0, Metrics.SHARDS - 1 do
			expect(seen[s]).toBe(true)
		end
		expect(Metrics.key("20261101", 3)).toBe("20261101-s3")
	end)
end)
