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
	local function play(index: number)
		current = index
		local sound = sounds[index]
		sound.Volume = 0
		sound:Play()
		TweenService:Create(sound, fade, { Volume = config.volume }):Play()
	end
	for index, sound in sounds do
		sound.Ended:Connect(function()
			if on and current == index then
				play(index % #sounds + 1)
			end
		end)
	end

	local button: TextButton
	button = menu.add("Music", "🎵 Music", function()
		on = not on
		button.Text = if on then "🎵 Music" else "🔇 Music"
		local sound = sounds[current]
		if on then
			play(current)
		else
			TweenService:Create(sound, fade, { Volume = 0 }):Play()
			task.delay(config.fadeSeconds, function()
				if not on then
					sound:Pause()
				end
			end)
		end
	end)
	play(1)
end

return Music
