--!strict
-- Daily Rewards: once a UTC day, a seven-day streak that resets when a day is
-- missed, rewards that grow through the week and scale with income.
local Daily = require("../src/shared/Daily")
local economy = require("../config/economy")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local DAY = 86400
local config = economy.daily

local function ledger()
	local l = { coins = 0, reasons = {} :: { string } }
	function l.add(self: any, _currency: string, amount: number, reason: string): number
		self.coins += amount
		table.insert(self.reasons, reason)
		return amount
	end
	return l
end

describe("Daily Rewards", function()
	it("pays once a day and moves the streak on", function()
		local d: { [string]: any } = { daily = { lastDay = 0, streak = 0 } }
		local l = ledger()
		local now = 100 * DAY + 3600
		local coins, day = Daily.claim(d, l, now, 0, config)
		expect(coins).toBe(config.rewards[1].minCoins)
		expect(day).toBe(1)
		expect(l.reasons[1]).toBe("TimedReward:DailyReward")
		-- Same day: refused, with the time left.
		local again, why = Daily.claim(d, l, now + 60, 0, config)
		expect(again).toBeNil()
		expect(string.find(why :: string, "Next reward in 22h") ~= nil).toBe(true)
		expect(Daily.status(d, now, 7).secondsLeft).toBe(DAY - 3600)
		-- Next day, even a minute after midnight: Day 2.
		local c2, d2 = Daily.claim(d, l, 101 * DAY + 60, 0, config)
		expect(d2).toBe(2)
		expect(c2).toBe(config.rewards[2].minCoins)
	end)

	it("starts over after a missed day and wraps after Day 7", function()
		local d: { [string]: any } = { daily = { lastDay = 0, streak = 0 } }
		local l = ledger()
		for i = 1, 7 do
			local _, day = Daily.claim(d, l, (200 + i) * DAY, 0, config)
			expect(day).toBe(i)
		end
		local _, eighth = Daily.claim(d, l, 208 * DAY, 0, config)
		expect(eighth).toBe(1)
		local _, after = Daily.claim(d, l, 210 * DAY, 0, config) -- skipped day 209
		expect(after).toBe(1)
	end)

	it("handles saves with no daily state", function()
		local d: { [string]: any } = {}
		expect(Daily.status(d, 5 * DAY, 7).ready).toBe(true)
		local coins = Daily.claim(d, ledger(), 5 * DAY, 0, config)
		expect(coins).toBe(config.rewards[1].minCoins)
		expect(d.daily.lastDay).toBe(5)
	end)

	it("scales with income and never shrinks through the week", function()
		expect(Daily.amount(1, 1000, config)).toBe(1000 * config.rewards[1].incomeSeconds)
		for i = 2, #config.rewards do
			expect(config.rewards[i].minCoins).toBeAtLeast(config.rewards[i - 1].minCoins)
			expect(config.rewards[i].incomeSeconds).toBeAtLeast(config.rewards[i - 1].incomeSeconds)
		end
		-- Day 7 is the big one, and no day is worth more than an hour of income.
		expect(config.rewards[#config.rewards].incomeSeconds).toBeAtMost(3600)
	end)
end)
