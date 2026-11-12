--!strict
-- Daily Rewards: one reward a day (UTC days), seven in a row. Claiming on
-- the next day moves the streak on; missing a day starts it again at Day 1;
-- after Day 7 it goes round again. Each reward is coins: so many seconds of
-- the player's income, but never less than a floor (so it matters to a new
-- player) and never more than a cap (so it never undercuts the coin packs)
-- (config/economy.luau `daily`).
--
-- A Streak Saver (25 Robux, sold on the daily window only on the day a
-- streak breaks) is kept in `d.streakSavers`. While the player holds one, a
-- streak that missed exactly one day carries on, and claiming uses it up.
--
-- Pure: time and income are arguments, so every rule is unit-tested.

export type Data = { [string]: any }

export type Status = {
	day: number, -- the reward that can be claimed next, 1 to 7
	ready: boolean, -- it can be claimed now
	secondsLeft: number, -- until it can be claimed (0 when ready)
	claimedToday: boolean,
	-- The streak missed exactly one day and starts over at Day 1 unless a
	-- Streak Saver keeps it (false while one is held: it carries on).
	broken: boolean,
	saving: boolean, -- a held Streak Saver keeps this claim's streak going
	lost: number, -- the streak day a Streak Saver would carry on from
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
			broken = false,
			saving = false,
			lost = 0,
		}
	end
	local continues = s.lastDay == today - 1 and s.streak > 0
	local missedOne = s.lastDay == today - 2 and s.streak > 0
	local saving = missedOne and (d.streakSavers or 0) > 0
	return {
		day = if continues or saving then s.streak % days + 1 else 1,
		ready = true,
		secondsLeft = 0,
		claimedToday = false,
		broken = missedOne and not saving,
		saving = saving,
		lost = if missedOne then s.streak else 0,
	}
end

-- `n` to two significant figures (601 -> 600, 5,410 -> 5,400), so a reward
-- reads as a designed number rather than a stray one (Studio gate, Nov 5).
function Daily.round(n: number): number
	if n < 100 then
		return math.floor(n)
	end
	local step = 10 ^ (math.floor(math.log10(n)) - 1)
	return math.floor(n / step + 0.5) * step
end

-- Coins for reward `day` at `perSecond` income, rounded.
function Daily.amount(day: number, perSecond: number, config: any): number
	local reward = config.rewards[day]
	local earned = math.max(reward.minCoins, Daily.round(perSecond * reward.incomeSeconds))
	return math.min(reward.maxCoins, earned)
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
	if status.saving then
		d.streakSavers -= 1
	end
	return coins, status.day
end

-- A Streak Saver bought: held until a streak that missed one day is claimed.
function Daily.addSaver(d: Data)
	d.streakSavers = (d.streakSavers or 0) + 1
end

-- Why a Streak Saver cannot be bought right now, or nil when it can: only
-- on the day a streak breaks, and only one held at a time.
function Daily.saverRefusal(d: Data, now: number, days: number): string?
	if (d.streakSavers or 0) > 0 then
		return "You already have a Streak Saver. It keeps your streak when you claim."
	end
	if not Daily.status(d, now, days).broken then
		return "Your streak isn't broken, so there's nothing to save."
	end
	return nil
end

return Daily
