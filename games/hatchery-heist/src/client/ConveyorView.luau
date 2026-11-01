--!strict
-- Draws every base's egg conveyor from the shared schedule (Conveyor.luau)
-- and the server clock, so no egg positions are ever sent over the network.
-- Eggs on the player's own belt get a Buy prompt; showing that prompt opens
-- the odds card, and the prompt stays off until the odds are known.

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Conveyor = require(Shared.Conveyor)
local Hatchery = require(Shared.Hatchery)
local Layout = require(Shared.Layout)

local Context = require(script.Parent.Context)
local OddsView = require(script.Parent.OddsView)

local ConveyorView = {}

export type Hooks = {
	showOdds: (eggId: string) -> (),
	hideOdds: () -> (),
}

function ConveyorView.start(ctx: Context.Context, hooks: Hooks)
	local belt = ctx.config.economy.conveyor
	local folder = Instance.new("Folder")
	folder.Name = "ConveyorEggs"
	folder.Parent = Workspace

	-- shown[plot][index] = egg part
	local shown: { [number]: { [number]: Part } } = {}
	-- Own-belt eggs bought (hidden) or waiting for the server's answer.
	local bought: { [number]: boolean } = {}
	local waiting: { [number]: boolean } = {}
	local ANSWER_TIMEOUT = 3 -- seconds before an unanswered purchase is shown again

	local function ownEgg(index: number): Part?
		local _, ownPlot = ctx.plot()
		local eggs = ownPlot and shown[ownPlot]
		return eggs and eggs[index]
	end

	-- Shows the egg and its prompt again after a refusal (or no answer).
	local function restore(index: number)
		waiting[index] = nil
		local egg = ownEgg(index)
		if egg == nil or bought[index] then
			return
		end
		egg.Transparency = 0
		local prompt = egg:FindFirstChild("Buy") :: ProximityPrompt?
		if prompt then
			prompt.Enabled = OddsView.ready(egg:GetAttribute("EggId") :: string)
		end
	end

	ctx.on(ctx.remotes["HH:EggResult"], function(index: number, ok: boolean)
		if ok then
			waiting[index] = nil
			bought[index] = true
			local egg = ownEgg(index)
			if egg then
				egg.Transparency = 1
			end
		else
			restore(index)
		end
	end)

	local function makeEgg(index: number, eggId: string, own: boolean): Part
		local egg = Instance.new("Part")
		egg.Name = `Egg{index}`
		egg.Shape = Enum.PartType.Ball
		egg.Size = Vector3.new(2.6, 2.6, 2.6)
		egg.Anchored = true
		egg.CanCollide = false
		egg.Material = Enum.Material.SmoothPlastic
		egg.Color = Layout.eggColor(eggId)
		egg:SetAttribute("EggId", eggId)
		egg:SetAttribute("Index", index)
		if own then
			local info = Hatchery.eggById(ctx.config.eggs, eggId)
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "Buy"
			prompt.ActionText = "Buy"
			prompt.ObjectText = if info and info.priceCoins
				then `{Layout.displayName(eggId)}: {Layout.shortNumber(info.priceCoins)} coins`
				else Layout.displayName(eggId)
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.Enabled = OddsView.ready(eggId)
			prompt:SetAttribute("HHEggId", eggId)
			prompt.Triggered:Connect(function()
				if bought[index] or waiting[index] then
					return
				end
				-- Dim it until the server answers; hidden only once bought.
				waiting[index] = true
				egg.Transparency = 0.6
				prompt.Enabled = false
				ctx.fire(ctx.remotes["HH:BuyEgg"], index)
				task.delay(ANSWER_TIMEOUT, function()
					if waiting[index] then
						restore(index)
					end
				end)
			end)
			prompt.Parent = egg
		end
		egg.Parent = folder
		return egg
	end

	OddsView.onChanged(function()
		for _, eggs in shown do
			for index, egg in eggs do
				local prompt = egg:FindFirstChild("Buy") :: ProximityPrompt?
				if prompt and not bought[index] and not waiting[index] then
					prompt.Enabled = OddsView.ready(egg:GetAttribute("EggId") :: string)
				end
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

	RunService.RenderStepped:Connect(function()
		local now = ctx.serverNow()
		local _, ownPlot = ctx.plot()
		for plot = 1, Layout.PLOTS do
			local frame = Layout.plotCFrame(plot)
			local current: { [number]: Part } = shown[plot] or {}
			shown[plot] = current
			local seen: { [number]: boolean } = {}
			for _, beltEgg in Conveyor.onBelt(now, plot, belt) do
				seen[beltEgg.index] = true
				local existing: Part? = current[beltEgg.index]
				local egg: Part = if existing
					then existing
					else makeEgg(beltEgg.index, beltEgg.eggId, plot == ownPlot)
				current[beltEgg.index] = egg
				local spin = CFrame.Angles(0, beltEgg.progress * math.pi * 4, 0)
				egg.CFrame = frame * CFrame.new(Layout.beltPoint(beltEgg.progress)) * spin
			end
			for index, egg in current do
				if not seen[index] then
					egg:Destroy()
					current[index] = nil
					if plot == ownPlot then
						bought[index] = nil
						waiting[index] = nil
					end
				end
			end
		end
	end)
end

return ConveyorView
