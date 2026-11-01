--!strict
-- The player's own plot: prompts on the counter (serve), the register
-- (collect), every station spot (build, upgrade, hire a cook, move), the next
-- district's gate (unlock) and the rebirth stand. Also writes the station
-- labels and build countdowns on every plot from the server's attributes.
-- Prompts and menus only ask; the server checks everything again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Layout)
local Restaurant = require(Shared.Restaurant)

local Context = require(script.Parent.Context)
local Hud = require(script.Parent.Hud)

local PlotView = {}

local function prompt(
	parent: Instance,
	name: string,
	action: string,
	key: Enum.KeyCode?,
	hold: number?
): ProximityPrompt
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("ProximityPrompt") then
		return existing
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.KeyboardKeyCode = key or Enum.KeyCode.E
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.Enabled = false
	p.Parent = parent
	return p
end

local function setText(part: Instance, text: string)
	local gui = part:FindFirstChild("Label")
	local label = gui and gui:FindFirstChild("Text")
	if label and (label :: TextLabel).Text ~= text then
		(label :: TextLabel).Text = text
	end
end

local function setPrompt(p: ProximityPrompt?, enabled: boolean, objectText: string?)
	if p == nil then
		return
	end
	p.Enabled = enabled
	local text = if enabled then objectText or "" else ""
	if p.ObjectText ~= text then
		p.ObjectText = text
	end
end

