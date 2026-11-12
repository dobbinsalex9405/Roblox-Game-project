--!strict
-- The egg chances screen (Alex, Nov 12): a tab per rarity tier with a
-- standout creature on its face, and behind each tab every creature of that
-- tier with its exact chance. Its numbers must be the egg's own, whole and
-- exact: every creature once, every tier the sum of its creatures, all of
-- them adding up to 100%.
local OddsTiers = require("../src/shared/OddsTiers")
local Eggs = require("../src/shared/Eggs")
local creatures = require("../config/creatures")
local atmosphere = require("../config/atmosphere")
local eggs = Eggs.expand(require("../config/eggs"), creatures.species)
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local look = atmosphere.oddsScreen

-- Synthetic species and an egg table (standing rule f), so the tests do not
-- move whenever a pool changes.
local species: { [string]: any } = {
	Chick = { rarity = "Common", coinsPerSecond = 1 },
	Bunny = { rarity = "Common", coinsPerSecond = 2 },
	Lamb = { rarity = "Common", coinsPerSecond = 3 },
	FoxKit = { rarity = "Uncommon", coinsPerSecond = 6 },
	Kitten = { rarity = "Uncommon", coinsPerSecond = 10 },
	Phoenix = { rarity = "Legendary", coinsPerSecond = 400 },
	Griffin = { rarity = "Legendary", coinsPerSecond = 500 },
}
local display = {
	total = 1000,
	rows = {
		{ id = "Chick", weight = 300 },
		{ id = "Bunny", weight = 300 },
		{ id = "Lamb", weight = 300 },
		{ id = "FoxKit", weight = 49 },
		{ id = "Kitten", weight = 49 },
		{ id = "Phoenix", weight = 2 },
	},
}
local RARITIES = Eggs.RARITIES

local function byRarity(tiers: { OddsTiers.Tier }): { [string]: OddsTiers.Tier }
	local out = {}
	for _, tier in tiers do
		out[tier.rarity] = tier
	end
	return out
end

describe("Egg chances screen", function()
	it("has a tab for every tier in the game, most common first, none for empty tiers", function()
		local tiers = OddsTiers.build(display, species, RARITIES, {})
		local names = {}
		for _, tier in tiers do
			table.insert(names, tier.rarity)
		end
		expect(table.concat(names, ",")).toBe("Common,Uncommon,Legendary")
	end)

	it("sums each tier from its creatures, and the tiers to the whole table", function()
		local tiers = byRarity(OddsTiers.build(display, species, RARITIES, {}))
		expect(tiers.Common.weight).toBe(900)
		expect(tiers.Uncommon.weight).toBe(98)
		expect(tiers.Legendary.weight).toBe(2)
		expect(tiers.Common.total).toBe(1000)
	end)

	it("lists standouts first: highest income, then by id", function()
		local tiers = byRarity(OddsTiers.build(display, species, RARITIES, {}))
		local ids = {}
		for _, m in tiers.Common.members do
			table.insert(ids, m.id)
		end
		expect(table.concat(ids, ",")).toBe("Lamb,Bunny,Chick")
	end)

	it("draws the chosen creature on a tab when the egg has it, else the egg's top earner", function()
		local tiers =
			byRarity(OddsTiers.build(display, species, RARITIES, { Common = "Bunny", Uncommon = "Puppy" }))
		expect(tiers.Common.face).toBe("Bunny")
		expect(tiers.Uncommon.face).toBe("Kitten") -- Puppy is not a species here
		-- The Griffin is chosen but this egg cannot hatch it.
		local only = byRarity(OddsTiers.build(display, species, RARITIES, { Legendary = "Griffin" }))
		expect(only.Legendary.face).toBe("Phoenix")
	end)

	it("keeps a tier the egg cannot hatch as a locked tab with the game's standout", function()
		local noLegend = { total = 1000, rows = { { id = "Chick", weight = 1000 } } }
		local tiers = byRarity(OddsTiers.build(noLegend, species, RARITIES, {}))
		expect(tiers.Legendary.inEgg).toBe(false)
		expect(#tiers.Legendary.members).toBe(0)
		expect(tiers.Legendary.weight).toBe(0)
		expect(tiers.Legendary.face).toBe("Griffin")
		expect(tiers.Common.inEgg).toBe(true)
	end)

	it("names the eggs that hatch a tier", function()
		local fake = {
			{ id = "A", outcomes = { { id = "Chick", weight = 10 } } },
			{ id = "B", outcomes = { { id = "Phoenix", weight = 1 }, { id = "Chick", weight = 9 } } },
			{ id = "C", outcomes = { { id = "Griffin", weight = 0 } } },
		}
		expect(table.concat(OddsTiers.eggsWith(fake, species, "Legendary"), ",")).toBe("B")
		expect(table.concat(OddsTiers.eggsWith(fake, species, "Common"), ",")).toBe("A,B")
	end)

	it("shows every creature of every real egg exactly once, adding up to 100%", function()
		for _, egg in eggs do
			local rows = {}
			for _, o in egg.outcomes do
				table.insert(rows, { id = o.id, weight = o.weight })
			end
			local total = egg.total or 10000
			local tiers =
				OddsTiers.build({ total = total, rows = rows }, creatures.species, RARITIES, look.faces)
			local seen: { [string]: boolean } = {}
			local sum = 0
			for _, tier in tiers do
				local tierSum = 0
				for _, m in tier.members do
					expect(seen[m.id]).toBe(nil)
					seen[m.id] = true
					expect(creatures.species[m.id].rarity).toBe(tier.rarity)
					tierSum += m.weight
				end
				expect(tierSum).toBe(tier.weight)
				expect(tier.inEgg).toBe(tier.weight > 0)
				expect(tier.face ~= nil).toBe(true)
				sum += tier.weight
			end
			expect(sum).toBe(total)
			for _, o in egg.outcomes do
				expect(seen[o.id]).toBe(true)
			end
		end
	end)

	it("faces a creature of the right tier on every tab", function()
		for rarity, id in look.faces do
			expect(table.find(RARITIES, rarity) ~= nil).toBe(true)
			expect(creatures.species[id] ~= nil).toBe(true)
			expect(creatures.species[id].rarity).toBe(rarity)
		end
	end)

	it("fits all seven tabs in one row on a phone held sideways, and wraps evenly when upright", function()
		-- 844 px phone: the window is 820 wide, its content 800.
		local columns, side = OddsTiers.grid(800 - 6, 7, look.tileGap, look.tileMin, look.tileMax)
		expect(columns).toBe(7)
		expect(side >= look.tileMin).toBe(true)
		expect(columns * side + (columns - 1) * look.tileGap <= 794).toBe(true)
		-- 390 px upright: 346 px of content.
		columns, side = OddsTiers.grid(340, 7, look.tileGap, look.tileMin, look.tileMax)
		expect(columns).toBe(3)
		expect(side >= look.tileMin).toBe(true)
		expect(columns * side + (columns - 1) * look.tileGap <= 340).toBe(true)
		-- A big screen stops at tileMax.
		local _, big = OddsTiers.grid(2000, 7, look.tileGap, look.tileMin, look.tileMax)
		expect(big).toBe(look.tileMax)
		-- Tabs are tall enough to tap (40 px or more).
		expect(look.tileMin >= 40).toBe(true)
	end)
end)
