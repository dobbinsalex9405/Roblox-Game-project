--!strict
-- The bait shop on the island: rods and bait for coins, with each bait's
-- stock until the next restock and a countdown to it. Robux items arrive
-- with the M5 shop. Buttons only ask; the server checks coins and stock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Cove = require(Shared.Cove)
local Layout = require(Shared.Layout)

local Context = require(script.Parent.Context)
local Ui = require(script.Parent.Ui)

local ShopView = {}

function ShopView.start(ctx: Context.Context)
	local config = ctx.config
	local fishing = config.fishing
	local gui = Instance.new("ScreenGui")
	gui.Name = "ShopGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	gui.Parent = ctx.player:WaitForChild("PlayerGui")

	local panel =
		Ui.panel(gui, "Shop", UDim2.fromOffset(340, 400), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	panel.Visible = false
	local title = Ui.label(panel, "Title", UDim2.new(1, -60, 0, 30), UDim2.fromOffset(10, 6))
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Bait & Tackle"
	local close = Ui.button(panel, "Close", "X", UDim2.fromOffset(40, 34), Ui.WARN)
	close.Position = UDim2.new(1, -46, 0, 4)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	local restock = Ui.label(panel, "Restock", UDim2.new(1, -20, 0, 18), UDim2.fromOffset(10, 38))
	restock.Font = Enum.Font.Gotham
	restock.TextColor3 = Ui.MUTED
	restock.TextXAlignment = Enum.TextXAlignment.Left

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "List"
	scroll.Size = UDim2.new(1, -12, 1, -66)
	scroll.Position = UDim2.fromOffset(6, 60)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 8
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	Ui.list(scroll, 2)
	scroll.Parent = panel

	local function itemRow(order: number, name: string, info: string, color: Color3): Frame
		local row = Instance.new("Frame")
		row.Name = `Item{order}`
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -10, 0, 46)
		row.BackgroundTransparency = 1
		local n = Ui.label(row, "Name", UDim2.fromScale(0.5, 0.55))
		n.TextXAlignment = Enum.TextXAlignment.Left
		n.TextColor3 = color
		n.Text = name
		local i = Ui.label(row, "Info", UDim2.fromScale(0.5, 0.45), UDim2.fromScale(0, 0.55))
		i.TextXAlignment = Enum.TextXAlignment.Left
		i.Font = Enum.Font.Gotham
		i.TextColor3 = Ui.MUTED
		i.Text = info
		row.Parent = scroll
		return row
	end

	local function render()
		local d = ctx.data()
		if d == nil or not panel.Visible then
			return
		end
		local now = ctx.serverNow()
		Ui.clear(scroll)
		local order = 0
		for tier, rod in fishing.rods do
			order += 1
			local owned = d.rodTier >= tier
			local row = itemRow(
				order,
				Layout.displayName(rod.id),
				if tier == 1 then "Starter rod" else `Luckier, faster bites, wider zone`,
				Ui.GOLD
			)
			local buy = Ui.button(
				row,
				"Buy",
				if owned then "Owned" else `{Layout.shortNumber(rod.priceCoins)}c`,
				UDim2.new(0.45, -4, 1, -4),
				if owned then Color3.fromRGB(70, 75, 85) else Ui.GOOD
			)
			buy.Position = UDim2.new(0.55, 2, 0, 2)
			if not owned then
				buy.Activated:Connect(function()
					ctx.fire(ctx.remotes["TC:BuyRod"], tier)
				end)
			end
		end
		for _, bait in fishing.bait do
			if bait.robux then
				continue -- Robux-only bait comes from the Robux shop, not for coins
			end
			order += 1
			local left = Cove.stockLeft(d, bait, now, config.economy)
			local boosts = {}
			for rarity, m in bait.rarityMultipliers do
				table.insert(boosts, `{rarity} x{m}`)
			end
			table.sort(boosts)
			local row = itemRow(
				order,
				`{Layout.displayName(bait.id)} ({bait.priceCoins}c)`,
				`{table.concat(boosts, ", ")}. {left} left`,
				Color3.new(1, 1, 1)
			)
			for i, count in { 1, 5 } do
				local can = left >= count
				local b = Ui.button(
					row,
					`Buy{count}`,
					`x{count}`,
					UDim2.new(0.22, -4, 1, -4),
					if can then Ui.GOOD else Color3.fromRGB(70, 75, 85)
				)
				b.Position = UDim2.new(0.56 + (i - 1) * 0.22, 2, 0, 2)
				b.Activated:Connect(function()
					if can then
						ctx.fire(ctx.remotes["TC:BuyBait"], bait.id, count)
					end
				end)
			end
		end
	end

	local shop = Workspace:WaitForChild("Map"):WaitForChild("BaitShop")
	local open = Instance.new("ProximityPrompt")
	open.Name = "Shop"
	open.ActionText = "Shop"
	open.ObjectText = "Bait & Tackle"
	open.MaxActivationDistance = 12
	open.RequiresLineOfSight = false
	open.Triggered:Connect(function()
		panel.Visible = true
		render()
	end)
	open.Parent = shop

	ctx.onData(function()
		render()
	end)

	-- The restock countdown, and a redraw when the stock refills.
	task.spawn(function()
		local lastWindow = -1
		while true do
			local now = ctx.serverNow()
			local window = Cove.restockWindow(now, config.economy)
			restock.Text = `Restocks in {Layout.formatTime(window + config.economy.restockSeconds - now)}`
			if window ~= lastWindow then
				lastWindow = window
				render()
			end
			task.wait(0.5)
		end
	end)
end

return ShopView
