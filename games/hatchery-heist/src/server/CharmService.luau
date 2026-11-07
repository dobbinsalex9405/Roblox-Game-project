--!strict
-- Charms and the claw machine on the server: builds the machine in the farm
-- hub (shared/ClawArt, made by tools/art/world/claw.py), wires the charm
-- remotes to shared/CharmActions, registers the two Robux pull products,
-- keeps each player's egg odds boosted by their Clover charm, and writes
-- what each player wears to their character's `Charms` attribute, which
-- every client draws (client/CharmView).
--
-- The machine's prompt only opens the claw window on the client: every pull
-- is a remote the server checks (at the machine, PolicyService, bag, coins).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Actions = require(Shared.Actions)
local CharmActions = require(Shared.CharmActions)
local Charms = require(Shared.Charms)
local ClawArt = require(Shared.ClawArt)
local VoxelProp = require(Shared.VoxelProp)

export type Deps = {
	services: any, -- CoreServer.Services
	actions: Actions.Actions,
	charms: any, -- config/charms.luau
	eggs: { any },
	species: { [string]: any },
	productIds: { [string]: number },
	groundY: number,
	notify: (player: Player, text: string) -> (),
	remotes: { [string]: any },
}

local CharmService = {}

CharmService.MODEL_NAME = "ClawMachine"
CharmService.PROMPT_NAME = "ClawPrompt"
local PROP = "ClawMachine"
local GLASS_HEX = "BEE6FF"
local LIGHT_BRIGHTNESS = 0.35 -- warm and soft (no Neon, studio lighting rule)