function PlotView.start(ctx: Context.Context, hud: Hud.Hud)
	local config = ctx.config
	local plots = Workspace:WaitForChild("Plots")
	local wired: Model? = nil
	local movingFrom: number? = nil
	local rebirthBonus = math.floor(config.economy.rebirth.incomeBonusPerRebirth * 100 + 0.5)

	local function cancelMove()
		movingFrom = nil
		hud.hideBanner()
	end

	local function stationName(stationId: string): string
		return Layout.displayName(stationId)
	end

	local function openBuildMenu(spot: number)
		local d = ctx.data()
		if d == nil then
			return
		end
		local options: { Hud.Option } = {}
		local sorted = table.clone(config.stations)
		table.sort(sorted, function(a, b)
			return a.levels[1].cost < b.levels[1].cost
		end)
		for _, station in sorted do
			if Restaurant.stationById(d, station.id) == nil and station.district <= d.districts + 1 then
				local level = station.levels[1]
				local open = station.district <= d.districts
				local district = config.districts[station.district]
				table.insert(options, {
					title = `{stationName(station.id)}  {Layout.cash(level.cost)}`,
					detail = if open
						then `+{Layout.cash(level.price)} on every meal · builds in {Layout.duration(
							level.buildSeconds
						)}`
						else `Opens with {Layout.displayName(district.id)}`,
					enabled = open and d.cash >= level.cost,
					pick = function()
						ctx.fire(ctx.remotes["SFE:Build"], station.id, spot)
					end,
				})
			end
		end
		if #options == 0 then
			hud.notice("You have built every station you can. Open the next district!")
			return
		end
		hud.openMenu("Build a station", options)
	end

	local function openHireMenu(spot: number)
		local d = ctx.data()
		if d == nil then
			return
		end
		local station = Restaurant.stationAt(d, spot)
		if station == nil then
			return
		end
		local stationConfig = Restaurant.stationConfig(config, station.stationId)
		local current = Restaurant.cookAt(d, station.stationId)
		local level = math.max(1, Restaurant.workingLevel(station, ctx.serverNow()))
		local price = if stationConfig then stationConfig.levels[level].price else 0
		local multiplier = Restaurant.multiplier(d.rebirths, ctx.perks(), config.economy)
		local options: { Hud.Option } = {}
		local better = current == nil
		for _, tier in config.cooks.tiers do
			if better then
				local cost = Restaurant.hireCost(d, config, tier.id) :: number
				local perSecond = tier.servesPerMinute / 60 * price * multiplier
				table.insert(options, {
					title = `{Layout.displayName(tier.id)}  {Layout.cash(cost)}`,
					detail = `Sells {tier.servesPerMinute} a minute here: +{Layout.cash(perSecond)}/s`
						.. (if current then ` (replaces your {Layout.displayName(current.tier)})` else ""),
					enabled = d.cash >= cost,
					pick = function()
						ctx.fire(ctx.remotes["SFE:HireCook"], tier.id, spot)
					end,
				})
			end
			if current and tier.id == current.tier then
				better = true
			end
		end
		if #options == 0 then
			hud.notice("This station already has the best cook.")
			return
		end
		hud.openMenu(`Hire a cook for the {stationName(station.stationId)}`, options)
	end

	local function wire(model: Model)
		wired = model
		cancelMove()
		local counter = model:WaitForChild("Counter")
		prompt(counter, "Serve", "Serve").Triggered:Connect(function()
			ctx.fire(ctx.remotes["SFE:Serve"])
		end)
		prompt(model:WaitForChild("Register"), "Collect", "Collect").Triggered:Connect(function()
			ctx.fire(ctx.remotes["SFE:Collect"])
		end)
		for _, tile in (model:WaitForChild("Spots") :: Folder):GetChildren() do
			local spot = tile:GetAttribute("Spot") :: number
			prompt(tile, "Build", "Build").Triggered:Connect(function()
				openBuildMenu(spot)
			end)
			prompt(tile, "Upgrade", "Upgrade").Triggered:Connect(function()
				ctx.fire(ctx.remotes["SFE:Upgrade"], spot)
			end)
			prompt(tile, "Hire", "Hire cook", Enum.KeyCode.F).Triggered:Connect(function()
				openHireMenu(spot)
			end)
			prompt(tile, "Move", "Move", Enum.KeyCode.R).Triggered:Connect(function()
				local id = tile:GetAttribute("StationId")
				if type(id) == "string" then
					movingFrom = spot
					hud.showBanner(`Moving the {stationName(id)}: pick a spot`, function()
						movingFrom = nil
					end)
				end
			end)
			prompt(tile, "MoveHere", "Move here").Triggered:Connect(function()
				local from = movingFrom
				if from then
					ctx.fire(ctx.remotes["SFE:Move"], from, spot)
				end
				cancelMove()
			end)
		end
		for _, gate in (model:WaitForChild("Gates") :: Folder):GetChildren() do
			prompt(gate, "Unlock", "Unlock", Enum.KeyCode.E, 1).Triggered:Connect(function()
				ctx.fire(ctx.remotes["SFE:UnlockDistrict"])
			end)
		end
		local rebirth = prompt(model:WaitForChild("RebirthStand"), "Rebirth", "Rebirth", Enum.KeyCode.E, 2)
		rebirth.Triggered:Connect(function()
			ctx.fire(ctx.remotes["SFE:Rebirth"])
		end)
	end

	-- Station label and look, from the tile's attributes (every plot).
	local function drawStation(tile: Instance, now: number)
		local found = tile:FindFirstChild("Station")
		local id = tile:GetAttribute("StationId")
		local level = tile:GetAttribute("Level")
		local readyAt = tile:GetAttribute("ReadyAt")
		local cook = tile:GetAttribute("Cook")
		if
			found == nil
			or not found:IsA("BasePart")
			or type(id) ~= "string"
			or type(level) ~= "number"
			or type(readyAt) ~= "number"
		then
			return
		end
		local body = found :: BasePart
		local stationConfig = Restaurant.stationConfig(config, id)
		local working =
			Restaurant.workingLevel({ stationId = id, spot = 0, level = level, readyAt = readyAt }, now)
		local lines = { `{stationName(id)}  Lv {math.max(working, 1)}` }
		if now < readyAt then
			table.insert(
				lines,
				`{if level == 1 then "Building" else "Upgrading"} {Layout.duration(readyAt - now)}`
			)
		elseif stationConfig and stationConfig.levels[level] then
			table.insert(lines, `{Layout.cash(stationConfig.levels[level].price)} a dish`)
		end
		if type(cook) == "string" then
			table.insert(lines, `Cook: {Layout.displayName(cook)}`)
		end
		setText(body, table.concat(lines, "\n"))
		body.Transparency = if working < 1 then 0.6 else 0
	end

	-- Updates prompts and labels ten times a second.
	task.spawn(function()
		while true do
			local now = ctx.serverNow()
			local own = ctx.plot()
			if own and own ~= wired then
				wire(own)
			end
			for _, model in plots:GetChildren() do
				local spots = model:FindFirstChild("Spots")
				if spots then
					for _, tile in spots:GetChildren() do
						drawStation(tile, now)
					end
				end
			end

			local d = ctx.data()
			if own and d then
				local perks = ctx.perks()
				local pending, queue = Restaurant.preview(d, config, perks, now)
				local people = Restaurant.waiting(queue)
				local meal = Restaurant.handServeValue(d, config, perks, now)
				local counter = own:FindFirstChild("Counter")
				if counter then
					setPrompt(
						counter:FindFirstChild("Serve") :: ProximityPrompt?,
						people >= 1 and meal > 0,
						`{people} waiting · {Layout.cash(meal)} a meal`
					)
					setText(counter, if people >= 1 then `{people} waiting` else "Counter")
				end
				local register = own:FindFirstChild("Register")
				if register then
					setPrompt(
						register:FindFirstChild("Collect") :: ProximityPrompt?,
						pending >= 1,
						Layout.cash(pending)
					)
				end

				for _, tile in (own:FindFirstChild("Spots") :: Folder):GetChildren() do
					local spot = tile:GetAttribute("Spot") :: number
					local state = tile:GetAttribute("State")
					local station = Restaurant.stationAt(d, spot)
					local moving = movingFrom ~= nil
					local building = station ~= nil and Restaurant.isBuilding(station, now)
					local upgradeCost = if station then Restaurant.upgradeCost(station, config) else nil
					local cook = if station then Restaurant.cookAt(d, station.stationId) else nil
					local bestTier = config.cooks.tiers[#config.cooks.tiers].id
					setPrompt(
						tile:FindFirstChild("Build") :: ProximityPrompt?,
						not moving and state == "Empty"
					)
					setPrompt(
						tile:FindFirstChild("Upgrade") :: ProximityPrompt?,
						not moving and station ~= nil and upgradeCost ~= nil and not building,
						if upgradeCost then Layout.cash(upgradeCost) else nil
					)
					setPrompt(
						tile:FindFirstChild("Hire") :: ProximityPrompt?,
						not moving and station ~= nil and (cook == nil or cook.tier ~= bestTier)
					)
					setPrompt(tile:FindFirstChild("Move") :: ProximityPrompt?, not moving and station ~= nil)
					setPrompt(
						tile:FindFirstChild("MoveHere") :: ProximityPrompt?,
						moving and spot ~= movingFrom and (state == "Empty" or state == "Built")
					)
				end

				for _, gate in (own:FindFirstChild("Gates") :: Folder):GetChildren() do
					local cost = gate:GetAttribute("Cost")
					setPrompt(
						gate:FindFirstChild("Unlock") :: ProximityPrompt?,
						gate:GetAttribute("Next") == true and type(cost) == "number",
						if type(cost) == "number" then Layout.cash(cost) else nil
					)
				end

				local stand = own:FindFirstChild("RebirthStand")
				if stand then
					setPrompt(
						stand:FindFirstChild("Rebirth") :: ProximityPrompt?,
						stand:GetAttribute("Available") == true,
						`Start over from a cart for +{rebirthBonus}% cash from every sale`
					)
				end
			end
			task.wait(0.1)
		end
	end)
end

return PlotView
