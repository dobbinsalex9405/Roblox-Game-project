--!strict
-- Depthbound client start-up: the core client, then the game's views.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Make sure the shared code has replicated before anything requires it.
for _, name in { "Core", "CoreClient", "Shared", "GameConfig" } do
	ReplicatedStorage:WaitForChild(name)
end

local CoreClient = require(ReplicatedStorage.CoreClient.CoreClient)
CoreClient.start()

local Context = require(script.Context)
local ctx = Context.new()

require(script.Hud).start(ctx)
require(script.Mining).start(ctx)
require(script.CampView).start(ctx)
