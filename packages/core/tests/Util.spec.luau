--!strict
-- Util.retry: calls that fail now and then on Roblox's side (asset loads).
local Util = require("@core/Util")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

describe("Util.retry", function()
	it("returns the value once a later try succeeds, waiting between tries", function()
		local calls, waits = 0, {}
		local value, err = Util.retry(function(): string
			calls += 1
			if calls < 3 then
				error("HTTP 429 (Too Many Requests)")
			end
			return "loaded"
		end, { 1, 2, 4 }, function(seconds)
			table.insert(waits, seconds)
		end)
		expect(value).toBe("loaded")
		expect(err).toBe(nil)
		expect(calls).toBe(3)
		expect(table.concat(waits, ",")).toBe("1,2")
	end)

	it("gives up after every try failed and returns the last error", function()
		local calls = 0
		local value, err = Util.retry(function(): string
			calls += 1
			error(`failure {calls}`, 0)
		end, { 1, 2 }, function() end)
		expect(value).toBe(nil)
		expect(calls).toBe(3)
		expect(err).toBe("failure 3")
	end)
end)
