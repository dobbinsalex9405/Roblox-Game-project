--!strict
-- Progress computed from a saved start time instead of a running clock, so it
-- survives leaving, server restarts and server hops (incubators, crop growth,
-- restocks). Offline progress can be capped so a timer does not finish
-- entirely while the player is away, when a game wants that.

export type Timer = {
	startedAt: number, -- unix seconds
	duration: number, -- seconds
}

export type Options = {
	-- Seconds of progress allowed while the player was away. nil = no cap.
	offlineCap: number?,
	-- When the player was last online (unix seconds), for the offline cap.
	lastSeenAt: number?,
}

local Timers = {}

-- Seconds of progress a timer has made by `now`.
function Timers.elapsed(timer: Timer, now: number, options: Options?): number
	local elapsed = math.max(0, now - timer.startedAt)
	local cap = options and options.offlineCap
	local lastSeenAt = options and options.lastSeenAt
	if cap ~= nil and lastSeenAt ~= nil and lastSeenAt < now then
		-- Time before the player left counts fully; time away counts up to `cap`.
		local online = math.max(0, math.min(now, lastSeenAt) - timer.startedAt)
		local away = math.max(0, now - math.max(lastSeenAt, timer.startedAt))
		elapsed = online + math.min(away, cap)
	end
	return math.min(elapsed, timer.duration)
end

-- Progress from 0 to 1.
function Timers.progress(timer: Timer, now: number, options: Options?): number
	if timer.duration <= 0 then
		return 1
	end
	return Timers.elapsed(timer, now, options) / timer.duration
end

function Timers.isDone(timer: Timer, now: number, options: Options?): boolean
	return Timers.progress(timer, now, options) >= 1
end

function Timers.remaining(timer: Timer, now: number, options: Options?): number
	return timer.duration - Timers.elapsed(timer, now, options)
end

-- Rewrites `startedAt` so that the timer keeps the progress it had at `now`
-- but continues from there (use when the player rejoins after a capped absence).
function Timers.rebase(timer: Timer, now: number, options: Options?): Timer
	return { startedAt = now - Timers.elapsed(timer, now, options), duration = timer.duration }
end

-- The start of the current repeating window of `period` seconds (shop restocks,
-- timed events). Every server computes the same answer from the clock alone.
function Timers.windowStart(now: number, period: number, offset: number?): number
	local o = offset or 0
	return ((now - o) // period) * period + o
end

return Timers
