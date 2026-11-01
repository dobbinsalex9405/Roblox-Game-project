--!strict
local ErrorReporter = require("@core/ErrorReporter")
local Feedback = require("@core/Feedback")
local Errors = require("../feedback/errors")
local lib = require("../feedback/lib")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local T0 = 1793520000 -- 2026-11-01 08:00:00 UTC

-- Real batches from the core ErrorReporter, as servers write them.
local function batchFrom(build: string, entries: { { string } }, at: number): ErrorReporter.Batch
	local written: ErrorReporter.Batch? = nil
	local reporter = ErrorReporter.new({
		game = "hatchery-heist",
		build = build,
		write = function(batch)
			written = batch
			return true
		end,
	})
	for _, e in entries do
		local source, message, count = e[1], e[2], tonumber(e[3]) or 1
		for _ = 1, count do
			reporter:record(source :: any, message, "Script 'Server.Raids', Line 42\nmore", at)
		end
	end
	reporter:flush(at, true)
	return written :: any
end

describe("error sweep", function()
	it("reads core ErrorReporter batches and the server from the key", function()
		local batch = batchFrom("abc1234def", { { "client", "attempt to index nil with 'Egg'", "3" } }, T0)
		local key = Feedback.batchKey(T0, "1b2c3d4e-0000-1111-2222-333344445555", 4)
		local records = Errors.from(batch, "staging", Errors.serverFromKey(key))
		expect(#records).toBe(1)
		expect(records[1].count).toBe(3)
		expect(records[1].source).toBe("client")
		expect(records[1].server).toBe("1b2c3d4e0000111122223333")
		expect(records[1].build).toBe("abc1234def")
		local none, why = Errors.from({ reports = {} }, "staging", "s")
		expect(#none).toBe(0)
		expect(why).toContain("not an error batch")
	end)

	it("follows PUBLISH_CHECKS: any server error or a client error seen 10+ times is a STOP", function()
		local records = {}
		local function add(batch: ErrorReporter.Batch, server: string)
			for _, r in Errors.from(batch, "production", server) do
				table.insert(records, r)
			end
		end
		-- The same client error on two servers adds up to 10: STOP.
		add(batchFrom("abc1234", { { "client", "UI nil", "6" } }, T0), "s1")
		add(batchFrom("abc1234", { { "client", "UI nil", "4" } }, T0 + 60), "s2")
		-- A rare client error: issue only.
		add(batchFrom("abc1234", { { "client", "rare thing", "2" } }, T0), "s1")
		local sweep = Errors.sweep(records)
		expect(sweep.stop).toBe(true)
		expect(#sweep.groups).toBe(2)
		expect(sweep.groups[1].verdict).toBe("stop")
		expect(sweep.groups[1].count).toBe(10)
		expect(sweep.groups[1].servers).toBe(2)
		expect(sweep.groups[2].verdict).toBe("issue")

		local calm = Errors.sweep({ records[#records] })
		expect(calm.stop).toBe(false)

		add(batchFrom("abc1234", { { "server", "DataStore failed", "1" } }, T0), "s3")
		local withServer = Errors.sweep(records)
		expect(withServer.groups[1].source).toBe("server")
		expect(withServer.groups[1].verdict).toBe("stop")
	end)

	it("keeps only the build being checked when asked", function()
		local records = {}
		for _, r in
			Errors.from(batchFrom("aaaaaaa111", { { "server", "old bug", "1" } }, T0), "staging", "s1")
		do
			table.insert(records, r)
		end
		for _, r in
			Errors.from(batchFrom("bbbbbbb222", { { "client", "new bug", "1" } }, T0), "staging", "s1")
		do
			table.insert(records, r)
		end
		local sweep = Errors.sweep(records, "bbbbbbb")
		expect(#sweep.groups).toBe(1)
		expect(sweep.groups[1].build).toBe("bbbbbbb222")
		expect(sweep.stop).toBe(false)
	end)

	it("never shows player names and escapes error text", function()
		local records = Errors.from(
			batchFrom("abc", { { "server", "Players.CoolKid99.Backpack is not valid @x", "1" } }, T0),
			"staging",
			"s1"
		)
		local sweep = Errors.sweep(records)
		local md = Errors.markdown(sweep, lib.escape)
		expect(string.find(md, "CoolKid99", 1, true)).toBeNil()
		expect(md).toContain("Players.\\*")
		expect(string.find(md, "@x", 1, true)).toBeNil()
		expect(md).toContain("**STOP**")
		expect(md).toContain("## Errors")
		local entries = Errors.blockEntries(sweep)
		expect(entries[1].verdict).toBe("stop")
		expect(entries[1].message).toBeNil() -- no error text in the machine block
		expect(Errors.markdown(Errors.sweep({}), lib.escape)).toContain("No server or client errors")
	end)
end)
