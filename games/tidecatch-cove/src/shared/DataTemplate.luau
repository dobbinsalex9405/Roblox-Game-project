--!strict
-- Saved data, version 1 (Wave 1 build plan, Tidecatch Cove). Never remove or
-- rename a field here: add a migration (see packages/core/src/DataService.luau)
-- and bump `version`.
--
-- Keep maps that a player empties (bait, journal) empty in the template: the
-- core fills missing keys from the template on load, so a template entry
-- would come back every time a player used it up. Starting bait is given in
-- code on the first join instead (Cove.welcomeNew).

local DataTemplate = {}

DataTemplate.template = {
	version = 1,
	coins = 100, -- matches config/economy.startingCoins; checked by tests
	rodTier = 1, -- best rod owned (index into config/fishing.rods)
	bait = {}, -- { [baitId] = count }
	-- Caught and not yet placed or sold:
	-- { { uid, speciesId, kg, mutation, caughtAt, spotId } }
	bucket = {},
	poolSlots = 2, -- pools unlocked with coins (matches config/pools.startingSlots)
	-- One creature per pool:
	-- { { slot, uid, speciesId, kg, mutation, placedAt, fed, lastFedAt } }
	-- `placedAt` is the growth timer's start (moved forward after a capped
	-- absence, see Cove.welcomeBack); `fed` is growth seconds added by feeding.
	pools = {},
	journal = {}, -- { [speciesId] = { caught, bestKg, firstAt } }
	shop = { window = 0, bought = {} }, -- bait bought in the current restock window
	nextUid = 1, -- next creature uid
	lastSeenAt = 0, -- unix seconds the server last saw the player online
	firsts = {}, -- { [moment] = unix seconds } for the onboarding funnel
	boosts = {}, -- { [boostId] = expiresAt } (milestone M5)
	receipts = {}, -- recent purchase ids, capped (core Receipts)
	stats = {
		casts = 0,
		catches = 0,
		escapes = 0,
		sold = 0,
		coinsFromSales = 0,
		biggestKg = 0,
		biggestSpecies = "",
		playSeconds = 0,
	},
	meta = { firstJoinAt = 0, lastJoinAt = 0, sessions = 0 }, -- written by the core on join
}

-- One entry per version step: { from = 1, run = function(data) ... end }.
DataTemplate.migrations = {}

return DataTemplate
