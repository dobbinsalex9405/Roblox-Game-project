--!strict
local Log = require("@core/Log")
local Stores = require("@core/Stores")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local UNPUBLISHED = "You must publish this place to the web to access DataStore."

-- A DataStoreService that behaves like an unpublished place in Studio.
local function unpublished()
	local calls = 0
	local service = {}
	function service.GetDataStore(_self: any, _name: string): any
		calls += 1
		error(UNPUBLISHED)
	end
	return service, function()
		return calls
	end
end

local function capture(): { string }
	local lines = {}
	Log.setSink(function(level, scope, message, fields)
		table.insert(lines, `{level} {Log.format(scope, message, fields)}`)
	end)
	return lines
end

describe("Stores", function()
	it("returns the store when DataStores work, with no warning", function()
		local lines = capture()
		local store = { name = "ErrorQueue" }
		local service = {
			GetDataStore = function(_self: any, name: string): any
				return if name == "ErrorQueue" then store else nil
			end,
		}
		expect(Stores.open(service, "ErrorQueue")).toBe(store)
		Log.setSink(nil)
		expect(#lines).toBe(0)
	end)

	-- The Studio gate found the whole server dying at start-up here: an
	-- unpublished place has no DataStores and GetDataStore throws.
	it("returns nil and warns once per store when DataStores are unavailable", function()
		local lines = capture()
		local service, calls = unpublished()
		Stores.reset()
		expect(Stores.open(service, "ErrorQueue")).toBe(nil)
		expect(Stores.open(service, "ErrorQueue")).toBe(nil)
		expect(Stores.open(service, "Feedback")).toBe(nil)
		Log.setSink(nil)
		expect(calls()).toBe(3)
		expect(#lines).toBe(2)
		expect(string.find(lines[1], "warn [Stores] DataStores unavailable", 1, true) ~= nil).toBe(true)
		expect(string.find(lines[1], "store=ErrorQueue", 1, true) ~= nil).toBe(true)
		expect(string.find(lines[1], UNPUBLISHED, 1, true) ~= nil).toBe(true)
		expect(string.find(lines[2], "store=Feedback", 1, true) ~= nil).toBe(true)
	end)
end)
