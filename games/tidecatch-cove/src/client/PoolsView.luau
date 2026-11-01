--!strict
-- The Pools panel: every tide pool the player owns, with Feed and Sell, and
-- the next pool to unlock, from anywhere on the map (the bucket already
-- places from anywhere). The cove's prompts do the same things up close.
-- Buttons only ask; the server checks everything again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cove = require(Shared.Cove)
local Creatures = require(Shared.Creatures)
local Layout = require(Shared.Layout)

local Context = require(script.Parent.Context)
local Hud = require(script.Parent.Hud)
local Ui = require(script.Parent.Ui)

local PoolsView = {}

local GREY = Color3.fromRGB(70, 75, 85)

function PoolsView.start(ctx: Context.Context, hud: Hud.Api)
	local config = ctx.config
	local gui = ctx.player:WaitForChild("PlayerGui"):WaitForChild("TidecatchHud")

	local panel =
		Ui.panel(gui, "Pools", UDim2.fromOffset(340, 360), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	panel.Visible = false
	local title = Ui.label(panel, "Title", UDim2.new(1, -60, 0, 30), UDim2.fromOffset(10, 6))
	title.TextXAlignment = Enum.TextXAlignment.Left
	local close = Ui.button(panel, "Close", "X", UDim2.fromOffset(40, 34), Ui.WARN)
	close.Position = UDim2.new(1, -46, 0, 4)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "List"
	scroll.Size = UDim2.new(1, -12, 1, -110)
	scroll.Position = UDim2.fromOffset(6, 42)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 8
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	Ui.list(scroll, 2)
	scroll.Parent = panel
	local unlock = Ui.button(panel, "Unlock", "", UDim2.new(1, -16, 0, 54), Ui.GOOD)
	unlock.Position = UDim2.new(0, 8, 1, -62)
	unlock.Activated:Connect(function()
		ctx.fire(ctx.remotes["TC:BuyPool"])
	end)

	-- Under the Bucket button, where the odds card goes while at a dock: the
	-- button steps aside for the card (pools wait while you fish).
	local button = Ui.button(gui, "PoolsButton", "Pools", UDim2.fromOffset(130, 52), Ui.GOOD)
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -12, 0, 66)
	local oddsCard = gui:WaitForChild("OddsCard") :: GuiObject
	local function placeButton()
		button.Visible = not oddsCard.Visible
	end
	oddsCard:GetPropertyChangedSignal("Visible"):Connect(placeButton)
	placeButton()

	-- One row per pool slot, built once per slot and then only updated, so
	-- buttons stay put under the player's thumb while timers tick.
	type Row = { frame: Frame, name: TextLabel, info: TextLabel, feed: TextButton, sell: TextButton }
	local rows: { [number]: Row } = {}
	local function rowFor(slot: number): Row
		local existing = rows[slot]
		if existing then
			return existing
		end
		local frame = Instance.new("Frame")
		frame.Name = `Pool{slot}`
		frame.LayoutOrder = slot
		frame.Size = UDim2.new(1, -10, 0, 44)
		frame.BackgroundTransparency = 1
		local name = Ui.label(frame, "Name", UDim2.fromScale(0.5, 0.55))
		name.TextXAlignment = Enum.TextXAlignment.Left
		local info = Ui.label(frame, "Info", UDim2.fromScale(0.5, 0.45), UDim2.fromScale(0, 0.55))
		info.TextXAlignment = Enum.TextXAlignment.Left
		info.Font = Enum.Font.Gotham
		info.TextColor3 = Ui.MUTED
		local feed = Ui.button(frame, "Feed", "Feed", UDim2.new(0.22, -4, 1, -4), Ui.GOOD)
		feed.Position = UDim2.new(0.5, 2, 0, 2)
		feed.Activated:Connect(function()
			if feed.Active then
				ctx.fire(ctx.remotes["TC:Feed"], slot)
			end
		end)
		local sell = Ui.button(frame, "Sell", "", UDim2.new(0.28, -4, 1, -4), Ui.WARN)
		sell.Position = UDim2.new(0.72, 2, 0, 2)
		sell.Activated:Connect(function()
			if sell.Active then
				ctx.fire(ctx.remotes["TC:SellPool"], slot)
			end
		end)
		frame.Parent = scroll
		local row = { frame = frame, name = name, info = info, feed = feed, sell = sell }
		rows[slot] = row
		return row
	end

	local function setEnabled(b: TextButton, on: boolean, color: Color3)
		b.Active = on
		b.AutoButtonColor = on
		b.BackgroundColor3 = if on then color else GREY
	end

	local function render()
		local d = ctx.data()
		if d == nil or not panel.Visible then
			return
		end
		local now = ctx.serverNow()
		local perks = ctx.perks()
		local count = Cove.poolCount(d, config.pools, perks)
		title.Text = `Tide pools ({#d.pools}/{count})`
		for slot = 1, math.max(count, #rows) do
			local row = rowFor(slot)
			row.frame.Visible = slot <= count
			local pooled = Cove.poolAt(d, slot)
			local def = pooled and config.species.species[pooled.speciesId]
			if pooled == nil or def == nil then
				row.name.Text = `Pool {slot}: empty`
				row.name.TextColor3 = Ui.MUTED
				row.info.Text = "Place a catch from your bucket."
				row.feed.Visible = false
				row.sell.Visible = false
				continue
			end
			local stage = Creatures.stage(pooled, now, config.species, config.pools)
			local nextIn = Creatures.nextStageIn(pooled, now, config.species, config.pools)
			local wait = Cove.feedCooldown(pooled, now, config.pools)
			row.name.Text = Layout.displayName(pooled.speciesId)
			row.name.TextColor3 = Layout.rarityColor(def.rarity)
			row.info.Text = `{config.pools.stages[stage].name}, `
				.. (if nextIn then `grows in {Layout.formatTime(nextIn)}` else "fully grown!")
			row.feed.Visible = true
			row.feed.Text = if nextIn == nil
				then "Grown"
				elseif wait > 0 then Layout.formatTime(wait)
				else "Feed"
			setEnabled(row.feed, nextIn ~= nil and wait <= 0, Ui.GOOD)
			row.sell.Visible = true
			local value =
				Cove.salePrice(Creatures.value(pooled, stage, config.species, config.pools), config, perks)
			row.sell.Text = `{Layout.shortNumber(value)}c`
			setEnabled(row.sell, true, Ui.WARN)
		end
		local cost = Cove.nextPoolCost(d, config.pools)
		unlock.Text = if cost
			then `Unlock pool {count + 1}: {Layout.shortNumber(cost)} coins`
			else "Every pool unlocked"
		setEnabled(unlock, cost ~= nil and d.coins >= cost, Ui.GOOD)
	end

	local function setOpen(open: boolean)
		panel.Visible = open
		if open then
			hud.hideBucket()
			render()
		end
	end
	button.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)
	hud.onBucketOpened(function()
		panel.Visible = false
	end)
	ctx.onData(function()
		render()
	end)

	-- Timers on the rows tick while the panel is open.
	task.spawn(function()
		while true do
			render()
			task.wait(0.5)
		end
	end)
end

return PoolsView
