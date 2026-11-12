--!strict
-- The studio price ladder, and the pricing table built from every game's
-- config/monetization.luau `listings`. ops/PRICING.md's table is generated
-- from here (`lune run tools/pricing/run`), so the laptop creates exactly what the
-- configs say, and tools/tests/Pricing.spec.luau keeps the two in step.

local lib = {}

-- Every Robux price the studio uses, cheapest first, and what belongs on each
-- rung. Nothing costs more than the top rung while the games are new.
lib.LADDER = table.freeze({
	{ robux = 25, tier = "Impulse", what = "small currency or bait pack, skip, refill, instant finish" },
	{ robux = 49, tier = "Boost", what = "15-minute boost, protection, one paid random roll" },
	{ robux = 99, tier = "Medium", what = "medium currency pack, convenience pass, cosmetic bundle" },
	{ robux = 149, tier = "Capacity", what = "pass that adds room or plays the core action for you" },
	{ robux = 199, tier = "Power", what = "pass that multiplies earnings" },
	-- Alex, Nov 7 2026 (approved Nov 12): the Giant Golden Egg outside its event.
	{ robux = 299, tier = "Premium", what = "a top-rarity egg (Epic or better), once a day" },
	{ robux = 399, tier = "Large", what = "large currency pack (best value per Robux); the ceiling" },
})

-- Roblox's limits on a pass or product listing.
lib.NAME_MAX = 50
lib.DESCRIPTION_MAX = 1000

export type CatalogItem = { key: string, kind: string, name: string }

export type Game = {
	id: string, -- folder under games/
	title: string,
	-- The currency field on currency-pack products (coins, cash), if any.
	packField: string?,
	monetization: any,
	-- What the shop lists today: an item is "live" once it is in here.
	catalog: { CatalogItem },
}

export type Row = {
	game: string,
	key: string,
	kind: "pass" | "product",
	name: string,
	robux: number,
	description: string,
	live: boolean,
}

local function tierOf(robux: number): string?
	for _, rung in lib.LADDER do
		if rung.robux == robux then
			return rung.tier
		end
	end
	return nil
end
lib.tierOf = tierOf

-- Every listing of one game, passes first, each kind in key order.
function lib.rows(g: Game): { Row }
	local live: { [string]: boolean } = {}
	for _, item in g.catalog do
		live[`{item.kind}:{item.key}`] = true
	end
	local rows: { Row } = {}
	for _, kind: "pass" | "product" in { "pass" :: "pass", "product" :: "product" } do
		local listings = g.monetization.listings[if kind == "pass" then "passes" else "products"]
		local keys: { string } = {}
		for key in listings do
			table.insert(keys, key)
		end
		table.sort(keys, function(a, b)
			local ra, rb = listings[a].robux, listings[b].robux
			if ra ~= rb then
				return ra < rb
			end
			return a < b
		end)
		for _, key in keys do
			local l = listings[key]
			table.insert(rows, {
				game = g.title,
				key = key,
				kind = kind,
				name = l.name,
				robux = l.robux,
				description = l.description,
				live = live[`{kind}:{key}`] == true,
			})
		end
	end
	return rows
end

-- What is wrong with one game's listings. Empty when all is well.
function lib.problems(g: Game): { string }
	local problems: { string } = {}
	local m = g.monetization
	local function say(text: string)
		table.insert(problems, `{g.title}: {text}`)
	end

	-- Every pass and product has exactly one listing, and nothing else does.
	for _, pair in { { "passes", m.passes }, { "products", m.products } } do
		local section, items = pair[1], pair[2]
		local listings = m.listings and m.listings[section] or {}
		for key in items do
			if listings[key] == nil then
				say(`{section}.{key} has no listing (name, robux, description)`)
			end
		end
		for key in listings do
			if items[key] == nil then
				say(`listings.{section}.{key} is not one of the game's {section}`)
			end
		end
	end

	for _, row in lib.rows(g) do
		local where = `{row.kind} {row.key}`
		if tierOf(row.robux) == nil then
			say(`{where} costs {row.robux} Robux, which is not on the studio ladder (ops/PRICING.md)`)
		end
		if #row.name == 0 or #row.name > lib.NAME_MAX then
			say(`{where}: name must be 1 to {lib.NAME_MAX} characters`)
		end
		if #row.description == 0 or #row.description > lib.DESCRIPTION_MAX then
			say(`{where}: description must be 1 to {lib.DESCRIPTION_MAX} characters`)
		end
	end

	-- The shop shows the same name the Roblox purchase prompt will.
	for _, item in g.catalog do
		local section = if item.kind == "pass" then "passes" else "products"
		local l = m.listings and m.listings[section] and m.listings[section][item.key]
		if l and l.name ~= item.name then
			say(`{item.kind} {item.key}: the shop calls it "{item.name}" but its listing says "{l.name}"`)
		end
	end

	-- A dearer currency pack never gives less per Robux than a cheaper one.
	local field = g.packField
	if field then
		local packs = {}
		for key, product in m.products do
			local l = m.listings and m.listings.products[key]
			if product[field] and l then
				table.insert(packs, { key = key, perRobux = product[field] / l.robux, robux = l.robux })
			end
		end
		table.sort(packs, function(a, b)
			return a.robux < b.robux
		end)
		for i = 2, #packs do
			if packs[i].perRobux < packs[i - 1].perRobux then
				say(`{packs[i].key} gives less {field} per Robux than {packs[i - 1].key}`)
			end
		end
	end
	return problems
end

local function cell(text: string): string
	return (string.gsub(text, "|", "\\|"))
end

-- The markdown table for ops/PRICING.md: one row per listing, every game.
function lib.markdown(games: { Game }): string
	local lines = {
		"| Game | Key | Type | Name on Roblox | Robux | Tier | In shop now | Description |",
		"| --- | --- | --- | --- | ---: | --- | --- | --- |",
	}
	for _, g in games do
		for _, row in lib.rows(g) do
			table.insert(
				lines,
				`| {row.game} | {row.key} | {if row.kind == "pass" then "Game Pass" else "Developer Product"} | {cell(
					row.name
				)} | {row.robux} | {tierOf(row.robux) or "OFF LADDER"} | {if row.live
					then "Yes"
					else "Not yet"} | {cell(row.description)} |`
			)
		end
	end
	return table.concat(lines, "\n")
end

lib.BEGIN =
	"<!-- pricing-table:begin (generated by `lune run tools/pricing/run`; edit the game configs, not this table) -->"
lib.END = "<!-- pricing-table:end -->"

-- `doc` with the text between the markers replaced by `tableText`.
function lib.render(doc: string, tableText: string): string
	local first = string.find(doc, lib.BEGIN, 1, true)
	local last = string.find(doc, lib.END, 1, true)
	assert(first and last and last > first, "ops/PRICING.md is missing the pricing-table markers")
	return string.sub(doc, 1, first + #lib.BEGIN - 1) .. "\n" .. tableText .. "\n" .. string.sub(doc, last)
end

return lib
