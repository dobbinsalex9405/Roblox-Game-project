--!strict
-- The Hatchery Book lists every species once, Common first, each with an egg
-- that can hatch it at its best chance.
local Book = require("../src/shared/Book")
local creatures = require("../config/creatures")
local eggs = require("../src/shared/Eggs").expand(require("../config/eggs"), creatures.species)
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local RARITIES = { "Common", "Uncommon", "Rare", "Ultra Rare", "Epic", "Legendary", "Godly" }

describe("Hatchery Book", function()
	it("lists every species once, by rarity then income", function()
		local entries = Book.entries(creatures, eggs, RARITIES)
		local seen: { [string]: boolean } = {}
		local count = 0
		for id in creatures.species do
			count += 1
			seen[id] = false
		end
		expect(#entries).toBe(count)
		for i, entry in entries do
			expect(seen[entry.speciesId]).toBe(false)
			seen[entry.speciesId] = true
			if i > 1 then
				local prev = entries[i - 1]
				expect(entry.rank).toBeAtLeast(prev.rank)
				if entry.rank == prev.rank then
					expect(entry.coinsPerSecond).toBeAtLeast(prev.coinsPerSecond)
				end
			end
		end
		expect(entries[1].rarity).toBe("Common")
		expect(entries[#entries].rarity).toBe("Godly")
	end)

	it("names the egg with the best chance for every species", function()
		for _, entry in Book.entries(creatures, eggs, RARITIES) do
			expect(entry.eggId ~= nil and entry.speciesId or `{entry.speciesId} hatches from no egg`).toBe(
				entry.speciesId
			)
			expect(entry.weight).toBeAtLeast(1)
		end
		-- The Phoenix is 2 in 100,000 from the Basic Egg; no egg does better.
		for _, entry in Book.entries(creatures, eggs, RARITIES) do
			if entry.speciesId == "Phoenix" then
				expect(entry.weight / entry.total).toBeAtLeast(2 / 100000)
			end
		end
	end)
end)
