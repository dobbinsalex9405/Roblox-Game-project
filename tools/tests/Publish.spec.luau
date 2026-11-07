--!strict
local lib = require("../publish/lib")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

describe("publish tool", function()
	local envs = {
		["hatchery-heist"] = {
			staging = { universeId = 111, placeId = 222 },
			production = { universeId = 0, placeId = 0 },
		},
	}

	it("finds configured targets and builds the Open Cloud URL", function()
		local target = lib.target(envs, "hatchery-heist", "staging")
		expect(target).toEqual({ universeId = 111, placeId = 222 })
		expect(lib.url(target :: any)).toBe(
			"https://apis.roblox.com/universes/v1/111/places/222/versions?versionType=Published"
		)
	end)

	it("refuses to send the key anywhere but Roblox or this machine", function()
		local target = { universeId = 1, placeId = 2 }
		expect(lib.url(target, "http://127.0.0.1:8080")).toContain("http://127.0.0.1:8080/universes/v1/1/")
		expect(function()
			lib.url(target, "https://evil.example.com")
		end).toThrow("only be Roblox")
	end)

	it("treats 0 ids and missing games as not configured", function()
		local target, reason = lib.target(envs, "hatchery-heist", "production")
		expect(target).toBeNil()
		expect(reason).toContain("no production experience ids")
		local missing, why = lib.target(envs, "coral-cove", "staging")
		expect(missing).toBeNil()
		expect(why).toContain("no entry")
	end)

	it("rejects malformed ids and unknown environments", function()
		expect(function()
			lib.target({ g = { staging = { universeId = "1", placeId = 2 } } }, "g", "staging")
		end).toThrow("whole number")
		expect(function()
			lib.target(envs, "hatchery-heist", "dev")
		end).toThrow("staging or production")
	end)

	it("names the secret after the game", function()
		expect(lib.secretName("hatchery-heist")).toBe("ROBLOX_API_KEY_HATCHERY_HEIST")
	end)

	it("reads the version from the response", function()
		expect(lib.versionFrom({ versionNumber = 12 })).toBe(12)
		expect(function()
			lib.versionFrom({})
		end).toThrow("versionNumber")
	end)

	it("the committed environments file parses and every game has all three entries", function()
		local fs = require("@lune/fs")
		local serde = require("@lune/serde")
		local committed = serde.decode("json", fs.readFile("ops/environments.json"))
		for _, dir in fs.readDir("games") do
			local entry = committed[dir]
			expect(type(entry)).toBe("table")
			for _, env in { "dev", "staging", "production" } do
				expect(type(entry[env])).toBe("table")
			end
			lib.target(committed, dir, "staging") -- must not throw
		end
	end)

	it("waits out Roblox's busy saves and rate limits, then gives up", function()
		-- 409 "Server is busy" settles in a minute or two: long waits, 45 s apart.
		expect(lib.retryDelay(409, 1)).toBe(45)
		expect(lib.retryDelay(409, 2)).toBe(90)
		expect(lib.retryDelay(409, 3)).toBe(135)
		expect(lib.retryDelay(409, lib.MAX_ATTEMPTS)).toBeNil()
		-- 429 and 5xx keep the short doubling waits.
		expect(lib.retryDelay(429, 1)).toBe(4)
		expect(lib.retryDelay(503, 2)).toBe(8)
		expect(lib.retryDelay(500, 3)).toBe(16)
		expect(lib.retryDelay(502, lib.MAX_ATTEMPTS)).toBeNil()
		-- Anything else is a real failure: wrong key, bad place, no retry.
		expect(lib.retryDelay(401, 1)).toBeNil()
		expect(lib.retryDelay(403, 1)).toBeNil()
		expect(lib.retryDelay(400, 1)).toBeNil()
		expect(lib.retryDelay(404, 2)).toBeNil()
	end)
end)
