--!strict
-- The Book's pictures load in page order, and the tab a player opens jumps
-- the queue.
local PreloadQueue = require("../src/shared/PreloadQueue")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

describe("PreloadQueue", function()
	it("hands out items in order, each once, in batches", function()
		local q = PreloadQueue.new({ "a", "b", "c", "d", "e" })
		expect(PreloadQueue.take(q, 2)).toEqual({ "a", "b" })
		expect(PreloadQueue.take(q, 2)).toEqual({ "c", "d" })
		expect(PreloadQueue.take(q, 2)).toEqual({ "e" })
		expect(#PreloadQueue.take(q, 2)).toBe(0)
	end)

	it("moves an opened tab's pictures to the front, keeping their order", function()
		-- Studio gate (#134): on a cold first scroll of the Uncommon tab, 21
		-- pictures took over 3 s, still queued behind the Common tab's.
		local q = PreloadQueue.new({ "c1", "c2", "c3", "u1", "u2", "e1" })
		expect(PreloadQueue.take(q, 1)).toEqual({ "c1" })
		PreloadQueue.prioritize(q, { "u1", "c1", "u2", "zz" })
		-- c1 was already handed out and zz was never queued: neither returns.
		expect(PreloadQueue.take(q, 3)).toEqual({ "u1", "u2", "c2" })
		expect(PreloadQueue.take(q, 3)).toEqual({ "c3", "e1" })
	end)
end)
