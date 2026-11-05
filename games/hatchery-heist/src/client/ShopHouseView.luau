--!strict
-- The Golden Egg Shop on this client (the server builds it: ShopHouse):
--
-- * a price tag on every display's plinth: the item's name, a short line on
--   what it does, and its Robux price from Roblox (or "Owned" for a pass
--   this player has, or "Coming soon" for an item not on Roblox yet);
-- * the Buy prompts: pressing one sends the same Shop:Buy the Shop window
--   sends, and the server re-checks it before Roblox's purchase prompt opens;
-- * the displays' small movements (coins bob and spin, the shield's halo
--   pulses, lamps flicker), only near the camera.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ClientNet = require(ReplicatedStorage.CoreClient.ClientNet)
local ShopRemotes = require(ReplicatedStorage.Core.ShopRemotes)
local Shared = ReplicatedStorage.Shared
local ShopArt = require(Shared.ShopArt)
local ShopPlan = require(Shared.ShopPlan)

local ShopHouseView = {}

local CREAM = Color3.fromRGB(250, 242, 222)
local BROWN = Color3.fromRGB(90, 52, 30)
local GOLD = Color3.fromRGB(244, 197, 66)
local GREEN = Color3.fromRGB(95, 190, 105)
local GREY = Color3.fromRGB(160, 160, 170)

type Entry = {
	key: string,
	kind: string,
	name: string,
	description: string,
	id: number,
	available: boolean,
	owned: boolean,
}

type Tag = { name: TextLabel, about: TextLabel, pill: Frame, price: TextLabel, prompt: ProximityPrompt? }

type Mover = {
	parts: { BasePart },
	rest: { CFrame }, -- each part relative to the pivot
	pivot: CFrame,
	anim: string,
	colors: { Color3 },
	transparency: { number },
	phase: number,
}

local function tagFor(card: BasePart, playerGui: Instance): Tag
	local gui = Instance.new("SurfaceGui")
	gui.Name = `ShopTag_{card.Parent and card.Parent.Name or ""}`
	gui.Adornee = card
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 80
	gui.LightInfluence = 0.15
	gui.ResetOnSpawn = false

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = CREAM
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromScale(0.05, 0.04)
	name.Size = UDim2.fromScale(0.9, 0.3)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = BROWN
	name.Parent = frame

	local about = Instance.new("TextLabel")
	about.BackgroundTransparency = 1
	about.Position = UDim2.fromScale(0.06, 0.34)
	about.Size = UDim2.fromScale(0.88, 0.3)
	about.Font = Enum.Font.GothamMedium
	about.TextScaled = true
	about.TextWrapped = true
	about.TextColor3 = BROWN
	local aboutSize = Instance.new("UITextSizeConstraint")
	aboutSize.MaxTextSize = 15
	aboutSize.Parent = about
	about.Parent = frame

	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.fromScale(0.5, 0.68)
	pill.Size = UDim2.fromScale(0.62, 0.27)
	pill.BackgroundColor3 = GOLD
	pill.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = pill
	pill.Parent = frame

	local price = Instance.new("TextLabel")
	price.BackgroundTransparency = 1
	price.Size = UDim2.fromScale(1, 1)
	price.Font = Enum.Font.FredokaOne
	price.TextScaled = true
	price.TextColor3 = BROWN
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.12, 0)
	pad.PaddingBottom = UDim.new(0.12, 0)
	pad.Parent = price
	price.Parent = pill

	gui.Parent = playerGui
	return { name = name, about = about, pill = pill, price = price }
end

-- A short line for the tag from the shop's description: its first sentence.
local function firstSentence(text: string): string
	local s = string.match(text, "^(.-%.)%s") or text
	return s
end

