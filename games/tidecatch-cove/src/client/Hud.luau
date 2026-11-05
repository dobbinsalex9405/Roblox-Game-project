--!strict
-- The minimal M2 interface, phone first: coins, rod and journal progress, a
-- bait picker, short notices, the welcome-back message, the catch card (keep
-- or sell), the bucket, and the odds card shown while standing at a dock.
-- The Pools panel is PoolsView.
-- Built from code; art comes after the gate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Catch = require(Shared.Catch)
local Cove = require(Shared.Cove)
local Creatures = require(Shared.Creatures)
local Layout = require(Shared.Layout)

local Context = require(script.Parent.Context)
local OddsView = require(script.Parent.OddsView)
local Ui = require(script.Parent.Ui)

local Hud = {}

export type Api = {
	notice: (text: string, seconds: number?) -> (),
	status: (text: string?) -> (), -- the fishing line's state, nil to hide
	showCatch: (speciesId: string, kg: number, uid: string, soldFor: number, isNew: boolean) -> (),
	showOdds: (spotId: string) -> (),
	hideOdds: () -> (),
	toggleBucket: () -> (),
	hideBucket: () -> (),
	onBucketOpened: (fn: () -> ()) -> (), -- so other panels in the middle close
}

function Hud.start(ctx: Context.Context): Api
	local config = ctx.config
	local species = config.species.species
	local gui = Instance.new("ScreenGui")
	gui.Name = "TidecatchHud"
	gui.ResetOnSpawn = false
	gui.Parent = ctx.player:WaitForChild("PlayerGui")

	-- Top bar: coins, rod, journal.
	local bar = Ui.panel(gui, "Bar", UDim2.fromOffset(360, 60), UDim2.new(0.5, 0, 0, 8), Vector2.new(0.5, 0))
	local coins = Ui.label(bar, "Coins", UDim2.new(0.5, -8, 0.58, 0), UDim2.fromOffset(8, 2))
	coins.TextXAlignment = Enum.TextXAlignment.Left
	coins.TextColor3 = Ui.GOLD
	local journal = Ui.label(bar, "Journal", UDim2.new(0.5, -8, 0.58, 0), UDim2.new(0.5, 0, 0, 2))
	journal.TextXAlignment = Enum.TextXAlignment.Right
	local rod = Ui.label(bar, "Rod", UDim2.new(1, -16, 0.36, 0), UDim2.new(0, 8, 0.6, 0))
	rod.Font = Enum.Font.Gotham
	rod.TextColor3 = Ui.MUTED

	-- Notices: one line at a time under the bar.
	local notice =
		Ui.panel(gui, "Notice", UDim2.fromOffset(380, 36), UDim2.new(0.5, 0, 0, 76), Vector2.new(0.5, 0))
	notice.Visible = false
	local noticeText = Ui.label(notice, "Text", UDim2.new(1, -16, 1, -8), UDim2.fromOffset(8, 4))
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

	-- The fishing line's state ("Waiting for a bite...").
	local status =
		Ui.panel(gui, "Status", UDim2.fromOffset(260, 34), UDim2.new(0.5, 0, 1, -230), Vector2.new(0.5, 1))
	status.Visible = false
	local statusText = Ui.label(status, "Text", UDim2.new(1, -16, 1, -8), UDim2.fromOffset(8, 4))

	-- Bait picker: one button per bait plus "No bait". Phones keep the
	-- thumbstick bottom left and jump bottom right, so the picker sits high on
	-- the left, and the bucket button and odds card on the top right.
	local picker = Ui.panel(gui, "Bait", UDim2.fromOffset(150, 0), UDim2.fromOffset(12, 60), Vector2.zero)
	picker.AutomaticSize = Enum.AutomaticSize.Y
	Ui.list(picker, 6)
	local pickerTitle = Ui.label(picker, "Title", UDim2.new(1, 0, 0, 18))
	pickerTitle.Text = "Bait"
	pickerTitle.LayoutOrder = 0
	local baitButtons: { [string]: TextButton } = {}
	local robuxBait: { [string]: boolean } = {}
	local baitOrder = { Catch.NO_BAIT }
	for _, bait in config.fishing.bait do
		table.insert(baitOrder, bait.id)
		robuxBait[bait.id] = bait.robux
	end
	for i, baitId in baitOrder do
		local b = Ui.button(picker, baitId, "", UDim2.new(1, 0, 0, 34))
		b.LayoutOrder = i
		b.Activated:Connect(function()
			local d = ctx.data()
			local have = if baitId == Catch.NO_BAIT then 1 elseif d then d.bait[baitId] or 0 else 0
			if have > 0 and not OddsView.blocked(baitId) then
				ctx.setBait(baitId)
			end
		end)
		baitButtons[baitId] = b
	end
	local function renderPicker()
		local d = ctx.data()
		local selected = ctx.bait()
		-- A bait that ran out falls back to no bait.
		if selected ~= Catch.NO_BAIT and d and (d.bait[selected] or 0) <= 0 then
			ctx.setBait(Catch.NO_BAIT)
			selected = Catch.NO_BAIT
		end
		for baitId, b in baitButtons do
			local have = if baitId == Catch.NO_BAIT then nil elseif d then d.bait[baitId] or 0 else 0
			local name = if baitId == Catch.NO_BAIT then "No bait" else Layout.displayName(baitId)
			b.Text = if have then `{name} x{have}` else name
			local usable = (have == nil or have > 0) and not OddsView.blocked(baitId)
			-- Robux-only bait shows up once the player has some.
			b.Visible = not robuxBait[baitId] or (have or 0) > 0
			b.Active = usable
			b.AutoButtonColor = usable
			b.BackgroundColor3 = if baitId == selected
				then Ui.GOOD
				elseif usable then Ui.BUTTON
				else Color3.fromRGB(70, 75, 85)
		end
	end
	ctx.onBait(function()
		renderPicker()
	end)

	-- Odds card while standing at a dock.
	local card =
		Ui.panel(gui, "OddsCard", UDim2.fromOffset(270, 0), UDim2.new(1, -12, 0, 68), Vector2.new(1, 0))
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.Visible = false
	Ui.list(card, 8)
	local cardSpot: string? = nil
	local function renderCard()
		if cardSpot then
			OddsView.render(card, cardSpot, ctx.bait())
		end
	end
	OddsView.onChanged(renderCard)
	ctx.onBait(function()
		renderCard()
	end)

	-- Catch card: what came up, with Keep and Sell.
	local catchCard = Ui.panel(
		gui,
		"CatchCard",
		UDim2.fromOffset(300, 150),
		UDim2.fromScale(0.5, 0.42),
		Vector2.new(0.5, 0.5)
	)
	catchCard.Visible = false
	local catchTitle = Ui.label(catchCard, "Title", UDim2.new(1, -16, 0, 34), UDim2.fromOffset(8, 8))
	local catchInfo = Ui.label(catchCard, "Info", UDim2.new(1, -16, 0, 24), UDim2.fromOffset(8, 46))
	catchInfo.Font = Enum.Font.Gotham
	local keep = Ui.button(catchCard, "Keep", "Keep", UDim2.new(0.5, -12, 0, 54), Ui.GOOD)
	keep.Position = UDim2.new(0, 8, 1, -62)
	local sell = Ui.button(catchCard, "Sell", "Sell", UDim2.new(0.5, -12, 0, 54), Ui.WARN)
	sell.Position = UDim2.new(0.5, 4, 1, -62)
	local catchUid: string? = nil
	local catchId = 0
	local function hideCatch()
		catchCard.Visible = false
		catchUid = nil
	end
	keep.Activated:Connect(hideCatch)
	sell.Activated:Connect(function()
		if catchUid then
			ctx.fire(ctx.remotes["TC:SellCatch"], catchUid)
		end
		hideCatch()
	end)

	-- Bucket: everything caught and not yet placed or sold.
	local bucket =
		Ui.panel(gui, "Bucket", UDim2.new(0, 330, 0.9, 0), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	local bucketFit = Instance.new("UISizeConstraint") -- never taller than the screen
	bucketFit.MaxSize = Vector2.new(330, 320)
	bucketFit.Parent = bucket
	bucket.Visible = false
	local bucketTitle = Ui.label(bucket, "Title", UDim2.new(1, -60, 0, 30), UDim2.fromOffset(10, 6))
	bucketTitle.TextXAlignment = Enum.TextXAlignment.Left
	local close = Ui.button(bucket, "Close", "X", UDim2.fromOffset(40, 34), Ui.WARN)
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
	scroll.Parent = bucket
	local sellAll = Ui.button(bucket, "SellAll", "Sell all", UDim2.new(1, -16, 0, 54), Ui.WARN)
	sellAll.Position = UDim2.new(0, 8, 1, -62)
	sellAll.Activated:Connect(function()
		ctx.fire(ctx.remotes["TC:SellBucket"])
	end)
	close.Activated:Connect(function()
		bucket.Visible = false
	end)

	local bucketButton = Ui.button(gui, "BucketButton", "Bucket", UDim2.fromOffset(130, 52))
	bucketButton.AnchorPoint = Vector2.new(1, 0)
	bucketButton.Position = UDim2.new(1, -12, 0, 8)

	local function renderBucket()
		local d = ctx.data()
		if d == nil then
			return
		end
		local perks = ctx.perks()
		bucketButton.Text = `Bucket {#d.bucket}/{config.fishing.bucketSlots}`
		if not bucket.Visible then
			return
		end
		bucketTitle.Text = `Bucket ({#d.bucket}/{config.fishing.bucketSlots})`
		Ui.clear(scroll)
		local hasFreePool = Cove.freePool(d, Cove.poolCount(d, config.pools, perks)) ~= nil
		for i, c in d.bucket do
			local def = species[c.speciesId]
			local rarity = if def then def.rarity else "Common"
			local row = Instance.new("Frame")
			row.Name = `Item{c.uid}`
			row.LayoutOrder = i
			row.Size = UDim2.new(1, -10, 0, 44)
			row.BackgroundTransparency = 1
			local name = Ui.label(row, "Name", UDim2.fromScale(0.5, 0.55))
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextColor3 = Layout.rarityColor(rarity)
			name.Text = Layout.displayName(c.speciesId)
			local info = Ui.label(row, "Info", UDim2.fromScale(0.5, 0.45), UDim2.fromScale(0, 0.55))
			info.TextXAlignment = Enum.TextXAlignment.Left
			info.Font = Enum.Font.Gotham
			info.TextColor3 = Ui.MUTED
			info.Text = `{rarity}, {Creatures.formatKg(c.kg)}`
			local value = Cove.salePrice(Creatures.value(c, 1, config.species, config.pools), config, perks)
			local place = Ui.button(row, "Place", "Pool", UDim2.new(0.22, -4, 1, -4), Ui.GOOD)
			place.Position = UDim2.new(0.5, 2, 0, 2)
			place.Active = hasFreePool
			place.BackgroundColor3 = if hasFreePool then Ui.GOOD else Color3.fromRGB(70, 75, 85)
			place.Activated:Connect(function()
				ctx.fire(ctx.remotes["TC:Place"], c.uid)
			end)
			local sellOne =
				Ui.button(row, "Sell", `{Layout.shortNumber(value)}c`, UDim2.new(0.28, -4, 1, -4), Ui.WARN)
			sellOne.Position = UDim2.new(0.72, 2, 0, 2)
			sellOne.Activated:Connect(function()
				ctx.fire(ctx.remotes["TC:SellCatch"], c.uid)
			end)
			row.Parent = scroll
		end
		if #d.bucket == 0 then
			local empty = Ui.label(scroll, "Empty", UDim2.new(1, -10, 0, 30))
			empty.Font = Enum.Font.Gotham
			empty.TextColor3 = Ui.MUTED
			empty.Text = "Empty. Go fishing at a dock!"
		end
	end
	local bucketOpened: { () -> () } = {}
	local function toggleBucket()
		bucket.Visible = not bucket.Visible
		if bucket.Visible then
			for _, fn in bucketOpened do
				fn()
			end
		end
		renderBucket()
	end
	bucketButton.Activated:Connect(toggleBucket)

	ctx.on(ctx.remotes["TC:Notice"], function(text: string)
		show(text)
	end)
	ctx.on(ctx.remotes["TC:WelcomeBack"], function(grew: number, restocked: boolean)
		local parts = {}
		if grew > 0 then
			table.insert(parts, `{grew} creature{if grew == 1 then "" else "s"} in your pools grew`)
		end
		if restocked then
			table.insert(parts, "the bait shop restocked")
		end
		show(`Welcome back! While you were away, {table.concat(parts, " and ")}.`, 8)
	end)

	ctx.onData(function(d: { [string]: any })
		coins.Text = `{Layout.shortNumber(d.coins)} coins`
		local caught, total = Cove.journalCount(d, config.species)
		journal.Text = `Journal {caught}/{total}`
		rod.Text = Layout.displayName(Catch.rod(config.fishing, d.rodTier).id)
		renderPicker()
		renderBucket()
		renderCard()
		-- A catch sold from the bucket elsewhere closes its card.
		if catchUid and Cove.bucketIndex(d, catchUid) == nil then
			hideCatch()
		end
	end)

	local api = {}

	function api.notice(text: string, seconds: number?)
		show(text, seconds)
	end

	function api.status(text: string?)
		status.Visible = text ~= nil
		statusText.Text = text or ""
	end

	function api.showCatch(speciesId: string, kg: number, uid: string, soldFor: number, isNew: boolean)
		local def = species[speciesId]
		local rarity = if def then def.rarity else "Common"
		catchTitle.Text = `{if isNew then "NEW! " else ""}{rarity} {Layout.displayName(speciesId)}`
		catchTitle.TextColor3 = Layout.rarityColor(rarity)
		catchCard.Visible = true
		catchId += 1
		local id = catchId
		if soldFor > 0 then
			catchInfo.Text = `{Creatures.formatKg(kg)}. Bucket full: sold for {soldFor} coins.`
			keep.Visible = false
			sell.Visible = false
			catchUid = nil
			task.delay(3, function()
				if catchId == id then
					hideCatch()
				end
			end)
			return
		end
		local value = Cove.salePrice(
			Creatures.value(
				{ uid = uid, speciesId = speciesId, kg = kg, mutation = "None" },
				1,
				config.species,
				config.pools
			),
			config,
			ctx.perks()
		)
		catchInfo.Text = `{Creatures.formatKg(kg)}. Raise it in a pool to sell for more.`
		keep.Visible = true
		sell.Visible = true
		sell.Text = `Sell {value}`
		catchUid = uid
	end

	function api.showOdds(spotId: string)
		cardSpot = spotId
		renderCard()
		card.Visible = true
	end

	function api.hideOdds()
		cardSpot = nil
		card.Visible = false
	end

	api.toggleBucket = toggleBucket

	function api.hideBucket()
		bucket.Visible = false
	end

	function api.onBucketOpened(fn: () -> ())
		table.insert(bucketOpened, fn)
	end

	renderPicker()
	return api
end

return Hud
