--!strict
local Fakes = require("./Fakes")
local Odds = require("@core/Odds")
local Policy = require("@core/Policy")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

describe("Policy", function()
	local function policyFor(infos: { [any]: any })
		return Policy.new({
			fetch = function(player)
				local info = infos[player]
				if info == "error" then
					error("PolicyService unavailable")
				end
				return info
			end,
		})
	end

	it("reads the rules once and answers from them", function()
		local open, restricted = Fakes.player(1), Fakes.player(2)
		local policy = policyFor({
			[open] = { ArePaidRandomItemsRestricted = false, IsPaidItemTradingAllowed = true },
			[restricted] = { ArePaidRandomItemsRestricted = true, IsPaidItemTradingAllowed = false },
		})
		policy:load(open)
		policy:load(restricted)
		expect(policy:paidRandomAllowed(open)).toBe(true)
		expect(policy:tradingAllowed(open)).toBe(true)
		expect(policy:paidRandomAllowed(restricted)).toBe(false)
		expect(policy:tradingAllowed(restricted)).toBe(false)
	end)

	it("fails closed when the rules cannot be read or are not loaded yet", function()
		local broken, unloaded = Fakes.player(1), Fakes.player(2)
		local policy = policyFor({ [broken] = "error" })
		expect(policy:load(broken)).toBe(false)
		expect(policy:paidRandomAllowed(broken)).toBe(false)
		expect(policy:tradingAllowed(broken)).toBe(false)
		expect(policy:paidRandomAllowed(unloaded)).toBe(false)
	end)

	it("a restricted player can never reach a paid roll", function()
		local restricted = Fakes.player(2)
		local policy = policyFor({
			[restricted] = { ArePaidRandomItemsRestricted = true, IsPaidItemTradingAllowed = false },
		})
		policy:load(restricted)
		local odds = Odds.new()
		odds:define({ id = "PremiumEgg", paid = true, outcomes = { { id = "Rare", weight = 10000 } } })
		local result, reason = odds:rollPaid("PremiumEgg", restricted, policy)
		expect(result).toBeNil()
		expect(reason).toContain("restricted")
		-- The free roll path refuses paid tables outright.
		expect(function()
			odds:roll("PremiumEgg", restricted)
		end).toThrow("rollPaid")
	end)
end)
