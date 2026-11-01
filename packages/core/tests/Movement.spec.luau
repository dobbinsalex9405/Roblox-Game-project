--!strict
local Movement = require("@core/Movement")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local function new()
	return Movement.new({ tolerance = 1.35, burstSeconds = 2, slackStuds = 4 })
end

-- Walks `key` along +X at `speed` for `seconds`, sampling every `step`.
local function walk(
	m: any,
	key: any,
	from: number,
	speed: number,
	seconds: number,
	step: number,
	start: number,
	allowed: number
)
	local x = from
	local time = start
	local violations = 0
	for _ = 1, math.floor(seconds / step) do
		x += speed * step
		time += step
		if m:check(key, x, 0, time, allowed) == "violation" then
			violations += 1
		end
	end
	return violations, x, time
end

describe("Movement check", function()
	it("accepts walking at or a little over the allowed speed", function()
		local m = new()
		m:reset("p", 0, 0, 0)
		expect((walk(m, "p", 0, 16, 30, 0.25, 0, 16))).toBe(0)
		expect((walk(m, "q", 0, 20, 30, 0.25, 0, 16))).toBe(0) -- 25% over, within tolerance
	end)

	it("rejects a speed hack", function()
		local m = new()
		m:reset("p", 0, 0, 0)
		local violations = walk(m, "p", 0, 50, 10, 0.25, 0, 16)
		expect(violations).toBeAtLeast(5)
	end)

	it("rejects a teleport and remembers the last good position", function()
		local m = new()
		m:reset("p", 0, 0, 0)
		local _, x, time = walk(m, "p", 0, 16, 5, 0.25, 0, 16)
		expect(m:check("p", x + 300, 0, time + 0.25, 16)).toBe("violation")
		local good = m:lastGood("p") :: Movement.Sample
		expect(good.x).toBeCloseTo(x, 1e-9)
	end)

	it("forgives a lag burst after standing still", function()
		local m = new()
		m:reset("p", 0, 0, 0)
		-- No updates for 2 seconds, then the whole 2 seconds of walking arrives at once.
		expect(m:check("p", 0, 0, 1, 16)).toBe("ok")
		expect(m:check("p", 32, 0, 2, 16)).toBe("ok")
	end)

	it("does not punish the moment of slowing down", function()
		local m = new()
		m:reset("p", 0, 0, 0)
		local _, x, time = walk(m, "p", 0, 0, 3, 0.25, 0, 32) -- builds budget at 32
		-- Speed drops to 10, but this sample still moved at 32.
		expect(m:check("p", x + 8, 0, time + 0.25, 10)).toBe("ok")
	end)

	it("restarts after reset (server-made teleports)", function()
		local m = new()
		m:reset("p", 0, 0, 0)
		m:reset("p", 500, 500, 1)
		expect(m:check("p", 502, 500, 1.25, 16)).toBe("ok")
		m:forget("p")
		expect(m:lastGood("p")).toBeNil()
	end)
end)
