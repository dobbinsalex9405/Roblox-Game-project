--!strict
-- Street Food Empire client start-up: the core client, then the game's views.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Make sure the shared code has replicated before anything requires it.
for _, name in { "Core", "CoreClient", "Shared", "GameConfig" } do
	ReplicatedStorage:WaitForChild(name)
end

local CoreClient = require(ReplicatedStorage.CoreClient.CoreClient)
CoreClient.start()

local Context = require(script.Context)
local ctx = Context.new()

local hud = require(script.Hud).start(ctx)
require(script.PlotView).start(ctx, hud)
require(script.CrowdView).start(ctx)
