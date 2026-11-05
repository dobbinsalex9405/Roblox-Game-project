--!strict
-- Basic riding: the creature being ridden is drawn under the player's
-- character and sets their walk speed (through Speed) from its species'
-- mountSpeed. The
-- choice of creature is saved (mountUid), so it comes back after a respawn or
-- a rejoin. RaidService checks every move against that speed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Speed = require(script.Parent.Speed)

local Mounts = {}

export type Ride = { speed: number, speciesId: string, rarity: string }

local rides: { [Player]: Ride? } = {}

local function clearCharacter(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local old = character:FindFirstChild("Mount")
	if old then
		old:Destroy()
	end
	if humanoid then
		local hip = humanoid:GetAttribute("BaseHipHeight")
		if type(hip) == "number" then
			humanoid.HipHeight = hip
			humanoid:SetAttribute("BaseHipHeight", nil)
		end
	end
end

local function applyToCharacter(player: Player, character: Model)
	clearCharacter(character)
	local ride = rides[player]
	if ride == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid == nil or root == nil then
		return
	end

	local size = Layout.mountSize(ride.rarity)
	local hip = humanoid.HipHeight
	humanoid:SetAttribute("BaseHipHeight", hip)
	humanoid.HipHeight = hip + size

	local body = Instance.new("Part")
	body.Name = "Mount"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(size, size, size)
	body.Color = Layout.rarityColor(ride.rarity)
	body.Material = Enum.Material.SmoothPlastic
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Massless = true
	body.Transparency = 1 -- the client draws the creature (CreatureView)
	body:SetAttribute("CreatureLook", ride.speciesId)
	-- Root centre sits HipHeight + half the root's height above the ground;
	-- the mount's centre sits half its size above the ground.
	body.CFrame = root.CFrame * CFrame.new(0, -(hip + root.Size.Y / 2 + size / 2), 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = body
	weld.Parent = body
	body.Parent = character
end

-- Starts riding (ride ~= nil) or stops (ride == nil).
function Mounts.set(player: Player, ride: Ride?)
	rides[player] = ride
	Speed.setMount(player, if ride then ride.speed else nil)
	local character = player.Character
	if character then
		applyToCharacter(player, character)
	end
end

function Mounts.rideOf(player: Player): Ride?
	return rides[player]
end

function Mounts.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			character:WaitForChild("HumanoidRootPart")
			character:WaitForChild("Humanoid")
			applyToCharacter(player, character)
			Speed.apply(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		rides[player] = nil
	end)
end

return Mounts
