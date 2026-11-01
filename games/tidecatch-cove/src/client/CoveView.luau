--!strict
-- The tide pools: labels with each creature's stage and the time to its next
-- one on every cove, and on the player's own cove the prompts to place a
-- creature from the bucket, feed, sell, and unlock the next pool. Prompts
-- only ask; the server checks everything again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Cove = require(Shared.Cove)
local Creatures = require(Shared.Creatures)
local Layout = require(Shared.Layout)

local Context = require(script.Parent.Context)

local CoveView = {}

local function prompt(parent: Instance, name: string, action: string, hold: number?): ProximityPrompt
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("ProximityPrompt") then
		return existing
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = 9
	p.RequiresLineOfSight = false
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

-- The pool as the server drew it, read back from its attributes.
local function pooledFrom(rim: Instance): Creatures.Pooled?
	local uid = rim:GetAttribute("Uid")
	local speciesId = rim:GetAttribute("SpeciesId")
	if type(uid) ~= "string" or type(speciesId) ~= "string" then
		return nil
	end
	return {
		uid = uid,
		speciesId = speciesId,
		kg = (rim:GetAttribute("Kg") or 0) :: number,
		mutation = (rim:GetAttribute("Mutation") or "None") :: string,
		slot = rim:GetAttribute("Slot") :: number,
		placedAt = (rim:GetAttribute("PlacedAt") or 0) :: number,
		fed = (rim:GetAttribute("Fed") or 0) :: number,
		lastFedAt = (rim:GetAttribute("LastFedAt") or 0) :: number,
	}
end

-- The bucket creature worth most when fully grown: the one to raise first.
local function bestInBucket(d: { [string]: any }, config: Cove.Config): any?
	local best, bestValue = nil, -1
	for _, c in d.bucket do
		local value = Creatures.value(c, #config.pools.stages, config.species, config.pools)
		if value > bestValue then
			best, bestValue = c, value
		end
	end
	return best
end

function CoveView.start(ctx: Context.Context)
	local config = ctx.config
	local coves = Workspace:WaitForChild("Map"):WaitForChild("Coves")
	local wired: Model? = nil

	local function wire(model: Model)
		wired = model
		for _, rim in (model:WaitForChild("Pools") :: Folder):GetChildren() do
			local slot = rim:GetAttribute("Slot") :: number
			prompt(rim, "Place", "Place").Triggered:Connect(function()
				local d = ctx.data()
				local best = d and bestInBucket(d, config)
				if best then
					ctx.fire(ctx.remotes["TC:Place"], best.uid)
				end
			end)
			prompt(rim, "Feed", "Feed").Triggered:Connect(function()
				ctx.fire(ctx.remotes["TC:Feed"], slot)
			end)
			local sell = prompt(rim, "Sell", "Sell", 0.6)
			sell.KeyboardKeyCode = Enum.KeyCode.F
			sell.UIOffset = Vector2.new(0, 70)
			sell.Triggered:Connect(function()
				ctx.fire(ctx.remotes["TC:SellPool"], slot)
			end)
			prompt(rim, "Unlock", "Unlock", 0.5).Triggered:Connect(function()
				ctx.fire(ctx.remotes["TC:BuyPool"])
			end)
		end
	end

	-- Labels and prompt state, a few times a second.
	task.spawn(function()
		while true do
			local now = ctx.serverNow()
			local own = ctx.cove()
			if own and own ~= wired then
				wire(own)
			end
			local d = ctx.data()
			local perks = ctx.perks()
			for _, model in coves:GetChildren() do
				local folder = model:FindFirstChild("Pools")
				if folder == nil then
					continue
				end
				local isOwn = model == own
				for _, rim in folder:GetChildren() do
					local state = rim:GetAttribute("State")
					local pooled = pooledFrom(rim)
					local stage, nextIn = 1, nil :: number?
					if state == "Full" and pooled then
						stage = Creatures.stage(pooled, now, config.species, config.pools)
						nextIn = Creatures.nextStageIn(pooled, now, config.species, config.pools)
						local stageName = config.pools.stages[stage].name
						setText(
							rim,
							`{Layout.displayName(pooled.speciesId)} ({stageName})\n`
								.. (if nextIn then `grows in {Layout.formatTime(nextIn)}` else "Fully grown!")
						)
					elseif state == "Buyable" then
						setText(rim, `Unlock: {Layout.shortNumber(rim:GetAttribute("Cost") :: number)}`)
					end
					if not isOwn then
						continue
					end
					local place = rim:FindFirstChild("Place") :: ProximityPrompt?
					local feed = rim:FindFirstChild("Feed") :: ProximityPrompt?
					local sell = rim:FindFirstChild("Sell") :: ProximityPrompt?
					local unlock = rim:FindFirstChild("Unlock") :: ProximityPrompt?
					local best = if d then bestInBucket(d, config) else nil
					if place then
						place.Enabled = state == "Empty" and best ~= nil
						place.ObjectText = if best then Layout.displayName(best.speciesId) else ""
					end
					if feed then
						local hungry = pooled ~= nil
							and nextIn ~= nil
							and Cove.feedCooldown(pooled, now, config.pools) <= 0
						feed.Enabled = state == "Full" and hungry
					end
					if sell then
						sell.Enabled = state == "Full" and pooled ~= nil
						if pooled then
							local value = Cove.salePrice(
								Creatures.value(pooled, stage, config.species, config.pools),
								config,
								perks
							)
							sell.ObjectText = `{Layout.shortNumber(value)} coins`
						end
					end
					if unlock then
						unlock.Enabled = state == "Buyable"
						unlock.ObjectText = if state == "Buyable"
							then `{Layout.shortNumber(rim:GetAttribute("Cost") :: number)} coins`
							else ""
					end
				end
			end
			task.wait(0.25)
		end
	end)
end

return CoveView
