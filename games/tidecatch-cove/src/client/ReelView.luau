--!strict
-- The reel minigame on screen. After the bite a big "!" button appears: tap
-- it to set the hook. Then a bar: hold anywhere on the big button (or the
-- space bar or mouse) to push the green catch zone right, let go to let it
-- drift left, and keep the fish inside until the bar fills. The simulation is
-- src/shared/Reel.luau; the server only accepts the result if it took at
-- least as long as a perfect human reel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Reel = require(Shared.Reel)

local Context = require(script.Parent.Context)
local Ui = require(script.Parent.Ui)

local ReelView = {}

export type Done = (caught: boolean) -> ()

export type Api = {
	play: (rarity: string, rodTier: number, done: Done) -> (),
	cancel: () -> (),
}

function ReelView.start(ctx: Context.Context): Api
	local fishing = ctx.config.fishing
	local gui = Instance.new("ScreenGui")
	gui.Name = "ReelGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = ctx.player:WaitForChild("PlayerGui")

	local root =
		Ui.panel(gui, "Reel", UDim2.new(0.9, 0, 0, 190), UDim2.new(0.5, 0, 1, -24), Vector2.new(0.5, 1))
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(520, 190)
	sizeLimit.Parent = root
	root.Visible = false

	local title = Ui.label(root, "Title", UDim2.new(1, -16, 0, 26), UDim2.fromOffset(8, 6))

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.new(1, -16, 0, 34)
	bar.Position = UDim2.fromOffset(8, 38)
	bar.BackgroundColor3 = Color3.fromRGB(10, 40, 70)
	Ui.corner(bar, 6)
	bar.Parent = root

	local zone = Instance.new("Frame")
	zone.Name = "Zone"
	zone.AnchorPoint = Vector2.new(0.5, 0)
	zone.Size = UDim2.fromScale(0.3, 1)
	zone.BackgroundColor3 = Ui.GOOD
	zone.BackgroundTransparency = 0.25
	Ui.corner(zone, 6)
	zone.Parent = bar

	local fish = Instance.new("Frame")
	fish.Name = "Fish"
	fish.AnchorPoint = Vector2.new(0.5, 0.5)
	fish.Size = UDim2.fromOffset(14, 28)
	fish.Position = UDim2.fromScale(0.5, 0.5)
	fish.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Ui.corner(fish, 7)
	fish.Parent = bar

	local progressBack = Instance.new("Frame")
	progressBack.Name = "Progress"
	progressBack.Size = UDim2.new(1, -16, 0, 10)
	progressBack.Position = UDim2.fromOffset(8, 78)
	progressBack.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	Ui.corner(progressBack, 5)
	progressBack.Parent = root
	local progress = Instance.new("Frame")
	progress.Size = UDim2.fromScale(0.3, 1)
	progress.BackgroundColor3 = Ui.GOLD
	Ui.corner(progress, 5)
	progress.Parent = progressBack

	-- One big target for the thumb: tap to hook, hold to reel.
	local hold = Ui.button(root, "Hold", "", UDim2.new(1, -16, 0, 86), Ui.BUTTON)
	hold.Position = UDim2.fromOffset(8, 96)

	local holding = false
	local tapped = false
	hold.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
			holding = true
			tapped = true
		end
	end)
	hold.InputEnded:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
			holding = false
		end
	end)
	local keyHeld = false
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.Space and root.Visible then
			keyHeld = true
			tapped = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.Space then
			keyHeld = false
		end
	end)

	local running: RBXScriptConnection? = nil
	local function stop()
		if running then
			running:Disconnect()
			running = nil
		end
		root.Visible = false
		holding = false
	end

	local api = {} :: Api

	-- Runs one reel. `done` gets the result once (caught or not).
	function api.play(rarity: string, rodTier: number, done: Done)
		stop()
		local params = Reel.params(rarity, rodTier, fishing)
		local rng = Random.new()
		local random = function()
			return rng:NextNumber()
		end
		local state = Reel.new(params, random)
		local reel = fishing.reel
		local phase = "hook"
		local phaseTime = 0
		tapped = false
		root.Visible = true
		bar.Visible = false
		progressBack.Visible = false
		title.Text = `Something {string.lower(rarity)} bit!`
		title.TextColor3 = Ui.GOLD
		hold.Text = "!  Tap to hook  !"
		zone.Size = UDim2.fromScale(params.zoneWidth, 1)

		local finished = false
		local function finish(caught: boolean)
			if finished then
				return
			end
			finished = true
			stop()
			done(caught)
		end

		running = RunService.RenderStepped:Connect(function(dt: number)
			phaseTime += dt
			if phase == "hook" then
				-- Taps before a human could react do not count; tapping
				-- early just waits for that moment.
				if tapped and phaseTime >= reel.reactionSeconds then
					phase = "reel"
					phaseTime = 0
					bar.Visible = true
					progressBack.Visible = true
					hold.Text = "Hold to reel"
					title.Text = "Keep the fish in the green zone!"
					title.TextColor3 = Color3.new(1, 1, 1)
				elseif phaseTime >= reel.hookSeconds then
					finish(false)
				end
				return
			end
			local result = Reel.step(state, params, dt, holding or keyHeld, random)
			zone.Position = UDim2.fromScale(state.zone, 0)
			fish.Position = UDim2.fromScale(state.fish, 0.5)
			fish.BackgroundColor3 = if Reel.inZone(state, params) then Ui.GOLD else Color3.new(1, 1, 1)
			progress.Size = UDim2.fromScale(state.progress, 1)
			if result then
				finish(result == "caught")
			end
		end)
	end

	function api.cancel()
		stop()
	end

	return api
end

return ReelView
