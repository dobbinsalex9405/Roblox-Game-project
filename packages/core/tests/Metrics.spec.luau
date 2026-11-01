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
		expect(Metrics.merge({ schema = 2, day = "20261101" }, delta, 1)).toBeNil()
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
