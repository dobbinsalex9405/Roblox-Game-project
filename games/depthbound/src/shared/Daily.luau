--!strict
-- The daily return reward (Wave 1 plan: "reward the first dive of each
-- day"): the first sale of each day with a real haul in it pays a multiple.
-- Days are UTC, from server time, and the day it was last paid is saved, so
-- it is once per day across servers and rejoins. Shared by the server (the
-- sale) and the client (the goal line).

local Daily = {}

local DAY_SECONDS = 24 * 60 * 60

-- The UTC day number for a server time in Unix seconds.
function Daily.day(now: number): number
	return now // DAY_SECONDS
end

-- Whether today's bonus is still waiting for this player.
function Daily.available(d: { [string]: any }, now: number): boolean
	return (d.dailyHaulDay or 0) ~= Daily.day(now)
end

-- The multiplier for selling `pieces` ore now, and whether this sale takes
-- today's bonus. Call inside the sale's update; it marks the day as paid.
function Daily.claim(d: { [string]: any }, config: any, pieces: number, now: number): (number, boolean)
	if pieces < config.minPieces or not Daily.available(d, now) then
		return 1, false
	end
	d.dailyHaulDay = Daily.day(now)
	return config.multiplier, true
end

return Daily
