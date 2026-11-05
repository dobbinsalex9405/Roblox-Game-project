--!strict
local ErrorReporter = require("@core/ErrorReporter")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local function setup()
	local writes: { ErrorReporter.Batch } = {}
	local reporter = ErrorReporter.new({
		game = "test-game",
		build = "abc123",
		write = function(batch)
			table.insert(writes, batch)
			return true
		end,
	})
	return reporter, writes
end

describe("ErrorReporter", function()
	it("a storm of 10,000 identical errors makes at most one write per minute", function()
		local reporter, writes = setup()
		local now = 0
		for i = 1, 10000 do
			now = i * 0.006 -- 10,000 errors spread over 60 seconds
			reporter:record(
				"server",
				`Players.Kid{i} attempt to index nil with 'Coins' at slot {i}`,
				"Script 'Raids', Line 42",
				now
			)
			reporter:flush(now)
		end
		expect(#writes).toBe(1)
		reporter:flush(now + 61)
		expect(#writes).toBe(2)
		local total = 0
		for _, batch in writes do
			expect(#batch.errors).toBe(1)
			total += batch.errors[1].count
		end
		expect(total).toBe(10000)
	end)

	it("groups by normalized message and first stack frame", function()
		local a = ErrorReporter.signature("server", "index nil with 'Coins' at 12", "Line 4\nLine 9")
		local b = ErrorReporter.signature("server", "index nil with 'Gems' at 99", "Line 4\nLine 10")
		local c = ErrorReporter.signature("server", "index nil with 'Coins' at 12", "Line 5")
		local d = ErrorReporter.signature("client", "index nil with 'Coins' at 12", "Line 4")
		expect(a).toBe(b)
		expect(a == c).toBe(false)
		expect(a == d).toBe(false)
	end)

	it("caps distinct signatures per batch and counts the overflow", function()
		local reporter, writes = setup()
		for i = 1, 80 do
			reporter:record("server", "error", `Line {i}`, 1)
		end
		reporter:flush(100)
		expect(#writes[1].errors).toBe(50)
		expect(writes[1].droppedSignatures).toBe(30)
	end)

	it("sorts the batch by count and clips long text", function()
		local reporter, writes = setup()
		reporter:record("server", "rare", "a", 1)
		for _ = 1, 5 do
			reporter:record("server", string.rep("x", 900), "b", 1)
		end
		reporter:flush(100)
		expect(writes[1].errors[1].count).toBe(5)
		expect(#writes[1].errors[1].message).toBe(500)
	end)

	it("does nothing when there is nothing to write", function()
		local reporter, writes = setup()
		expect(reporter:flush(1000)).toBe(false)
		expect(#writes).toBe(0)
	end)
end)
