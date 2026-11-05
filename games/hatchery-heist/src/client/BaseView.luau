--!strict
-- Prompts and labels on the bases.
--   Own base: hatch and unlock incubators, ride or guard creatures, collect,
--   rebirth, raise the shield, set traps and place decoy eggs.
--   Other bases: steal a creature (or what looks like one: a decoy egg).
-- Also writes the countdowns on every base's incubators and shield pylon from
-- the server's attributes. Prompts only ask; the server checks everything
-- again, including how close the player really is.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local IncubatorLabel = require(Shared.IncubatorLabel)
local Layout = require(Shared.Layout)

local Context = require(script.Parent.Context)

local BaseView = {}

local TRAP_COLORS: { [string]: Color3 } = {
	Snare = Color3.fromRGB(200, 60, 60),
	Slime = Color3.fromRGB(110, 220, 80),
}
local TRAP_HIDDEN = Color3.fromRGB(90, 90, 90) -- how every trap spot looks to raiders
local SECOND_PROMPT = Vector2.new(0, 72) -- keeps two prompts on one part apart

type PromptOptions = {
	hold: number?,
	key: Enum.KeyCode?,
	gamepad: Enum.KeyCode?,
	reach: number?,
	offset: Vector2?,
}

local function prompt(
	parent: Instance,
	name: string,
	action: string,
	options: PromptOptions?
): ProximityPrompt
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("ProximityPrompt") then
		return existing
	end
	local o: PromptOptions = options or {}
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.HoldDuration = o.hold or 0
	p.MaxActivationDistance = o.reach or 10
	p.RequiresLineOfSight = false
	p.Enabled = false
	if o.key then
		p.KeyboardKeyCode = o.key
	end
	if o.gamepad then
		p.GamepadKeyCode = o.gamepad
	end
	if o.offset then
		p.UIOffset = o.offset
	end
	p.Parent = parent
	return p
end

local function setPrompt(
	parent: Instance,
	name: string,
	enabled: boolean,
	objectText: string?,
	actionText: string?
)
	local p = parent:FindFirstChild(name) :: ProximityPrompt?
	if p == nil then
		return
	end
	p.Enabled = enabled
	if objectText and p.ObjectText ~= objectText then
		p.ObjectText = objectText
	end
	if actionText and p.ActionText ~= actionText then
		p.ActionText = actionText
	end
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

local function number(instance: Instance, attribute: string): number
	local value = instance:GetAttribute(attribute)
	return if type(value) == "number" then value else 0
end

