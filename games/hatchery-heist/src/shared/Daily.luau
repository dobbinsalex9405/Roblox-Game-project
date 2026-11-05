--!strict
-- Daily Rewards: one reward a day (UTC days), seven in a row. Claiming on
-- the next day moves the streak on; missing a day starts it again at Day 1;
-- after Day 7 it goes round again. Each reward is coins: so many seconds of
-- the player's income, but never less than a floor, so it matters to a new
-- player and a rich one alike (config/economy.luau `daily`).
--
-- Pure: time and income are arguments, so every rule is unit-tested.

export type Data = { [string]: any }

export type Status = {
	day: number, -- the reward that can be claimed next, 1 to 7
	ready: boolean, -- it can be claimed now
	secondsLeft: number, -- until it can be claimed (0 when ready)
	claimedToday: boolean,
}

local DAY = 86400

local Daily = {}

function Daily.dayNumber(now: number): number
	return now // DAY
end

local function state(d: Data): { lastDay: number, streak: number }
	if d.daily == nil then
		d.daily = { lastDay = 0, streak = 0 }
	end
	return d.daily
end

function Daily.status(d: Data, now: number, days: number): Status
	local s = d.daily or { lastDay = 0, streak = 0 }
	local today = Daily.dayNumber(now)
	if s.lastDay == today then
		return {
			day = s.streak % days + 1,
			ready = false,
			secondsLeft = (today + 1) * DAY - now,
			claimedToday = true,
		}
	end
	local continues = s.lastDay == today - 1 and s.streak > 0
	return {
		day = if continues then s.streak % days + 1 else 1,
		ready = true,
		secondsLeft = 0,
		claimedToday = false,
	}
end

-- Coins for reward `day` at `perSecond` income.
function Daily.amount(day: number, perSecond: number, config: any): number
	local reward = config.rewards[day]
	return math.max(reward.minCoins, math.floor(perSecond * reward.incomeSeconds))
end

-- Claims today's reward into the ledger. Returns the coins and the day, or
-- nil and a refusal.
function Daily.claim(
	d: Data,
	ledger: any,
	now: number,
	perSecond: number,
	config: any
): (number?, number | string)
	local status = Daily.status(d, now, #config.rewards)
	if not status.ready then
		local hours = status.secondsLeft // 3600
		local minutes = math.ceil((status.secondsLeft % 3600) / 60)
		return nil, `Next reward in {hours}h {minutes}m.`
	end
	local coins = Daily.amount(status.day, perSecond, config)
	ledger:add("coins", coins, "TimedReward:DailyReward")
	local s = state(d)
	s.lastDay = Daily.dayNumber(now)
	s.streak = status.day
	return coins, status.day
end

return Daily
