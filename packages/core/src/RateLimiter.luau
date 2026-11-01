--!strict
-- Token bucket keyed by any value (usually player + action).
-- `capacity` requests may burst at once; the bucket refills at
-- `capacity / window` tokens per second.

export type RateLimiter = {
	allow: (self: RateLimiter, key: any, now: number) -> boolean,
	forget: (self: RateLimiter, key: any) -> (),
}

type Bucket = { tokens: number, updated: number }

local RateLimiter = {}

function RateLimiter.new(capacity: number, window: number): RateLimiter
	assert(capacity >= 1, "capacity must be at least 1")
	assert(window > 0, "window must be positive")
	local refillPerSecond = capacity / window
	local buckets: { [any]: Bucket } = {}

	local limiter = {}

	function limiter.allow(_self: RateLimiter, key: any, now: number): boolean
		local bucket = buckets[key]
		if bucket == nil then
			bucket = { tokens = capacity, updated = now }
			buckets[key] = bucket
		end
		local elapsed = math.max(0, now - bucket.updated)
		bucket.tokens = math.min(capacity, bucket.tokens + elapsed * refillPerSecond)
		bucket.updated = now
		if bucket.tokens >= 1 then
			bucket.tokens -= 1
			return true
		end
		return false
	end

	function limiter.forget(_self: RateLimiter, key: any)
		buckets[key] = nil
	end

	return (limiter :: any) :: RateLimiter
end

return RateLimiter
