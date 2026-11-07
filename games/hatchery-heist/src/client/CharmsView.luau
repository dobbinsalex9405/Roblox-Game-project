--!strict
-- The Charms window (side-menu "Charms"): the equipped slots across the top
-- (locked ones say which floor opens them), what they add up to, filters
-- and the show/hide switches, and the bag as a grid of cards stacked by
-- charm. Tapping a card or a slot opens its details: a turning 3D preview,
-- Equip or Unequip, Fuse 5 into 1 with the fee, and Show on my character.
-- "Fuse all" in the header fuses every set of five after a confirm.
--
-- Everything shown comes from the player's saved data through shared/Charms;
-- every button only asks the server, which checks again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Charms = require(Shared.Charms)
local Claw = require(Shared.Claw)
local Layout = require(Shared.Layout)

local CharmUi = require(script.Parent.CharmUi)
local CharmView = require(script.Parent.CharmView)
local Context = require(script.Parent.Context)
local Sfx = require(script.Parent.Sfx)

local CharmsView = {}

export type Menu = {
	add: (name: string, text: string, onClick: () -> ()) -> TextButton,
}

local MAX_W, MAX_H = 700, 480
local SLOT = 60
local GAP = 8
local CARD_MIN_W = 108
local CARD_H = 116

local opener: ((id: string?) -> ())? = nil

