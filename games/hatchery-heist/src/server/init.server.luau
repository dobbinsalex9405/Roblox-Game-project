--!strict
-- Hatchery Heist server start-up: validate config, build the map, start the
-- core, then wire the base loop (Actions) to remotes, the map and a tick.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Core = ReplicatedStorage.Core
local Config = require(Core.Config)
local Log = require(Core.Log)
local Net = require(Core.Net)
local Odds = require(Core.Odds)
local Monetization = require(Core.Monetization)
local Schema = require(Core.Schema)
local CoreServer = require(ServerScriptService.CoreServer.CoreServer)

local Shared = ReplicatedStorage.Shared
local Actions = require(Shared.Actions)
local Build = require(Shared.Build)
local DataTemplate = require(Shared.DataTemplate)
local FeedbackContext = require(Shared.FeedbackContext)
local Eggs = require(Shared.Eggs)
local Geometry = require(Shared.Geometry)
local Hatchery = require(Shared.Hatchery)
local Layout = require(Shared.Layout)
local Tower = require(Shared.Tower)
local Raids = require(Shared.Raids)
local Remotes = require(Shared.Remotes)(Net, Schema)
local Schemas = require(Shared.Schemas)(Schema, Odds)

local CreatureAssets = require(script.CreatureAssets)
local EnvAssets = require(script.EnvAssets)
local Mounts = require(script.Mounts)
local RaidService = require(script.RaidService)
local Scenery = require(script.Scenery)
local ShopHouse = require(script.ShopHouse)
local Speed = require(script.Speed)
local World = require(script.World)

local TICK_SECONDS = 10 -- income is added to the pending pile this often

local log = Log.new("Game")

local GameConfig = ReplicatedStorage.GameConfig
local raw = {
	economy = require(GameConfig.economy),
	creatures = require(GameConfig.creatures),
	eggs = Eggs.expand(require(GameConfig.eggs) :: any, (require(GameConfig.creatures) :: any).species),
	raids = require(GameConfig.raids),
	monetization = require(GameConfig.monetization),
	atmosphere = require(GameConfig.atmosphere),
	shophouse = require(GameConfig.shophouse),
}

