--!strict
-- The Golden Egg Shop (shared/ShopArt, made by tools/art/world/shop.py):
-- well-formed props within budget, a layout that only names props it has,
-- and exactly one display for every Robux item the Shop window sells, never
-- one for an item with random results.
local Products = require("../src/shared/Products")
local ShopArt = require("../src/shared/ShopArt")
local ShopPlan = require("../src/shared/ShopPlan")
local WorldArt = require("../src/shared/WorldArt")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local monetization = require("../config/monetization")
local raids = require("../config/raids")
local shophouse = require("../config/shophouse")

-- Most boxes (Parts) the whole shop may build: one building's worth.
local TOTAL_BUDGET = 3500
local PROP_BUDGET = 400

local ANIMS = { static = true, bob = true, spin = true, pulse = true, flicker = true }

describe("Golden Egg Shop art", function()
	it("every prop is well formed: whole boxes, known colours, parents, animations", function()
		for id, prop in ShopArt.props do
			expect(prop.voxel > 0 and id or `{id} voxel`).toBe(id)
			expect(prop.anchor ~= nil and id or `{id} has no anchor`).toBe(id)
			local names: { [string]: boolean } = {}
			for _, part in prop.parts do
				names[part.name] = true
			end
			for _, part in prop.parts do
				expect(ANIMS[part.anim] and id or `{id}.{part.name} anim {part.anim}`).toBe(id)
				expect(#part.boxes % 7).toBe(0)
				if part.parent then
					expect(names[part.parent] and id or `{id}.{part.name} parent {part.parent}`).toBe(id)
				end
				for i = 1, #part.boxes, 7 do
					local c = part.boxes[i + 6]
					expect(c >= 1 and c <= #prop.palette and id or `{id} colour {c}`).toBe(id)
					for k = 3, 5 do
						expect(part.boxes[i + k] > 0 and id or `{id} empty box`).toBe(id)
					end
				end
			end
			for _, hex in prop.palette do
				expect(string.match(hex, "^%x%x%x%x%x%x%*?$") ~= nil and id or `{id} colour {hex}`).toBe(id)
			end
		end
	end)

	it("stays within its box budget, per prop and as a whole building", function()
		local count: { [string]: number } = {}
		for id, prop in ShopArt.props do
			local n = 0
			for _, part in prop.parts do
				n += #part.boxes // 7
			end
			count[id] = n
			expect(n <= PROP_BUDGET and id or `{id} has {n} boxes`).toBe(id)
		end
		local total = 0
		for _, entry in ShopArt.layout do
			if entry.type == "piece" then
				total += count[entry.prop :: string]
			elseif entry.type == "display" then
				total += count[entry.plinth :: string] + count[entry.item :: string]
			end
		end
		expect(total <= TOTAL_BUDGET and "ok" or `{total} boxes`).toBe("ok")
	end)

	it("the layout names only props it has, and every plinth knows its top", function()
		for i, entry in ShopArt.layout do
			for _, field in { "prop", "plinth", "item" } do
				local name = (entry :: any)[field]
				if name then
					expect(ShopArt.props[name] ~= nil and name or `layout {i}: no prop {name}`).toBe(name)
				end
			end
			if entry.plinth then
				expect(ShopArt.plinthTop[entry.plinth] ~= nil).toBe(true)
			end
			expect(#entry.at).toBe(3)
		end
	end)

	it("no prop name clashes with WorldArt (the placer looks there first)", function()
		for id in ShopArt.props do
			expect(WorldArt.props[id] == nil and id or `{id} is also a WorldArt prop`).toBe(id)
		end
	end)
end)

describe("Golden Egg Shop displays", function()
	local catalog = Products.catalog(monetization, raids)

	it("has exactly one display for every item in the Shop window", function()
		local displays, problems = ShopPlan.displays(ShopArt.layout, catalog :: any)
		expect(table.concat(problems, "\n")).toBe("")
		expect(#displays).toBe(#catalog)
	end)

	it("never puts an item with random results on a display", function()
		local withOdds = table.clone(catalog) :: { any }
		for i, item in withOdds do
			if item.key == "CoinPackSmall" then
				withOdds[i] = table.clone(item)
				withOdds[i].oddsTable = "Mystery"
				withOdds[i].paidRandom = true
			end
		end
		local displays, problems = ShopPlan.displays(ShopArt.layout, withOdds)
		expect(#problems).toBe(1)
		expect(string.find(problems[1], "random results", 1, true) ~= nil).toBe(true)
		for _, d in displays do
			expect(d.key ~= "CoinPackSmall").toBe(true)
		end
	end)

	it("reports a shop item with no display", function()
		local more = table.clone(catalog) :: { any }
		table.insert(more, { key = "NewThing", kind = "product", name = "New Thing", description = "x" })
		local _, problems = ShopPlan.displays(ShopArt.layout, more)
		expect(table.concat(problems, "\n")).toBe("product:NewThing (New Thing) has no display in the shop")
	end)

	it("price tags say Owned, Coming soon or the Robux price", function()
		expect(ShopPlan.priceText(true, true, 149)).toBe("Owned")
		expect(ShopPlan.priceText(false, false, 99)).toBe("Coming soon")
		expect(ShopPlan.priceText(true, false, 25)).toBe("R$ 25")
		expect(ShopPlan.priceText(true, false, nil)).toBe("R$ ...")
	end)
end)

-- The Studio check found the room washed out white: ten warm PointLights
-- (brightness up to 1.6) plus 78 Neon accents under the game's bloom. Roblox
-- adds overlapping lights, so the room's total lamp brightness is capped,
-- and Neon stays off indoors.
describe("Golden Egg Shop lighting", function()
	it("the room's lamps add up to a soft light, not a glare", function()
		local total = 0
		for _, entry in ShopArt.layout do
			if entry.type == "light" then
				total += (entry.brightness :: number) * shophouse.lightScale
			end
		end
		expect(total > 0).toBe(true)
		expect(total <= 3.5).toBe(true)
	end)

	it("glowing accents are plain colour, not Neon", function()
		expect(shophouse.neon).toBe(false)
	end)
end)
