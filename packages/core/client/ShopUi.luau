--!strict
-- The shared shop screen: a Shop button in the top bar and a list of what the
-- game sells, with Robux prices from Roblox. Items with random results show
-- their odds first; Buy stays off until the odds have been seen (the server
-- checks this too). Buying opens Roblox's own purchase prompt.
--
-- A game can add its own tabs in front of the Robux one (ShopUi.addTab), for
-- things bought with its in-game currency. The shop then opens on the first
-- game tab, with Robux items one tab over.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ShopRemotes = require(ReplicatedStorage.Core.ShopRemotes)

local ClientNet = require(script.Parent.ClientNet)
local UiKit = require(script.Parent.UiKit)

local ODDS_FRESH_SECONDS = 540 -- a little under the server's 600 s

type Entry = {
	key: string,
	kind: "product" | "pass",
	name: string,
	description: string,
	id: number,
	available: boolean,
	owned: boolean,
	blocked: boolean,
	oddsTable: string?,
	oddsLabels: { [string]: string }?,
}

export type Hooks = {
	requestOdds: (tableId: string) -> (),
	onOdds: (listener: (display: any) -> ()) -> (),
}

export type TabApi = {
	showRobux: () -> (), -- switch to the Robux tab
}

-- Fills `body` (already cleared) with the tab's content.
export type TabRender = (body: ScrollingFrame, api: TabApi) -> ()

type Tab = { name: string, render: TabRender }

local ROBUX_TAB = "Robux"

local ShopUi = {}

local tabs: { Tab } = {}
local onTabsChanged: (() -> ())? = nil
local refreshShown: (() -> ())? = nil

local prices: { [string]: string } = {}
local fetching: { [string]: boolean } = {}

local function priceKey(entry: Entry): string
	return `{entry.kind}:{entry.id}`
end

local function priceText(entry: Entry): string
	if not entry.available then
		return "Not on Roblox yet"
	end
	return prices[priceKey(entry)] or "Loading price..."
end

-- Looks up Robux prices in the background, then calls `done` once.
local function fetchPrices(entries: { Entry }, done: () -> ())
	local pending = 0
	for _, entry in entries do
		local key = priceKey(entry)
		if entry.available and prices[key] == nil and not fetching[key] then
			fetching[key] = true
			pending += 1
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(
						entry.id,
						if entry.kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
					)
				end)
				local price = ok and type(info) == "table" and info.PriceInRobux
				prices[key] = if type(price) == "number" then `R$ {price}` else "Price unavailable"
				fetching[key] = nil
				pending -= 1
				if pending == 0 then
					done()
				end
			end)
		end
	end
end

-- Adds a game tab before the Robux tab (call once per tab, in order).
function ShopUi.addTab(name: string, render: TabRender)
	assert(name ~= ROBUX_TAB, "the Robux tab is built in")
	table.insert(tabs, { name = name, render = render })
	if onTabsChanged then
		onTabsChanged()
	end
end

-- Redraws the open tab, e.g. after the player's coins change.
function ShopUi.refresh()
	if refreshShown then
		refreshShown()
	end
end

