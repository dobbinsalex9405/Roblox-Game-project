--!strict
-- The one place that sets a character's walk speed. Speed comes from the
-- mount (or walking), then carrying a stolen creature, then trap effects:
--
--   stunned            0
--   carrying           Defenses.carrySpeed(mount)
--   riding / walking   mount speed / StarterPlayer.CharacterWalkSpeed
--   slowed             × the slow factor
--
-- RaidService checks every move against `allowed`, so a client that raises
-- its own WalkSpeed gains nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Defenses = require(ReplicatedStorage.Shared.Defenses)

local Speed = {}

type State = {
	mount: number?,
	carrying: boolean,
	stunUntil: number,
	slowUntil: number,
	slowFactor: number,
}

local states: { [Player]: State } = {}
local raidsConfig: any = nil

function Speed.configure(raids: any)
	raidsConfig = raids
end

local function stateOf(player: Player): State
	local state = states[player]
	if state == nil then
		state = { mount = nil, carrying = false, stunUntil = 0, slowUntil = 0, slowFactor = 1 }
		states[player] = state
	end
	return state :: State
end

-- The walk speed the player should have right now.
function Speed.allowed(player: Player): number
	local state = stateOf(player)
	local now = os.clock()
	if state.stunUntil > now then
		return 0
	end
	local speed = state.mount or StarterPlayer.CharacterWalkSpeed
	if state.carrying and raidsConfig then
		speed = Defenses.carrySpeed(state.mount, raidsConfig)
	end
	if state.slowUntil > now then
		speed *= state.slowFactor
	end
	return speed
end

function Speed.apply(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Speed.allowed(player)
	end
end

function Speed.setMount(player: Player, speed: number?)
	stateOf(player).mount = speed
	Speed.apply(player)
end

function Speed.setCarrying(player: Player, carrying: boolean)
	stateOf(player).carrying = carrying
	Speed.apply(player)
end

local function after(player: Player, seconds: number)
	task.delay(seconds + 0.05, function()
		if states[player] then
			Speed.apply(player)
		end
	end)
end

function Speed.stun(player: Player, seconds: number)
	local state = stateOf(player)
	state.stunUntil = math.max(state.stunUntil, os.clock() + seconds)
	Speed.apply(player)
	after(player, seconds)
end

function Speed.slow(player: Player, factor: number, seconds: number)
	local state = stateOf(player)
	state.slowUntil = os.clock() + seconds
	state.slowFactor = factor
	Speed.apply(player)
	after(player, seconds)
end

function Speed.forget(player: Player)
	states[player] = nil
end

return Speed
