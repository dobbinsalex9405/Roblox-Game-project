--!strict
-- The Golden Egg Shop: a walk-in shop in the farm hub where every Robux item
-- stands on its own display (coin packs on one wall, the passes and the
-- shield on the other). Walking up to a display shows a Buy prompt; the
-- client turns that into the same `Shop:Buy` the Shop window sends, so the
-- core shop re-checks everything and opens Roblox's own purchase prompt.
--
-- The building, the furniture and where everything goes come from
-- shared/ShopArt (tools/art/world/shop.py); config/shophouse.luau says
-- where it stands and what its signs say. This module only places Parts,
-- lights, the signs' text and the prompts. Price tags and animation are
-- drawn by each client (client/ShopHouseView), because "Owned" differs per
-- player.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Products = require(Shared.Products)
local ShopArt = require(Shared.ShopArt)
local ShopPlan = require(Shared.ShopPlan)
local VoxelProp = require(Shared.VoxelProp)

local ShopHouse = {}

local GLASS_HEX = "bee6ff" -- ShopArt's window glass colour
local LIGHT_COLOR = Color3.fromRGB(255, 205, 150)
local TEXT_COLOR = Color3.fromRGB(150, 44, 38)

local function vec(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

-- The building's frame in the world: on the ring, its door (-Z) toward the
-- middle of the map.
function ShopHouse.frame(config: any): CFrame
	local a = math.rad(config.angle)
	local at = Vector3.new(math.cos(a) * config.radius, config.groundY, math.sin(a) * config.radius)
	return CFrame.lookAt(at, Vector3.new(0, config.groundY, 0))
end

-- Where an entry's anchor goes, in the world.
local function target(building: CFrame, entry: ShopArt.Entry): CFrame
	return building * CFrame.new(vec(entry.at)) * CFrame.Angles(0, math.rad(entry.turn), 0)
end

-- A prop with its anchor at `at`: a Model of Parts, its origin remembered
-- for the client's animation.
local function place(name: string, at: CFrame, collide: boolean, parent: Instance): Model
	local origin = at * CFrame.new(-VoxelProp.anchor(name))
	local model = VoxelProp.build(name, origin)
	assert(model, `ShopArt has no prop {name}`)
	for _, child in model:GetChildren() do
		local p = child :: Part
		if collide then
			p.CanCollide = true
		end
		if p.Color:ToHex() == GLASS_HEX then
			p.Material = Enum.Material.Glass
			p.Transparency = 0.45
		end
	end
	model:SetAttribute("ShopProp", name)
	model:SetAttribute("Origin", origin)
	model.Parent = parent
	return model
end

local function invisible(name: string, cframe: CFrame, size: Vector3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cframe
	p.Parent = parent
	return p
end

-- A text board: an invisible slab over the board's face with the words on
-- its front (-Z) side.
local function sign(at: CFrame, board: { at: { number }, size: { number } }, text: string, parent: Instance)
	local w, h = board.size[1], board.size[2]
	local slab = invisible(
		"SignText",
		at * CFrame.new(vec(board.at) - Vector3.new(0, 0, 0.03)),
		Vector3.new(w, h, 0.05),
		parent
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Text"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.2
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = TEXT_COLOR
	label.Text = text
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.Parent = label
	label.Parent = gui
	gui.Parent = slab
end

local function light(at: CFrame, range: number, brightness: number, parent: Instance)
	local holder = invisible("Lamp", at, Vector3.new(0.2, 0.2, 0.2), parent)
	local l = Instance.new("PointLight")
	l.Range = range
	l.Brightness = brightness
	l.Color = LIGHT_COLOR
	l.Shadows = false
	l.Parent = holder
end

-- Builds the shop. `monetization` and `raids` are the configs the Shop
-- window's catalog comes from, so every display matches a shop item.
function ShopHouse.build(config: any, monetization: any, raids: any): Model
	VoxelProp.register(ShopArt.props)
	local displays, problems = ShopPlan.displays(ShopArt.layout, Products.catalog(monetization, raids) :: any)
	assert(#problems == 0, "Golden Egg Shop:\n  " .. table.concat(problems, "\n  "))
	local byIndex: { [number]: ShopPlan.Display } = {}
	for _, d in displays do
		byIndex[d.index] = d
	end

	local building = ShopHouse.frame(config)
	local shop = Instance.new("Model")
	shop.Name = ShopPlan.MODEL_NAME
	local pieces = Instance.new("Folder")
	pieces.Name = "Pieces"
	pieces.Parent = shop
	local folder = Instance.new("Folder")
	folder.Name = "Displays"
	folder.Parent = shop
	local texts = {
		title = config.title,
		coins = config.coinsHeader,
		passes = config.passesHeader,
	}

	for index, entry in ShopArt.layout do
		local at = target(building, entry)
		if entry.type == "piece" then
			place(entry.prop :: string, at, entry.collide == true, pieces)
		elseif entry.type == "text" then
			sign(at, entry.board :: any, texts[entry.slot :: string] or "", shop)
		elseif entry.type == "light" then
			light(at, entry.range :: number, (entry.brightness :: number) * config.lightScale, shop)
		elseif entry.type == "keeper" then
			-- The shopkeeper: an invisible stand-in the client draws as a
			-- creature (CreatureView), like the farm animals.
			local size = entry.size :: number
			local keeper =
				invisible("Shopkeeper", at * CFrame.new(0, size / 2, 0), Vector3.new(size, size, size), shop)
			keeper.Shape = Enum.PartType.Ball
			keeper:SetAttribute("CreatureLook", entry.species)
		elseif entry.type == "display" then
			local d = byIndex[index]
			local model = Instance.new("Model")
			model.Name = d.key
			model:SetAttribute("ShopKey", d.key)
			model:SetAttribute("ShopKind", d.kind)
			place(entry.plinth :: string, at, true, model)
			local top = at * CFrame.new(0, ShopArt.plinthTop[entry.plinth :: string], 0)
			local item = place(entry.item :: string, top, false, model)
			item.Name = "Item"
			local card = ShopArt.card
			invisible(
				"Card",
				at * CFrame.new(vec(card.at) - Vector3.new(0, 0, 0.03)),
				Vector3.new(card.size[1], card.size[2], 0.05),
				model
			)
			-- The prompt sits over the item, a little toward the room.
			local _, itemSize = item:GetBoundingBox()
			local anchor = invisible(
				"PromptAnchor",
				top * CFrame.new(0, itemSize.Y / 2, -1),
				Vector3.new(1, 1, 1),
				model
			)
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "Buy"
			prompt.ActionText = "Buy"
			prompt.ObjectText = d.name
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = config.promptDistance
			prompt.RequiresLineOfSight = false
			prompt:SetAttribute("ShopKey", d.key)
			prompt:SetAttribute("ShopKind", d.kind)
			prompt.Parent = anchor
			model.Parent = folder
		end
	end
	shop.Parent = Workspace
	return shop
end

return ShopHouse
