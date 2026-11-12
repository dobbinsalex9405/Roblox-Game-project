--!strict
-- Draws the Egg Market in the middle of the map from the shared schedule
-- (shared/Conveyor) and the server clock, so no egg positions are ever sent
-- over the network: the belt's slats travelling round both lanes, and each
-- egg on its own pedestal, bobbing and slowly turning. The rails, bed and
-- odds boards are the server's (server/Market).
--
-- Every egg has a Buy prompt; showing it opens the odds card, and it stays
-- off until the odds are known. Whoever buys an egg first gets it: the
-- server tells everyone (HH:EggSold) and the egg leaves its pedestal.
--
-- Thousands of small parts move every frame, so they are anchored, never
-- collide and move together in one workspace:BulkMoveTo, and eggs that ride
-- off the belt are kept for the next egg of their kind.

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Conveyor = require(Shared.Conveyor)
local Hatchery = require(Shared.Hatchery)
local Layout = require(Shared.Layout)
local VoxelProp = require(Shared.VoxelProp)

local Context = require(script.Parent.Context)
local EventClock = require(script.Parent.EventClock)
local OddsView = require(script.Parent.OddsView)

local ConveyorView = {}

export type Hooks = {
	showOdds: (eggId: string) -> (),
	hideOdds: () -> (),
}

local SLAT_SPACING = 1.2 -- studs between slats along a lane
local SLAT_SIZE = Vector3.new(Layout.MARKET_WIDTH, 0.4, 0.55)
local SLAT_COLORS = { Color3.fromRGB(201, 142, 82), Color3.fromRGB(184, 126, 70) }
local PEDESTAL = { size = 2.4, height = 0.75 } -- the plan's crate
local BOB = 0.12 -- studs an egg bobs up and down
local BOB_SECONDS = 2.4
local TURN_SECONDS = 8 -- one slow turn of an egg on its pedestal
local ANSWER_TIMEOUT = 3 -- seconds before an unanswered purchase is shown again
local PROMPT_REACH = 10

type Piece = { part: BasePart, offset: CFrame }
type Egg = {
	index: number,
	eggId: string,
	pedestal: { Piece }, -- move with the belt
	shell: { Piece }, -- the egg: bobs and turns, hidden once sold
	prompt: ProximityPrompt,
	hidden: boolean,
}

local function piece(parent: Instance, name: string, size: Vector3, color: Color3, offset: CFrame): Piece
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.Color = color
	p.Parent = parent
	return { part = p, offset = offset }
end

