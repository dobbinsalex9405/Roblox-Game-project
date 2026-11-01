--!strict
-- Tidecatch Cove client start-up: the core client, then the game's views.

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
local reel = require(script.ReelView).start(ctx)
require(script.FishingView).start(ctx, hud, reel)
require(script.CoveView).start(ctx)
require(script.PoolsView).start(ctx, hud)
require(script.ShopView).start(ctx)
