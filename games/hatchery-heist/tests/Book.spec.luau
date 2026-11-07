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

	it("caps the income bonus: a full book is exactly the maximum, whatever the roster", function()
		local book = require("../config/economy").book
		local full: { [string]: number } = {}
		for id in creatures.species do
			full[id] = 1
		end
		expect(math.abs(Book.bonus(full, creatures.species, book) - book.maxBonus) < 1e-9).toBe(true)
		expect(Book.bonus({}, creatures.species, book)).toBe(0)
		expect(Book.bonus(nil, creatures.species, book)).toBe(0)
		-- Twice the Commons: a full book is still the maximum, and one Common is
		-- worth at most half as much.
		local more = table.clone(creatures.species)
		local commons = 0
		for _, s in creatures.species do
			if s.rarity == "Common" then
				commons += 1
			end
		end
		for i = 1, commons do
			more[`TestCommon{i}`] = { rarity = "Common", coinsPerSecond = 1 }
			full[`TestCommon{i}`] = 1
		end
		expect(math.abs(Book.bonus(full, more, book) - book.maxBonus) < 1e-9).toBe(true)
		local oneNow = Book.bonus({ Chick = 1 }, creatures.species, book)
		expect(Book.bonus({ Chick = 1 }, more, book)).toBeAtMost(oneNow / 2)
		-- Unknown ids (a species since removed) never count.
		expect(Book.bonus({ NotACreature = 1 }, creatures.species, book)).toBe(0)
	end)

	it("marks cards found since the book was last opened as NEW", function()
		local found = { Chick = 100, Bunny = 200, Phoenix = 300 }
		expect(Book.isNew(found, "Chick", 150)).toBe(false)
		expect(Book.isNew(found, "Bunny", 150)).toBe(true)
		expect(Book.isNew(found, "Duckling", 0)).toBe(false)
		expect(Book.newCount(found, creatures.species, 150)).toBe(2)
		expect(Book.newCount(found, creatures.species, 300)).toBe(0)
		expect(Book.newCount(nil, creatures.species, 0)).toBe(0)
	end)

	it("shows a creature's picture once it has one, and lists them all to preload", function()
		-- Studio gate (#119): live 3D cards drew blank on a flick, a reopen
		-- and a tab switch. A card with a picture shows the image instead.
		local thumbs = { Chick = 123, Kitten = 0 }
		expect(Book.picture("Chick", thumbs)).toBe("rbxassetid://123")
		expect(Book.picture("Kitten", thumbs)).toBe(nil) -- 0: not uploaded
		expect(Book.picture("Frog", thumbs)).toBe(nil) -- none: drawn live
		local function entry(id: string, rarity: string): Book.Entry
			return { speciesId = id, rarity = rarity, rank = 1, coinsPerSecond = 1, weight = 1, total = 1 }
		end
		local list = Book.pictures(
			{ entry("Chick", "Common"), entry("Kitten", "Common"), entry("Frog", "Common") },
			thumbs
		)
		expect(#list).toBe(1)
		expect(list[1]).toBe("rbxassetid://123")
		-- The generated map only names creatures the game has.
		for speciesId, id in require("../src/shared/CreatureThumbs") do
			expect(creatures.species[speciesId] ~= nil or `{speciesId} is not a creature`).toBe(true)
			expect(id > 0).toBe(true)
		end
	end)

	it("preloads the pictures in page order, several at a time", function()
		-- Studio gate (#125): one call for all 114 pictures left the first
		-- open blank for 1-3 s. The Common tab, where the Book opens, loads
		-- first, over several requests at once.
		local entries = Book.entries(creatures, eggs, RARITIES)
		local thumbs = {}
		for i, e in entries do
			thumbs[e.speciesId] = i
		end
		local list = Book.pictures(entries, thumbs)
		expect(#list).toBe(#entries)
		expect(list[1]).toBe(`rbxassetid://1`)
		expect(entries[1].rarity).toBe("Common")
		for i = 2, #list do
			expect(list[i] == `rbxassetid://{i}`).toBe(true)
		end
		local look = require("../config/atmosphere").book
		expect(look.preloadStreams >= 2).toBe(true)
		expect(look.preloadBatch >= 1).toBe(true)
	end)
end)
