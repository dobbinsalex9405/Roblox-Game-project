--!strict
-- Short sound effects from config/atmosphere.luau `sounds`, on this player's
-- client only. A sound whose id is 0 is silent: the game plays the same with
-- or without it, so ids can be picked by ear later without code changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sfx = {}

type Entry = { id: number, volume: number }

local sounds: { [string]: Sound } = {}

local function config(): { [string]: Entry }
	local atmosphere = require(ReplicatedStorage.GameConfig.atmosphere) :: any
	return atmosphere.sounds or {}
end

-- Plays a named sound once; pitch nudges it (1 = as recorded).
function Sfx.play(name: string, pitch: number?)
	local entry = config()[name]
	if entry == nil or entry.id == 0 then
		return
	end
	local sound: Sound? = sounds[name]
	if not sound then
		local s = Instance.new("Sound")
		s.Name = `Sfx_{name}`
		s.SoundId = `rbxassetid://{entry.id}`
		s.Volume = entry.volume
		s.Parent = SoundService
		sounds[name] = s
		sound = s
	end
	assert(sound, "the sound was just made")
	sound.PlaybackSpeed = pitch or 1
	sound.TimePosition = 0
	sound:Play()
end

return Sfx