function BaseView.start(ctx: Context.Context)
	local plots = Workspace:WaitForChild("Plots")
	local raids = ctx.config.raids
	local wired: { [Instance]: boolean } = {}
	local remotes = ctx.remotes

	-- Every base gets every prompt once; the update loop below enables the
	-- ones that fit (own base or someone else's).
	local function wire(model: Model)
		wired[model] = true
		local function plotIndex(): number?
			return ctx.plotIndexOf(model)
		end

		for _, incubator in (model:WaitForChild("Incubators") :: Folder):GetChildren() do
			local slot = incubator:GetAttribute("Slot") :: number
			prompt(incubator, "Hatch", "Hatch").Triggered:Connect(function()
				ctx.fire(remotes["HH:Hatch"], slot)
			end)
			prompt(incubator, "Unlock", "Unlock", { hold = 0.5 }).Triggered:Connect(function()
				ctx.fire(remotes["HH:BuySlot"])
			end)
		end

		for _, pad in (model:WaitForChild("Pads") :: Folder):GetChildren() do
			local function uid(): string?
				local value = pad:GetAttribute("CreatureUid")
				return if type(value) == "string" then value else nil
			end
			prompt(pad, "Ride", "Ride").Triggered:Connect(function()
				local id = uid()
				if id then
					ctx.fire(remotes["HH:Ride"], id)
				end
			end)
			prompt(pad, "Guard", "Make guard", {
				hold = 0.3,
				key = Enum.KeyCode.R,
				gamepad = Enum.KeyCode.ButtonY,
				offset = SECOND_PROMPT,
			}).Triggered:Connect(function()
				local id = uid()
				if id then
					ctx.fire(remotes["HH:Guard"], id)
				end
			end)
			prompt(pad, "Steal", "Steal", { hold = 0.4, reach = raids.pickupReach }).Triggered:Connect(
				function()
					local index = plotIndex()
					local padIndex = pad:GetAttribute("Pad")
					if index and type(padIndex) == "number" then
						ctx.fire(remotes["HH:Steal"], index, padIndex)
					end
				end
			)
		end

		prompt(model:WaitForChild("CollectPad"), "Collect", "Collect").Triggered:Connect(function()
			ctx.fire(remotes["HH:Collect"])
		end)
		local rebirth = prompt(model:WaitForChild("RebirthStand"), "Rebirth", "Rebirth", { hold = 2 })
		rebirth.ObjectText = "Resets coins and creatures for +income"
		rebirth.Triggered:Connect(function()
			ctx.fire(remotes["HH:Rebirth"])
		end)

		local pylon = model:WaitForChild("ShieldPylon")
		prompt(pylon, "Shield", "Raise shield", { hold = 0.3 }).Triggered:Connect(function()
			ctx.fire(remotes["HH:Shield"])
		end)

		for _, trap in (model:WaitForChild("Traps") :: Folder):GetChildren() do
			local spot = trap:GetAttribute("Spot") :: number
			local snare = prompt(trap, "Snare", "Set snare", { hold = 0.3 })
			snare.ObjectText = `{Layout.shortNumber(raids.traps.Snare.price)} coins`
			snare.Triggered:Connect(function()
				ctx.fire(remotes["HH:BuyTrap"], spot, "Snare")
			end)
			local slime = prompt(trap, "Slime", "Set slime", {
				hold = 0.3,
				key = Enum.KeyCode.R,
				gamepad = Enum.KeyCode.ButtonY,
				offset = SECOND_PROMPT,
			})
			slime.ObjectText = `{Layout.shortNumber(raids.traps.Slime.price)} coins`
			slime.Triggered:Connect(function()
				ctx.fire(remotes["HH:BuyTrap"], spot, "Slime")
			end)
		end

		for _, decoy in (model:WaitForChild("Decoys") :: Folder):GetChildren() do
			local spot = decoy:GetAttribute("Spot") :: number
			local place = prompt(decoy, "Place", "Place decoy egg", { hold = 0.3 })
			place.ObjectText = `{Layout.shortNumber(raids.decoy.price)} coins`
			place.Triggered:Connect(function()
				ctx.fire(remotes["HH:BuyDecoy"], spot)
			end)
			-- To a raider a decoy looks like any other creature.
			prompt(decoy, "Steal", "Steal", { hold = 0.4, reach = raids.pickupReach }).Triggered:Connect(
				function()
					local index = plotIndex()
					if index then
						ctx.fire(remotes["HH:StealDecoy"], index, spot)
					end
				end
			)
		end
	end

	local function updateIncubators(model: Model, isOwn: boolean, now: number)
		for _, incubator in (model:FindFirstChild("Incubators") :: Folder):GetChildren() do
			local state = incubator:GetAttribute("State")
			local readyAt = incubator:GetAttribute("ReadyAt")
			local eggId = incubator:GetAttribute("EggId")
			local cost = incubator:GetAttribute("Cost")
			-- Every state sets the label, so an emptied incubator never keeps "Ready!".
			local label, ready = IncubatorLabel.text(
				if type(state) == "string" then state else "Locked",
				if type(eggId) == "string" then eggId else nil,
				if type(readyAt) == "number" then readyAt else nil,
				if type(cost) == "number" then cost else nil,
				now,
				Layout.displayName,
				Layout.shortNumber
			)
			setText(incubator, label)
			setPrompt(incubator, "Hatch", isOwn and ready)
			setPrompt(
				incubator,
				"Unlock",
				isOwn and state == "Buyable",
				if state == "Buyable" then `{Layout.shortNumber(number(incubator, "Cost"))} coins` else ""
			)
		end
	end

	local function updatePads(model: Model, isOwn: boolean, canSteal: boolean)
		for _, pad in (model:FindFirstChild("Pads") :: Folder):GetChildren() do
			local species = pad:GetAttribute("SpeciesId")
			local has = type(species) == "string"
			local name = if has then Layout.displayName(species :: string) else ""
			local riding = pad:GetAttribute("Riding") == true
			local guarding = pad:GetAttribute("Guard") == true
			local carried = pad:GetAttribute("Carried") == true
			setPrompt(pad, "Ride", isOwn and has and not riding and not guarding, name)
			setPrompt(
				pad,
				"Guard",
				isOwn and has and not riding,
				name,
				if guarding then "Stand down" else "Make guard"
			)
			setPrompt(pad, "Steal", canSteal and has and not riding and not guarding and not carried, name)
		end
	end

	local function updateDefenses(model: Model, isOwn: boolean, canSteal: boolean, now: number)
		for _, trap in (model:FindFirstChild("Traps") :: Folder):GetChildren() do
			local kind = trap:GetAttribute("Kind")
			local armed = type(kind) == "string"
			-- Only the owner sees which spots hold which trap.
			local color = if isOwn and armed then TRAP_COLORS[kind :: string] or TRAP_HIDDEN else TRAP_HIDDEN
			if (trap :: BasePart).Color ~= color then
				(trap :: BasePart).Color = color
			end
			setText(trap, if isOwn and armed then kind :: string else "")
			setPrompt(trap, "Snare", isOwn and not armed)
			setPrompt(trap, "Slime", isOwn and not armed)
		end

		for _, decoy in (model:FindFirstChild("Decoys") :: Folder):GetChildren() do
			local placed = decoy:GetAttribute("Placed") == true
			setPrompt(decoy, "Place", isOwn and not placed)
			setPrompt(decoy, "Steal", canSteal and placed, Layout.displayName("Duckling"))
		end

		local pylon = model:FindFirstChild("ShieldPylon")
		if pylon then
			local shieldUntil = number(pylon, "ShieldUntil")
			local readyAt = number(pylon, "ReadyAt")
			local up = shieldUntil > now
			local text = if up
				then `Shielded {formatTime(shieldUntil - now)}`
				elseif isOwn and readyAt > now then `Shield recharging {formatTime(readyAt - now)}`
				elseif isOwn then "Shield ready"
				else ""
			setText(pylon, text)
			setPrompt(
				pylon,
				"Shield",
				isOwn and not up and readyAt <= now,
				`{raids.freeShieldSeconds}s, free`
			)
		end
	end

	-- Updates prompt and label state ten times a second.
	task.spawn(function()
		while true do
			local now = ctx.serverNow()
			local own = ctx.plot()
			local carrying = ctx.player:GetAttribute("Carrying") ~= nil
			for _, child in plots:GetChildren() do
				if not child:IsA("Model") then
					continue
				end
				local model = child :: Model
				if not wired[model] then
					wire(model)
				end
				local isOwn = model == own
				local taken = number(model, "OwnerUserId") ~= 0
				local shielded = number(model, "ShieldUntil") > now
				-- Steal prompts only on someone else's unshielded base, one
				-- creature at a time. The server also checks protection and
				-- cooldowns, and explains a refusal.
				local canSteal = own ~= nil and not isOwn and taken and not shielded and not carrying
				updateIncubators(model, isOwn, now)
				updatePads(model, isOwn, canSteal)
				updateDefenses(model, isOwn, canSteal, now)
				if isOwn then
					local collect = (model:FindFirstChild("CollectPad") :: Part):FindFirstChild("Collect")
					if collect then
						(collect :: ProximityPrompt).Enabled = ctx.data() ~= nil
					end
					setPrompt(model:FindFirstChild("RebirthStand") :: Instance, "Rebirth", true)
				else
					setPrompt(model:FindFirstChild("CollectPad") :: Instance, "Collect", false)
					setPrompt(model:FindFirstChild("RebirthStand") :: Instance, "Rebirth", false)
				end
			end
			task.wait(0.1)
		end
	end)
end

return BaseView
