--!strict
-- Saved data, version 1 (Wave 1 plan, Depthbound). Never remove or rename a
-- field here: add a migration (see packages/core/src/DataService.luau) and
-- bump `version`. The mine itself is never saved; each server builds a fresh one.

local DataTemplate = {}

DataTemplate.template = {
	version = 1,
	coins = 0, -- matches config/economy.startingCoins; checked by tests
	gear = { pick = 1, pack = 1, lamp = 1 }, -- tiers in config/gear
	pack = {}, -- ore carried: { [blockId] = count }
	deepestRow = 0, -- deepest row this player has broken a block in, ever
	layersReached = 0, -- deepest layer reached (1, 2, 3)
	geodes = {}, -- unopened geodes: { [geodeId] = count } (M5)
	boosts = {}, -- { [boostId] = expiresAt } (M5)
	receipts = {}, -- recent purchase ids, capped (core Receipts)
	firsts = {}, -- { [moment] = unix seconds } for the onboarding funnel
	stats = {
		blocksMined = 0,
		oreSold = 0,
		coinsEarned = 0,
		dives = 0, -- dives that ended back at camp with the pack
		lampOuts = 0,
		playSeconds = 0,
	},
	meta = { firstJoinAt = 0, lastJoinAt = 0, sessions = 0 }, -- written by the core on join
}

-- One entry per version step: { from = 1, run = function(data) ... end }.
DataTemplate.migrations = {}

return DataTemplate
