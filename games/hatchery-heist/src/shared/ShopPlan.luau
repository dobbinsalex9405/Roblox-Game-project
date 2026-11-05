--!strict
-- What the Golden Egg Shop shows on its displays, as a pure function, so the
-- server and the Lune tests agree: one display per Robux item the shop sells
-- (src/shared/Products.luau), each standing for exactly that item.
--
-- A display opens Roblox's purchase prompt from the world, with no odds
-- screen in between, so an item with random results (an odds table, or
-- paidRandom) is never put on a display: it stays in the Shop window, which
-- shows its exact odds before Buy.

local ShopPlan = {}

ShopPlan.MODEL_NAME = "GoldenEggShop" -- the shop's Model in Workspace
ShopPlan.SOURCE = "GoldenEggShop" -- where its purchases are counted (ops/METRICS.md)

export type CatalogItem = {
	key: string,
	kind: string,
	name: string,
	description: string,
	oddsTable: string?,
	paidRandom: boolean?,
}

export type Display = {
	key: string,
	kind: string,
	name: string,
	description: string,
	index: number, -- its entry in ShopArt.layout
}

-- The displays to build, and anything wrong with the layout or catalog.
function ShopPlan.displays(layout: { any }, catalog: { CatalogItem }): ({ Display }, { string })
	local byKey: { [string]: CatalogItem } = {}
	for _, item in catalog do
		byKey[`{item.kind}:{item.key}`] = item
	end
	local out: { Display } = {}
	local problems: { string } = {}
	local shown: { [string]: boolean } = {}
	for index, entry in layout do
		if entry.type == "display" then
			local id = `{entry.kind}:{entry.key}`
			local item = byKey[id]
			if item == nil then
				table.insert(problems, `display {id} is not in the shop's catalog`)
			elseif item.oddsTable ~= nil or item.paidRandom then
				table.insert(
					problems,
					`display {id} has random results: it belongs in the Shop window, with its odds`
				)
			elseif shown[id] then
				table.insert(problems, `display {id} appears twice`)
			else
				shown[id] = true
				table.insert(out, {
					key = item.key,
					kind = item.kind,
					name = item.name,
					description = item.description,
					index = index,
				})
			end
		end
	end
	for id, item in byKey do
		if not shown[id] and item.oddsTable == nil and not item.paidRandom then
			table.insert(problems, `{id} ({item.name}) has no display in the shop`)
		end
	end
	table.sort(problems)
	return out, problems
end

-- The text a display's price tag shows.
function ShopPlan.priceText(available: boolean, owned: boolean, robux: number?): string
	if owned then
		return "Owned"
	elseif not available then
		return "Coming soon"
	elseif robux then
		return `R$ {robux}`
	end
	return "R$ ..."
end

return ShopPlan
