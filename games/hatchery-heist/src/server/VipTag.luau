--!strict
-- The VIP pass's gold "VIP" tag, floating over the player's head where
-- everyone can see it. Set on every spawn and on the income tick, so a pass
-- bought mid-session shows within seconds.

local VipTag = {}

local NAME = "VIPTag"
local GOLD = Color3.fromRGB(255, 205, 50)
local OUTLINE = Color3.fromRGB(90, 55, 0)

local function build(head: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = NAME
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(64, 26)
	-- Above Roblox's own name label, which sits about 2 studs over the head.
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(40, 28, 0)
	label.BackgroundTransparency = 0.25
	label.Font = Enum.Font.FredokaOne
	label.Text = "VIP"
	label.TextSize = 20
	label.TextColor3 = GOLD
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = GOLD
	edge.Thickness = 2
	edge.Parent = label
	local textEdge = Instance.new("UIStroke")
	textEdge.Color = OUTLINE
	textEdge.Thickness = 1.5
	textEdge.Parent = label
	label.Parent = gui
	gui.Parent = head
	return gui
end

-- Shows the tag on `player`'s current character when `isVip`, removes it
-- otherwise. Does nothing until the character has a head.
function VipTag.apply(player: Player, isVip: boolean)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local existing = head:FindFirstChild(NAME)
	if isVip and existing == nil then
		build(head)
	elseif not isVip and existing then
		existing:Destroy()
	end
end

return VipTag
