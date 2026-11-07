--!strict
-- The Hatchery Book's pages as plain data: every species, grouped by rarity
-- (Common first) and within a tier by income, with the egg that gives the
-- best chance of hatching it; the capped income bonus; and which cards are
-- NEW. Pure, so tests check every creature is listed and can be hatched
-- from some egg.

export type Entry = {
	speciesId: string,
	rarity: string,
	rank: number, -- 1 Common .. 7 Godly
	coinsPerSecond: number,
	eggId: string?, -- the egg with the best chance; nil if no egg hatches it
	weight: number, -- that chance as a weight out of `total`
	total: number,
}

local CreatureThumbs = require("./CreatureThumbs")

local Book = {}

-- A creature's Book picture (CreatureThumbs: a render of its meshes, kept
-- only while it matches the art), or nil when the card draws it live.
-- `thumbs` is for tests.
function Book.picture(speciesId: string, thumbs: { [string]: number }?): string?
	local id = (thumbs or CreatureThumbs)[speciesId]
	if id ~= nil and id > 0 then
		return `rbxassetid://{id}`
	end
	return nil
end

-- Every picture the Book can show for `species`, to preload at join.
function Book.pictures(species: { [string]: any }, thumbs: { [string]: number }?): { string }
	local out = {}
	for speciesId in species do
		local picture = Book.picture(speciesId, thumbs)
		if picture then
			table.insert(out, picture)
		end
	end
	table.sort(out)
	return out
end

-- `rarities` lists the tiers from Common up (Layout.RARITIES).
function Book.entries(creatureConfig: any, eggs: { any }, rarities: { string }): { Entry }
	local list: { Entry } = {}
	for speciesId, species in creatureConfig.species do
		local entry: Entry = {
			speciesId = speciesId,
			rarity = species.rarity,
			rank = table.find(rarities, species.rarity) or 1,
			coinsPerSecond = species.coinsPerSecond,
			eggId = nil,
			weight = 0,
			total = 1,
		}
		for _, egg in eggs do
			local total = egg.total or 10000 -- the core Odds default
			for _, outcome in egg.outcomes do
				if outcome.id == speciesId and outcome.weight / total > entry.weight / entry.total then
					entry.eggId = egg.id
					entry.weight = outcome.weight
					entry.total = total
				end
			end
		end
		table.insert(list, entry)
	end
	table.sort(list, function(a: Entry, b: Entry): boolean
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		if a.coinsPerSecond ~= b.coinsPerSecond then
			return a.coinsPerSecond < b.coinsPerSecond
		end
		return a.speciesId < b.speciesId
	end)
	return list
end

export type Tier = { have: number, total: number }

-- How many of each tier's species are in the book (`found` is the saved
-- { [speciesId] = unix seconds }); ids no longer in the game never count.
function Book.tiers(found: { [string]: any }?, species: { [string]: any }): { [string]: Tier }
	local out: { [string]: Tier } = {}
	for id, s in species do
		local tier = out[s.rarity]
		if tier == nil then
			tier = { have = 0, total = 0 }
			out[s.rarity] = tier
		end
		tier.total += 1
		if found and found[id] ~= nil then
			tier.have += 1
		end
	end
	return out
end

-- The book's income bonus (0.07 = +7%). Each tier owns `tierShare` of
-- `maxBonus`, earned in step with the share of that tier found, so a full
-- book is exactly `maxBonus` however many creatures the game has.
function Book.bonus(found: { [string]: any }?, species: { [string]: any }, book: any): number
	local bonus = 0
	for rarity, tier in Book.tiers(found, species) do
		local share = book.tierShare[rarity] or 0
		bonus += book.maxBonus * share * tier.have / tier.total
	end
	return bonus
end

-- Species found after `seenAt` (unix seconds the player last opened the
-- book): the cards marked NEW.
function Book.isNew(found: { [string]: any }?, speciesId: string, seenAt: number): boolean
	local at = if found then found[speciesId] else nil
	return type(at) == "number" and at > seenAt
end

function Book.newCount(found: { [string]: any }?, species: { [string]: any }, seenAt: number): number
	local n = 0
	for id in species do
		if Book.isNew(found, id, seenAt) then
			n += 1
		end
	end
	return n
end

return Book
