--!strict
local Timers = require("@core/Timers")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

describe("Timers", function()
	local egg = { startedAt = 1000, duration = 600 }

	it("progresses from the saved start time", function()
		expect(Timers.progress(egg, 1000)).toBe(0)
		expect(Timers.progress(egg, 1300)).toBe(0.5)
		expect(Timers.isDone(egg, 1599)).toBe(false)
		expect(Timers.isDone(egg, 1600)).toBe(true)
		expect(Timers.remaining(egg, 1450)).toBe(150)
		expect(Timers.progress(egg, 99999)).toBe(1)
		expect(Timers.progress(egg, 0)).toBe(0) -- clock before start never goes negative
	end)

	it("caps progress made while away", function()
		-- Online for 100s, away for 1000s with a 120s cap: 220s of progress.
		local options = { offlineCap = 120, lastSeenAt = 1100 }
		expect(Timers.elapsed(egg, 2100, options)).toBe(220)
		expect(Timers.isDone(egg, 2100, options)).toBe(false)
		-- No cap: done.
		expect(Timers.isDone(egg, 2100)).toBe(true)
		-- Rebase keeps the progress and resumes normally.
		local resumed = Timers.rebase(egg, 2100, options)
		expect(Timers.elapsed(resumed, 2100)).toBe(220)
		expect(Timers.isDone(resumed, 2100 + 380)).toBe(true)
	end)

	it("puts every server in the same restock window", function()
		local hour = 3600
		expect(Timers.windowStart(7300, hour)).toBe(7200)
		expect(Timers.windowStart(7199, hour)).toBe(3600)
		expect(Timers.windowStart(7300, hour, 300)).toBe(7500 - hour)
	end)
end)
