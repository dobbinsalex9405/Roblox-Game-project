--!strict
-- The Hatchery Book's pages as plain data: every species, grouped by rarity
-- (Common first) and within a tier by income, with the egg that gives the
-- best chance of hatching it. Pure, so tests check every creature is listed
-- and can be hatched from some egg.

export type Entry = {
	speciesId: string,
	rarity: string,
	rank: number, -- 1 Common .. 7 Godly
	coinsPerSecond: number,
	eggId: string?, -- the egg with the best chance; nil if no egg hatches it
	weight: number, -- that chance as a weight out of `total`
	total: number,
}

local Book = {}

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

return Book
