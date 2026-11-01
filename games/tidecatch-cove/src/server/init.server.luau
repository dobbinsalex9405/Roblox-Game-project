--!strict
-- Tidecatch Cove server start-up: validate config, build the map, start the
-- core, then wire the game loop (Actions) to remotes, the map and a tick.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Core = ReplicatedStorage.Core
local Config = require(Core.Config)
local Log = require(Core.Log)
local Net = require(Core.Net)
local Odds = require(Core.Odds)
local Schema = require(Core.Schema)
local CoreServer = require(ServerScriptService.CoreServer.CoreServer)

local Shared = ReplicatedStorage.Shared
local Actions = require(Shared.Actions)
local Build = require(Shared.Build)
local Catch = require(Shared.Catch)
local Cove = require(Shared.Cove)
local DataTemplate = require(Shared.DataTemplate)
local Layout = require(Shared.Layout)
local Remotes = require(Shared.Remotes)(Net, Schema)
local Schemas = require(Shared.Schemas)(Schema, Odds)

local World = require(script.World)

local TICK_SECONDS = 10 -- play time, first growth and pool redraws run this often

local log = Log.new("Game")

local GameConfig = ReplicatedStorage.GameConfig
local raw = {
	species = require(GameConfig.species),
	fishing = require(GameConfig.fishing),
	pools = require(GameConfig.pools),
	economy = require(GameConfig.economy),
	monetization = require(GameConfig.monetization),
}

-- A bad config stops the server here, loudly, before any player data is touched.
-- CI runs the same checks, so this should never fire on a published build.
local problems = Schemas.crossCheck(raw)
assert(#problems == 0, "Invalid config:\n  " .. table.concat(problems, "\n  "))
Config.load(Schemas.sections(raw))

local config: Cove.Config = {
	species = Config.get("species"),
	fishing = Config.get("fishing"),
	pools = Config.get("pools"),
	economy = Config.get("economy"),
	monetization = Config.get("monetization"),
}
local monetization = config.monetization
assert(
	config.pools.maxSlots + config.pools.passBonusSlots <= Layout.POOL_POSITIONS,
	"the map has fewer pools than maxSlots + passBonusSlots"
)

-- Coins are never sold for Robux in Tidecatch Cove, so only bait marked
-- `robux` makes a cast a paid random roll. If a coin pack is ever added, this
-- turns every bait cast into a paid roll (src/shared/Catch.luau).
local sellsCurrency = false
for key in monetization.products do
	if string.match(key, "^CoinPack") then
		sellsCurrency = true
	end
end

local spotIndex: { [string]: number } = {}
for index, spot in config.fishing.spots do
	spotIndex[spot.id] = index
end

World.build(config.fishing)

local services: CoreServer.Services
local actions: Actions.Actions? = nil

local function perks(player: Player): Actions.Perks
	return {
		autoReel = services.passes:owns(player, "AutoReel"),
		extraPools = services.passes:owns(player, "ExtraPools"),
		sellMultiplier = services.passes:owns(player, "SellMultiplier"),
	}
end

-- Redraws a player's cove from their data (at most once per frame).
local pendingSync: { [Player]: boolean } = {}
local function syncCove(player: Player)
	if pendingSync[player] then
		return
	end
	pendingSync[player] = true
	task.defer(function()
		pendingSync[player] = nil
		local index = World.coveOf(player)
		local d = services.data:get(player)
		if index and d then
			World.sync(index, d, config, Cove.poolCount(d, config.pools, perks(player)), os.time())
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
		log:error("no free cove; set the server size to 8", { userId = player.UserId })
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
	syncCove(player)
end

local function onPlayerLeaving(player: Player)
	if actions then
		actions:leave(player)
	end
	World.release(player)
	pendingSync[player] = nil
end

services = CoreServer.start({
	game = "tidecatch-cove",
	build = Build.commit,
	dataStoreName = "PlayerData_v1",
	template = DataTemplate.template,
	migrations = DataTemplate.migrations,
	currencies = { coins = { field = "coins", max = config.economy.coinsMax } },
	passes = monetization.passes,
	oddsTables = Catch.oddsTables(config.fishing, config.species.species, Odds.normalize, sellsCurrency),
	remotes = Remotes,
	onPlayerReady = onPlayerReady,
	onPlayerLeaving = onPlayerLeaving,
})

local function fire(remote: any, player: Player, ...: any)
	if player.Parent == Players then
		services.net:fire(remote, player, ...)
	end
end

local rng = Random.new()

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
	clock = function()
		return Workspace:GetServerTimeNow()
	end,
	random = function()
		return rng:NextNumber()
	end,
	schedule = function(seconds: number, fn: () -> ())
		task.delay(seconds, fn)
	end,
	canReach = function(player: Player, spotId: string)
		local index = spotIndex[spotId]
		return index ~= nil and World.canReach(player, index, config.fishing.castReach)
	end,
	spotOpen = function(_spotId: string)
		return false -- the tide cycle arrives in milestone M4
	end,
	notify = function(player: Player, text: string)
		fire(Remotes["TC:Notice"], player, text)
	end,
	castStarted = function(player: Player, castId: number, spotId: string)
		fire(Remotes["TC:CastStarted"], player, castId, spotId)
	end,
	bite = function(player: Player, castId: number, rarity: string)
		fire(Remotes["TC:Bite"], player, castId, rarity)
	end,
	caught = function(player: Player, caught: Actions.Caught)
		fire(
			Remotes["TC:Caught"],
			player,
			caught.castId,
			caught.speciesId,
			caught.kg,
			caught.uid,
			caught.soldFor,
			caught.isNew
		)
	end,
	escaped = function(player: Player, castId: number, text: string)
		fire(Remotes["TC:Escaped"], player, castId, text)
	end,
	welcome = function(player: Player, grew: number, restocked: boolean)
		fire(Remotes["TC:WelcomeBack"], player, grew, restocked)
	end,
})
actions = ready

