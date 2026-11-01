--!strict
-- Timed boosts bought with Robux (config/monetization.luau, `boosts`). The
-- saved data keeps when each one ends, in server time (Unix seconds), so a
-- boost keeps running across servers and rejoins. Shared by the server (sale
-- prices) and the client (the HUD timer and pack worth).

local Boosts = {}

-- Seconds left on a boost (0 when it is not running).
function Boosts.left(d: { [string]: any }, boostId: string, now: number): number
	local endsAt = d.boosts and d.boosts[boostId]
	if type(endsAt) ~= "number" then
		return 0
	end
	return math.max(0, endsAt - now)
end

-- Starts a boost, or adds its time to what is left. Returns the new end time.
function Boosts.extend(d: { [string]: any }, boostId: string, seconds: number, now: number): number
	if d.boosts == nil then
		d.boosts = {}
	end
	local endsAt = math.max(now, d.boosts[boostId] or 0) + seconds
	d.boosts[boostId] = endsAt
	return endsAt
end

-- What a sale is multiplied by right now.
function Boosts.sellMultiplier(d: { [string]: any }, boosts: { [string]: any }?, now: number): number
	local ore = boosts and boosts.OreBoost
	if ore and Boosts.left(d, "OreBoost", now) > 0 then
		return ore.sellMultiplier
	end
	return 1
end

-- "14:05" for a countdown.
function Boosts.clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

return Boosts
