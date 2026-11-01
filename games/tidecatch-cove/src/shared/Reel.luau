--!strict
-- The reel minigame, as a pure simulation the client steps every frame.
--
-- A bar from 0 to 1. The fish darts between random points; the player holds
-- (screen, button or key) to push the catch zone right and lets go to let it
-- drift back left. Progress fills while the fish is inside the zone and
-- drains while it is outside. Full = caught; empty or out of time = it got
-- away. One big hold target, no precise taps: built for phones first.
--
-- The server cannot watch the bar, so it checks the one thing it can: a reel
-- can never finish sooner than `Reel.minSeconds` after the bite (a human
-- reaction plus filling the bar without a single miss). Faster is a script.

export type Params = {
	fill: number,
	drain: number,
	fishSpeed: number,
	zoneWidth: number,
	startProgress: number,
	timeoutSeconds: number,
}

export type Result = "caught" | "escaped"

export type State = {
	progress: number,
	fish: number,
	fishTarget: number,
	retargetIn: number,
	zone: number, -- centre of the catch zone
	zoneVelocity: number,
	elapsed: number,
	result: Result?,
}

local Reel = {}

-- How the catch zone moves, in bar widths per second (squared).
Reel.ZONE_ACCELERATION = 3.2
Reel.ZONE_MAX_SPEED = 1.4
Reel.BOUNCE = 0.35

function Reel.params(rarity: string, rodTier: number, fishing: any): Params
	local reel = fishing.reel
	local r = reel.rarity[rarity] or reel.rarity.Common
	local rod = fishing.rods[math.clamp(rodTier, 1, #fishing.rods)]
	return {
		fill = r.fill,
		drain = r.drain,
		fishSpeed = r.fishSpeed,
		zoneWidth = rod.zone,
		startProgress = reel.startProgress,
		timeoutSeconds = reel.timeoutSeconds,
	}
end

-- The shortest time from bite to a caught fish that a human can manage.
function Reel.minSeconds(rarity: string, fishing: any): number
	local reel = fishing.reel
	local r = reel.rarity[rarity] or reel.rarity.Common
	return reel.reactionSeconds + (1 - reel.startProgress) / r.fill
end

-- The latest a reel result can arrive after the bite and still count.
function Reel.maxSeconds(fishing: any): number
	local reel = fishing.reel
	return reel.hookSeconds + reel.timeoutSeconds + 2 -- 2 s for the network
end

-- `random` returns a number in [0, 1).
function Reel.new(params: Params, random: () -> number): State
	local fish = 0.3 + random() * 0.4
	local half = params.zoneWidth / 2
	return {
		progress = params.startProgress,
		fish = fish,
		fishTarget = fish,
		retargetIn = 0.4,
		zone = math.clamp(fish, half, 1 - half),
		zoneVelocity = 0,
		elapsed = 0,
		result = nil,
	}
end

function Reel.inZone(state: State, params: Params): boolean
	return math.abs(state.fish - state.zone) <= params.zoneWidth / 2
end

-- Advances the minigame by `dt` seconds. Returns the result once decided.
function Reel.step(state: State, params: Params, dt: number, holding: boolean, random: () -> number): Result?
	if state.result then
		return state.result
	end
	dt = math.clamp(dt, 0, 0.1) -- a frame hitch must not skip the bar
	state.elapsed += dt

	-- The fish darts towards a target and picks a new one now and then.
	state.retargetIn -= dt
	if state.retargetIn <= 0 or math.abs(state.fishTarget - state.fish) < 0.01 then
		state.fishTarget = random()
		state.retargetIn = 0.5 + random() * 1.2
	end
	local toTarget = state.fishTarget - state.fish
	local move = math.min(math.abs(toTarget), params.fishSpeed * dt)
	state.fish += if toTarget >= 0 then move else -move

	-- The zone accelerates right while held and left while released.
	local accel = if holding then Reel.ZONE_ACCELERATION else -Reel.ZONE_ACCELERATION
	state.zoneVelocity =
		math.clamp(state.zoneVelocity + accel * dt, -Reel.ZONE_MAX_SPEED, Reel.ZONE_MAX_SPEED)
	state.zone += state.zoneVelocity * dt
	local half = params.zoneWidth / 2
	if state.zone < half then
		state.zone = half
		state.zoneVelocity = -state.zoneVelocity * Reel.BOUNCE
	elseif state.zone > 1 - half then
		state.zone = 1 - half
		state.zoneVelocity = -state.zoneVelocity * Reel.BOUNCE
	end

	if Reel.inZone(state, params) then
		state.progress = math.min(1, state.progress + params.fill * dt)
	else
		state.progress = math.max(0, state.progress - params.drain * dt)
	end

	if state.progress >= 1 then
		state.result = "caught"
	elseif state.progress <= 0 or state.elapsed >= params.timeoutSeconds then
		state.result = "escaped"
	end
	return state.result
end

return Reel