function ShopHouseView.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local config = require(ReplicatedStorage.GameConfig.shophouse) :: any
	local listings = (require(ReplicatedStorage.GameConfig.monetization) :: any).listings

	local tags: { [string]: Tag } = {}
	local catalog: { [string]: Entry } = {}
	local prices: { [string]: number } = {}
	local fetching: { [string]: boolean } = {}

	local function listedPrice(kind: string, key: string): number?
		local group = if kind == "pass" then listings.passes else listings.products
		local listing = group and group[key]
		return listing and listing.robux
	end

	local function redraw(id: string)
		local tag = tags[id]
		local entry = catalog[id]
		if tag == nil or entry == nil then
			return
		end
		tag.name.Text = entry.name
		tag.about.Text = firstSentence(entry.description)
		local robux = prices[id] or listedPrice(entry.kind, entry.key)
		tag.price.Text = ShopPlan.priceText(entry.available, entry.owned, robux)
		tag.pill.BackgroundColor3 = if entry.owned then GREEN elseif entry.available then GOLD else GREY
		local prompt = tag.prompt
		if prompt then
			prompt.ActionText = if entry.owned
				then "Owned"
				elseif entry.available then `Buy for R$ {robux or "?"}`
				else "Coming soon"
			-- Studio keeps unfinished items pressable, so the server's
			-- "Use the Test panel" notice can be checked there.
			prompt.Enabled = not entry.owned and (entry.available or RunService:IsStudio())
		end
	end

	local function fetchPrice(id: string, entry: Entry)
		if not entry.available or prices[id] or fetching[id] then
			return
		end
		fetching[id] = true
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(
					entry.id,
					if entry.kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
				)
			end)
			fetching[id] = nil
			local price = ok and type(info) == "table" and (info :: any).PriceInRobux
			if type(price) == "number" then
				prices[id] = price
				redraw(id)
			end
		end)
	end

	ClientNet.on(ShopRemotes["Shop:Catalog"], function(entries: { Entry })
		if type(entries) ~= "table" then
			return
		end
		for _, entry in entries do
			local id = `{entry.kind}:{entry.key}`
			catalog[id] = entry
			fetchPrice(id, entry)
			redraw(id)
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		if who ~= player then
			return
		end
		local key, kind = prompt:GetAttribute("ShopKey"), prompt:GetAttribute("ShopKind")
		if type(key) == "string" and (kind == "product" or kind == "pass") then
			ClientNet.fire(ShopRemotes["Shop:Buy"], kind, key, ShopPlan.SOURCE)
		end
	end)

	-- Animated parts: every prop part whose `anim` moves, grouped by model.
	local movers: { Mover } = {}
	local function addMovers(model: Model)
		local name = model:GetAttribute("ShopProp")
		local origin = model:GetAttribute("Origin")
		if type(name) ~= "string" or typeof(origin) ~= "CFrame" then
			return
		end
		local prop = ShopArt.props[name]
		if prop == nil then
			return
		end
		for _, part in prop.parts do
			if part.anim ~= "static" then
				local pivot = (origin :: CFrame)
					* CFrame.new(
						part.pivot[1] * prop.voxel,
						part.pivot[2] * prop.voxel,
						part.pivot[3] * prop.voxel
					)
				local m: Mover = {
					parts = {},
					rest = {},
					pivot = pivot,
					anim = part.anim,
					colors = {},
					transparency = {},
					phase = (#movers % 7) * 0.9,
				}
				for _, child in model:GetChildren() do
					if child:IsA("BasePart") and child.Name == part.name then
						table.insert(m.parts, child)
						table.insert(m.rest, pivot:ToObjectSpace(child.CFrame))
						table.insert(m.colors, child.Color)
						table.insert(m.transparency, child.Transparency)
					end
				end
				if #m.parts > 0 then
					table.insert(movers, m)
				end
			end
		end
	end

	task.spawn(function()
		local shop = Workspace:WaitForChild(ShopPlan.MODEL_NAME, 60)
		if shop == nil then
			return
		end
		for _, d in (shop:WaitForChild("Displays") :: Folder):GetChildren() do
			local key, kind = d:GetAttribute("ShopKey"), d:GetAttribute("ShopKind")
			local card = d:WaitForChild("Card", 10)
			if type(key) == "string" and type(kind) == "string" and card and card:IsA("BasePart") then
				local id = `{kind}:{key}`
				local tag = tagFor(card, playerGui)
				local anchor = d:WaitForChild("PromptAnchor", 10)
				tag.prompt = anchor and anchor:FindFirstChildOfClass("ProximityPrompt") or nil
				tags[id] = tag
				-- Until the catalog arrives, show the listing.
				tag.name.Text = (tag.prompt and tag.prompt.ObjectText) or key
				tag.price.Text = ShopPlan.priceText(true, false, listedPrice(kind, key))
				redraw(id)
			end
		end
		for _, m in shop:GetDescendants() do
			if m:IsA("Model") and m:GetAttribute("ShopProp") then
				addMovers(m)
			end
		end
		ClientNet.fire(ShopRemotes["Shop:RequestCatalog"])

		local centre = shop:GetPivot().Position
		RunService.RenderStepped:Connect(function()
			local camera = Workspace.CurrentCamera
			if camera == nil or (camera.CFrame.Position - centre).Magnitude > config.animateRange then
				return
			end
			local t = os.clock()
			for _, m in movers do
				local k = t + m.phase
				if m.anim == "bob" or m.anim == "spin" then
					local motion = if m.anim == "bob"
						then CFrame.new(0, math.sin(k * 2) * 0.18, 0) * CFrame.Angles(0, k * 0.6, 0)
						else CFrame.Angles(0, k * 1.4, 0)
					for i, p in m.parts do
						p.CFrame = m.pivot * motion * m.rest[i]
					end
				elseif m.anim == "pulse" then
					local a = 0.5 + 0.5 * math.sin(k * 2.4)
					for i, p in m.parts do
						p.Transparency = m.transparency[i] + 0.55 * a
					end
				elseif m.anim == "flicker" then
					local a = 0.9 + 0.1 * math.sin(k * 13) * math.sin(k * 7.3)
					for i, p in m.parts do
						p.Color = m.colors[i]:Lerp(Color3.new(0, 0, 0), 1 - a)
					end
				end
			end
		end)
	end)
end

return ShopHouseView
