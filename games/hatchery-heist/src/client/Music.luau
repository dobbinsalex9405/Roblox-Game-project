--!strict
-- Background music from config/atmosphere.luau: the tracks play in order and
-- loop, on this player's client only. A side-menu button turns it off and on.
--
-- Music never starts or stops abruptly. It starts once the player has
-- spawned and the first track has loaded, rising from silence over
-- `startFadeSeconds` (slow at first, so it is noticed gently rather than
-- arriving at a random moment). Each track fades into the next over
-- `crossfadeSeconds` before it ends, and the button fades over `fadeSeconds`.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Music = {}

export type Menu = {
	add: (name: string, text: string, onClick: () -> ()) -> TextButton,
}

local LOAD_SECONDS = 10 -- a track that hasn't loaded by then is skipped

function Music.start(menu: Menu)
	local config = (require(ReplicatedStorage.GameConfig.atmosphere) :: any).music
	if #config.tracks == 0 then
		return
	end
	local sounds: { Sound } = {}
	for index, id in config.tracks do
		local sound = Instance.new("Sound")
		sound.Name = `Music{index}`
		sound.SoundId = `rbxassetid://{id}`
		sound.Volume = 0
		sound.Looped = #config.tracks == 1
		sound.Parent = SoundService
		table.insert(sounds, sound)
	end
	-- Load every track up front, so a change of track never waits.
	task.spawn(function()
		pcall(ContentProvider.PreloadAsync, ContentProvider, sounds)
	end)

	-- One volume change at a time per track: a new fade replaces the last.
	local tweens: { [Sound]: Tween } = {}
	local function fadeTo(sound: Sound, volume: number, seconds: number, direction: Enum.EasingDirection)
		local old = tweens[sound]
		if old then
			old:Cancel()
		end
		local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, direction)
		local tween = TweenService:Create(sound, info, { Volume = volume })
		tweens[sound] = tween
		tween:Play()
	end
	-- Fade a track out, then stop it, unless something started it again.
	local function fadeOut(sound: Sound, seconds: number, stop: () -> ())
		fadeTo(sound, 0, seconds, Enum.EasingDirection.Out)
		local tween = tweens[sound]
		task.delay(seconds, function()
			if tweens[sound] == tween then
				stop()
			end
		end)
	end

	local on = true
	local current = 1
	local generation = 0 -- bumps on every track change, so stale waits give up
	local crossing = false -- the current track is already fading into the next
	local started = false -- a track has been asked to play at least once

	local play: (index: number, skipped: number, fadeSeconds: number) -> ()
	local function advance(skipped: number, fadeSeconds: number)
		if skipped >= #sounds then
			return -- nothing loads: stay silent rather than spin
		end
		play(current % #sounds + 1, skipped + 1, fadeSeconds)
	end

	function play(index: number, skipped: number, fadeSeconds: number)
		generation += 1
		local mine = generation
		current = index
		crossing = false
		started = true
		local sound = sounds[index]
		task.spawn(function()
			if not sound.IsLoaded then
				local started = os.clock()
				while not sound.IsLoaded and os.clock() - started < LOAD_SECONDS do
					task.wait(0.25)
				end
			end
			if mine ~= generation or not on then
				return
			end
			if not sound.IsLoaded then
				advance(skipped, fadeSeconds)
				return
			end
			sound.Volume = 0
			sound.TimePosition = 0
			sound:Play()
			fadeTo(sound, config.volume, fadeSeconds, Enum.EasingDirection.In)
		end)
	end

	-- Fade into the next track a little before this one ends.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local sound = sounds[current]
			local left = sound.TimeLength - sound.TimePosition
			if on and #sounds > 1 and not crossing and sound.IsPlaying and sound.TimeLength > 0 then
				if left <= config.crossfadeSeconds then
					crossing = true
					fadeOut(sound, math.max(left, 0.1), function()
						sound:Stop()
					end)
					play(current % #sounds + 1, 0, config.crossfadeSeconds)
				end
			end
		end
	end)
	-- A track that ends before the crossfade caught it still moves on.
	for index, sound in sounds do
		sound.Ended:Connect(function()
			if on and current == index and not crossing then
				play(index % #sounds + 1, 0, config.crossfadeSeconds)
			end
		end)
	end

	local button: TextButton
	button = menu.add("Music", "🎵 Music", function()
		on = not on
		button.Text = if on then "🎵 Music" else "🔇 Music"
		local sound = sounds[current]
		if on then
			if sound.IsPlaying then
				-- Turned back on mid fade-out: just fade up again.
				fadeTo(sound, config.volume, config.fadeSeconds, Enum.EasingDirection.In)
			elseif sound.IsPaused and sound.TimePosition > 0 then
				-- Carry on where it stopped instead of restarting the track.
				sound:Resume()
				fadeTo(sound, config.volume, config.fadeSeconds, Enum.EasingDirection.In)
			else
				play(current, 0, config.fadeSeconds)
			end
		else
			generation += 1
			fadeOut(sound, config.fadeSeconds, function()
				if not on then
					sound:Pause()
				end
			end)
		end
	end)

	-- Start once the player is in the world, not while the game is loading.
	task.spawn(function()
		local player = Players.LocalPlayer
		if player.Character == nil then
			player.CharacterAdded:Wait()
		end
		task.wait(config.startDelaySeconds)
		if on and not started then
			play(1, 0, config.startFadeSeconds)
		end
	end)
end

return Music