function ConveyorView.start(ctx: Context.Context, hooks: Hooks)
	local belt = ctx.config.economy.conveyor
	local folder = Instance.new("Folder")
	folder.Name = "MarketEggs"
	folder.Parent = Workspace

	-- The slats: a ring of them per lane, all turning together.
	type Slat = { part: BasePart, lane: number, angle: number }
	local slats: { Slat } = {}
	for lane, radius in Layout.MARKET_LANES do
		local count = math.floor(2 * math.pi * radius / SLAT_SPACING)
		for k = 0, count - 1 do
			local p = piece(folder, "Slat", SLAT_SIZE, SLAT_COLORS[k % 2 + 1], CFrame.identity).part
			p.CanQuery = false
			table.insert(slats, { part = p, lane = lane, angle = k / count * 2 * math.pi })
		end
	end

	local shown: { [number]: Egg } = {}
	local pool: { [string]: { Egg } } = {}
	-- Eggs this player bought (hidden) or is waiting to hear about.
	local bought: { [number]: boolean } = {}
	local waiting: { [number]: boolean } = {}
	-- Eggs someone bought: gone for everyone.
	local sold: { [number]: boolean } = {}

	local function setHidden(egg: Egg, hidden: boolean, dim: number?)
		egg.hidden = hidden
		local t = if hidden then 1 else (dim or 0)
		for _, pc in egg.shell do
			pc.part.Transparency = t
		end
	end

	-- Prices, and the cheapest coin egg on the belt (Conveyor.offered).
	local prices: { [string]: number } = {}
	local cheapest = math.huge
	for eggId in belt.weights do
		local info = Hatchery.eggById(ctx.config.eggs, eggId)
		if info and info.priceCoins then
			prices[eggId] = info.priceCoins
			cheapest = math.min(cheapest, info.priceCoins)
		end
	end
	local coins = 0
	do
		local d = ctx.data()
		if d then
			coins = d.coins
		end
	end

	-- An Egg Sale (timed events) lowers every price while it runs.
	local function refreshPrompt(egg: Egg)
		local i = egg.index
		local price = prices[egg.eggId]
		local now = if price then EventClock.price(price) else 0
		egg.prompt.Enabled = not egg.hidden
			and not bought[i]
			and not waiting[i]
			and not sold[i]
			and OddsView.ready(egg.eggId)
			and Conveyor.offered(now, coins, EventClock.price(cheapest))
		if price then
			local text = `{Layout.displayName(egg.eggId)}: {Layout.shortNumber(now)} coins`
			egg.prompt.ObjectText = if now < price then `SALE! {text}` else text
		end
	end

	-- Shows the egg again after a refusal (or no answer), unless it is gone.
	local function restore(index: number)
		waiting[index] = nil
		local egg = shown[index]
		if egg == nil or bought[index] or sold[index] then
			return
		end
		setHidden(egg, false)
		refreshPrompt(egg)
	end

	local function gone(index: number)
		sold[index] = true
		local egg = shown[index]
		if egg then
			setHidden(egg, true)
			egg.prompt.Enabled = false
		end
	end

	ctx.on(ctx.remotes["HH:EggResult"], function(index: number, ok: boolean)
		if ok then
			waiting[index] = nil
			bought[index] = true
			gone(index)
		else
			restore(index)
		end
	end)
	ctx.on(ctx.remotes["HH:EggSold"], function(index: number)
		waiting[index] = nil
		gone(index)
	end)

	local function makeEgg(eggId: string): Egg
		local model = Instance.new("Model")
		model.Name = eggId
		local color = Layout.eggColor(eggId)
		local s = PEDESTAL.size
		local h = PEDESTAL.height
		local pedestal = {
			piece(
				model,
				"Crate",
				Vector3.new(s, h * 0.7, s),
				Color3.fromRGB(139, 90, 51),
				CFrame.new(0, h * 0.35, 0)
			),
			piece(
				model,
				"Trim",
				Vector3.new(s + 0.1, 0.18, s + 0.1),
				color,
				CFrame.new(0, h * 0.7 + 0.09, 0)
			),
			piece(
				model,
				"Straw",
				Vector3.new(s * 0.8, 0.14, s * 0.8),
				Color3.fromRGB(242, 206, 92),
				CFrame.new(0, h + 0.07, 0)
			),
		}
		local shell: { Piece } = {}
		local boxes: { VoxelProp.Box } = VoxelProp.boxes(eggId) or {}
		for _, box in boxes do
			local p = VoxelProp.part(box, CFrame.identity)
			p.Parent = model
			local pc: Piece = { part = p :: BasePart, offset = box.offset }
			table.insert(shell, pc)
		end
		if #shell == 0 then
			-- No art for this egg yet: a plain egg in its colour.
			local p = piece(model, "Shell", Vector3.new(1.5, 2, 1.5), color, CFrame.new(0, 1, 0))
			local ball = p.part :: Part
			ball.Shape = Enum.PartType.Ball
			table.insert(shell, p)
		end
		local info = Hatchery.eggById(ctx.config.eggs, eggId)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Buy"
		prompt.ActionText = "Buy"
		prompt.ObjectText = if info and info.priceCoins
			then `{Layout.displayName(eggId)}: {Layout.shortNumber(info.priceCoins)} coins`
			else Layout.displayName(eggId)
		prompt.MaxActivationDistance = PROMPT_REACH
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt:SetAttribute("HHEggId", eggId)
		prompt.Parent = pedestal[1].part
		model.Parent = folder
		local egg: Egg = {
			index = -1,
			eggId = eggId,
			pedestal = pedestal,
			shell = shell,
			prompt = prompt,
			hidden = false,
		}
		prompt.Triggered:Connect(function()
			local index = egg.index
			if index < 0 or bought[index] or waiting[index] or sold[index] then
				return
			end
			-- Dim it until the server answers; hidden once bought.
			waiting[index] = true
			setHidden(egg, false, 0.6)
			prompt.Enabled = false
			ctx.fire(ctx.remotes["HH:BuyEgg"], index)
			task.delay(ANSWER_TIMEOUT, function()
				if waiting[index] and egg.index == index then
					restore(index)
				end
			end)
		end)
		return egg
	end

	local function showPedestal(egg: Egg, shownNow: boolean)
		for _, pc in egg.pedestal do
			pc.part.Transparency = if shownNow then 0 else 1
		end
	end

	local function take(index: number, eggId: string): Egg
		local free = pool[eggId]
		local egg = if free and #free > 0 then table.remove(free) :: Egg else makeEgg(eggId)
		egg.index = index
		showPedestal(egg, true)
		setHidden(egg, sold[index] == true)
		refreshPrompt(egg)
		return egg
	end

	local function release(egg: Egg)
		egg.index = -1
		egg.prompt.Enabled = false
		setHidden(egg, true)
		showPedestal(egg, false)
		local free = pool[egg.eggId] or {}
		pool[egg.eggId] = free
		table.insert(free, egg)
	end

	OddsView.onChanged(function()
		for _, egg in shown do
			refreshPrompt(egg)
		end
	end)
	-- When an Egg Sale starts or ends, every egg on the belt changes price
	-- at once, not each at its own next update (Studio gate, Nov 7).
	task.spawn(function()
		local lastFactor = EventClock.price(1_000_000)
		while true do
			task.wait(0.5)
			local factor = EventClock.price(1_000_000)
			if factor ~= lastFactor then
				lastFactor = factor
				for _, egg in shown do
					refreshPrompt(egg)
				end
			end
		end
	end)
	ctx.onData(function(d: { [string]: any })
		if d.coins ~= coins then
			coins = d.coins
			for _, egg in shown do
				refreshPrompt(egg)
			end
		end
	end)

	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		local eggId = prompt:GetAttribute("HHEggId")
		if type(eggId) == "string" then
			hooks.showOdds(eggId)
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		if prompt:GetAttribute("HHEggId") then
			hooks.hideOdds()
		end
	end)

	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	RunService.RenderStepped:Connect(function()
		local now = ctx.serverNow()
		table.clear(parts)
		table.clear(frames)

		-- Slats: each lane turns once per travelSeconds, its own way.
		local turn = (now % belt.travelSeconds) / belt.travelSeconds * 2 * math.pi
		for _, slat in slats do
			local radius = Layout.MARKET_LANES[slat.lane]
			local a = slat.angle + (if slat.lane == 1 then -turn else turn)
			local outward = Vector3.new(math.cos(a), 0, math.sin(a))
			local at = outward * radius + Vector3.new(0, Layout.MARKET_SLAT_Y + SLAT_SIZE.Y / 2, 0)
			table.insert(parts, slat.part)
			table.insert(frames, CFrame.fromMatrix(at, outward, Vector3.yAxis))
		end

		local seen: { [number]: boolean } = {}
		for _, beltEgg in Conveyor.onBelt(now, belt) do
			local index = beltEgg.index
			seen[index] = true
			local egg = shown[index]
			if egg == nil then
				egg = take(index, beltEgg.eggId)
				shown[index] = egg
			end
			local e = egg :: Egg
			local frame = Layout.marketFrame(Conveyor.laneOf(index, belt), beltEgg.progress)
			for _, pc in e.pedestal do
				table.insert(parts, pc.part)
				table.insert(frames, frame * pc.offset)
			end
			if not e.hidden then
				local phase = now + index * 0.37
				local lift = PEDESTAL.height
					+ 0.14
					+ BOB * (0.5 + 0.5 * math.sin(phase / BOB_SECONDS * 2 * math.pi))
				local top = frame
					* CFrame.new(0, lift, 0)
					* CFrame.Angles(0, phase / TURN_SECONDS * 2 * math.pi, 0)
				for _, pc in e.shell do
					table.insert(parts, pc.part)
					table.insert(frames, top * pc.offset)
				end
			end
		end
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)

		for index, egg in shown do
			if not seen[index] then
				shown[index] = nil
				bought[index] = nil
				waiting[index] = nil
				release(egg)
			end
		end
		for index in sold do
			if not seen[index] then
				sold[index] = nil
			end
		end
	end)
end

return ConveyorView
