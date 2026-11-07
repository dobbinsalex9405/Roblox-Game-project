--!strict
-- The Giant Legendary Egg on the Golden Nest (Alex, Nov 7 2026): builds it
-- (shared/GiantEggArt, made by tools/art/world/giantegg.py), shows today's
-- Legendary standing on top of it, and sells it.
--
-- Buying (an event special, Alex Nov 7): while the day's event runs, the
-- egg's ProximityPrompt buys it for coins (shared/GiantEgg.coinPrice) in one
-- data update. The rest of the day it goes through the core shop's normal
-- checks plus this module's guard (once a cycle per player, never during
-- the event), then Roblox's purchase prompt; the receipt grants the
-- Legendary that was on the egg when the prompt opened. Either way the
-- Legendary is placed like a hatch and plays the hatch reveal. Each client draws the sign over
-- the egg itself (client/EventView), because "bought today" is per player.
--
-- Model attributes for the clients: Species (today's Legendary) and
-- CycleEndsAt (unix seconds a new one arrives).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local GiantEggArt = require(Shared.GiantEggArt)
local GiantEggRules = require(Shared.GiantEgg)
local Layout = require(Shared.Layout)
local PromptKeys = require(Shared.PromptKeys)
local VoxelProp = require(Shared.VoxelProp)

export type Deps = {
	services: any, -- CoreServer.Services
	productId: number,
	actions: any, -- Actions.Actions (giftInside)
	events: any, -- config/events.luau
	species: { [string]: any },
	eventActive: () -> boolean, -- one of the day's events is running
	incomeOf: (player: Player) -> number?, -- coins a second, nil before the save loads
	notify: (player: Player, text: string) -> (),
	hatched: (player: Player, speciesId: string, eggId: string, isNew: boolean) -> (),
}

local GiantEgg = {}

GiantEgg.MODEL_NAME = "GiantEgg"
GiantEgg.SOURCE = "GiantEgg" -- where its purchases are counted (ops/METRICS.md)
local PROP = "GiantLegendaryEgg"
local SIGN_GAP = 0.8 -- studs between the Legendary's head and the sign
local SHOWCASE_SCALE = 1.5 -- today's Legendary on top, this many times its pad size
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
-- the model, its prompt and where today's Legendary stands.
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
	prompt.ActionText = "Buy"
	prompt.ObjectText = "Giant Legendary Egg"
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

	-- Today's Legendary on top of the egg: an invisible ball the clients
	-- draw as the creature (client/CreatureView), swapped each cycle.
	local showcase: Part? = nil
	local shownSpecies: string? = nil
	local function refresh()
		local status = GiantEggRules.status(nil, os.time(), events, deps.species)
		model:SetAttribute("Species", status.species)
		model:SetAttribute("CycleEndsAt", status.endsAt)
		if status.species == shownSpecies then
			return
		end
		shownSpecies = status.species
		if showcase then
			showcase:Destroy()
			showcase = nil
		end
		if status.species then
			local size = Layout.raritySize("Legendary") * SHOWCASE_SCALE
			local ball = invisible(
				"TodaysLegendary",
				Vector3.new(size, size, size),
				top * CFrame.new(0, size / 2, 0),
				model
			)
			ball.Shape = Enum.PartType.Ball
			ball:SetAttribute("CreatureLook", status.species)
			showcase = ball
		end
	end
	-- Where the client's sign goes: clear above today's Legendary, so the
	-- creature never hides it from any side (Studio gate, Nov 7).
	model:SetAttribute(
		"SignBottom",
		top.Position.Y + Layout.raritySize("Legendary") * SHOWCASE_SCALE + SIGN_GAP
	)
	refresh()
	task.spawn(function()
		while true do
			task.wait(1)
			refresh()
		end
	end)

	-- The Legendary each player's open prompt was for, so a purchase that
	-- completes just after midnight still gets the one they saw.
	local promptedFor: { [Player]: { cycle: number, species: string } } = {}
	Players.PlayerRemoving:Connect(function(player: Player)
		promptedFor[player] = nil
	end)

	services.receipts:register(
		GiantEggRules.EGG_ID,
		deps.productId,
		function(player: Player, d: { [string]: any }, ledger)
			local status = GiantEggRules.status(d, os.time(), events, deps.species)
			local cycle, speciesId = status.cycle, status.species
			local seen = promptedFor[player]
			if seen and status.cycle - seen.cycle <= 1 then
				cycle, speciesId = seen.cycle, seen.species
			end
			assert(speciesId, "no Legendary for the Giant Egg")
			GiantEggRules.record(d, cycle)
			local _, isNew = deps.actions:giftInside(player, d, ledger, speciesId, GiantEggRules.EGG_ID)
			promptedFor[player] = nil
			local granted = speciesId :: string
			-- After the save: the reveal, and the count for the uptake numbers.
			task.defer(function()
				services.analytics:custom(player, "GiantEgg:Bought", 1, { granted })
				deps.hatched(player, granted, GiantEggRules.EGG_ID, isNew)
			end)
		end
	)

	services.shop:guard(GiantEggRules.EGG_ID, function(player: Player): string?
		if deps.eventActive() then
			return "During the event the Giant Egg costs coins: walk up to it in the middle of the map."
		end
		local d = services.data:get(player)
		local refusal = GiantEggRules.refusal(d, os.time(), events, deps.species)
		if refusal == nil then
			local status = GiantEggRules.status(d, os.time(), events, deps.species)
			promptedFor[player] = { cycle = status.cycle, species = status.species :: string }
			services.analytics:custom(player, "GiantEgg:Prompted", 1, { status.species :: string })
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
				GiantEggRules.buyWithCoins(d, ledger, os.time(), events, deps.species, price)
			if speciesId == nil then
				return refusal
			end
			local _, fresh = deps.actions:giftInside(player, d, ledger, speciesId, GiantEggRules.EGG_ID)
			granted, isNew = speciesId, fresh
			return nil
		end)
		if ok and granted then
			local speciesId = granted :: string
			services.analytics:custom(player, "GiantEgg:BoughtCoins", 1, { speciesId })
			deps.hatched(player, speciesId, GiantEggRules.EGG_ID, isNew)
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