-- Opens the window (on a charm's details when `id` is given).
function CharmsView.open(id: string?)
	if opener then
		opener(id)
	end
end

function CharmsView.start(ctx: Context.Context, menu: Menu)
	local config = ctx.config.charms
	local player = Players.LocalPlayer
	local gui, window = CharmUi.window(player:WaitForChild("PlayerGui"), "CharmsWindow", 22)

	local title = CharmUi.text(window, "Title", "Charms", 30, CharmUi.GOLD)
	title.Position = UDim2.fromOffset(16, 6)
	title.Size = UDim2.fromOffset(120, 40)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local bag = CharmUi.text(window, "Bag", "", 16)
	bag.Position = UDim2.fromOffset(130, 14)
	bag.Size = UDim2.fromOffset(110, 24)
	bag.TextXAlignment = Enum.TextXAlignment.Left
	local close = CharmUi.close(window)
	local fuseAll = CharmUi.button(window, "FuseAll", "Fuse all", CharmUi.BLUE, 110)
	fuseAll.AnchorPoint = Vector2.new(1, 0)
	fuseAll.Position = UDim2.new(1, -62, 0, 8)

	-- The equipped slots.
	local slotRow = Instance.new("Frame")
	slotRow.Name = "Slots"
	slotRow.BackgroundTransparency = 1
	slotRow.Position = UDim2.fromOffset(16, 58)
	slotRow.Size = UDim2.new(1, -32, 0, SLOT)
	slotRow.Parent = window
	type Slot = { button: TextButton, icon: TextLabel, eye: TextLabel, label: TextLabel, stroke: UIStroke }
	local slots: { Slot } = {}
	for i = 1, Charms.maxSlots(config) do
		local b = Instance.new("TextButton")
		b.Name = `Slot{i}`
		b.Text = ""
		b.Size = UDim2.fromOffset(SLOT, SLOT)
		b.Position = UDim2.fromOffset((i - 1) * (SLOT + GAP), 0)
		b.BackgroundColor3 = CharmUi.TILE
		CharmUi.corner(b, 12)
		local s = CharmUi.stroke(b, CharmUi.GREY, 2)
		local icon = CharmUi.text(b, "Icon", "", 28)
		icon.Size = UDim2.new(1, 0, 1, -14)
		local label = CharmUi.text(b, "Label", "", 13)
		label.Size = UDim2.new(1, 0, 0, 16)
		label.Position = UDim2.new(0, 0, 1, -18)
		local eye = CharmUi.text(b, "Eye", "", 14)
		eye.AnchorPoint = Vector2.new(1, 0)
		eye.Position = UDim2.new(1, -2, 0, 1)
		eye.Size = UDim2.fromOffset(20, 18)
		b.Parent = slotRow
		slots[i] = { button = b, icon = icon, eye = eye, label = label, stroke = s }
	end

	local totals = CharmUi.text(window, "Totals", "", 16, Color3.fromRGB(215, 225, 245))
	totals.Position = UDim2.fromOffset(16, 122)
	totals.Size = UDim2.new(1, -32, 0, 22)
	totals.TextXAlignment = Enum.TextXAlignment.Left
	totals.TextTruncate = Enum.TextTruncate.AtEnd

	-- Filters and the show/hide switches, in one row that scrolls sideways
	-- on a narrow screen.
	local controls = Instance.new("ScrollingFrame")
	controls.Name = "Controls"
	controls.BackgroundTransparency = 1
	controls.BorderSizePixel = 0
	controls.Position = UDim2.fromOffset(16, 150)
	controls.Size = UDim2.new(1, -32, 0, CharmUi.BUTTON + 6)
	controls.ScrollingDirection = Enum.ScrollingDirection.X
	controls.AutomaticCanvasSize = Enum.AutomaticSize.X
	controls.CanvasSize = UDim2.new()
	controls.ScrollBarThickness = 4
	controls.Parent = window
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.Padding = UDim.new(0, GAP)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = controls
	local filter: string? = nil
	local filterButtons: { [string]: TextButton } = {}
	local function addFilter(key: string, label: string, order: number, width: number)
		local b = CharmUi.button(controls, `Filter{key}`, label, CharmUi.TILE, width)
		b.LayoutOrder = order
		filterButtons[key] = b
	end
	addFilter("All", "All", 1, 64)
	for i, kindId in Charms.activeKinds(config) do
		local kind = Charms.kind(config, kindId)
		addFilter(kindId, `{kind.icon} {kindId}`, 1 + i, 112)
	end
	local mine = CharmUi.button(controls, "ShowMine", "", CharmUi.GREEN, 150)
	mine.LayoutOrder = 50
	local others = CharmUi.button(controls, "ShowOthers", "", CharmUi.GREEN, 150)
	others.LayoutOrder = 51

	-- The bag.
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.fromOffset(16, 204)
	grid.Size = UDim2.new(1, -24, 1, -214)
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.ScrollBarThickness = 6
	grid.Parent = window
	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(GAP, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local empty = CharmUi.text(
		window,
		"Empty",
		"No charms yet. Play the Charm Claw in the farm hub, next to the Golden Egg Shop!",
		18,
		Color3.fromRGB(215, 225, 245)
	)
	empty.Position = UDim2.fromOffset(24, 220)
	empty.Size = UDim2.new(1, -48, 0, 60)
	empty.TextWrapped = true
	empty.Visible = false

	-- Details of one charm, over the slots and the grid.
	local detail = Instance.new("Frame")
	detail.Name = "Detail"
	detail.BackgroundColor3 = CharmUi.PANEL
	detail.BorderSizePixel = 0
	detail.Position = UDim2.fromOffset(10, 52)
	detail.Size = UDim2.new(1, -20, 1, -60)
	detail.Visible = false
	detail.ZIndex = 5
	detail.Parent = window
	local previewBox = Instance.new("Frame")
	previewBox.Name = "PreviewBox"
	previewBox.BackgroundColor3 = CharmUi.TILE
	previewBox.Position = UDim2.fromOffset(6, 6)
	previewBox.Size = UDim2.fromOffset(170, 170)
	CharmUi.corner(previewBox, 14)
	local previewStroke = CharmUi.stroke(previewBox, CharmUi.GREY, 3)
	previewBox.Parent = detail
	local showCharm = CharmUi.preview(previewBox, config)
	local info = Instance.new("Frame")
	info.Name = "Info"
	info.BackgroundTransparency = 1
	info.Position = UDim2.fromOffset(192, 0)
	info.Size = UDim2.new(1, -192, 1, 0)
	info.Parent = detail
	local dName = CharmUi.text(info, "CharmName", "", 26, CharmUi.GOLD)
	dName.Size = UDim2.new(1, -110, 0, 32)
	dName.TextXAlignment = Enum.TextXAlignment.Left
	local dTier = CharmUi.text(info, "Tier", "", 18)
	dTier.Position = UDim2.fromOffset(0, 32)
	dTier.Size = UDim2.new(1, 0, 0, 22)
	dTier.TextXAlignment = Enum.TextXAlignment.Left
	local dEffect = CharmUi.text(info, "Effect", "", 17)
	dEffect.Position = UDim2.fromOffset(0, 56)
	dEffect.Size = UDim2.new(1, 0, 0, 22)
	dEffect.TextXAlignment = Enum.TextXAlignment.Left
	local dOwned = CharmUi.text(info, "Owned", "", 15, Color3.fromRGB(205, 210, 230))
	dOwned.Position = UDim2.fromOffset(0, 80)
	dOwned.Size = UDim2.new(1, 0, 0, 20)
	dOwned.TextXAlignment = Enum.TextXAlignment.Left
	local back = CharmUi.button(info, "Back", "Back", CharmUi.GREY, 90)
	back.AnchorPoint = Vector2.new(1, 0)
	back.Position = UDim2.new(1, -6, 0, 0)
	local actions = Instance.new("Frame")
	actions.Name = "Actions"
	actions.BackgroundTransparency = 1
	actions.Position = UDim2.fromOffset(0, 108)
	actions.Size = UDim2.new(1, -6, 0, 3 * CharmUi.BUTTON + 2 * GAP)
	actions.Parent = info
	local actionList = Instance.new("UIListLayout")
	actionList.Padding = UDim.new(0, GAP)
	actionList.SortOrder = Enum.SortOrder.LayoutOrder
	actionList.Parent = actions
	local equip = CharmUi.button(actions, "Equip", "Equip", CharmUi.GREEN, 220)
	equip.LayoutOrder = 1
	local fuse = CharmUi.button(actions, "Fuse", "Fuse", CharmUi.BLUE, 220)
	fuse.LayoutOrder = 2
	local wear = CharmUi.button(actions, "ShowOnMe", "", CharmUi.GREEN, 220)
	wear.LayoutOrder = 3

	-- The Fuse all confirm.
	local confirm = Instance.new("Frame")
	confirm.Name = "Confirm"
	confirm.BackgroundColor3 = CharmUi.PANEL
	confirm.Position = UDim2.fromOffset(10, 52)
	confirm.Size = UDim2.new(1, -20, 1, -60)
	confirm.Visible = false
	confirm.ZIndex = 6
	confirm.Parent = window
	local plan = CharmUi.text(confirm, "Plan", "", 17)
	plan.Position = UDim2.fromOffset(10, 6)
	plan.Size = UDim2.new(1, -20, 1, -64)
	plan.TextWrapped = true
	plan.TextYAlignment = Enum.TextYAlignment.Top
	plan.TextXAlignment = Enum.TextXAlignment.Left
	local yes = CharmUi.button(confirm, "Yes", "Fuse them", CharmUi.GREEN, 150)
	yes.AnchorPoint = Vector2.new(0, 1)
	yes.Position = UDim2.new(0, 10, 1, -6)
	local no = CharmUi.button(confirm, "No", "Cancel", CharmUi.GREY, 120)
	no.AnchorPoint = Vector2.new(0, 1)
	no.Position = UDim2.new(0, 170, 1, -6)

	local selected: string? = nil
	local cards: { [string]: CharmUi.Card } = {}
	local cardKey = ""

	local function data(): { [string]: any }?
		return ctx.data()
	end

	local function fee(d: { [string]: any }): number
		return Claw.fuseFee(d.incomePeak or 0, config)
	end

	local function layoutGrid()
		local width = grid.AbsoluteSize.X
		if width <= 0 then
			width = MAX_W - 24
		end
		local inner = width - 10 -- the scroll bar
		local cols = math.clamp(math.floor((inner + GAP) / (CARD_MIN_W + GAP)), 3, 6)
		local cellW = math.floor((inner - (cols - 1) * GAP) / cols)
		layout.CellSize = UDim2.fromOffset(cellW, CARD_H)
	end

	local refresh: () -> ()

	local function select(id: string?)
		selected = id
		confirm.Visible = false
		detail.Visible = id ~= nil
		showCharm(id)
		refresh()
	end

	local function fit()
		local size = CharmUi.fit(window, MAX_W, MAX_H)
		-- The preview shrinks on a short screen so the buttons still fit.
		local room = math.max(110, math.min(170, size.Y - 60 - 12))
		previewBox.Size = UDim2.fromOffset(room, room)
		info.Position = UDim2.fromOffset(room + 20, 0)
		info.Size = UDim2.new(1, -(room + 20), 1, 0)
		layoutGrid()
	end

	refresh = function()
		local d = data()
		if d == nil then
			return
		end
		local count = Charms.bagCount(d)
		bag.Text = `{count} / {config.bagSlots}`
		bag.TextColor3 = if count >= config.bagWarnAt then CharmUi.AMBER else Color3.new(1, 1, 1)
		local open = Charms.slots(d, config)
		local equipped = Charms.equipped(d, config)
		-- Equipped charms fill the slots in kind order.
		local order = {}
		for _, kindId in Charms.activeKinds(config) do
			if equipped[kindId] then
				table.insert(order, equipped[kindId])
			end
		end
		for i, slot in slots do
			local entry = order[i]
			local locked = i > open
			slot.button.AutoButtonColor = entry ~= nil
			if entry then
				local def = entry.def
				local color = Layout.rarityColor(def.tier)
				local kind = Charms.kind(config, def.kind)
				slot.icon.Text = if kind then kind.icon else "?"
				slot.label.Text = def.tier
				slot.label.TextColor3 = color
				slot.stroke.Color = color
				slot.stroke.Thickness = 3
				slot.button.BackgroundColor3 = CharmUi.TILE:Lerp(color, 0.2)
				slot.eye.Text = if Charms.isShown(d, def.kind) then "" else "off"
				slot.eye.TextColor3 = CharmUi.AMBER
				slot.button:SetAttribute("CharmId", def.id)
			else
				slot.icon.Text = if locked then "" else "+"
				slot.icon.TextColor3 = CharmUi.GREY
				local floor = Charms.slotFloor(config, i)
				slot.label.Text = if locked and floor then `Floor {floor}` else "Empty"
				slot.label.TextColor3 = CharmUi.GREY
				slot.stroke.Color = CharmUi.GREY
				slot.stroke.Thickness = 2
				slot.button.BackgroundColor3 = if locked then CharmUi.SHADOW else CharmUi.TILE
				slot.eye.Text = ""
				slot.button:SetAttribute("CharmId", nil)
			end
			if entry then
				slot.icon.TextColor3 = Color3.new(1, 1, 1)
			end
		end
		local stats = Charms.stats(d, config)
		local line = Charms.totalsText(stats)
		totals.Text = if line == ""
			then "Nothing equipped yet: tap a charm, then Equip."
			else `Equipped: {line}`

		for key, b in filterButtons do
			local on = (filter == nil and key == "All") or filter == key
			b.BackgroundColor3 = if on then CharmUi.GOLD else CharmUi.TILE
			b.TextColor3 = if on then CharmUi.SHADOW else Color3.new(1, 1, 1)
		end
		local shownAll = d.charmsShown ~= false
		mine.Text = if shownAll then "My charms: On" else "My charms: Off"
		mine.BackgroundColor3 = if shownAll then CharmUi.GREEN else CharmUi.GREY
		local seeOthers = CharmView.showOthers()
		others.Text = if seeOthers then "Others': On" else "Others': Off"
		others.BackgroundColor3 = if seeOthers then CharmUi.GREEN else CharmUi.GREY

		-- The grid, rebuilt only when what it shows changes.
		local stacks = Charms.stacks(d, config, filter)
		local parts = { filter or "All" }
		for _, s in stacks do
			table.insert(parts, `{s.def.id}:{s.count}:{s.equipped}`)
		end
		local key = table.concat(parts, ",")
		if key ~= cardKey then
			cardKey = key
			for _, card in cards do
				card.button:Destroy()
			end
			table.clear(cards)
			for i, s in stacks do
				local card = CharmUi.card(grid, config, s.def, i)
				card.count.Text = if s.count > 1 then `x{s.count}` else ""
				card.ribbon.Visible = s.equipped
				card.button.Activated:Connect(function()
					Sfx.play("click")
					select(s.def.id)
				end)
				cards[s.def.id] = card
			end
		end
		empty.Visible = #stacks == 0
		empty.Text = if count == 0
			then "No charms yet. Play the Charm Claw in the farm hub, next to the Golden Egg Shop!"
			else "No charms of this kind yet."

		-- Fuse all is only lit when it would do something.
		local steps = Charms.fuseAllPlan(d, config, fee(d), d.coins or 0)
		fuseAll.BackgroundColor3 = if #steps > 0 then CharmUi.BLUE else CharmUi.GREY
		fuseAll.AutoButtonColor = #steps > 0

		if selected then
			local def = Charms.def(config, selected)
			if def == nil then
				return
			end
			local all, free = Charms.counts(d)
			local color = Layout.rarityColor(def.tier)
			previewStroke.Color = color
			dName.Text = def.name
			dTier.Text = `{def.tier} {def.kind}`
			dTier.TextColor3 = color
			dEffect.Text = Charms.effectText(config, def)
			local have = all[def.id] or 0
			local isOn = equipped[def.kind] ~= nil and equipped[def.kind].def.id == def.id
			dOwned.Text = if have == 0
				then "You don't have this one."
				elseif isOn then `You have {have}: one is equipped.`
				else `You have {have}.`
			equip.Text = if isOn then "Unequip" else "Equip"
			equip.BackgroundColor3 = if isOn
				then CharmUi.GREY
				elseif have > 0 then CharmUi.GREEN
				else CharmUi.SHADOW
			local nextDef = Charms.nextTier(config, def.id)
			local need = config.fuseCount
			if nextDef == nil then
				fuse.Text = "Godly: can't fuse higher"
				fuse.BackgroundColor3 = CharmUi.SHADOW
			else
				local f = fee(d)
				fuse.Text = `Fuse {need} into 1 {nextDef.tier} ({Layout.shortNumber(f)} coins)`
				local can = (free[def.id] or 0) >= need and (d.coins or 0) >= f
				fuse.BackgroundColor3 = if can then CharmUi.BLUE else CharmUi.SHADOW
			end
			wear.Visible = isOn
			local shown = Charms.isShown(d, def.kind)
			wear.Text = if shown then "On my character: Shown" else "On my character: Hidden"
			wear.BackgroundColor3 = if shown then CharmUi.GREEN else CharmUi.GREY
		end
	end

	-- Buttons.
	-- A filled slot opens its charm; an empty one does nothing (the hint
	-- under the slots says how to fill it).
	for _, slot in slots do
		slot.button.Activated:Connect(function()
			local id = slot.button:GetAttribute("CharmId")
			if type(id) == "string" then
				Sfx.play("click")
				select(id)
			end
		end)
	end
	for key, b in filterButtons do
		b.Activated:Connect(function()
			Sfx.play("click")
			filter = if key == "All" then nil else key
			refresh()
		end)
	end
	mine.Activated:Connect(function()
		local d = data()
		if d then
			Sfx.play("click")
			ctx.fire(ctx.remotes["HH:CharmShown"], "all", d.charmsShown == false)
		end
	end)
	others.Activated:Connect(function()
		Sfx.play("click")
		CharmView.setShowOthers(not CharmView.showOthers())
		refresh()
	end)
	equip.Activated:Connect(function()
		local d = data()
		local def = selected and Charms.def(config, selected)
		if d == nil or def == nil then
			return
		end
		Sfx.play("click")
		local equippedNow = Charms.equipped(d, config)[def.kind]
		if equippedNow and equippedNow.def.id == def.id then
			ctx.fire(ctx.remotes["HH:CharmUnequip"], def.kind)
		else
			ctx.fire(ctx.remotes["HH:CharmEquip"], def.id)
		end
	end)
	fuse.Activated:Connect(function()
		local def = selected and Charms.def(config, selected)
		if def and Charms.nextTier(config, def.id) then
			Sfx.play("click")
			ctx.fire(ctx.remotes["HH:CharmFuse"], def.id, 1)
		end
	end)
	wear.Activated:Connect(function()
		local d = data()
		local def = selected and Charms.def(config, selected)
		if d and def then
			Sfx.play("click")
			ctx.fire(ctx.remotes["HH:CharmShown"], def.kind, not Charms.isShown(d, def.kind))
		end
	end)
	back.Activated:Connect(function()
		Sfx.play("click")
		select(nil)
	end)
	fuseAll.Activated:Connect(function()
		local d = data()
		if d == nil then
			return
		end
		local steps, spent = Charms.fuseAllPlan(d, config, fee(d), d.coins or 0)
		Sfx.play("click")
		if #steps == 0 then
			select(nil)
			confirm.Visible = true
			plan.Text = `Nothing to fuse yet: you need {config.fuseCount} of the same charm, not equipped.`
			yes.Visible = false
			return
		end
		local lines = { "Fuse all will make:" }
		for _, step in steps do
			local to = Charms.def(config, step.to)
			local from = Charms.def(config, step.from)
			if to and from then
				table.insert(
					lines,
					`{step.times} {to.name} (from {step.times * config.fuseCount} {from.name})`
				)
			end
		end
		table.insert(lines, `Fee: {Layout.shortNumber(spent)} coins.`)
		select(nil)
		plan.Text = table.concat(lines, "\n")
		yes.Visible = true
		confirm.Visible = true
	end)
	yes.Activated:Connect(function()
		Sfx.play("click")
		ctx.fire(ctx.remotes["HH:CharmFuseAll"])
		confirm.Visible = false
	end)
	no.Activated:Connect(function()
		Sfx.play("click")
		confirm.Visible = false
	end)
	close.Activated:Connect(function()
		Sfx.play("click")
		gui.Enabled = false
		select(nil)
	end)

	local function toggle(id: string?)
		if id == nil and gui.Enabled then
			gui.Enabled = false
			select(nil)
			return
		end
		gui.Enabled = true
		fit()
		select(id)
	end
	opener = function(id: string?)
		if gui.Enabled and id == nil then
			return
		end
		toggle(id)
	end
	menu.add("Charms", "🍀 Charms", function()
		Sfx.play("click")
		toggle(nil)
	end)

	window:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutGrid)
	-- The screen's size can arrive (or change, turning a phone) after the
	-- window opened.
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if gui.Enabled then
			fit()
		end
	end)
	ctx.onData(function()
		if gui.Enabled then
			refresh()
		end
	end)
	task.spawn(function()
		while true do
			if gui.Enabled then
				fit()
				refresh()
			end
			task.wait(1)
		end
	end)
end

return CharmsView
