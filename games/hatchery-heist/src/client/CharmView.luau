--!strict
-- Worn charms: every player's equipped, shown charms float as small voxel
-- trinkets in a slow wheel behind their shoulders (config/charms.luau
-- `worn`). The server writes what each player wears to their character's
-- `Charms` attribute ("FeedBag,HeatLamp"); this client draws it, for its own
-- player always and for others within `othersRange` studs (at most
-- `othersMax` of them, nearest first) while "Show other players' charms" is
-- on. Hiding a charm never changes its bonus.
--
-- Each charm is its own little Model of boxes (shared/ClawArt, the kind's
-- model with its "trim" in the tier colour), welded to one invisible
-- anchored root that this file moves every frame.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Charms = require(Shared.Charms)
local ClawArt = require(Shared.ClawArt)
local Layout = require(Shared.Layout)
local VoxelProp = require(Shared.VoxelProp)

local CharmView = {}

local SPARKLE_RANK = 4 -- Ultra Rare and up sparkle
local LIGHT_RANK = 6 -- Legendary and up glow softly
local DRAWN_HEIGHT = 2.4 -- studs the charm models are drawn at (tools/art/world/claw.py)

type Worn = { root: BasePart, model: Model, rank: number }
type Rig = { attribute: string, charms: { Worn }, folder: Folder }

local showOthers = true
local listeners: { () -> () } = {}

-- The client-only setting "Show other players' charms".
function CharmView.showOthers(): boolean
	return showOthers
end

function CharmView.setShowOthers(on: boolean)
	showOthers = on
	for _, listener in listeners do
		task.spawn(listener)
	end
end

-- The model name of a charm kind's art (ClawArt).
function CharmView.propOf(kindId: string): string
	return `Charm{kindId}`
end

-- One charm as a Model, `height` studs tall, its trim in the tier colour,
-- welded to an anchored root at `at`. Shared with the Charms window's
-- preview.
function CharmView.build(config: any, id: string, height: number, at: CFrame): (Model?, BasePart?)
	VoxelProp.register(ClawArt)
	local def = Charms.def(config, id)
	if def == nil then
		return nil, nil
	end
	local prop = CharmView.propOf(def.kind)
	local art = ClawArt[prop]
	if art == nil then
		return nil, nil
	end
	local scale = height / DRAWN_HEIGHT
	local color = Layout.rarityColor(def.tier)
	local model = VoxelProp.build(prop, at * CFrame.new(0, -height / 2, 0), scale, { trim = color })
	if model == nil then
		return nil, nil
	end
	model.Name = id
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.Transparency = 1
	root.Size = Vector3.new(0.1, 0.1, 0.1)
	root.CFrame = at
	root.Parent = model
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child ~= root then
			child.Anchored = false
			child.Massless = true
			child.CastShadow = false
			child.Material = Enum.Material.SmoothPlastic
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = child
			weld.Parent = child
		end
	end
	model.PrimaryPart = root
	if def.rank >= SPARKLE_RANK then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Name = "Sparkle"
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.5))
		sparkle.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, height * 0.12),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparkle.Lifetime = NumberRange.new(0.5, 0.9)
		sparkle.Rate = 3 + (def.rank - SPARKLE_RANK) * 2
		sparkle.Speed = NumberRange.new(0.2, 0.6)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.LightEmission = 0.4
		sparkle.Parent = root
	end
	if def.rank >= LIGHT_RANK then
		local worn = config.worn
		local light = Instance.new("PointLight")
		light.Brightness = worn.lightBrightness
		light.Range = worn.lightRange
		light.Color = color:Lerp(Color3.fromRGB(255, 230, 190), 0.5)
		light.Shadows = false
		light.Parent = root
	end
	return model, root
end

function CharmView.start(config: any)
	local worn = config.worn
	local folder = Instance.new("Folder")
	folder.Name = "WornCharms"
	folder.Parent = Workspace
	local rigs: { [Model]: Rig } = {}
	local localPlayer = Players.LocalPlayer

	local function clear(character: Model)
		local rig = rigs[character]
		if rig then
			rig.folder:Destroy()
			rigs[character] = nil
		end
	end

	local function rebuild(character: Model, attribute: string)
		clear(character)
		if attribute == "" then
			return
		end
		local rigFolder = Instance.new("Folder")
		rigFolder.Name = character.Name
		local rig: Rig = { attribute = attribute, charms = {}, folder = rigFolder }
		for _, id in string.split(attribute, ",") do
			local model, root = CharmView.build(config, id, worn.size, CFrame.new(0, -500, 0))
			local def = Charms.def(config, id)
			if model and root and def then
				model.Parent = rigFolder
				table.insert(rig.charms, { root = root, model = model, rank = def.rank })
			end
		end
		rigFolder.Parent = folder
		rigs[character] = rig
	end

	-- Which characters should wear their charms right now.
	local function wanted(): { [Model]: string }
		local out: { [Model]: string } = {}
		local mine = localPlayer.Character
		local myRoot = mine and mine:FindFirstChild("HumanoidRootPart") :: BasePart?
		local others: { { character: Model, distance: number, attribute: string } } = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local attribute = character and character:GetAttribute("Charms")
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if character and root and type(attribute) == "string" and attribute ~= "" then
				if player == localPlayer then
					out[character] = attribute
				elseif showOthers and myRoot then
					local distance = (root.Position - myRoot.Position).Magnitude
					if distance <= worn.othersRange then
						table.insert(
							others,
							{ character = character, distance = distance, attribute = attribute }
						)
					end
				end
			end
		end
		table.sort(others, function(a, b)
			return a.distance < b.distance
		end)
		for i = 1, math.min(#others, worn.othersMax) do
			out[others[i].character] = others[i].attribute
		end
		return out
	end

	local function sync()
		local want = wanted()
		for character in rigs do
			if want[character] == nil or character.Parent == nil then
				clear(character)
			end
		end
		for character, attribute in want do
			local rig = rigs[character]
			if rig == nil or rig.attribute ~= attribute then
				rebuild(character, attribute)
			end
		end
	end
	table.insert(listeners, sync)

	-- Who wears what changes rarely; distance a little more often.
	task.spawn(function()
		while true do
			sync()
			task.wait(0.5)
		end
	end)

	local spin = math.rad(worn.degreesPerSecond)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for character, rig in rigs do
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				-- The wheel's centre, behind the shoulders, upright, facing
				-- the same way as the player.
				local look = root.CFrame - root.CFrame.Position
				local centre = root.CFrame * CFrame.new(0, worn.height, worn.behind)
				local n = #rig.charms
				for i, charm in rig.charms do
					local a = t * spin + (i - 1) / n * 2 * math.pi
					local bob = math.sin(t * 2 + i) * 0.06
					local offset = Vector3.new(
						math.cos(a) * worn.ringRadius,
						math.sin(a) * worn.ringRadius * 0.55 + bob,
						0
					)
					-- Each charm stays upright and faces back toward the camera,
					-- turning slowly on its own.
					local at = CFrame.new(centre * offset)
						* look
						* CFrame.Angles(0, math.pi + math.sin(t * 0.8 + i) * 0.5, 0)
					charm.root.CFrame = at
				end
			end
		end
	end)
end

return CharmView
