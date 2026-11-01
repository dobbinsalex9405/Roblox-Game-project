--!strict
-- Shows the exact catch odds for a spot with the picked bait. The numbers
-- come from the server's odds table for this player (the same table the bite
-- rolls from, rod included), never from client config. Free casts need no
-- odds screen under the policy; every spot shows its odds anyway (build plan).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoreClient = require(ReplicatedStorage.CoreClient.CoreClient)
local Shared = ReplicatedStorage.Shared
local Catch = require(Shared.Catch)
local Layout = require(Shared.Layout)

local Context = require(script.Parent.Context)
local Ui = require(script.Parent.Ui)

local OddsView = {}

-- The server allows 5 odds requests a second; stay under it.
local REQUEST_GAP = 0.25

local displays: { [string]: any } = {}
local requested: { [string]: boolean } = {}
local queue: { string } = {}
local listeners: { () -> () } = {}
local ctx: Context.Context

local function request(tableId: string)
	if requested[tableId] then
		return
	end
	requested[tableId] = true
	table.insert(queue, tableId)
end

function OddsView.start(context: Context.Context)
	ctx = context
	CoreClient.onOdds(function(display: any)
		if type(display) == "table" and type(display.tableId) == "string" then
			displays[display.tableId] = display
			for _, listener in listeners do
				task.spawn(listener)
			end
		end
	end)
	task.spawn(function()
		while true do
			local tableId = table.remove(queue, 1)
			if tableId then
				CoreClient.requestOdds(tableId)
			end
			task.wait(REQUEST_GAP)
		end
	end)
	local function requestBait(baitId: string)
		for _, spot in ctx.config.fishing.spots do
			request(Catch.tableId(spot.id, baitId))
		end
	end
	requestBait(Catch.NO_BAIT)
	ctx.onBait(requestBait)
end

function OddsView.onChanged(listener: () -> ())
	table.insert(listeners, listener)
end

-- Whether a cast with this bait would be a paid roll this player may not make.
function OddsView.blocked(baitId: string): boolean
	local bait = Catch.bait(ctx.config.fishing, baitId)
	return ctx.restricted() and bait ~= nil and bait.robux == true
end

-- Fills `container` (which should have a UIListLayout) with one spot's odds
-- for the picked bait.
function OddsView.render(container: GuiObject, spotId: string, baitId: string)
	Ui.clear(container)
	local tableId = Catch.tableId(spotId, baitId)
	request(tableId)
	local baitName = if baitId == Catch.NO_BAIT then "no bait" else Layout.displayName(baitId)
	Ui.row(container, 0, `{Layout.displayName(spotId)}, {baitName}`, "Odds", Color3.new(1, 1, 1), true)
	if OddsView.blocked(baitId) then
		Ui.row(container, 1, "This bait is not available to you.", "", Ui.MUTED, false)
		return
	end
	local display = displays[tableId]
	if display == nil then
		Ui.row(container, 1, "Loading odds...", "", Ui.MUTED, false)
		return
	end
	if #display.boosts > 0 then
		local names = {}
		for _, id in display.boosts do
			table.insert(names, Layout.displayName(id))
		end
		Ui.row(container, 1, `With your {table.concat(names, ", ")}`, "", Ui.GOLD, true)
	end
	local species = ctx.config.species.species
	local data = ctx.data()
	for i, r in display.rows do
		local def = species[r.id]
		local rarity = if def then def.rarity else "Common"
		local seen = data ~= nil and data.journal[r.id] ~= nil
		-- On free casts, species not in the journal yet show as "???" with
		-- their rarity, so there is something to discover; the odds are still
		-- exact. A paid roll always names every outcome.
		local name = if seen or display.paid then Layout.displayName(r.id) else "???"
		Ui.row(container, i + 1, `{name} ({rarity})`, r.percent, Layout.rarityColor(rarity), false)
	end
end

return OddsView
