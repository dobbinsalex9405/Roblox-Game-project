--!strict
-- Street Food Empire server start-up: validate config, build the street,
-- start the core, then wire the restaurant loop (Actions) to remotes, the
-- map and a tick.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Core = ReplicatedStorage.Core
local Config = require(Core.Config)
local Log = require(Core.Log)
local Monetization = require(Core.Monetization)
local Net = require(Core.Net)
local Schema = require(Core.Schema)
local CoreServer = require(ServerScriptService.CoreServer.CoreServer)

local Shared = ReplicatedStorage.Shared
local Actions = require(Shared.Actions)
local Build = require(Shared.Build)
local DataTemplate = require(Shared.DataTemplate)
local Layout = require(Shared.Layout)
local Remotes = require(Shared.Remotes)(Net, Schema)
local Restaurant = require(Shared.Restaurant)
local Schemas = require(Shared.Schemas)(Schema)

local World = require(script.World)

local TICK_SECONDS = 10 -- the restaurant is brought up to date this often

local log = Log.new("Game")

local GameConfig = ReplicatedStorage.GameConfig
local raw = {
	economy = require(GameConfig.economy),
	districts = require(GameConfig.districts),
	stations = require(GameConfig.stations),
	cooks = require(GameConfig.cooks),
	monetization = require(GameConfig.monetization),
}

-- A bad config stops the server here, loudly, before any player data is touched.
-- CI runs the same checks, so this should never fire on a published build.
local problems = Schemas.crossCheck(raw)
assert(#problems == 0, "Invalid config:\n  " .. table.concat(problems, "\n  "))
Config.load(Schemas.sections(raw))

local config: Restaurant.Config = {
	economy = Config.get("economy"),
	districts = Config.get("districts"),
	stations = Config.get("stations"),
	cooks = Config.get("cooks"),
	monetization = Config.get("monetization"),
}
assert(#config.districts <= Layout.ZONES, "the map has 3 district zones")
for _, district in config.districts do
	assert(district.spots <= Layout.SPOTS_PER_ZONE, "the map has 4 station spots per district")
end
-- Pass and product ids for the experience this build is for (ops/SHOP.md).
local ids = Monetization.resolve(raw.monetization, Build.environment)

World.build()

local services: CoreServer.Services
local actions: Actions.Actions? = nil

local function perks(player: Player): Actions.Perks
	return {
		doubleCash = services.passes:owns(player, "DoubleCash"),
		autoCollect = services.passes:owns(player, "AutoCollect"),
	}
end

-- Redraws a player's plot from their data (at most once per frame).
local pendingSync: { [Player]: boolean } = {}
local function syncPlot(player: Player)
	if pendingSync[player] then
		return
	end
	pendingSync[player] = true
	task.defer(function()
		pendingSync[player] = nil
		local index = World.plotOf(player)
		local d = services.data:get(player)
		if index and d then
			World.sync(index, d, config)
		end
	end)
end

local function onPlayerReady(player: Player)
	-- start() returns before any player finishes loading (loading yields), but
	-- guard anyway so a fast load can never see actions unset.
	while actions == nil do
		task.wait()
	end
	local index = World.claim(player)
	if index == nil then
		log:error("no free plot; set the server size to 8", { userId = player.UserId })
		player:Kick("This server is full. Please join another one.")
		return
	end
	player.CharacterAdded:Connect(function(character: Model)
		character:WaitForChild("HumanoidRootPart")
		World.sendHome(player)
	end)
	World.sendHome(player)
	local loop = actions :: Actions.Actions
	loop:join(player)
	syncPlot(player)
end

local function onPlayerLeaving(player: Player)
	if actions then
		actions:leave(player)
	end
	World.release(player)
	pendingSync[player] = nil
end

services = CoreServer.start({
	game = "street-food-empire",
	build = Build.commit,
	dataStoreName = "PlayerData_v1",
	template = DataTemplate.template,
	migrations = DataTemplate.migrations,
	currencies = { cash = { field = "cash", max = config.economy.cashMax } },
	passes = ids.passes,
	oddsTables = {}, -- nothing in this game is random
	remotes = Remotes,
	onPlayerReady = onPlayerReady,
	onPlayerLeaving = onPlayerLeaving,
})

local function fire(remote: any, player: Player, ...: any)
	if player.Parent == Players then
		services.net:fire(remote, player, ...)
	end
end

local ready: Actions.Actions = Actions.new({
	data = services.data,
	economy = services.economy,
	analytics = services.analytics,
	config = config,
	perks = perks,
	now = os.time,
	notify = function(player: Player, text: string)
		fire(Remotes["SFE:Notice"], player, text)
	end,
	served = function(player: Player, cash: number)
		fire(Remotes["SFE:Served"], player, cash)
	end,
	welcome = function(player: Player, cash: number, waiting: number)
		fire(Remotes["SFE:WelcomeBack"], player, cash, waiting)
	end,
})
actions = ready

services.data:onChanged(function(player: Player)
	syncPlot(player)
end)

local net = services.net
net:on(Remotes["SFE:Serve"], function(player: Player)
	ready:serve(player)
end)
net:on(Remotes["SFE:Collect"], function(player: Player)
	ready:collect(player)
end)
net:on(Remotes["SFE:Build"], function(player: Player, stationId: string, spot: number)
	ready:build(player, stationId, spot)
end)
net:on(Remotes["SFE:Upgrade"], function(player: Player, spot: number)
	ready:upgrade(player, spot)
end)
net:on(Remotes["SFE:Move"], function(player: Player, from: number, to: number)
	ready:move(player, from, to)
end)
net:on(Remotes["SFE:HireCook"], function(player: Player, tierId: string, spot: number)
	ready:hireCook(player, tierId, spot)
end)
net:on(Remotes["SFE:UnlockDistrict"], function(player: Player)
	ready:unlockDistrict(player)
end)
net:on(Remotes["SFE:Rebirth"], function(player: Player)
	ready:rebirth(player)
end)

require(script.Shop).register(services, Config, ids, ready)

-- Tick: brings each restaurant up to date (the register, the queue), runs
-- Auto-Collect and redraws plots (a station may have finished building).
task.spawn(function()
	while true do
		task.wait(TICK_SECONDS)
		for _, player in Players:GetPlayers() do
			if services.data:isLoaded(player) and World.plotOf(player) then
				ready:tick(player)
				syncPlot(player)
			end
		end
	end
end)
