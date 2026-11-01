--!strict
-- Depthbound server start-up: validate config, build the camp and the mine,
-- start the core, then wire the dive loop (Actions) to remotes, prompts,
-- characters and a fast step.

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
local DataTemplate = require(Shared.DataTemplate)
local FeedbackContext = require(Shared.FeedbackContext)
local Layout = require(Shared.Layout)
local MineGrid = require(Shared.MineGrid)
local Remotes = require(Shared.Remotes)(Net, Schema)
local Schemas = require(Shared.Schemas)(Schema, Odds)

local Camp = require(script.Camp)
local MineView = require(script.MineView)

local STEP_SECONDS = 0.2 -- oil, depth and dive endings are checked this often
local REGROW_SECONDS = 15 -- how often old mined-out blocks are checked for regrowth
local LAMP_RANGE = 26

local log = Log.new("Game")

local GameConfig = ReplicatedStorage.GameConfig
local raw = {
	economy = require(GameConfig.economy),
	blocks = require(GameConfig.blocks),
	mine = require(GameConfig.mine),
	gear = require(GameConfig.gear),
	dive = require(GameConfig.dive),
	monetization = require(GameConfig.monetization),
}

-- A bad config stops the server here, loudly, before any player data is touched.
-- CI runs the same checks, so this should never fire on a published build.
local problems = Schemas.crossCheck(raw)
assert(#problems == 0, "Invalid config:\n  " .. table.concat(problems, "\n  "))
Config.load(Schemas.sections(raw))

local economy = Config.get("economy")
local monetization = Config.get("monetization")
local mine = Config.get("mine")
local config = {
	mine = mine,
	blocks = Config.get("blocks"),
	gear = Config.get("gear"),
	dive = Config.get("dive"),
}

-- A fresh mine for this server. The seed is logged so a bug report can rebuild it.
local seed = Random.new():NextInteger(1, 2 ^ 31 - 2)
local grid = MineGrid.new(mine, config.blocks, seed)
log:info("mine built", { seed = seed, exposed = grid.exposedCount })

local services: CoreServer.Services
local actions: Actions.Actions? = nil

local function withActions(fn: (a: Actions.Actions) -> ())
	if actions then
		fn(actions)
	end
end

Camp.build(mine, {
	sell = function(player: Player)
		withActions(function(a)
			a:sell(player)
		end)
	end,
	upgrade = function(player: Player, kind)
		withActions(function(a)
			a:upgrade(player, kind)
		end)
	end,
})
Camp.pickaxe()
MineView.start(grid, config.blocks)

local campSpawn = Layout.campSpawn(mine)

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function perks(player: Player): Actions.Perks
	return {
		biggerPack = services.passes:owns(player, "BiggerPack"),
		betterLamp = services.passes:owns(player, "BetterLamp"),
		autoSell = services.passes:owns(player, "AutoSell"),
	}
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local head = character:WaitForChild("Head") :: BasePart
	-- Everyone's lamp is visible to everyone; each client dims its own as oil runs low.
	local light = Instance.new("PointLight")
	light.Name = "Lamp"
	light.Range = LAMP_RANGE
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 210, 150)
	light.Shadows = true
	light.Parent = head
	humanoid.Died:Connect(function()
		withActions(function(a)
			a:died(player)
		end)
	end)
end

local function onPlayerReady(player: Player)
	-- start() returns before any player finishes loading (loading yields), but
	-- guard anyway so a fast load can never see actions unset.
	while actions == nil do
		task.wait()
	end
	player.CharacterAdded:Connect(function(character: Model)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	local loop = actions :: Actions.Actions
	loop:join(player)
end

local function onPlayerLeaving(player: Player)
	withActions(function(a)
		a:leave(player)
	end)
end

services = CoreServer.start({
	game = "depthbound",
	build = Build.commit,
	dataStoreName = "PlayerData_v1",
	template = DataTemplate.template,
	migrations = DataTemplate.migrations,
	currencies = { coins = { field = "coins", max = economy.coinsMax } },
	passes = monetization.passes,
	oddsTables = Schemas.oddsTables(mine),
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
	analytics = services.analytics,
	grid = grid,
	config = config,
	perks = perks,
	now = function()
		return Workspace:GetServerTimeNow()
	end,
	position = function(player: Player)
		local root = rootOf(player)
		if root == nil then
			return nil
		end
		local p = root.Position
		return { x = p.X, y = p.Y, z = p.Z }
	end,
	notify = function(player: Player, text: string)
		fire(Remotes["DB:Notice"], player, text)
	end,
	dive = function(player: Player, phase, meter, capacity: number, climbEndsAt: number)
		fire(Remotes["DB:Dive"], player, phase, meter.oil, meter.rate, meter.at, capacity, climbEndsAt)
	end,
	ore = function(player: Player, blockId: string)
		fire(Remotes["DB:Ore"], player, blockId)
	end,
	lampOut = function(player: Player, kept: number, dropped: number, row: number)
		fire(Remotes["DB:LampOut"], player, kept, dropped, row)
	end,
	sold = function(player: Player, coins: number, pieces: number)
		fire(Remotes["DB:Sold"], player, coins, pieces)
	end,
	mineChanged = MineView.apply,
	damaged = MineView.damaged,
	climbing = function(player: Player, on: boolean)
		local root = rootOf(player)
		if root then
			root.Anchored = on
		end
	end,
	rescue = function(player: Player)
		local character = player.Character
		local root = rootOf(player)
		if character and root then
			root.Anchored = false
			character:PivotTo(CFrame.new(campSpawn.x, campSpawn.y + 4, campSpawn.z))
		end
	end,
})
actions = ready

local net = services.net
net:on(Remotes["DB:Hit"], function(player: Player, x: number, y: number, z: number)
	ready:hit(player, x, y, z)
end)
net:on(Remotes["DB:Climb"], function(player: Player)
	ready:climb(player)
end)

require(script.Shop).register(services, Config)

-- The dive step: oil, depth, lamp-outs and dive endings for everyone.
task.spawn(function()
	while true do
		task.wait(STEP_SECONDS)
		for _, player in Players:GetPlayers() do
			if services.data:isLoaded(player) then
				ready:step(player)
			end
		end
	end
end)

-- Old tunnels grow back where nobody is standing.
task.spawn(function()
	while true do
		task.wait(REGROW_SECONDS)
		ready:regrowMine()
		Workspace:SetAttribute("MineParts", MineView.count())
	end
end)