-- A bad config stops the server here, loudly, before any player data is touched.
-- CI runs the same checks, so this should never fire on a published build.
local problems = Schemas.crossCheck(raw)
assert(#problems == 0, "Invalid config:\n  " .. table.concat(problems, "\n  "))
Config.load(Schemas.sections(raw))

local economy = Config.get("economy")
local monetization = Config.get("monetization")
local config = {
	economy = economy,
	creatures = Config.get("creatures"),
	eggs = Config.get("eggs"),
	raids = Config.get("raids"),
}
assert(
	economy.incubators.maxSlots + economy.incubators.passBonusSlots <= Layout.INCUBATOR_POSITIONS,
	"the map has fewer incubators than maxSlots + passBonusSlots"
)
assert(#economy.tower.floorPrices + 1 == Geometry.FLOORS, "the map has 10 tower floors")
-- Raid geometry (plain numbers) must match the map (CFrames) exactly.
for index = 1, Layout.PLOTS do
	local frame = Layout.plotCFrame(index)
	for _, probe in { Vector3.new(10, 0, -20), Vector3.new(-25, 0, 15) } do
		local world = frame * probe
		local lx, lz = Geometry.toLocal(index, world.X, world.Z)
		assert(
			math.abs(lx - probe.X) < 1e-3 and math.abs(lz - probe.Z) < 1e-3,
			"Geometry and Layout disagree"
		)
	end
end

-- Coin packs make coins Robux-bought currency, so coin eggs count as paid random items.
local sellsCurrency = false
for key in monetization.products do
	if string.match(key, "^CoinPack") then
		sellsCurrency = true
	end
end

-- Pass and product ids for the experience this build is for.
local ids = Monetization.resolve(monetization, Build.environment)

World.build()
-- Each base's floor shows only a low lip above the grass (Alex found a
-- 1-stud step "way too high"). The boot check runs this, so it fails CI.
for index = 1, Layout.PLOTS do
	local plot = World.model(index)
	local floor = plot and plot.PrimaryPart
	assert(floor, "every base has a floor")
	-- CFrame, not Position: the headless boot shim keeps Position at its default.
	local top = floor.CFrame.Position.Y + floor.Size.Y / 2
	assert(top > 0.05 and top <= 0.5, `base {index}'s floor top is at {top}, not a low lip above the grass`)
end
local atmosphere = Config.get("atmosphere")
Scenery.build(atmosphere)
ShopHouse.build(Config.get("shophouse"), monetization, Config.get("raids"))
Mounts.start()
CreatureAssets.start(log)
-- Nature meshes, skybox and grass tile (tools/art/env); until they load the
-- world keeps its box trees, Roblox's sky and the plain Grass material.
EnvAssets.start(log, function(url: string)
	Scenery.grass(url, atmosphere)
end, function()
	Scenery.skybox(atmosphere)
end)

local services: CoreServer.Services
local actions: Actions.Actions? = nil
local raids: Raids.Raids? = nil

local function perks(player: Player): Actions.Perks
	return {
		doubleCoins = services.passes:owns(player, "DoubleCoins"),
		extraIncubators = services.passes:owns(player, "ExtraIncubators"),
		autoCollect = services.passes:owns(player, "AutoCollect"),
	}
end

-- Redraws a player's base from their data (at most once per frame).
local pendingSync: { [Player]: boolean } = {}
local function syncBase(player: Player)
	if pendingSync[player] then
		return
	end
	pendingSync[player] = true
	task.defer(function()
		pendingSync[player] = nil
		local index = World.plotOf(player)
		local d = services.data:get(player)
		if index and d then
			local p = perks(player)
			local carried = if raids then raids:carriedFrom(player) else {}
			World.sync(index, d, config, Hatchery.slotCount(d, economy, p), carried, os.time())
		end
	end)
end

local function syncAll()
	for _, player in Players:GetPlayers() do
		if World.plotOf(player) then
			syncBase(player)
		end
	end
end

local function rideFor(player: Player, speed: number?): Mounts.Ride?
	local d = services.data:get(player)
	if speed == nil or d == nil then
		return nil
	end
	local creature = Hatchery.creatureByUid(d, d.mountUid)
	local species = creature and config.creatures.species[creature.speciesId]
	if species == nil then
		return nil
	end
	return { speed = speed, speciesId = creature.speciesId, rarity = species.rarity }
end

local function onPlayerReady(player: Player)
	-- start() returns before any player finishes loading (loading yields), but
	-- guard anyway so a fast load can never see actions unset.
	while actions == nil do
		task.wait()
	end
	local index = World.claim(player)
	if index == nil then
		log:error("no free base; set the server size to 8", { userId = player.UserId })
		player:Kick("This server is full. Please join another one.")
		return
	end
	player:SetAttribute("PaidRandomRestricted", not services.policy:paidRandomAllowed(player))
	player.CharacterAdded:Connect(function(character: Model)
		character:WaitForChild("HumanoidRootPart")
		World.sendHome(player)
	end)
	World.sendHome(player)
	local loop = actions :: Actions.Actions
	loop:join(player)
	syncBase(player)
end

local function onPlayerLeaving(player: Player)
	if raids then
		raids:leave(player)
	end
	if actions then
		actions:leave(player)
	end
	Mounts.set(player, nil)
	World.release(player)
	pendingSync[player] = nil
end

services = CoreServer.start({
	game = "hatchery-heist",
	build = Build.commit,
	dataStoreName = "PlayerData_v1",
	template = DataTemplate.template,
	migrations = DataTemplate.migrations,
	currencies = { coins = { field = "coins", max = economy.coinsMax } },
	passes = ids.passes,
	oddsTables = Eggs.oddsTables(config.eggs, sellsCurrency),
	remotes = Remotes,
	onPlayerReady = onPlayerReady,
	onPlayerLeaving = onPlayerLeaving,
	feedbackContext = function(player: Player)
		local data = services.data:get(player)
		return if data then FeedbackContext.from(data, os.time()) else {}
	end,
})

local function fire(remote: any, player: Player, ...: any)
	if player.Parent == Players then
		services.net:fire(remote, player, ...)
	end
end

local ready: Actions.Actions = Actions.new({
	data = services.data,
	economy = services.economy,
	odds = services.odds,
	policy = services.policy,
	analytics = services.analytics,
	config = config,
	sellsCurrency = sellsCurrency,
	perks = perks,
	now = os.time,
	serverTime = function()
		return Workspace:GetServerTimeNow()
	end,
	plotOf = World.plotOf,
	notify = function(player: Player, text: string)
		fire(Remotes["HH:Notice"], player, text)
	end,
	hatched = function(player: Player, speciesId: string, eggId: string, isNew: boolean)
		fire(Remotes["HH:Hatched"], player, speciesId, eggId, isNew)
	end,
	welcome = function(player: Player, coins: number, readyEggs: number)
		fire(Remotes["HH:WelcomeBack"], player, coins, readyEggs)
	end,
	mount = function(player: Player, speed: number?)
		Mounts.set(player, rideFor(player, speed))
	end,
})
actions = ready

-- Studio test panel: give any creature, so guard walks and rides can be
-- checked without hatching the right egg first.
do
	local speciesIds = {}
	for id in config.creatures.species do
		table.insert(speciesIds, id)
	end
	table.sort(speciesIds)
	services.addTestAction(
		"creature",
		"Give a creature (on a free pad, ready to ride or guard)",
		speciesIds,
		function(player: Player, speciesId: string): string
			local _, text = ready:grantCreature(player, speciesId)
			return text
		end
	)
end

local notify = function(player: Player, text: string)
	fire(Remotes["HH:Notice"], player, text)
end

local raidRules: Raids.Raids = Raids.new({
	actions = ready,
	data = services.data,
	analytics = services.analytics,
	config = config,
	now = os.time,
	notify = notify,
	name = function(player: Player)
		return player.DisplayName
	end,
	userId = function(player: Player)
		return player.UserId
	end,
	stun = function(player: Player, seconds: number)
		Speed.stun(player, seconds)
	end,
	slow = function(player: Player, factor: number, seconds: number)
		Speed.slow(player, factor, seconds)
	end,
	changed = function(raider: Player)
		RaidService.changed(raider)
	end,
})
raids = raidRules

RaidService.start({
	raids = raidRules,
	data = services.data,
	config = config,
	net = services.net,
	remotes = Remotes,
	notify = notify,
	syncAll = syncAll,
})

services.data:onChanged(function(player: Player)
	syncBase(player)
end)

local net = services.net
net:on(Remotes["HH:BuyEgg"], function(player: Player, index: number)
	local bought = ready:buyEgg(player, index)
	fire(Remotes["HH:EggResult"], player, index, bought)
end)
net:on(Remotes["HH:Hatch"], function(player: Player, slot: number)
	ready:hatch(player, slot)
end)
net:on(Remotes["HH:BuySlot"], function(player: Player)
	ready:buySlot(player)
end)
net:on(Remotes["HH:Collect"], function(player: Player)
	ready:collect(player)
end)
net:on(Remotes["HH:BuyFloor"], function(player: Player)
	ready:buyFloor(player)
end)
net:on(Remotes["HH:UpgradeFloor"], function(player: Player, floor: number)
	ready:upgradeFloor(player, floor)
end)
net:on(Remotes["HH:Place"], function(player: Player, uid: string, floor: number)
	ready:place(player, uid, floor)
end)
net:on(Remotes["HH:TakeBack"], function(player: Player, uid: string)
	ready:takeBack(player, uid)
end)
net:on(Remotes["HH:PlaceBest"], function(player: Player)
	ready:placeBest(player)
end)
-- The elevator: only from one of the player's own stops, only to a floor
-- they have built.
net:on(Remotes["HH:GoFloor"], function(player: Player, floor: number)
	local d = services.data:get(player)
	if d == nil then
		return
	end
	local owned = Tower.owned(d)
	if floor > owned then
		notify(player, "Build that floor first.")
		return
	end
	if not World.atElevator(player, owned) then
		notify(player, "Step onto your elevator first.")
		return
	end
	World.elevatorTo(player, floor)
end)
net:on(Remotes["HH:BookSeen"], function(player: Player)
	ready:seeBook(player)
end)
net:on(Remotes["HH:ClaimDaily"], function(player: Player)
	ready:claimDaily(player)
end)
net:on(Remotes["HH:Rebirth"], function(player: Player)
	ready:rebirth(player)
end)
net:on(Remotes["HH:Ride"], function(player: Player, uid: string)
	ready:ride(player, uid)
end)
net:on(Remotes["HH:Dismount"], function(player: Player)
	ready:dismount(player)
end)

local Shop = require(script.Shop)
local function incomeOf(player: Player): number?
	local d = services.data:get(player)
	return if d then Hatchery.incomePerSecond(d, config, perks(player)) else nil
end
Shop.register(services, Config, ids, incomeOf)
-- The shop's coin packs scale with income: resend a player's catalog when
-- one of their pack amounts changes.
local packsShown: { [Player]: string } = {}
local function refreshPacks(player: Player)
	local income = incomeOf(player)
	if income == nil then
		return
	end
	local amounts = Shop.packAmounts(Config, income)
	if packsShown[player] ~= amounts then
		packsShown[player] = amounts
		services.shop:refresh(player)
	end
end
Players.PlayerRemoving:Connect(function(player)
	packsShown[player] = nil
end)

-- Income tick: adds earnings to each player's pending pile, runs Auto-Collect
-- and redraws bases (a pass bought mid-session can unlock incubators, a
-- shield can run out).
task.spawn(function()
	while true do
		task.wait(TICK_SECONDS)
		for _, player in Players:GetPlayers() do
			if services.data:isLoaded(player) and World.plotOf(player) then
				ready:tick(player)
				syncBase(player)
				refreshPacks(player)
			end
		end
	end
end)
