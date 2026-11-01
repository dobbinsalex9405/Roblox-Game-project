--!strict
-- The player's own base: prompts on incubators (hatch, unlock), creature pads
-- (ride), the collect pad and the rebirth stand. Also writes the countdown
-- text on every base's incubators from the server's ReadyAt attribute.
-- Prompts only ask; the server checks everything again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Layout)

local Context = require(script.Parent.Context)

local BaseView = {}

local function prompt(parent: Instance, name: string, action: string, hold: number?): ProximityPrompt
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("ProximityPrompt") then
		return existing
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

local function setText(part: Instance, text: string)
	local gui = part:FindFirstChild("Label")
	local label = gui and gui:FindFirstChild("Text")
	if label and (label :: TextLabel).Text ~= text then
		(label :: TextLabel).Text = text
	end
end

local function formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function BaseView.start(ctx: Context.Context)
	local plots = Workspace:WaitForChild("Plots")
	local wired: Model? = nil

	local function wire(model: Model)
		wired = model
		for _, incubator in (model:WaitForChild("Incubators") :: Folder):GetChildren() do
			local slot = incubator:GetAttribute("Slot") :: number
			local hatch = prompt(incubator, "Hatch", "Hatch")
			hatch.Triggered:Connect(function()
				ctx.fire(ctx.remotes["HH:Hatch"], slot)
			end)
			local unlock = prompt(incubator, "Unlock", "Unlock", 0.5)
			unlock.Triggered:Connect(function()
				ctx.fire(ctx.remotes["HH:BuySlot"])
			end)
		end
		for _, pad in (model:WaitForChild("Pads") :: Folder):GetChildren() do
			local ride = prompt(pad, "Ride", "Ride")
			ride.Triggered:Connect(function()
				local uid = pad:GetAttribute("CreatureUid")
				if type(uid) == "string" then
					ctx.fire(ctx.remotes["HH:Ride"], uid)
				end
			end)
		end
		local collect = prompt(model:WaitForChild("CollectPad"), "Collect", "Collect")
		collect.Triggered:Connect(function()
			ctx.fire(ctx.remotes["HH:Collect"])
		end)
		local rebirth = prompt(model:WaitForChild("RebirthStand"), "Rebirth", "Rebirth", 2)
		rebirth.ObjectText = "Resets coins and creatures for +income"
		rebirth.Triggered:Connect(function()
			ctx.fire(ctx.remotes["HH:Rebirth"])
		end)
	end

	-- Updates prompt and label state ten times a second.
	task.spawn(function()
		while true do
			local now = ctx.serverNow()
			local own = ctx.plot()
			if own and own ~= wired then
				wire(own)
			end
			for _, model in plots:GetChildren() do
				local folder = model:FindFirstChild("Incubators")
				if folder == nil then
					continue
				end
				local isOwn = model == own
				for _, incubator in folder:GetChildren() do
					local state = incubator:GetAttribute("State")
					local readyAt = incubator:GetAttribute("ReadyAt")
					local ready = state == "Busy" and type(readyAt) == "number" and readyAt <= now
					if state == "Busy" then
						local eggId = incubator:GetAttribute("EggId") :: string
						setText(
							incubator,
							if ready
								then "Ready!"
								else `{Layout.displayName(eggId)} {formatTime((readyAt :: number) - now)}`
						)
					elseif state == "Buyable" then
						setText(
							incubator,
							`Unlock: {Layout.shortNumber(incubator:GetAttribute("Cost") :: number)}`
						)
					end
					if isOwn then
						local hatch = incubator:FindFirstChild("Hatch") :: ProximityPrompt?
						local unlock = incubator:FindFirstChild("Unlock") :: ProximityPrompt?
						if hatch then
							hatch.Enabled = ready
						end
						if unlock then
							unlock.Enabled = state == "Buyable"
							unlock.ObjectText = if state == "Buyable"
								then `{Layout.shortNumber(incubator:GetAttribute("Cost") :: number)} coins`
								else ""
						end
					end
				end
				if isOwn then
					for _, pad in (model:FindFirstChild("Pads") :: Folder):GetChildren() do
						local ride = pad:FindFirstChild("Ride") :: ProximityPrompt?
						if ride then
							local species = pad:GetAttribute("SpeciesId")
							ride.Enabled = type(species) == "string" and pad:GetAttribute("Riding") ~= true
							ride.ObjectText = if type(species) == "string"
								then Layout.displayName(species)
								else ""
						end
					end
					local data = ctx.data()
					local collect = (model:FindFirstChild("CollectPad") :: Part):FindFirstChild(
							"Collect"
						) :: ProximityPrompt?
					if collect then
						collect.Enabled = data ~= nil
					end
				end
			end
			task.wait(0.1)
		end
	end)
end

return BaseView
