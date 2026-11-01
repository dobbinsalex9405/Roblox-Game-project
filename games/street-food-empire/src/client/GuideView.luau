--!strict
-- Shows the first-session guide (src/shared/Guide.luau): the current goal on
-- a line under the cash bar, a bouncing arrow over the place to go and a
-- beam from the player to it. Disappears for good once Market Row is open.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Guide = require(Shared.Guide)
local Layout = require(Shared.Layout)

local Context = require(script.Parent.Context)

local GuideView = {}

local GOLD = Color3.fromRGB(255, 210, 63)

local function findTarget(plot: Model, target: Guide.Target): BasePart?
	local part: Instance? = nil
	if target.kind == "Counter" then
		part = plot:FindFirstChild("Counter")
	elseif target.kind == "Register" then
		part = plot:FindFirstChild("Register")
	elseif target.kind == "Spot" then
		local spots = plot:FindFirstChild("Spots")
		if spots then
			for _, tile in spots:GetChildren() do
				if tile:GetAttribute("Spot") == target.spot then
					part = tile
				end
			end
		end
	elseif target.kind == "Gate" then
		local gates = plot:FindFirstChild("Gates")
		if gates then
			for _, gate in gates:GetChildren() do
				if gate:GetAttribute("Next") == true then
					part = gate
				end
			end
		end
	end
	return if part and part:IsA("BasePart") then part else nil
end

function GuideView.start(ctx: Context.Context)
	local player = Players.LocalPlayer

	-- The goal line, under the cash bar (Hud).
	local gui = Instance.new("ScreenGui")
	gui.Name = "StreetFoodGuide"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local panel = Instance.new("Frame")
	panel.Name = "Goal"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 96)
	panel.Size = UDim2.new(0.92, 0, 0, 40)
	panel.BackgroundColor3 = Color3.fromRGB(30, 34, 80)
	panel.BackgroundTransparency = 0.15
	panel.Visible = false
	panel.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(420, 40)
	limit.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 2
	stroke.Parent = panel
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(10, 4)
	text.Size = UDim2.new(1, -20, 1, -8)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextWrapped = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Parent = panel

	-- The arrow over the target.
	local arrow = Instance.new("BillboardGui")
	arrow.Name = "GuideArrow"
	arrow.AlwaysOnTop = true
	arrow.Size = UDim2.fromOffset(60, 60)
	arrow.LightInfluence = 0
	arrow.Enabled = false
	local glyph = Instance.new("TextLabel")
	glyph.BackgroundTransparency = 1
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.Font = Enum.Font.GothamBlack
	glyph.Text = "▼"
	glyph.TextScaled = true
	glyph.TextColor3 = GOLD
	glyph.TextStrokeTransparency = 0.2
	glyph.Parent = arrow
	arrow.Parent = gui

	-- The beam from the player to the target.
	local anchor = Instance.new("Part")
	anchor.Name = "GuideAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Parent = Workspace
	local to = Instance.new("Attachment")
	to.Parent = anchor
	local beam = Instance.new("Beam")
	beam.Attachment1 = to
	beam.Color = ColorSequence.new(GOLD)
	beam.Transparency = NumberSequence.new(0.35)
	beam.Width0 = 0.5
	beam.Width1 = 0.5
	beam.FaceCamera = true
	beam.LightInfluence = 0
	beam.Enabled = false
	beam.Parent = anchor
	local from: Attachment? = nil

	local function attachToCharacter(character: Model)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root then
			local attachment = Instance.new("Attachment")
			attachment.Name = "GuideFrom"
			attachment.Parent = root
			from = attachment
			beam.Attachment0 = attachment
		end
	end
	if player.Character then
		task.spawn(attachToCharacter, player.Character)
	end
	player.CharacterAdded:Connect(attachToCharacter)

	local targetPart: BasePart? = nil
	local done = false

	-- The goal changes with cash and the queue; a few times a second is plenty.
	task.spawn(function()
		while not done do
			local d = ctx.data()
			local plot = ctx.plot()
			local step = if d and plot
				then Guide.next(
					d :: any,
					ctx.config,
					ctx.perks(),
					ctx.serverNow(),
					ctx.autoCollect(),
					Layout.cash
				)
				else nil
			if d and plot and step == nil then
				done = true
			end
			panel.Visible = step ~= nil
			targetPart = if step and step.target and plot then findTarget(plot, step.target) else nil
			if step then
				text.Text = step.text
			end
			task.wait(0.25)
		end
		panel.Visible = false
		targetPart = nil
	end)

	-- Arrow bounce and beam end, every frame.
	RunService.RenderStepped:Connect(function()
		local part = targetPart
		if part == nil then
			arrow.Enabled = false
			beam.Enabled = false
			return
		end
		local bob = math.sin(os.clock() * 4) * 0.6
		arrow.Adornee = part
		arrow.StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y / 2 + 5 + bob, 0)
		arrow.Enabled = true
		anchor.CFrame = CFrame.new(part.Position + Vector3.new(0, part.Size.Y / 2 + 0.5, 0))
		beam.Enabled = from ~= nil and from.Parent ~= nil
	end)
end

return GuideView