function ShopUi.start(hooks: Hooks)
	local gui = Instance.new("ScreenGui")
	gui.Name = "CoreShop"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local catalog: { Entry } = {}
	local oddsSeenAt: { [string]: number } = {}
	local oddsShown: { [string]: any } = {}
	local window: Frame, body: ScrollingFrame
	local notice: TextLabel
	local tabBar: Frame? = nil
	local selected = ROBUX_TAB
	local render: () -> ()

	local button = UiKit.topbarButton(gui, "Shop", 0, 72)
	button.Visible = false

	local function selectTab(name: string)
		selected = name
		render()
	end
	local api: TabApi = {
		showRobux = function()
			selectTab(ROBUX_TAB)
		end,
	}

	-- The tab row under the title, once the game has added a tab.
	local function drawTabs()
		if #tabs == 0 then
			return
		end
		if tabBar == nil then
			local bar = UiKit.row(window, UiKit.TOUCH_ROW)
			bar.Name = "Tabs"
			bar.Position = UDim2.fromOffset(10, 48)
			bar.Size = UDim2.new(1, -20, 0, UiKit.TOUCH_ROW)
			body.Position = UDim2.fromOffset(10, 98)
			body.Size = UDim2.new(1, -20, 1, -108)
			tabBar = bar
		end
		local bar = tabBar :: Frame
		UiKit.clear(bar)
		local names = {}
		for _, tab in tabs do
			table.insert(names, tab.name)
		end
		table.insert(names, ROBUX_TAB)
		for index, name in names do
			local tabButton = UiKit.button(
				bar,
				name,
				110,
				UiKit.TOUCH,
				if name == selected then UiKit.ACCENT else UiKit.MUTED
			)
			tabButton.Name = `Tab{name}`
			tabButton.LayoutOrder = index
			tabButton.Activated:Connect(function()
				selectTab(name)
			end)
		end
		button.Visible = true
	end

	local function renderGameTab(): boolean
		for _, tab in tabs do
			if tab.name == selected then
				UiKit.clear(body)
				-- A broken game tab must not break the Robux tab; the error
				-- still reaches the error queue.
				local ok, err = pcall(function()
					tab.render(body, api)
				end)
				if not ok then
					task.spawn(error, err)
				end
				return true
			end
		end
		return false
	end

	function render()
		if not window.Visible then
			return
		end
		drawTabs()
		if renderGameTab() then
			return
		end
		UiKit.clear(body)
		for index, entry in catalog do
			local card = UiKit.card(body)
			card.LayoutOrder = index
			UiKit.label(card, entry.name, 22, true)
			UiKit.label(card, entry.description, 34)
			local status = if entry.owned
				then "Owned"
				elseif entry.blocked then "Not available in your region"
				else priceText(entry)
			UiKit.label(card, status, 18).TextColor3 = Color3.fromRGB(255, 220, 90)

			local display = entry.oddsTable and oddsShown[entry.oddsTable]
			if display then
				UiKit.label(card, "Odds:", 18, true)
				local labels = entry.oddsLabels or {}
				for _, row in display.rows do
					UiKit.label(card, `{labels[row.id] or row.id}: {row.percent}`, 16)
				end
			end

			local buttons = UiKit.row(card, UiKit.TOUCH_ROW)
			local oddsTable = entry.oddsTable
			if oddsTable and not entry.blocked then
				local oddsButton = UiKit.button(buttons, "Show odds", 110, UiKit.TOUCH, UiKit.MUTED)
				oddsButton.Activated:Connect(function()
					hooks.requestOdds(oddsTable)
				end)
			end
			local fresh = oddsTable == nil
				or (oddsSeenAt[oddsTable] ~= nil and os.clock() - oddsSeenAt[oddsTable] < ODDS_FRESH_SECONDS)
			local canBuy = not entry.owned and not entry.blocked and fresh
			local buy = UiKit.button(
				buttons,
				if entry.owned then "Owned" elseif fresh then "Buy" else "See odds first",
				130,
				UiKit.TOUCH,
				if canBuy then UiKit.ACCENT else UiKit.MUTED
			)
			buy.AutoButtonColor = canBuy
			buy.Activated:Connect(function()
				if canBuy then
					notice.Text = ""
					ClientNet.fire(ShopRemotes["Shop:Buy"], entry.kind, entry.key, "Shop")
				end
			end)
		end
		notice = UiKit.label(body, notice and notice.Text or "", 36)
		notice.LayoutOrder = #catalog + 1
		notice.TextColor3 = Color3.fromRGB(255, 200, 120)
	end

	window, body = UiKit.window(gui, "Shop", function()
		window.Visible = false
	end)
	notice = UiKit.label(body, "", 36)

	onTabsChanged = function()
		drawTabs()
		render()
	end
	refreshShown = render
	drawTabs()

	button.Activated:Connect(function()
		window.Visible = not window.Visible
		if window.Visible then
			-- Open on the game's own currency first; Robux is one tab over.
			selected = if #tabs > 0 then tabs[1].name else ROBUX_TAB
			ClientNet.fire(ShopRemotes["Shop:RequestCatalog"])
			render()
		end
	end)

	ClientNet.on(ShopRemotes["Shop:Catalog"], function(entries: { Entry })
		-- Items not created on Roblox yet only show in Studio (for the test
		-- panel); players never see a card they can't buy.
		if not RunService:IsStudio() then
			local live = {}
			for _, entry in entries do
				if entry.available then
					table.insert(live, entry)
				end
			end
			entries = live
		end
		catalog = entries
		button.Visible = #entries > 0 or #tabs > 0
		render()
		fetchPrices(entries, render)
	end)
	ClientNet.on(ShopRemotes["Shop:Notice"], function(text: string)
		-- Purchase results belong to the Robux tab.
		selected = ROBUX_TAB
		window.Visible = true
		render()
		notice.Text = text
	end)
	hooks.onOdds(function(display: any)
		if type(display) ~= "table" or type(display.tableId) ~= "string" then
			return
		end
		for _, entry in catalog do
			if entry.oddsTable == display.tableId then
				oddsShown[display.tableId] = display
				oddsSeenAt[display.tableId] = os.clock()
				render()
				return
			end
		end
	end)

	ClientNet.fire(ShopRemotes["Shop:RequestCatalog"])
end

return ShopUi
