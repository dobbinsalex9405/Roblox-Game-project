--!strict
-- The minimal M2 interface, phone first: coins, the pack, depth, the oil
-- meter with a marker for the oil a climb from here needs, the Climb out
-- button, the oil refill button, the Ore Boost timer, short notices, ore
-- pickups, lamp-out and sale messages. Built from code; art comes after the
-- gate. The shop itself is the core's (top bar).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ShopRemotes = require(ReplicatedStorage.Core.ShopRemotes)
local Shared = ReplicatedStorage.Shared
local Boosts = require(Shared.Boosts)
local Gear = require(Shared.Gear)
local Guide = require(Shared.Guide)
local Lamp = require(Shared.Lamp)
local Layout = require(Shared.Layout)
local Pack = require(Shared.Pack)

local Context = require(script.Parent.Context)

local Hud = {}

local GOLD = Color3.fromRGB(255, 215, 90)
local OIL_OK = Color3.fromRGB(255, 190, 70)
local OIL_LOW = Color3.fromRGB(255, 120, 40)
local OIL_DRY = Color3.fromRGB(230, 50, 50)
local SHOP_NOTICE_SECONDS = 5 -- shop answers to the HUD's Buy button show here for this long

local function label(parent: Instance, name: string, size: UDim2, position: UDim2?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = position or UDim2.new()
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5
	l.Text = ""
	l.Parent = parent
	return l
end

local function panel(parent: Instance, name: string, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = position
	f.AnchorPoint = anchor
	f.BackgroundColor3 = Color3.fromRGB(25, 22, 20)
	f.BackgroundTransparency = 0.2
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = f
	f.Parent = parent
	return f
end

function Hud.start(ctx: Context.Context)
	local config = ctx.config
	local gui = Instance.new("ScreenGui")
	gui.Name = "DepthboundHud"
	gui.ResetOnSpawn = false
	gui.Parent = ctx.player:WaitForChild("PlayerGui")

	-- Top bar: coins and the pack.
	local bar = panel(gui, "Bar", UDim2.fromOffset(360, 64), UDim2.new(0.5, 0, 0, 8), Vector2.new(0.5, 0))
	local coins = label(bar, "Coins", UDim2.new(0.5, -8, 0.6, 0), UDim2.fromOffset(8, 2))
	coins.TextXAlignment = Enum.TextXAlignment.Left
	coins.TextColor3 = GOLD
	local pack = label(bar, "Pack", UDim2.new(0.5, -8, 0.6, 0), UDim2.new(0.5, 0, 0, 2))
	pack.TextXAlignment = Enum.TextXAlignment.Right
	local depth = label(bar, "Depth", UDim2.new(1, -16, 0.38, 0), UDim2.new(0, 8, 0.6, 0))
	depth.Font = Enum.Font.Gotham

	-- Oil meter, bottom center.
	local meter = panel(gui, "Oil", UDim2.fromOffset(320, 50), UDim2.new(0.5, 0, 1, -16), Vector2.new(0.5, 1))
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, -16, 0, 14)
	track.Position = UDim2.fromOffset(8, 30)
	track.BackgroundColor3 = Color3.fromRGB(60, 50, 40)
	track.BorderSizePixel = 0
	track.Parent = meter
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = OIL_OK
	fill.BorderSizePixel = 0
	fill.Parent = track
	-- The oil a climb from here needs.
	local marker = Instance.new("Frame")
	marker.Name = "ClimbMarker"
	marker.Size = UDim2.new(0, 3, 1, 8)
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.fromScale(0, 0.5)
	marker.BackgroundColor3 = Color3.new(1, 1, 1)
	marker.BorderSizePixel = 0
	marker.Parent = track
	local oilText = label(meter, "Text", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 4))

	-- Climb out, right side above the jump button.
	local climb = Instance.new("TextButton")
	climb.Name = "Climb"
	climb.Size = UDim2.fromOffset(170, 52)
	climb.Position = UDim2.new(1, -16, 1, -150)
	climb.AnchorPoint = Vector2.new(1, 1)
	climb.BackgroundColor3 = Color3.fromRGB(70, 160, 90)
	climb.Font = Enum.Font.GothamBold
	climb.TextScaled = true
	climb.TextColor3 = Color3.new(1, 1, 1)
	climb.Text = "Climb out"
	climb.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = climb
	climb.Parent = gui
	climb.Activated:Connect(function()
		ctx.fire(ctx.remotes["DB:Climb"])
	end)

	-- Oil refill, above Climb out: pours one the player owns, or buys one.
	local refill = climb:Clone()
	refill.Name = "Refill"
	refill.Position = UDim2.new(1, -16, 1, -210)
	refill.BackgroundColor3 = Color3.fromRGB(200, 140, 40)
	refill.Text = "Oil refill"
	refill.Parent = gui
	local boughtAt = -math.huge
	refill.Activated:Connect(function()
		local d = ctx.data()
		if d and (d.oilRefills or 0) > 0 then
			ctx.fire(ctx.remotes["DB:Refill"])
		else
			boughtAt = os.clock()
			ctx.fire(ShopRemotes["Shop:Buy"], "product", "OilRefill")
		end
	end)

	-- Ore Boost timer, just above the oil meter.
	local boost = label(gui, "Boost", UDim2.fromOffset(320, 24), UDim2.new(0.5, 0, 1, -72))
	boost.AnchorPoint = Vector2.new(0.5, 1)
	boost.TextColor3 = GOLD
	boost.Visible = false

	-- First-session goal line, just under the bar (gone after the first upgrade).
	local goal = panel(gui, "Goal", UDim2.fromOffset(380, 30), UDim2.new(0.5, 0, 0, 76), Vector2.new(0.5, 0))
	goal.BackgroundColor3 = Color3.fromRGB(45, 50, 110)
	goal.Visible = false
	local goalText = label(goal, "Text", UDim2.new(1, -16, 1, -8), UDim2.fromOffset(8, 4))
	goalText.TextColor3 = GOLD

	-- Notices: one line at a time under the bar (and the goal line).
	local notice =
		panel(gui, "Notice", UDim2.fromOffset(380, 36), UDim2.new(0.5, 0, 0, 112), Vector2.new(0.5, 0))
	notice.Visible = false
	local noticeText = label(notice, "Text", UDim2.new(1, -16, 1, -8), UDim2.fromOffset(8, 4))
	local noticeId = 0
	local function show(text: string, seconds: number?)
		noticeId += 1
		local id = noticeId
		noticeText.Text = text
		notice.Visible = true
		task.delay(seconds or 3, function()
			if noticeId == id then
				notice.Visible = false
			end
		end)
	end

	-- Ore pickups float up on the left.
	local pickups = Instance.new("Frame")
	pickups.Name = "Pickups"
	pickups.BackgroundTransparency = 1
	pickups.Size = UDim2.fromOffset(200, 160)
	pickups.Position = UDim2.new(0, 16, 0.5, 0)
	pickups.AnchorPoint = Vector2.new(0, 0.5)
	pickups.Parent = gui
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.Parent = pickups
	local pickupOrder = 0

	ctx.on(ctx.remotes["DB:Notice"], function(text: string)
		show(text)
	end)
	-- The shop's answer to the HUD's own Buy button (the shop window may be closed).
	ctx.on(ShopRemotes["Shop:Notice"], function(text: string)
		if os.clock() - boughtAt < SHOP_NOTICE_SECONDS then
			show(text, 5)
		end
	end)
	ctx.on(ctx.remotes["DB:Ore"], function(blockId: string)
		local block = config.blocks[blockId]
		pickupOrder += 1
		local l = label(pickups, "Pickup", UDim2.new(1, 0, 0, 26))
		l.LayoutOrder = pickupOrder
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Text = `+1 {Layout.displayName(blockId)} ({block and block.value or 0})`
		if block then
			l.TextColor3 = Color3.fromRGB(block.color[1], block.color[2], block.color[3])
		end
		task.delay(2.5, function()
			l:Destroy()
		end)
	end)
	ctx.on(ctx.remotes["DB:LampOut"], function(kept: number, dropped: number, row: number)
		show(`Your lamp went out at row {row}! You dropped {dropped} ore in the dark and kept {kept}.`, 7)
	end)
	ctx.on(ctx.remotes["DB:Sold"], function(earned: number, pieces: number)
		show(`Sold {pieces} ore for {Layout.shortNumber(earned)} coins.`, 4)
	end)

	-- Coins and the pack, with the pack's worth at today's price (an Ore
	-- Boost can start or end at any time, so this runs every frame too).
	local function showData(d: { [string]: any }, now: number)
		coins.Text = `{Layout.shortNumber(d.coins)} coins`
		local capacity = Gear.packCapacity(d, config.gear, ctx.perks())
		local count = Pack.count(d.pack)
		local multiplier = Boosts.sellMultiplier(d, config.monetization.boosts, now)
		local worth = math.floor(Pack.value(d.pack, config.blocks) * multiplier)
		pack.Text = `Pack {count}/{capacity} · {Layout.shortNumber(worth)}`
		pack.TextColor3 = if count >= capacity then OIL_LOW else Color3.new(1, 1, 1)
		local objective = Guide.objective(d, config.gear, ctx.dive().phase)
		goal.Visible = objective ~= nil
		goalText.Text = objective or ""
		local left = Boosts.left(d, "OreBoost", now)
		boost.Visible = left > 0
		if left > 0 then
			boost.Text = `Ore Boost {multiplier}x · {Boosts.clock(left)}`
		end
	end
	ctx.onData(function(d: { [string]: any })
		showData(d, ctx.serverNow())
	end)

	-- The own lamp dims as oil runs low (everyone else sees it at full).
	local function lampLight(): PointLight?
		local character = ctx.player.Character
		local head = character and character:FindFirstChild("Head")
		local light = head and head:FindFirstChild("Lamp")
		if light and light:IsA("PointLight") then
			return light
		end
		return nil
	end

	-- Numbers that move every frame: oil, depth, the climb button.
	RunService.Heartbeat:Connect(function()
		local dive = ctx.dive()
		local now = ctx.serverNow()
		local d = ctx.data()
		if d then
			showData(d, now)
		end
		local stock = if d then d.oilRefills or 0 else 0
		refill.Visible = dive.phase ~= "Camp" and not dive.refilled
		refill.Text = if stock > 0 then `Pour oil refill ({stock})` else "Buy oil refill"
		local pos = ctx.position()
		local row = if pos then math.max(0, Layout.rowAt(config.mine, pos.y)) else 0
		local oil = Lamp.oilAt(dive.meter, now)
		local fraction = if dive.capacity > 0 then math.clamp(oil / dive.capacity, 0, 1) else 0
		fill.Size = UDim2.fromScale(fraction, 1)

		if dive.phase == "Camp" then
			depth.Text = "At camp: step onto the mine to dive"
			oilText.Text = `Lamp full: {math.floor(dive.capacity)} oil`
			fill.BackgroundColor3 = OIL_OK
			marker.Visible = false
			climb.Visible = false
		elseif dive.phase == "Climbing" then
			local left = math.max(0, dive.climbEndsAt - now)
			depth.Text = `Climbing out from row {row}`
			oilText.Text = `Climbing… {math.ceil(left)}s to camp`
			local need = left * config.dive.climb.oilPerSecond
			fill.BackgroundColor3 = if oil < need then OIL_DRY else OIL_OK
			marker.Visible = false
			climb.Visible = false
		else
			local layer = config.mine.layers[Layout.layerOf(config.mine, math.max(1, row))]
			depth.Text = if row == 0 then `On the mine · {layer.name}` else `Row {row} · {layer.name}`
			local need = Lamp.climbOil(config.dive, row)
			-- The marker sits one second of climbing above the bare need, to
			-- cover the tap reaching the server.
			local mark = need + config.dive.climb.oilPerSecond
			local seconds = if dive.meter.rate > 0 then oil / dive.meter.rate else oil
			marker.Visible = true
			marker.Position = UDim2.fromScale(math.clamp(mark / math.max(dive.capacity, 1), 0, 1), 0.5)
			local climbSeconds = math.ceil(Lamp.climbSeconds(config.dive, row))
			if oil < need then
				fill.BackgroundColor3 = OIL_DRY
				oilText.Text = `Too little oil to climb out! {math.floor(seconds)}s left`
			elseif oil < mark * 1.3 then
				fill.BackgroundColor3 = OIL_LOW
				oilText.Text = `Climb now! {math.floor(seconds)}s of oil left`
			else
				fill.BackgroundColor3 = OIL_OK
				oilText.Text = `{math.floor(seconds)}s of oil · climbing out takes {climbSeconds}s`
			end
			climb.Text = `Climb out ({climbSeconds}s)`
			-- On the top face, walking off is quicker than the rope.
			climb.Visible = row > 0
		end

		local light = lampLight()
		if light then
			light.Brightness = 0.3 + 1.7 * (if dive.phase == "Camp" then 1 else fraction)
		end
	end)
end

return Hud
