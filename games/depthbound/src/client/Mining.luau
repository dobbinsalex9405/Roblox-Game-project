--!strict
-- The pickaxe: while it is held (mouse button or finger down), swing at the
-- block under the pointer once per swing interval. A box outlines the block
-- that would be hit. The client only aims; the server checks reach, swing
-- speed, exposure and pick tier on every swing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Layout)

local Context = require(script.Parent.Context)

local Mining = {}

function Mining.start(ctx: Context.Context)
	local config = ctx.config
	local mouse = ctx.player:GetMouse()
	local equipped: Tool? = nil
	local holding = false
	local lastSwing = 0

	local box = Instance.new("SelectionBox")
	box.Name = "MiningTarget"
	box.LineThickness = 0.06
	box.Color3 = Color3.fromRGB(255, 220, 120)
	box.SurfaceTransparency = 1
	box.Parent = ctx.player:WaitForChild("PlayerGui")

	local function target(): BasePart?
		local part: BasePart? = mouse.Target
		local mineFolder = Workspace:FindFirstChild("Mine")
		if part == nil or mineFolder == nil or part.Parent ~= mineFolder then
			return nil
		end
		local pos = ctx.position()
		if pos == nil then
			return nil
		end
		local x, y, z = part:GetAttribute("X"), part:GetAttribute("Y"), part:GetAttribute("Z")
		if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
			return nil
		end
		local center = Layout.blockCenter(config.mine, x, y, z)
		if Layout.distance(pos, center) > config.dive.reach then
			return nil
		end
		return part
	end

	local function swing()
		local now = os.clock()
		if now - lastSwing < config.dive.swingSeconds then
			return
		end
		local part = target()
		if part == nil then
			return
		end
		lastSwing = now
		ctx.fire(
			ctx.remotes["DB:Hit"],
			part:GetAttribute("X") :: number,
			part:GetAttribute("Y") :: number,
			part:GetAttribute("Z") :: number
		)
	end

	local function watch(tool: Tool)
		tool.Equipped:Connect(function()
			equipped = tool
		end)
		tool.Unequipped:Connect(function()
			equipped = nil
			holding = false
		end)
		tool.Activated:Connect(function()
			holding = true
			swing() -- a tap on a phone swings at once
		end)
		tool.Deactivated:Connect(function()
			holding = false
		end)
	end

	-- Each spawn gets a fresh pickaxe from StarterPack. It is put in the
	-- player's hand straight away: a new player should never have to find
	-- the hotbar before their first swing.
	local function onCharacter(character: Model)
		equipped = nil
		holding = false
		local tool = character:FindFirstChild("Pickaxe")
		if tool == nil then
			local backpack = ctx.player:WaitForChild("Backpack")
			tool = backpack:FindFirstChild("Pickaxe") or backpack:WaitForChild("Pickaxe", 10)
		end
		if tool == nil or not tool:IsA("Tool") or character.Parent == nil then
			return
		end
		local pickaxe = tool :: Tool
		watch(pickaxe)
		if pickaxe.Parent == character then
			equipped = pickaxe -- already in hand: Equipped fired before we listened
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid:EquipTool(pickaxe)
		end
	end
	ctx.player.CharacterAdded:Connect(onCharacter)
	if ctx.player.Character then
		task.spawn(onCharacter, ctx.player.Character)
	end

	RunService.RenderStepped:Connect(function()
		local part = if equipped then target() else nil
		box.Adornee = part
		if holding and equipped and ctx.dive().phase ~= "Climbing" then
			swing()
		end
	end)
end

return Mining
