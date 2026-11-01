--!strict
-- Movement check (Wave 1 core addition). Clients move their own characters,
-- so a cheater can walk faster than allowed or teleport. The server samples
-- each character's position a few times a second and runs it through this
-- check, which keeps a movement budget per player:
--
--   * each sample adds `allowedSpeed × tolerance × dt` studs to the budget,
--     up to `burstSeconds` worth (so a lag spike that delivers several
--     positions at once is not punished);
--   * the horizontal distance moved is spent from the budget;
--   * spending more than the budget plus `slackStuds` is a violation.
--
-- Height is ignored (falling is fast and harmless). When the allowed speed
-- drops (picking up a creature, a trap), unspent budget from the old speed
-- stays until used, so the moment of slowing down is never a violation.
-- Server-made moves (teleporting home) must call `reset` first.

export type Options = {
	tolerance: number, -- e.g. 1.35: 35% over the allowed speed is still fine
	burstSeconds: number, -- budget cap, in seconds of movement at the allowed speed
	slackStuds: number, -- extra distance forgiven per sample
}

export type Sample = { x: number, z: number, t: number }

export type Result = "ok" | "violation"

export type Movement = {
	reset: (self: Movement, key: any, x: number, z: number, t: number) -> (),
	check: (
		self: Movement,
		key: any,
		x: number,
		z: number,
		t: number,
		allowedSpeed: number
	) -> (Result, number),
	lastGood: (self: Movement, key: any) -> Sample?,
	forget: (self: Movement, key: any) -> (),
}

type State = { last: Sample, good: Sample, budget: number }

local Movement = {}

function Movement.new(options: Options): Movement
	assert(options.tolerance >= 1, "tolerance must be at least 1")
	assert(options.burstSeconds > 0, "burstSeconds must be positive")
	assert(options.slackStuds >= 0, "slackStuds must not be negative")

	local states: { [any]: State } = {}
	local movement = {}

	function movement.reset(_self: Movement, key: any, x: number, z: number, t: number)
		local sample = { x = x, z = z, t = t }
		states[key] = { last = sample, good = sample, budget = 0 }
	end

	-- Returns "ok" or "violation", and the distance moved since the last sample.
	-- After a violation the budget restarts at zero from the new position, so
	-- the caller decides what to do (pull back to `lastGood`, drop a carried item).
	function movement.check(
		self: Movement,
		key: any,
		x: number,
		z: number,
		t: number,
		allowedSpeed: number
	): (Result, number)
		local state = states[key]
		if state == nil then
			self:reset(key, x, z, t)
			return "ok", 0
		end
		local dt = math.max(0, t - state.last.t)
		local distance = math.sqrt((x - state.last.x) ^ 2 + (z - state.last.z) ^ 2)
		local rate = math.max(0, allowedSpeed) * options.tolerance
		local cap = rate * options.burstSeconds
		if state.budget < cap then
			state.budget = math.min(cap, state.budget + rate * dt)
		end
		state.budget -= distance
		state.last = { x = x, z = z, t = t }
		if state.budget < -options.slackStuds then
			state.budget = 0
			return "violation", distance
		end
		state.good = state.last
		return "ok", distance
	end

	-- The last position that passed the check.
	function movement.lastGood(_self: Movement, key: any): Sample?
		local state = states[key]
		return if state then state.good else nil
	end

	function movement.forget(_self: Movement, key: any)
		states[key] = nil
	end

	return (movement :: any) :: Movement
end

return Movement
