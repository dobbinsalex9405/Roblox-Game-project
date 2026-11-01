--!strict
-- The first-minute guide (src/shared/Guide.luau): a goal banner under the
-- top bar and, until the first catch, a glowing arrow from the player to the
-- nearest dock they can fish from. A brand-new player also starts with their
-- Worms picked, so the first casts show off rarer fish.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Catch = require(Shared.Catch)
local Guide = require(Shared.Guide)

local Context = require(script.Parent.Context)
local Ui = require(script.Parent.Ui)

local GuideView = {}

function GuideView.start(ctx: Context.Context)
	local config = ctx.config
	local gui = ctx.player:WaitForChild("PlayerGui"):WaitForChild("TidecatchHud")
	local docks = Workspace:WaitForChild("Map"):WaitForChild("Docks")

	local banner =
		Ui.panel(gui, "Guide", UDim2.fromOffset(380, 44), UDim2.new(0.5, 0, 0, 118), Vector2.new(0.5, 0))
	banner.BackgroundColor3 = Color3.fromRGB(30, 70, 110)
	banner.Visible = false
	local text = Ui.label(banner, "Text", UDim2.new(1, -16, 1, -8), UDim2.fromOffset(8, 4))
	text.TextColor3 = Ui.GOLD
	-- At a dock the odds card has this spot, and the Cast prompt and the reel
	-- panel say what to do, so the banner steps aside.
	local oddsCard = gui:WaitForChild("OddsCard") :: GuiObject

	-- The arrow: a wide glowing beam from the character's feet to the dock's
	-- float.
	local arrow: Beam? = nil
	local arrowDock: string? = nil
	local function clearArrow()
		if arrow then
			arrow:Destroy()
			arrow = nil
		end
		arrowDock = nil
	end
	local function pointAt(spotId: string)
		local character = ctx.player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local dock = docks:FindFirstChild(spotId)
		local float = dock and dock:FindFirstChild("Float") :: BasePart?
		if root == nil or float == nil then
			clearArrow()
			return
		end
		if arrow and arrowDock == spotId and arrow.Attachment0 and arrow.Attachment0.Parent == root then
			return
		end
		clearArrow()
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, -2.5, 0)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Parent = float
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Width0 = 1.6
		b.Width1 = 1.6
		b.FaceCamera = true
		b.LightEmission = 1
		b.Transparency = NumberSequence.new(0.2)
		b.Color = ColorSequence.new(Ui.GOLD)
		b.Parent = root
		b.Destroying:Connect(function()
			a0:Destroy()
			a1:Destroy()
		end)
		arrow = b
		arrowDock = spotId
	end

	-- Within this many studs of the dock, the Cast prompt takes over.
	local NEAR_DOCK = config.fishing.castReach

	local pickedStartingBait = false
	local function render()
		local d = ctx.data()
		if d == nil then
			return
		end
		if not pickedStartingBait then
			pickedStartingBait = true
			if d.firsts.FirstCatch == nil and ctx.bait() == Catch.NO_BAIT then
				ctx.setBait(Guide.startingBait(d, config.fishing))
			end
		end
		local step = Guide.step(d)
		banner.Visible = step ~= nil and not oddsCard.Visible
		text.Text = if step then step.text else ""
		local spotId = Guide.dockFor(d, config.fishing)
		local wantArrow = step ~= nil and step.arrowToDock and spotId ~= nil
		if wantArrow then
			local character = ctx.player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local dock = docks:FindFirstChild(spotId :: string)
			local float = dock and dock:FindFirstChild("Float") :: BasePart?
			if root and float then
				local flat = Vector3.new(1, 0, 1)
				wantArrow = ((root.Position - float.Position) * flat).Magnitude > NEAR_DOCK
			end
		end
		if wantArrow then
			pointAt(spotId :: string)
		else
			clearArrow()
		end
	end

	ctx.onData(function()
		render()
	end)
	oddsCard:GetPropertyChangedSignal("Visible"):Connect(render)
	-- Walking changes whether the arrow is needed; respawns need a new one.
	task.spawn(function()
		while Players.LocalPlayer.Parent do
			render()
			task.wait(0.5)
		end
	end)
end

return GuideView