services.data:onChanged(function(player: Player)
	syncCove(player)
end)

local net = services.net
net:on(Remotes["TC:Cast"], function(player: Player, spotId: string, baitId: string)
	ready:cast(player, spotId, baitId)
end)
net:on(Remotes["TC:Reel"], function(player: Player, castId: number, success: boolean)
	ready:reel(player, castId, success)
end)
net:on(Remotes["TC:SellCatch"], function(player: Player, uid: string)
	ready:sellCatch(player, uid)
end)
net:on(Remotes["TC:SellBucket"], function(player: Player)
	ready:sellBucket(player)
end)
net:on(Remotes["TC:Place"], function(player: Player, uid: string)
	ready:place(player, uid)
end)
net:on(Remotes["TC:Feed"], function(player: Player, slot: number)
	ready:feed(player, slot)
end)
net:on(Remotes["TC:SellPool"], function(player: Player, slot: number)
	ready:sellPool(player, slot)
end)
net:on(Remotes["TC:BuyPool"], function(player: Player)
	ready:buyPool(player)
end)
net:on(Remotes["TC:BuyRod"], function(player: Player, tier: number)
	ready:buyRod(player, tier)
end)
net:on(Remotes["TC:BuyBait"], function(player: Player, baitId: string, count: number)
	ready:buyBait(player, baitId, count)
end)

require(script.Shop).register(services, Config)

-- Tick: play time, the first-growth moment, forgotten lines, and pool redraws
-- (creatures grow a stage on the clock, with no data change to trigger one).
task.spawn(function()
	while true do
		task.wait(TICK_SECONDS)
		for _, player in Players:GetPlayers() do
			if services.data:isLoaded(player) and World.coveOf(player) then
				ready:tick(player)
				syncCove(player)
			end
		end
	end
end)
