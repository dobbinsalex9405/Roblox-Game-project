--!strict
-- Fishing at the docks: a Cast prompt on every dock, the odds card while the
-- prompt is up, the odds board on each dock, the line out to the float, and
-- the reel minigame when a fish bites. Prompts only ask; the server checks
-- the rod, the bait, the distance and the timing again.

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Catch = require(Shared.Catch)
local Layout = require(Shared.Layout)

local Context = require(script.Parent.Context)
local Hud = require(script.Parent.Hud)
local OddsView = require(script.Parent.OddsView)
local ReelView = require(script.Parent.ReelView)
local Ui = require(script.Parent.Ui)

local FishingView = {}

function FishingView.start(ctx: Context.Context, hud: Hud.Api, reel: ReelView.Api)
	local fishing = ctx.config.fishing
	local docks = Workspace:WaitForChild("Map"):WaitForChild("Docks")

	local line: { id: number, spotId: string, bitten: boolean, startedAt: number }? = nil
	local prompts: { [string]: ProximityPrompt } = {}
	local boards: { [string]: Frame } = {}

	-- The fishing line: a beam from the character's hand to the float.
	local beam: Beam? = nil
	local function clearLine()
		if beam then
			beam:Destroy()
			beam = nil
		end
	end
	local function drawLine(spotId: string)
		clearLine()
		local character = ctx.player.Character
		local hand = character
			and (
				character:FindFirstChild("RightHand") or character:FindFirstChild("HumanoidRootPart")
			) :: BasePart?
		local dock = docks:FindFirstChild(spotId)
		local float = dock and dock:FindFirstChild("Float") :: BasePart?
		if hand == nil or float == nil then
			return
		end
		local a0 = Instance.new("Attachment")
		a0.Parent = hand
		local a1 = Instance.new("Attachment")
		a1.Parent = float
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Width0 = 0.08
		b.Width1 = 0.08
		b.CurveSize0 = 4
		b.FaceCamera = true
		b.Color = ColorSequence.new(Color3.fromRGB(240, 240, 240))
		b.Parent = float
		-- Clean the attachments up with the beam.
		b.Destroying:Connect(function()
			a0:Destroy()
			a1:Destroy()
		end)
		beam = b
	end

	local function refreshPrompts()
		local d = ctx.data()
		for spotId, prompt in prompts do
			local spot = Catch.spot(fishing, spotId)
			local rodOk = d ~= nil and spot ~= nil and d.rodTier >= spot.minRod
			local open = spot ~= nil and not spot.lowTideOnly
			prompt.Enabled = line == nil and open and rodOk
			local baitId = ctx.bait()
			prompt.ObjectText = if baitId == Catch.NO_BAIT then "No bait" else Layout.displayName(baitId)
		end
	end

	local function renderBoards()
		for spotId, holder in boards do
			OddsView.render(holder, spotId, ctx.bait())
		end
	end

	-- Docks may stream in after start-up (and back in after streaming out),
	-- so each one is set up when it appears.
	local function setupDock(dock: Instance)
		local spotId = dock:GetAttribute("SpotId")
		if type(spotId) ~= "string" then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Cast"
		prompt.ActionText = "Cast"
		prompt.MaxActivationDistance = fishing.castReach - 2
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("TCSpotId", spotId)
		prompt.Triggered:Connect(function()
			if line == nil then
				ctx.fire(ctx.remotes["TC:Cast"], spotId, ctx.bait())
			end
		end)
		prompt.Parent = dock
		prompts[spotId] = prompt
		refreshPrompts()

		local board = dock:WaitForChild("OddsBoard", 10)
		if board == nil or dock.Parent == nil then
			return
		end
		local old = boards[spotId]
		if old then
			(old.Parent :: Instance):Destroy()
		end
		local sg = Instance.new("SurfaceGui")
		sg.Name = `Odds{spotId}`
		sg.Face = Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 30
		sg.Adornee = board
		local holder = Instance.new("Frame")
		holder.Name = "Holder"
		holder.Size = UDim2.fromScale(1, 1)
		holder.BackgroundTransparency = 1
		Ui.list(holder, 8)
		holder.Parent = sg
		sg.Parent = ctx.player:WaitForChild("PlayerGui")
		boards[spotId] = holder
		OddsView.render(holder, spotId, ctx.bait())
	end
	docks.ChildAdded:Connect(function(dock: Instance)
		task.spawn(setupDock, dock)
	end)
	for _, dock in docks:GetChildren() do
		task.spawn(setupDock, dock)
	end

	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		local spotId = prompt:GetAttribute("TCSpotId")
		if type(spotId) == "string" then
			hud.showOdds(spotId)
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		if prompt:GetAttribute("TCSpotId") then
			hud.hideOdds()
		end
	end)

	local function endLine()
		line = nil
		clearLine()
		hud.status(nil)
		refreshPrompts()
	end

	ctx.on(ctx.remotes["TC:CastStarted"], function(castId: number, spotId: string)
		line = { id = castId, spotId = spotId, bitten = false, startedAt = os.clock() }
		drawLine(spotId)
		hud.status("Waiting for a bite...")
		refreshPrompts()
	end)
	ctx.on(ctx.remotes["TC:Bite"], function(castId: number, rarity: string, auto: boolean)
		local current = line
		if current == nil or current.id ~= castId then
			return
		end
		current.bitten = true
		if auto then
			-- The Auto-reel pass lands it on the server; Caught or Escaped follows.
			hud.status(`Auto-reeling a {rarity} fish...`)
			return
		end
		hud.status(nil)
		local d = ctx.data()
		local rodTier = if d then d.rodTier else 1
		reel.play(rarity, rodTier, function(caught: boolean)
			ctx.fire(ctx.remotes["TC:Reel"], castId, caught)
			hud.status(if caught then "Reeling in..." else nil)
		end)
	end)
	ctx.on(
		ctx.remotes["TC:Caught"],
		function(castId: number, speciesId: string, kg: number, uid: string, soldFor: number, isNew: boolean)
			if line and line.id == castId then
				endLine()
			end
			hud.showCatch(speciesId, kg, uid, soldFor, isNew)
		end
	)
	ctx.on(ctx.remotes["TC:Escaped"], function(castId: number, text: string)
		if line and line.id == castId then
			endLine()
			reel.cancel()
		end
		hud.notice(text)
	end)

	ctx.onBait(function()
		refreshPrompts()
		renderBoards()
	end)
	OddsView.onChanged(renderBoards)
	ctx.onData(function()
		refreshPrompts()
		renderBoards()
	end)

	-- A line that never hears back (a lost message, a server restart) is
	-- forgotten after the longest a cast and a reel can take.
	local longest = fishing.biteSeconds.max + fishing.reel.hookSeconds + fishing.reel.timeoutSeconds + 10
	task.spawn(function()
		while true do
			task.wait(1)
			local current = line
			if current and os.clock() - current.startedAt > longest then
				reel.cancel()
				endLine()
			end
		end
	end)

	refreshPrompts()
	renderBoards()
end

return FishingView
