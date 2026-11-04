--!strict
-- Background music from config/atmosphere.luau: the tracks play in order and
-- loop, on this player's client only. A side-menu button turns it off and on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Music = {}

export type Menu = {
	add: (name: string, text: string, onClick: () -> ()) -> TextButton,
}

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

	local on = true
	local current = 1
	local fade = TweenInfo.new(config.fadeSeconds)
	local LOAD_SECONDS = 10 -- a track that hasn't loaded by then is skipped
	local generation = 0 -- bumps on every track change, so stale waits give up

	local play: (index: number, skipped: number) -> ()
	local function advance(skipped: number)
		if skipped >= #sounds then
			return -- nothing loads: stay silent rather than spin
		end
		play(current % #sounds + 1, skipped + 1)
	end

	function play(index: number, skipped: number)
		generation += 1
		local mine = generation
		current = index
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
				advance(skipped)
				return
			end
			sound.Volume = 0
			sound:Play()
			TweenService:Create(sound, fade, { Volume = config.volume }):Play()
		end)
	end

	for index, sound in sounds do
		sound.Ended:Connect(function()
			if on and current == index then
				play(index % #sounds + 1, 0)
			end
		end)
	end

	local button: TextButton
	button = menu.add("Music", "🎵 Music", function()
		on = not on
		button.Text = if on then "🎵 Music" else "🔇 Music"
		local sound = sounds[current]
		if on then
			if sound.IsPaused and sound.TimePosition > 0 then
				-- Carry on where it stopped instead of restarting the track.
				sound:Resume()
				TweenService:Create(sound, fade, { Volume = config.volume }):Play()
			else
				play(current, 0)
			end
		else
			generation += 1
			TweenService:Create(sound, fade, { Volume = 0 }):Play()
			task.delay(config.fadeSeconds, function()
				if not on then
					sound:Pause()
				end
			end)
		end
	end)
	play(1, 0)
end

return Music
