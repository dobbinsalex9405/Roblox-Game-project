--!strict
-- Hatchery Heist client start-up: the core client, then the game's views.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Make sure the shared code has replicated before anything requires it.
for _, name in { "Core", "CoreClient", "Shared", "GameConfig" } do
	ReplicatedStorage:WaitForChild(name)
end

local CoreClient = require(ReplicatedStorage.CoreClient.CoreClient)
CoreClient.start()

local Context = require(script.Context)
local ctx = Context.new()

require(script.OddsView).start(ctx)
local hud = require(script.Hud).start(ctx)
require(script.ConveyorView).start(ctx, hud)
require(script.BaseView).start(ctx)
require(script.CreatureView).start()
require(script.SceneryView).start()
require(script.TowerShellView).start()
local menu = require(script.GuideView).start(ctx)
require(script.BookView).start(ctx, menu)
require(script.TowerView).start(ctx, menu)
require(script.TowerDecorView).start()
require(script.DailyView).start(ctx, menu)
require(script.Music).start(menu)
require(script.CoinShop).start(ctx)
require(script.ShopHouseView).start()
require(script.EventView).start(ctx)
