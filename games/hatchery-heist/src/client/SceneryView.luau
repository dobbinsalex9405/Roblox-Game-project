--!strict
-- Small touches of life in the scenery, on this client only: the windmill's
-- sails turn (config/atmosphere.luau `scenery.farm.windmillTurnSeconds`).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SceneryView = {}

function SceneryView.start()
	local farm = (require(ReplicatedStorage.GameConfig.atmosphere) :: any).scenery.farm
	task.spawn(function()
		local scenery = Workspace:WaitForChild("Scenery", 30)
		local sails = scenery and scenery:FindFirstChild("Sails", true)
		if sails == nil or not sails:IsA("Model") then
			return
		end
		local model = sails :: Model
		local home = model:GetPivot()
		local speed = math.pi * 2 / farm.windmillTurnSeconds
		local angle = 0
		RunService.RenderStepped:Connect(function(dt: number)
			angle = (angle + speed * dt) % (math.pi * 2)
			model:PivotTo(home * CFrame.Angles(0, 0, angle))
		end)
	end)
end

return SceneryView
