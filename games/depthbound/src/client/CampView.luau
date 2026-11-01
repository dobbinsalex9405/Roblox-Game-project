--!strict
-- Camp, as this player sees it: prices and pack value on the prompts (the
-- prompts themselves are the server's), and the layer guide board with every
-- layer's ore and its exact chance. Finding ore is free, but the chances are
-- shown anyway, from the same table the mine is built from.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Odds = require(ReplicatedStorage.Core.Odds)
local Shared = ReplicatedStorage.Shared
local Gear = require(Shared.Gear)
local Layout = require(Shared.Layout)
local Pack = require(Shared.Pack)

local Context = require(script.Parent.Context)

local CampView = {}

local function text(parent: Instance, value: string, height: number, bold: boolean?): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, height)
	l.BackgroundTransparency = 1
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = value
	l.Parent = parent
	return l
end

local function buildGuide(ctx: Context.Context, board: BasePart)
	local config = ctx.config
	local sg = Instance.new("SurfaceGui")
	sg.Name = "LayerGuide"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.Adornee = board
	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Parent = sg
	local columns = Instance.new("UIListLayout")
	columns.FillDirection = Enum.FillDirection.Horizontal
	columns.SortOrder = Enum.SortOrder.LayoutOrder
	columns.Padding = UDim.new(0, 16)
	columns.Parent = holder
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 16)
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = holder

	local layers = config.mine.layers
	for index, layer in layers do
		local column = Instance.new("Frame")
		column.LayoutOrder = index
		column.BackgroundTransparency = 1
		column.Size = UDim2.new(1 / #layers, -16, 1, -16)
		local rows = Instance.new("UIListLayout")
		rows.SortOrder = Enum.SortOrder.LayoutOrder
		rows.Padding = UDim.new(0, 4)
		rows.Parent = column
		local top = Layout.layerTop(config.mine, index)
		text(column, `{index}. {layer.name}`, 34, true)
		text(column, `Rows {top}-{top + layer.rows - 1}`, 24)
		text(column, `Needs: {config.gear.pick[layer.minPickTier].name}`, 24)
		text(column, `Oil burn: x{layer.oilPerSecond}`, 24)
		for _, entry in layer.blocks do
			local block = config.blocks[entry.id]
			local worth = if block.value > 0 then `{block.value} coins` else "rock"
			local line = text(
				column,
				`{Layout.displayName(entry.id)} · {Odds.formatPercent(entry.weight)} · {worth}`,
				24
			)
			line.TextColor3 = Color3.fromRGB(block.color[1], block.color[2], block.color[3])
			line.TextStrokeTransparency = 0.3
		end
		column.Parent = holder
	end
	sg.Parent = ctx.player:WaitForChild("PlayerGui")
end

function CampView.start(ctx: Context.Context)
	local config = ctx.config
	local camp = Workspace:WaitForChild("Camp")
	local stations = camp:WaitForChild("Stations")

	buildGuide(ctx, stations:WaitForChild("LayerGuide") :: BasePart)

	-- Rewrites the prompt text locally (only this player sees it).
	local function refresh(d: { [string]: any })
		local sell = stations:FindFirstChild("SellPad")
		local sellPrompt = sell and sell:FindFirstChildOfClass("ProximityPrompt")
		if sellPrompt then
			local pieces = Pack.count(d.pack)
			sellPrompt.ObjectText = if pieces > 0
				then `{pieces} ore for {Layout.shortNumber(Pack.value(d.pack, config.blocks))} coins`
				else "Pack is empty"
		end
		for _, kind in Gear.KINDS do
			local stand = stations:FindFirstChild(kind)
			local prompt = stand and stand:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				local nextTier = Gear.nextTier(d, config.gear, kind)
				if nextTier then
					prompt.ActionText = `Buy for {Layout.shortNumber(nextTier.cost)}`
					prompt.ObjectText = nextTier.name
				else
					prompt.ActionText = "Best tier"
					prompt.ObjectText = Gear.current(d, config.gear, kind).name
				end
			end
		end
	end
	ctx.onData(refresh)
end

return CampView
