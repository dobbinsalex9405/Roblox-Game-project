--!strict
-- The Merge Station window (shared/Merge.luau): merges running, with a
-- countdown, Finish now (25 Robux) and Cancel; a second merge slot to
-- unlock; and every creature the player could merge, with how many copies
-- they have and what it costs. Opened from the Merge Station in the base or
-- the Pets window's Merge button.
--
-- The client only asks; the server checks every merge (Actions).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Layout)
local Merge = require(Shared.Merge)
local ShopRemotes = require(ReplicatedStorage.Core.ShopRemotes)

local Context = require(script.Parent.Context)
local Sfx = require(script.Parent.Sfx)

local MergeView = {}

local PANEL = Color3.fromRGB(28, 30, 48)
local ROW = Color3.fromRGB(44, 47, 72)
local GOLD = Color3.fromRGB(255, 210, 63)
local GREEN = Color3.fromRGB(80, 200, 100)
local BLUE = Color3.fromRGB(70, 150, 230)
local RED = Color3.fromRGB(215, 70, 70)
local GREY = Color3.fromRGB(110, 110, 125)
local SOFT = Color3.fromRGB(210, 210, 225)
local SHADOW = Color3.fromRGB(16, 16, 26)
local FONT = Enum.Font.FredokaOne

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function text(parent: Instance, name: string, value: string, size: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextSize = size
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Text = value
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	local s = Instance.new("UIStroke")
	s.Thickness = 1.5
	s.Color = SHADOW
	s.Parent = l
	l.Parent = parent
	return l
end

local function button(parent: Instance, name: string, label: string, color: Color3, width: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.fromOffset(width, 34)
	b.BackgroundColor3 = color
	b.Font = FONT
	b.TextSize = 15
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = label
	corner(b, 8)
	stroke(b, SHADOW, 1.5)
	b.Parent = parent
	return b
end

local function row(list: Instance, order: number, height: number, color: Color3?): Frame
	local f = Instance.new("Frame")
	f.Name = `Row{order}`
	f.LayoutOrder = order
	f.Size = UDim2.new(1, 0, 0, height)
	f.BackgroundColor3 = color or ROW
	corner(f, 10)
	f.Parent = list
	return f
end

-- A strip of buttons on the right of a row.
local function buttons(r: Frame, width: number): Frame
	local f = Instance.new("Frame")
	f.Name = "Buttons"
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(1, 0.5)
	f.Position = UDim2.new(1, -8, 0.5, 0)
	f.Size = UDim2.fromOffset(width, 34)
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.HorizontalAlignment = Enum.HorizontalAlignment.Right
	l.Padding = UDim.new(0, 6)
	l.Parent = f
	f.Parent = r
	return f
end

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function heading(list: Instance, order: number, value: string)
	local h = text(list, `Heading{order}`, value, 18, GOLD)
	h.LayoutOrder = order
	h.Size = UDim2.new(1, 0, 0, 26)
end

-- Opens the window; set by start.
local openWindow: () -> () = function() end

function MergeView.open()
	openWindow()
end

function MergeView.start(ctx: Context.Context)
	local player = Players.LocalPlayer
	local creatures = ctx.config.creatures
	local economy = ctx.config.economy
	local copies = economy.merge.copies

	local gui = Instance.new("ScreenGui")
	gui.Name = "MergeMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 24
	gui.Enabled = false
	local frame = Instance.new("Frame")
	frame.Name = "Window"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.BackgroundColor3 = PANEL
	corner(frame, 16)
	stroke(frame, GOLD, 3)
	frame.Parent = gui
	local title = text(frame, "Title", "⭐ Merge Station", 28, GOLD)
	title.Position = UDim2.fromOffset(16, 8)
	title.Size = UDim2.new(1, -80, 0, 36)
	local close = button(frame, "Close", "X", RED, 44)
	close.Size = UDim2.fromOffset(44, 40)
	close.TextSize = 24
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Activated:Connect(function()
		Sfx.play("click")
		gui.Enabled = false
	end)
	local info = text(
		frame,
		"Info",
		`{copies} of the same creature make 1 with a star more. {Merge.stars(2, true)} earns x{creatures.stars[2]}, {Merge.stars(
			3,
			true
		)} earns x{creatures.stars[3]}. Godlies don't merge.`,
		14,
		SOFT
	)
	info.Position = UDim2.fromOffset(16, 52)
	info.Size = UDim2.new(1, -32, 0, 40)
	info.TextWrapped = true
	info.TextYAlignment = Enum.TextYAlignment.Top
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(10, 98)
	list.Size = UDim2.new(1, -20, 1, -106)
	list.CanvasSize = UDim2.fromScale(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = list
	list.Parent = frame
	gui.Parent = player:WaitForChild("PlayerGui")

	local function fit()
		local cam = Workspace.CurrentCamera
		local screen = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		frame.Size = UDim2.fromOffset(math.min(600, screen.X - 24), math.min(520, screen.Y - 40))
	end

	-- Countdown labels of running merges, refreshed every second.
	local timers: { { label: TextLabel, bar: Frame, job: any } } = {}

	local function draw()
		local d = ctx.data()
		if d == nil then
			return
		end
		for _, child in list:GetChildren() do
			if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
				child:Destroy()
			end
		end
		table.clear(timers)
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end

		-- Running merges and free slots.
		local jobs = d.merges or {}
		local slots = Merge.slotCount(d, economy)
		heading(list, nextOrder(), `Merging ({#jobs}/{slots})`)
		if (d.mergeRushes or 0) > 0 then
			local saved = text(
				list,
				"Saved",
				`{d.mergeRushes} instant finish saved: your next merge finishes at once.`,
				14,
				GREEN
			)
			saved.LayoutOrder = nextOrder()
			saved.Size = UDim2.new(1, 0, 0, 20)
		end
		for _, job in jobs do
			local species = creatures.species[job.speciesId]
			local color = if species then Layout.rarityColor(species.rarity) else GOLD
			local r = row(list, nextOrder(), 64)
			local name = text(
				r,
				"Name",
				`{Layout.displayName(job.speciesId)}  {Merge.stars(job.star, true)}`,
				17,
				color
			)
			name.Position = UDim2.fromOffset(12, 6)
			name.Size = UDim2.new(1, -250, 0, 22)
			local left = text(r, "Time", "", 14, SOFT)
			left.Position = UDim2.fromOffset(12, 30)
			left.Size = UDim2.new(1, -250, 0, 18)
			local track = Instance.new("Frame")
			track.Name = "Track"
			track.Position = UDim2.fromOffset(12, 50)
			track.Size = UDim2.new(1, -262, 0, 6)
			track.BackgroundColor3 = SHADOW
			corner(track, 3)
			track.Parent = r
			local bar = Instance.new("Frame")
			bar.Name = "Bar"
			bar.BackgroundColor3 = GOLD
			corner(bar, 3)
			bar.Parent = track
			table.insert(timers, { label = left, bar = bar, job = job })
			local b = buttons(r, 236)
			local finish = button(b, "Finish", "Finish now R$25", GREEN, 140)
			finish.Activated:Connect(function()
				Sfx.play("click")
				ctx.fire(ShopRemotes["Shop:Buy"], "product", "FinishMerge", "Merge")
			end)
			local cancel = button(b, "Cancel", "Cancel", GREY, 84)
			cancel.Activated:Connect(function()
				Sfx.play("click")
				ctx.fire(ctx.remotes["HH:CancelMerge"], job.id)
			end)
		end
		for _ = #jobs + 1, slots do
			local r = row(list, nextOrder(), 40, ROW:Lerp(SHADOW, 0.4))
			local empty = text(r, "Empty", "Empty merge slot: pick a creature below.", 14, SOFT)
			empty.Position = UDim2.fromOffset(12, 0)
			empty.Size = UDim2.new(1, -24, 1, 0)
		end
		local slotCost = Merge.nextSlotCost(d, economy)
		if slotCost then
			local r = row(list, nextOrder(), 48, ROW:Lerp(SHADOW, 0.4))
			local label = text(r, "Label", "Run two merges at once", 15)
			label.Position = UDim2.fromOffset(12, 0)
			label.Size = UDim2.new(1, -200, 1, 0)
			local b = buttons(r, 180)
			local buy = button(
				b,
				"BuySlot",
				`Unlock {Layout.shortNumber(slotCost)} coins`,
				if d.coins >= slotCost then GREEN else GREY,
				180
			)
			buy.Activated:Connect(function()
				Sfx.play("click")
				ctx.fire(ctx.remotes["HH:BuyMergeSlot"])
			end)
		end

		-- What could merge.
		heading(list, nextOrder(), "Your creatures")
		local groups = Merge.groups(d, { creatures = creatures, economy = economy })
		if #groups == 0 then
			local none = text(
				list,
				"None",
				"Hatch creatures to merge them. Three of the same make one with a star more.",
				14,
				SOFT
			)
			none.LayoutOrder = nextOrder()
			none.Size = UDim2.new(1, 0, 0, 40)
			none.TextWrapped = true
		end
		local busy = #jobs >= slots
		for _, g in groups do
			local species = creatures.species[g.speciesId]
			local color = Layout.rarityColor(species.rarity)
			local target = g.star + 1
			local cost =
				Merge.cost(g.speciesId, g.mutation, target, { creatures = creatures, economy = economy })
			local seconds = Merge.seconds(g.speciesId, target, { creatures = creatures, economy = economy })
			local ready = #g.uids >= copies
			local r = row(list, nextOrder(), 56)
			local swatch = Instance.new("Frame")
			swatch.Name = "Swatch"
			swatch.Position = UDim2.fromOffset(8, 8)
			swatch.Size = UDim2.fromOffset(10, 40)
			swatch.BackgroundColor3 = color
			corner(swatch, 4)
			swatch.Parent = r
			local mutation = if g.mutation ~= "None" then `{g.mutation} ` else ""
			local name = text(
				r,
				"Name",
				`{mutation}{Layout.displayName(g.speciesId)}  {Merge.stars(g.star, true)}  ({math.min(
					#g.uids,
					copies
				)}/{copies})`,
				16,
				color
			)
			name.Position = UDim2.fromOffset(26, 4)
			name.Size = UDim2.new(1, -230, 0, 22)
			local earns = species.coinsPerSecond
				* (creatures.mutations[g.mutation] or 1)
				* (creatures.stars[target] or 1)
			local detail =
				`{Merge.stars(target, true)} earns {Layout.shortNumber(earns)}/s  ·  {clock(seconds)}`
			if g.busy > 0 and not ready then
				detail ..= `  ·  {g.busy} riding or guarding`
			end
			local sub = text(r, "Detail", detail, 13, SOFT)
			sub.Position = UDim2.fromOffset(26, 28)
			sub.Size = UDim2.new(1, -230, 0, 20)
			local b = buttons(r, 200)
			local can = ready and not busy and d.coins >= cost
			local go = button(
				b,
				"Merge",
				if ready then `Merge {Layout.shortNumber(cost)}` else `Need {copies - #g.uids} more`,
				if can then GREEN elseif ready then GREY:Lerp(BLUE, 0.3) else GREY,
				150
			)
			go.Activated:Connect(function()
				Sfx.play("click")
				if ready then
					ctx.fire(ctx.remotes["HH:Merge"], g.speciesId, g.mutation, g.star)
				end
			end)
		end
	end

	local function tickTimers()
		local now = ctx.serverNow()
		for _, t in timers do
			local total = math.max(1, t.job.readyAt - t.job.startedAt)
			local left = t.job.readyAt - now
			t.label.Text = if left > 0 then `Ready in {clock(left)}` else "Done! Arriving…"
			t.bar.Size = UDim2.fromScale(math.clamp(1 - left / total, 0, 1), 1)
		end
	end

	openWindow = function()
		fit()
		draw()
		tickTimers()
		gui.Enabled = true
	end

	-- Redraw when what the window shows changes.
	local last = ""
	ctx.onData(function(d: { [string]: any })
		if not gui.Enabled then
			return
		end
		local parts =
			{ tostring(d.mergeSlotsBought or 0), tostring(d.mergeRushes or 0), tostring(d.coins // 100) }
		for _, job in d.merges or {} do
			table.insert(parts, `{job.id}:{job.readyAt}`)
		end
		for _, c in d.creatures do
			table.insert(parts, `{c.uid}:{c.star or 1}`)
		end
		local key = table.concat(parts, ",")
		if key ~= last then
			last = key
			draw()
		end
	end)

	-- The station in the player's own base opens the window.
	task.spawn(function()
		while true do
			local own = ctx.plot()
			local station = own and own:FindFirstChild("MergeStation")
			if station and station:FindFirstChild("Open") == nil then
				local p = Instance.new("ProximityPrompt")
				p.Name = "Open"
				p.ActionText = "Merge"
				p.ObjectText = "Merge Station"
				p.MaxActivationDistance = 10
				p.RequiresLineOfSight = false
				p.Triggered:Connect(function()
					Sfx.play("click")
					openWindow()
				end)
				p.Parent = station
			end
			if gui.Enabled then
				tickTimers()
			end
			task.wait(1)
		end
	end)
end

return MergeView
