--!strict
-- The Roblox side of raids: measures where everyone is a few times a second
-- and feeds Raids.luau (which owns the rules), moves guard creatures, runs the
-- movement check, and draws the carried creature over the raider's head.
--
-- Every distance the rules need is measured here, on the server, from the
-- characters' positions; the client only asks to steal or to buy defenses.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Movement = require(ReplicatedStorage.Core.Movement)
local Util = require(ReplicatedStorage.Core.Util)
local Shared = ReplicatedStorage.Shared
local Geometry = require(Shared.Geometry)
local Defenses = require(Shared.Defenses)
local Layout = require(Shared.Layout)
local Raids = require(Shared.Raids)

local Speed = require(script.Parent.Speed)
local World = require(script.Parent.World)

local CHECK_SECONDS = 0.25
local TRAP_REACH = 3
local NOTICE_GAP = 3 -- seconds between repeated "you can't enter" notices

export type Deps = {
	raids: Raids.Raids,
	data: any,
	config: { raids: any, creatures: any, economy: any },
	net: any,
	remotes: { [string]: any },
	notify: (player: Player, text: string) -> (),
	syncAll: () -> (),
}

local RaidService = {}

local deps: Deps
local movement: Movement.Movement
local lastRefusal: { [Player]: number } = {}
local guards: { [number]: Part? } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Called by Raids whenever a raider starts or stops carrying.
function RaidService.changed(raider: Player)
	local raid = deps.raids:raidOf(raider)
	local carry = raid and raid.carrying
	Speed.setCarrying(raider, carry ~= nil)
	raider:SetAttribute("Carrying", if carry then carry.speciesId else nil)
	raider:SetAttribute("CarryStartedAt", if carry then carry.pickedAt else nil)
	local character = raider.Character
	local old = character and character:FindFirstChild("Carried")
	if old then
		old:Destroy()
	end
	local root = rootOf(raider)
	if carry and root and character then
		local species = deps.config.creatures.species[carry.speciesId]
		local size = Layout.raritySize(if species then species.rarity else "Common")
		local body = Instance.new("Part")
		body.Name = "Carried"
		body.Shape = Enum.PartType.Ball
		body.Size = Vector3.new(size, size, size)
		body.Color = Layout.rarityColor(if species then species.rarity else "Common")
		body.CanCollide = false
		body.CanQuery = false
		body.CanTouch = false
		body.Massless = true
		body.CFrame = root.CFrame * CFrame.new(0, 3 + size / 2, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = body
		weld.Parent = body
		body.Parent = character
	end
	deps.syncAll()
end

local function refuse(player: Player, text: string)
	local now = os.clock()
	if now - (lastRefusal[player] or 0) >= NOTICE_GAP then
		lastRefusal[player] = now
		deps.notify(player, text)
	end
end

local function worldSpot(plot: number, xz: { number }): (number, number)
	return Geometry.toWorld(plot, xz[1], xz[2])
end

-- Movement check and raid rules for one player.
local function checkPlayer(player: Player, now: number)
	local root = rootOf(player)
	if root == nil then
		return
	end
	local position = root.Position
	local x, z = position.X, position.Z

	local result = movement:check(player, x, z, os.clock(), Speed.allowed(player))
	if result == "violation" then
		local raid = deps.raids:raidOf(player)
		if raid and raid.carrying then
			deps.raids:drop(player, "speed")
		end
		local good = movement:lastGood(player)
		if good then
			World.teleport(player, CFrame.new(good.x, position.Y, good.z) * root.CFrame.Rotation)
		end
		return
	end

	local raids = deps.raids
	local plot = Geometry.plotAt(x, z)
	local owner = if plot then World.ownerOfIndex(plot) else nil
	local raid = raids:raidOf(player)

	if raid and raid.carrying then
		local home = World.plotOf(player)
		if home and plot == home then
			raids:deliver(player)
			return
		end
		local ownerRoot = rootOf(raid.owner)
		if ownerRoot then
			local p = ownerRoot.Position
			if Geometry.distance(x, z, p.X, p.Z) <= deps.config.raids.ownerCatchReach then
				raids:drop(player, "owner")
				return
			end
		end
		local ownerPlot = World.plotOf(raid.owner)
		local guard = ownerPlot and guards[ownerPlot]
		if guard then
			local g = guard.Position
			if Geometry.distance(x, z, g.X, g.Z) <= deps.config.raids.guardCatchReach then
				raids:drop(player, "guard")
				return
			end
		end
	end

	if owner and plot and owner ~= player then
		local d = deps.data:get(owner)
		local carrying = raid ~= nil and raid.carrying ~= nil
		if d and d.shieldUntil > now and not carrying then
			World.pushOut(player, plot)
			refuse(player, `This base is shielded for {math.ceil(d.shieldUntil - now)}s.`)
			raids:exit(player)
			return
		end
		local ok, why = raids:enter(player, owner)
		if not ok then
			if not carrying then
				World.pushOut(player, plot)
				refuse(player, why or "You cannot raid this base now.")
			end
			return
		end
		for spot, xz in Geometry.TRAP_SPOTS do
			local tx, tz = worldSpot(plot, xz)
			if Geometry.distance(x, z, tx, tz) <= TRAP_REACH then
				raids:trap(player, spot)
			end
		end
	elseif raid and raid.carrying == nil then
		raids:exit(player)
	end
end

-- Guard creatures: chase the nearest raider they can see, otherwise patrol.
local function moveGuards(dt: number)
	local raidsConfig = deps.config.raids
	for plot = 1, Layout.PLOTS do
		local owner = World.ownerOfIndex(plot)
		local d = if owner then deps.data:get(owner) else nil
		local creature, species = Defenses.guardOf(d, deps.config.creatures.species)
		local guard = guards[plot]
		if creature == nil or species == nil or owner == nil then
			if guard then
				guard:Destroy()
				guards[plot] = nil
			end
			continue
		end
		local model = World.model(plot) :: Model
		local size = Layout.raritySize(species.rarity)
		if guard == nil or guard:GetAttribute("Uid") ~= creature.uid then
			if guard then
				guard:Destroy()
			end
			local px, pz = Geometry.toWorld(plot, 0, 10)
			local g = Instance.new("Part")
			g.Name = "Guard"
			g.Shape = Enum.PartType.Ball
			g.Size = Vector3.new(size, size, size)
			g.Color = Layout.rarityColor(species.rarity)
			g.Material = Enum.Material.Neon
			g.Anchored = true
			g.CanCollide = false
			g.Position = Vector3.new(px, Layout.FLOOR_TOP + size / 2, pz)
			g:SetAttribute("Uid", creature.uid)
			g.Parent = model
			guards[plot] = g
			guard = g
		end
		local g = guard :: Part
		local here = g.Position
		local targetX, targetZ = nil, nil
		local best = raidsConfig.guardSightRange
		for _, raider in deps.raids:raidersOf(owner) do
			local root = rootOf(raider)
			if root then
				local p = root.Position
				local distance = Geometry.distance(here.X, here.Z, p.X, p.Z)
				if distance <= best and Geometry.inside(plot, p.X, p.Z) then
					best = distance
					targetX, targetZ = p.X, p.Z
				end
			end
		end
		if targetX == nil then
			local angle = os.clock() * 0.4
			targetX, targetZ = Geometry.toWorld(plot, math.cos(angle) * 14, 10 + math.sin(angle) * 10)
		end
		local dx, dz = (targetX :: number) - here.X, (targetZ :: number) - here.Z
		local distance = math.sqrt(dx * dx + dz * dz)
		local step = math.min(distance, species.mountSpeed * raidsConfig.guardSpeedFactor * dt)
		if distance > 0.01 then
			local nx, nz = here.X + dx / distance * step, here.Z + dz / distance * step
			-- Guards stay on their own base.
			if Geometry.inside(plot, nx, nz, size / 2) then
				g.Position = Vector3.new(nx, here.Y, nz)
			end
		end
	end
end

local function distanceTo(player: Player, plot: number, xz: { number }): number
	local root = rootOf(player)
	if root == nil then
		return math.huge
	end
	local wx, wz = worldSpot(plot, xz)
	return Geometry.distance(root.Position.X, root.Position.Z, wx, wz)
end

function RaidService.start(d: Deps)
	deps = d
	local raidsConfig = d.config.raids
	movement = Movement.new({
		tolerance = raidsConfig.carrySpeedTolerance,
		burstSeconds = 2,
		slackStuds = 4,
	})
	Speed.configure(raidsConfig)

	World.onTeleport(function(player: Player)
		local root = rootOf(player)
		if root then
			movement:reset(player, root.Position.X, root.Position.Z, os.clock())
		end
	end)

	local net = d.net
	local remotes = d.remotes
	net:on(remotes["HH:Steal"], function(player: Player, plot: number, pad: number)
		local raid = d.raids:raidOf(player)
		if raid == nil or World.ownerOfIndex(plot) ~= raid.owner then
			return
		end
		local px, pz = Geometry.pad(pad)
		local ok, why = d.raids:steal(player, pad, distanceTo(player, plot, { px, pz }))
		if not ok and why then
			d.notify(player, why)
		end
	end)
	net:on(remotes["HH:StealDecoy"], function(player: Player, plot: number, spot: number)
		local raid = d.raids:raidOf(player)
		if raid == nil or World.ownerOfIndex(plot) ~= raid.owner then
			return
		end
		local xz = Geometry.DECOY_SPOTS[spot]
		if xz then
			d.raids:stealDecoy(player, spot, distanceTo(player, plot, xz))
		end
	end)
	net:on(remotes["HH:Shield"], function(player: Player)
		if d.raids:raiseShield(player) then
			-- Redraw when it ends so the dome goes away on time.
			task.delay(raidsConfig.freeShieldSeconds + 0.5, d.syncAll)
		end
	end)
	net:on(remotes["HH:BuyTrap"], function(player: Player, spot: number, kind: string)
		d.raids:buyTrap(player, spot, kind)
	end)
	net:on(remotes["HH:BuyDecoy"], function(player: Player, spot: number)
		d.raids:buyDecoy(player, spot)
	end)
	net:on(remotes["HH:Guard"], function(player: Player, uid: string)
		d.raids:toggleGuard(player, uid)
	end)

	-- A new character starts a new movement history. Dying, resetting or
	-- losing the character while carrying drops the creature: respawning at
	-- home must never count as a delivery.
	local function watch(player: Player)
		player.CharacterRemoving:Connect(function()
			d.raids:drop(player, "respawn")
			movement:forget(player)
		end)
		local function hook(character: Model)
			movement:forget(player)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid and humanoid:IsA("Humanoid") then
				humanoid.Died:Connect(function()
					d.raids:drop(player, "respawn")
				end)
			end
		end
		player.CharacterAdded:Connect(hook)
		if player.Character then
			task.spawn(hook, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		movement:forget(player)
		lastRefusal[player] = nil
		Speed.forget(player)
	end)

	RunService.Heartbeat:Connect(moveGuards)

	task.spawn(function()
		local sinceTick = 0
		while true do
			task.wait(CHECK_SECONDS)
			local now = os.time()
			for _, player in Players:GetPlayers() do
				if d.data:isLoaded(player) then
					local ok, err = Util.try(checkPlayer, player, now)
					if not ok then
						warn("raid check failed: " .. tostring(err))
					end
				end
			end
			-- How many raiders are on each base, for the owner's alarm banner.
			for plot = 1, Layout.PLOTS do
				local owner = World.ownerOfIndex(plot)
				local model = World.model(plot)
				if model then
					model:SetAttribute("Raiders", if owner then #d.raids:raidersOf(owner) else 0)
				end
			end
			sinceTick += CHECK_SECONDS
			if sinceTick >= 1 then
				sinceTick = 0
				d.raids:tick()
			end
		end
	end)
end

return RaidService
