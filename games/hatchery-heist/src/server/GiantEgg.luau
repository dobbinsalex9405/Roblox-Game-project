--!strict
-- The Giant Golden Egg in the middle of the map (Alex, Nov 7 2026): builds
-- it (shared/GiantEggArt, made by tools/art/world/giantegg.py) and sells it,
-- once per player per event cycle.
--
-- What it hatches (Alex, Nov 12): a roll on egg "GiantEgg" in
-- config/eggs.luau (Epic or better, far better odds than any other egg),
-- shown on the odds card before purchase and policy-checked like every egg.
--
-- Buying (an event special, Alex Nov 7): while the day's event runs, the
-- egg's ProximityPrompt buys it for coins (shared/GiantEgg.coinPrice) in one
-- data update. The rest of the day it goes through the core shop's normal
-- checks plus this module's guard (once a cycle per player, never during
-- the event), then Roblox's purchase prompt, and the receipt rolls it.
-- Either way the creature is placed like a hatch and plays the hatch
-- reveal. Each client draws the sign beside the egg itself
-- (client/EventView), because "bought today" is per player.
--
-- Model attributes for the clients: CycleEndsAt (unix seconds the next egg
-- can be bought) and SignY (the sign's height).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local GiantEggArt = require(Shared.GiantEggArt)
local GiantEggRules = require(Shared.GiantEgg)
local Hatchery = require(Shared.Hatchery)
local PromptKeys = require(Shared.PromptKeys)
local VoxelProp = require(Shared.VoxelProp)

export type Deps = {
	services: any, -- CoreServer.Services
	productId: number,
	actions: any, -- Actions.Actions (giftInside)
	events: any, -- config/events.luau
	egg: any, -- its expanded egg in config.eggs (the fixed order)
	eventActive: () -> boolean, -- one of the day's events is running
	incomeOf: (player: Player) -> number?, -- coins a second, nil before the save loads
	notify: (player: Player, text: string) -> (),
	hatched: (player: Player, speciesId: string, eggId: string, isNew: boolean) -> (),
}

local GiantEgg = {}

GiantEgg.MODEL_NAME = "GiantEgg"
GiantEgg.SOURCE = "GiantEgg" -- where its purchases are counted (ops/METRICS.md)
local PROP = "GiantLegendaryEgg"
local SIGN_DROP = 0.45 -- the sign's centre, this share of the egg's height below its top
local LIGHT_BRIGHTNESS = 0.35 -- warm, soft (studio lighting rule: 0.3 to 0.4, no Neon)

local function vec(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function invisible(name: string, size: Vector3, at: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = at
	p.Parent = parent
	return p
end

-- The egg's model: plinth and cradle, the shell (in its own Model so each
-- client can rock it), colliders, a soft light and the Buy prompt. Returns
-- the model, its prompt and the egg's top (where the sign hangs from).
function GiantEgg.build(config: any): (Model, ProximityPrompt, CFrame)
	VoxelProp.register(GiantEggArt)
	local art = GiantEggArt[PROP]
	local native = art.size[2] * art.voxel
	local scale = config.height / native
	local base = CFrame.new(vec(config.position))
	local model = VoxelProp.build(PROP, base * CFrame.new(-VoxelProp.anchor(PROP, scale)), scale)
	assert(model, "GiantEggArt has no GiantLegendaryEgg")
	model.Name = GiantEgg.MODEL_NAME
	local shell = Instance.new("Model")
	shell.Name = "Shell"
	for _, child in model:GetChildren() do
		local p = child :: Part
		-- No Neon anywhere (studio lighting rule).
		p.Material = Enum.Material.SmoothPlastic
		if p.Name == "shell" then
			p.Parent = shell
		end
	end
	shell.Parent = model
	-- The shell's rocking pivot: the bottom of the shell, from the art.
	local pivot = Vector3.zero
	for _, part in art.parts do
		if part.name == "shell" and part.pivot then
			local pv = part.pivot :: { number }
			pivot = Vector3.new(pv[1], pv[2], pv[3]) * art.voxel * scale
		end
	end
	local width = art.size[1] * art.voxel * scale
	local height = native * scale
	local shellBottom = base.Position.Y + pivot.Y
	model:SetAttribute("ShellPivot", base.Position + Vector3.new(0, pivot.Y, 0))
	-- Collide as a drum (plinth) and a fat cylinder (the shell), so nobody
	-- walks into the egg; neither is seen.
	local plinth = invisible(
		"PlinthCollider",
		Vector3.new(pivot.Y, width, width),
		CFrame.new(base.Position + Vector3.new(0, pivot.Y / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		model
	)
	plinth.Shape = Enum.PartType.Cylinder
	plinth.CanCollide = true
	local shellHeight = height - pivot.Y
	local body = invisible(
		"Hitbox",
		Vector3.new(shellHeight * 0.8, width * 0.8, width * 0.8),
		CFrame.new(Vector3.new(base.Position.X, shellBottom + shellHeight * 0.45, base.Position.Z))
			* CFrame.Angles(0, 0, math.rad(90)),
		model
	)
	body.Shape = Enum.PartType.Cylinder
	body.CanCollide = true
	body.CanQuery = true
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 120)
	light.Brightness = LIGHT_BRIGHTNESS
	light.Range = 18
	light.Shadows = false
	light.Parent = body

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	-- The odds card shows while it is up, like every egg's (client/ConveyorView).
	prompt:SetAttribute("HHEggId", GiantEggRules.EGG_ID)
	prompt.ActionText = "Buy"
	prompt.ObjectText = "Giant Golden Egg"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = config.promptDistance
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = (Enum.KeyCode :: any)[PromptKeys.GiantEgg.keyboard]
	prompt.GamepadKeyCode = (Enum.KeyCode :: any)[PromptKeys.GiantEgg.gamepad]
	prompt.Parent = body

	local top = CFrame.new(base.Position + Vector3.new(0, height, 0))
	return model, prompt, top
end

function GiantEgg.start(deps: Deps)
	local services = deps.services
	local events = deps.events
	local model, prompt, top = GiantEgg.build(events.giantEgg)
	model.Parent = Workspace

	-- When the next egg can be bought (the clients' sign counts down to it).
	local function refresh()
		model:SetAttribute("CycleEndsAt", GiantEggRules.status(nil, os.time(), events).endsAt)
	end
	-- Where the client's sign goes: beside the egg at about its middle
	-- (Studio gate, Nov 7), clear of the coin bar on a phone's follow camera.
	model:SetAttribute("SignY", top.Position.Y - events.giantEgg.height * SIGN_DROP)
	refresh()
	task.spawn(function()
		while true do
			task.wait(1)
			refresh()
		end
	end)

	-- What a purchase hatches: a roll on the egg's odds table, which runs the
	-- policy check first; a player under the fixed-order rule gets the next
	-- creature in the fixed order the odds card shows them. A Lucky Hatch
	-- never touches this egg (EventService leaves it out).
	local function picker(player: Player): GiantEggRules.Pick
		return function(boughtBefore: number): string?
			if not services.policy:paidRandomAllowed(player) then
				return Hatchery.fixedOrderOutcome(deps.egg, boughtBefore)
			end
			return (services.odds:rollPaid(GiantEggRules.EGG_ID, player, services.policy))
		end
	end

	-- After the save: the reveal, and the count for the uptake numbers.
	local function hatched(player: Player, speciesId: string, isNew: boolean, event: string)
		task.defer(function()
			services.analytics:custom(player, event, 1, { speciesId })
			deps.hatched(player, speciesId, GiantEggRules.EGG_ID, isNew)
		end)
	end

	-- Outside the event: Robux. The receipt always grants (money taken is
	-- never refused), even if the cycle turned over while the prompt was up.
	services.receipts:register(
		GiantEggRules.EGG_ID,
		deps.productId,
		function(player: Player, d: { [string]: any }, ledger)
			local status = GiantEggRules.status(d, os.time(), events)
			local speciesId = GiantEggRules.open(d, status.cycle, picker(player))
			assert(speciesId, "the Giant Egg has nothing to hatch")
			local _, isNew = deps.actions:giftInside(player, d, ledger, speciesId, GiantEggRules.EGG_ID)
			hatched(player, speciesId, isNew, "GiantEgg:Bought")
		end
	)

	services.shop:guard(GiantEggRules.EGG_ID, function(player: Player): string?
		if deps.eventActive() then
			return "During the event the Giant Egg costs coins: walk up to it in the middle of the map."
		end
		local refusal = GiantEggRules.refusal(services.data:get(player), os.time(), events)
		if refusal == nil then
			services.analytics:custom(player, "GiantEgg:Prompted", 1, {})
		end
		return refusal
	end)

	-- During the event: coins, in one data update, at the price the
	-- player's sign shows (their income right now).
	local function buyWithCoins(player: Player)
		local income = deps.incomeOf(player)
		if income == nil then
			deps.notify(player, "Your hatchery is still loading.")
			return
		end
		local price = GiantEggRules.coinPrice(events, income)
		local granted: string? = nil
		local isNew = false
		local ok = deps.actions:change(player, function(d, ledger): string?
			local speciesId, refusal =
				GiantEggRules.buyWithCoins(d, ledger, os.time(), events, price, picker(player))
			if speciesId == nil then
				return refusal
			end
			local _, fresh = deps.actions:giftInside(player, d, ledger, speciesId, GiantEggRules.EGG_ID)
			granted, isNew = speciesId, fresh
			return nil
		end)
		if ok and granted then
			hatched(player, granted :: string, isNew, "GiantEgg:BoughtCoins")
		end
	end

	prompt.Triggered:Connect(function(player: Player)
		if deps.eventActive() then
			buyWithCoins(player)
		else
			services.shop:prompt(player, "product", GiantEggRules.EGG_ID, GiantEgg.SOURCE)
		end
	end)

	-- Studio test panel: buy today's egg again.
	services.addTestAction(
		"giantegg",
		"Giant Egg: forget today's purchase so it can be bought again",
		{ "Forget" },
		function(player: Player): string
			local ok = services.data:update(player, function(d)
				d.giantEgg = { lastCycle = 0, bought = (d.giantEgg and d.giantEgg.bought) or 0 }
			end)
			return if ok then "Today's Giant Egg can be bought again." else "Your data is not loaded."
		end
	)
end

return GiantEgg
