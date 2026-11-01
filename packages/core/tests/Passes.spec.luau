--!strict
local Fakes = require("./Fakes")
local Passes = require("@core/Passes")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

describe("Passes", function()
	local function setup(ownedIds: { [number]: boolean }, failing: boolean?)
		local granted = {}
		local passes = Passes.new({
			passes = { DoubleCoins = 10, AutoCollect = 20, NotCreatedYet = 0 },
			ownsAsync = function(_player, id)
				if failing then
					error("HTTP 500")
				end
				return ownedIds[id] == true
			end,
			onOwned = function(_player, key)
				table.insert(granted, key)
			end,
		})
		return passes, granted
	end

	it("checks ownership on join", function()
		local passes, granted = setup({ [10] = true })
		local p = Fakes.player(1)
		passes:load(p)
		expect(passes:owns(p, "DoubleCoins")).toBe(true)
		expect(passes:owns(p, "AutoCollect")).toBe(false)
		expect(passes:owns(p, "NotCreatedYet")).toBe(false)
		expect(granted).toEqual({ "DoubleCoins" })
	end)

	it("a pass bought mid-session works without rejoining", function()
		local passes, granted = setup({})
		local p = Fakes.player(1)
		passes:load(p)
		expect(passes:owns(p, "AutoCollect")).toBe(false)
		passes:onPurchaseFinished(p, 20, false)
		expect(passes:owns(p, "AutoCollect")).toBe(false)
		passes:onPurchaseFinished(p, 20, true)
		expect(passes:owns(p, "AutoCollect")).toBe(true)
		expect(granted).toEqual({ "AutoCollect" })
	end)

	it("treats a failing ownership check as not owned and does not throw", function()
		local passes = setup({}, true)
		local p = Fakes.player(1)
		passes:load(p)
		expect(passes:owns(p, "DoubleCoins")).toBe(false)
	end)

	it("throws on unknown pass keys", function()
		local passes = setup({})
		expect(function()
			passes:owns(Fakes.player(1), "Typo")
		end).toThrow("unknown pass")
	end)

	it("the Studio test panel can own a pass for the session, even one not created yet", function()
		local passes, granted = setup({})
		local p = Fakes.player(1)
		passes:load(p)
		passes:setSessionOwned(p, "NotCreatedYet", true)
		expect(passes:owns(p, "NotCreatedYet")).toBe(true)
		expect(granted).toEqual({ "NotCreatedYet" })
		passes:setSessionOwned(p, "NotCreatedYet", false)
		expect(passes:owns(p, "NotCreatedYet")).toBe(false)
		expect(function()
			passes:setSessionOwned(p, "Nope", true)
		end).toThrow("unknown pass")
		-- Nothing persists: a fresh join checks Roblox again.
		passes:setSessionOwned(p, "AutoCollect", true)
		passes:release(p)
		passes:load(p)
		expect(passes:owns(p, "AutoCollect")).toBe(false)
	end)

	it("forgets players who leave", function()
		local passes = setup({ [10] = true })
		local p = Fakes.player(1)
		passes:load(p)
		passes:release(p)
		expect(passes:owns(p, "DoubleCoins")).toBe(false)
	end)
end)