local function invisible(name: string, size: Vector3, at: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = at
	p.Parent = parent
	return p
end

-- Where the machine stands: on the hub's ring, its front (-Z) toward the
-- middle of the map.
function CharmService.frame(claw: any, groundY: number): CFrame
	local a = math.rad(claw.angle)
	local at = Vector3.new(math.cos(a) * claw.radius, groundY, math.sin(a) * claw.radius)
	return CFrame.lookAt(at, Vector3.new(0, groundY, 0))
end

-- Builds the machine. Returns it and the point the server measures reach from.
function CharmService.build(charms: any, groundY: number): (Model, Vector3)
	VoxelProp.register(ClawArt)
	local claw = charms.claw
	local art = ClawArt[PROP]
	local scale = claw.height / (art.size[2] * art.voxel)
	local base = CharmService.frame(claw, groundY)
	local model = VoxelProp.build(PROP, base, scale)
	assert(model, "ClawArt has no ClawMachine")
	model.Name = CharmService.MODEL_NAME
	local clawModel = Instance.new("Model")
	clawModel.Name = "Claw"
	for _, child in model:GetChildren() do
		local p = child :: Part
		p.Material = Enum.Material.SmoothPlastic
		if p.Color:ToHex():upper() == GLASS_HEX then
			p.Material = Enum.Material.Glass
			p.Transparency = 0.55
		elseif p.Name == "claw" then
			p.Parent = clawModel
		end
	end
	clawModel.Parent = model
	-- One collider for the whole machine.
	local width = art.size[1] * art.voxel * scale
	local depth = art.size[3] * art.voxel * scale
	local collider = invisible(
		"Collider",
		Vector3.new(width * 0.9, claw.height, depth * 0.9),
		base * CFrame.new(0, claw.height / 2, 0),
		model
	)
	collider.CanCollide = true
	collider.CanQuery = true
	-- The marquee: the game writes on its blank cream face (the art's anchor).
	local anchor = VoxelProp.anchor(PROP, scale)
	local slab = invisible(
		"SignText",
		Vector3.new(width * 0.78, 1.2 * scale, 0.05),
		base * CFrame.new(anchor - Vector3.new(0, 0, 0.06)),
		model
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Text"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(150, 44, 38)
	label.Text = "Charm Claw"
	label.Parent = gui
	gui.Parent = slab
	-- A warm light inside the glass case.
	local lamp =
		invisible("Lamp", Vector3.new(0.2, 0.2, 0.2), base * CFrame.new(0, claw.height * 0.62, 0), model)
	local light = Instance.new("PointLight")
	light.Brightness = LIGHT_BRIGHTNESS
	light.Range = 10
	light.Color = Color3.fromRGB(255, 220, 170)
	light.Shadows = false
	light.Parent = lamp
	-- The prompt, at the console on the front.
	local console =
		invisible("Console", Vector3.new(1, 1, 1), base * CFrame.new(0, 3.2 * scale, -depth / 2 - 0.4), model)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = CharmService.PROMPT_NAME
	prompt.ActionText = "Play"
	prompt.ObjectText = "Charm Claw"
	prompt.MaxActivationDistance = claw.promptDistance
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = console
	model:SetAttribute("ClawMachine", true)
	model.Parent = Workspace
	return model, base.Position
end

function CharmService.start(deps: Deps)
	local services = deps.services
	local charms = deps.charms
	local _, at = CharmService.build(charms, deps.groundY)
	services.odds:setBoostCap(charms.luckCap)

	local function fire(remote: any, player: Player, ...: any)
		if player.Parent == Players then
			services.net:fire(remote, player, ...)
		end
	end

	-- The Clover's luck on every egg this player can hatch, as its own boost
	-- source ("charms"), so events and the Luck Boost keep theirs.
	local luckShown: { [Player]: string } = {}
	local function refreshLuck(player: Player, d: any)
		local equipped = Charms.equipped(d, charms).Clover
		local key = if equipped and next(Charms.luckMultipliers(d, charms)) then equipped.def.id else ""
		if luckShown[player] == key then
			return
		end
		luckShown[player] = key
		for _, egg in deps.eggs do
			services.odds:setSourceBoosts(
				player,
				egg.id,
				"charms",
				Charms.luckBoosts(d, charms, egg, deps.species)
			)
		end
	end

	-- What the player wears, for every client to draw.
	local function refreshWorn(player: Player, d: any)
		local worn = Charms.wornAttribute(d, charms)
		local character = player.Character
		if character and character:GetAttribute("Charms") ~= worn then
			character:SetAttribute("Charms", worn)
		end
	end

	local function refresh(player: Player)
		local d = services.data:get(player)
		if d then
			refreshLuck(player, d)
			refreshWorn(player, d)
		end
	end

	local play = CharmActions.new({
		actions = deps.actions,
		odds = services.odds,
		policy = services.policy,
		analytics = services.analytics,
		charms = charms,
		now = os.time,
		nearClaw = function(player: Player): boolean
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root == nil then
				return false
			end
			local flat = Vector3.new(root.Position.X - at.X, 0, root.Position.Z - at.Z)
			return flat.Magnitude <= charms.claw.reach
		end,
		notify = deps.notify,
		result = function(player: Player, ids: { string }, source: string)
			fire(deps.remotes["HH:ClawResult"], player, ids, source)
		end,
		changed = refresh,
	})

	-- The Robux pulls. Registered with the receipts even while their ids are
	-- 0 (Alex hasn't approved the prices), so the Studio test panel can run
	-- them through the real receipt path; the shop never prompts an id of 0.
	for _, pull in charms.claw.pulls do
		local key = pull.product
		if key then
			services.receipts:register(
				key,
				deps.productIds[key] or 0,
				function(player: Player, data: any, _ledger)
					local ids = play:grantInside(player, data, pull.count)
					task.defer(function()
						fire(deps.remotes["HH:ClawResult"], player, ids, "Robux")
					end)
				end
			)
		end
	end

	local net = services.net
	local remotes = deps.remotes
	net:on(remotes["HH:ClawPull"], function(player: Player, count: number)
		play:pull(player, count)
	end)
	net:on(remotes["HH:CharmCounter"], function(player: Player, id: string)
		play:counter(player, id)
	end)
	net:on(remotes["HH:CharmEquip"], function(player: Player, id: string)
		play:equip(player, id)
	end)
	net:on(remotes["HH:CharmUnequip"], function(player: Player, kind: string)
		play:unequip(player, kind)
	end)
	net:on(remotes["HH:CharmShown"], function(player: Player, which: string, shown: boolean)
		play:setShown(player, which, shown)
	end)
	net:on(remotes["HH:CharmFuse"], function(player: Player, id: string, times: number)
		play:fuse(player, id, times)
	end)
	net:on(remotes["HH:CharmFuseAll"], function(player: Player)
		play:fuseAll(player)
	end)

	-- Studio test panel: any charm.
	local ids = {}
	for _, c in charms.charms do
		table.insert(ids, c.id)
	end
	table.sort(ids)
	services.addTestAction(
		"charm",
		"Give a charm (into your charm bag)",
		ids,
		function(player: Player, id: string): string
			local _, text = play:grant(player, id)
			return text
		end
	)

	-- Joining, respawning and any data change (a pass, a fusion, rebirth)
	-- re-check what the player wears and their luck; both only act on change.
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(refresh, player)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		luckShown[player] = nil
	end)
	services.data:onChanged(function(player: Player)
		refresh(player)
	end)
end

return CharmService
