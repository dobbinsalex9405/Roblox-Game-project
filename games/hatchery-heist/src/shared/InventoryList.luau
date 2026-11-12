--!strict
-- What the Creatures window lists (client/InventoryView): the player's
-- creatures for one rarity tab, narrowed by the search box and a filter,
-- in the chosen order, plus each tab's count and the creature on its face.
-- Pure, so the tests check every filter and the client only draws.

local DisplayName = require("./DisplayName")
local Hatchery = require("./Hatchery")
local Merge = require("./Merge")

export type Filter = "All" | "Placed" | "Stashed" | "Merge"
export type Sort = "Best" | "Newest" | "Name"

export type Query = {
	tier: string?, -- a rarity, or nil for every tier
	search: string?,
	filter: Filter?,
	sort: Sort?,
}

export type Entry = {
	creature: any,
	rarity: string,
	name: string, -- as players read it
	income: number, -- coins/s before floor, rebirth and pass bonuses
	canMerge: boolean,
}

export type Tab = { count: number, face: string? }

local InventoryList = {}

InventoryList.FILTERS = { "All", "Placed", "Stashed", "Merge" } :: { Filter }
InventoryList.FILTER_LABELS = {
	All = "All",
	Placed = "Placed",
	Stashed = "Stashed",
	Merge = "Can merge",
} :: { [string]: string }
InventoryList.SORTS = { "Best", "Newest", "Name" } :: { Sort }
InventoryList.SORT_LABELS =
	{ Best = "Best first", Newest = "Newest", Name = "A to Z" } :: { [string]: string }

-- Lower-cased, trimmed search text; "" matches everything.
local function clean(text: string?): string
	local s = string.lower(text or "")
	return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local function better(a: Entry, b: Entry): boolean
	if a.income ~= b.income then
		return a.income > b.income
	end
	return a.creature.uid < b.creature.uid
end

-- Every creature the query shows, in its order.
function InventoryList.build(
	d: { [string]: any },
	config: { creatures: any, economy: any },
	query: Query,
	carried: { [string]: boolean }?
): { Entry }
	local ready = Merge.ready(d, config.economy, carried)
	local search = clean(query.search)
	local filter = query.filter or "All"
	local out: { Entry } = {}
	for _, c in d.creatures do
		local species = config.creatures.species[c.speciesId]
		if species == nil then
			continue
		end
		if query.tier and species.rarity ~= query.tier then
			continue
		end
		if filter == "Placed" and c.slot == nil then
			continue
		elseif filter == "Stashed" and c.slot ~= nil then
			continue
		elseif filter == "Merge" and not ready[c.uid] then
			continue
		end
		local name = DisplayName(c.speciesId)
		if search ~= "" and string.find(string.lower(name), search, 1, true) == nil then
			continue
		end
		table.insert(out, {
			creature = c,
			rarity = species.rarity,
			name = name,
			income = Hatchery.creatureIncome(c, config.creatures, config.economy),
			canMerge = ready[c.uid] == true,
		})
	end
	local sort = query.sort or "Best"
	table.sort(out, function(a: Entry, b: Entry): boolean
		if sort == "Newest" then
			local ha, hb = a.creature.hatchedAt or 0, b.creature.hatchedAt or 0
			if ha ~= hb then
				return ha > hb
			end
			return (tonumber(a.creature.uid) or 0) > (tonumber(b.creature.uid) or 0)
		elseif sort == "Name" then
			if a.name ~= b.name then
				return a.name < b.name
			end
			local sa, sb = Merge.stars(a.creature), Merge.stars(b.creature)
			if sa ~= sb then
				return sa > sb
			end
		end
		return better(a, b)
	end)
	return out
end

-- Each rarity's count and the species on its tab's face (the best one the
-- player owns there); "All" covers every tier.
function InventoryList.tabs(d: { [string]: any }, config: { creatures: any, economy: any }): { [string]: Tab }
	local tabs: { [string]: Tab } = { All = { count = 0, face = nil } }
	local bestIncome: { [string]: number } = {}
	for _, c in d.creatures do
		local species = config.creatures.species[c.speciesId]
		if species == nil then
			continue
		end
		local income = Hatchery.creatureIncome(c, config.creatures, config.economy)
		for _, key in { species.rarity, "All" } do
			local tab = tabs[key]
			if tab == nil then
				tab = { count = 0, face = nil }
				tabs[key] = tab
			end
			tab.count += 1
			if bestIncome[key] == nil or income > bestIncome[key] then
				bestIncome[key] = income
				tab.face = c.speciesId
			end
		end
	end
	return tabs
end

return InventoryList
