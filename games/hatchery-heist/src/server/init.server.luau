--!strict
-- Hatchery Heist server start-up: validate config, start the core, wire the shop.
-- Gameplay (conveyor, incubators, hatching, collecting, rebirth) arrives in M2.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Core = ReplicatedStorage.Core
local Config = require(Core.Config)
local Net = require(Core.Net)
local Odds = require(Core.Odds)
local Schema = require(Core.Schema)
local CoreServer = require(ServerScriptService.CoreServer.CoreServer)

local Shared = ReplicatedStorage.Shared
local Build = require(Shared.Build)
local DataTemplate = require(Shared.DataTemplate)
local Eggs = require(Shared.Eggs)
local Remotes = require(Shared.Remotes)(Net, Schema)
local Schemas = require(Shared.Schemas)(Schema, Odds)

local GameConfig = ReplicatedStorage.GameConfig
local raw = {
	economy = require(GameConfig.economy),
	creatures = require(GameConfig.creatures),
	eggs = require(GameConfig.eggs),
	raids = require(GameConfig.raids),
	monetization = require(GameConfig.monetization),
}

-- A bad config stops the server here, loudly, before any player data is touched.
-- CI runs the same checks, so this should never fire on a published build.
local problems = Schemas.crossCheck(raw)
assert(#problems == 0, "Invalid config:\n  " .. table.concat(problems, "\n  "))
Config.load(Schemas.sections(raw))

local economy = Config.get("economy")
local monetization = Config.get("monetization")
-- Coin packs make coins Robux-bought currency, so coin eggs count as paid random items.
local sellsCurrency = false
for key in monetization.products do
	if string.match(key, "^CoinPack") then
		sellsCurrency = true
	end
end

local services = CoreServer.start({
	game = "hatchery-heist",
	build = Build.commit,
	dataStoreName = "PlayerData_v1",
	template = DataTemplate.template,
	migrations = DataTemplate.migrations,
	currencies = { coins = { field = "coins", max = economy.coinsMax } },
	passes = monetization.passes,
	oddsTables = Eggs.oddsTables(Config.get("eggs"), sellsCurrency),
	remotes = Remotes,
})

require(script.Shop).register(services, Config)
