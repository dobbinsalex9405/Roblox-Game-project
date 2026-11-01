--!strict
-- The shared shop screen: a Shop button in the top bar and a list of what the
-- game sells, with Robux prices from Roblox. Items with random results show
-- their odds first; Buy stays off until the odds have been seen (the server
-- checks this too). Buying opens Roblox's own purchase prompt.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
}

export type Hooks = {
	requestOdds: (tableId: string) -> (),
	onOdds: (listener: (display: any) -> ()) -> (),
}

local ShopUi = {}

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

	local button = UiKit.topbarButton(gui, "Shop", 0, 72)
	button.Visible = false

	local function render()
		if not window.Visible then
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
				for _, row in display.rows do
					UiKit.label(card, `{row.id}: {row.percent}`, 16)
				end
			end

			local buttons = UiKit.row(card, 34)
			local oddsTable = entry.oddsTable
			if oddsTable and not entry.blocked then
				local oddsButton = UiKit.button(buttons, "Show odds", 110, 32, UiKit.MUTED)
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
				32,
				if canBuy then UiKit.ACCENT else UiKit.MUTED
			)
			buy.AutoButtonColor = canBuy
			buy.Activated:Connect(function()
				if canBuy then
					notice.Text = ""
					ClientNet.fire(ShopRemotes["Shop:Buy"], entry.kind, entry.key)
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

	button.Activated:Connect(function()
		window.Visible = not window.Visible
		if window.Visible then
			ClientNet.fire(ShopRemotes["Shop:RequestCatalog"])
			render()
		end
	end)

	ClientNet.on(ShopRemotes["Shop:Catalog"], function(entries: { Entry })
		catalog = entries
		button.Visible = #entries > 0
		render()
		fetchPrices(entries, render)
	end)
	ClientNet.on(ShopRemotes["Shop:Notice"], function(text: string)
		notice.Text = text
		window.Visible = true
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
