--!strict
-- Saved data, version 1 (plan section 7). Never remove or rename a field here:
-- add a migration (see packages/core/src/DataService.luau) and bump `version`.

local DataTemplate = {}

DataTemplate.template = {
	version = 1,
	coins = 50, -- matches config/economy.startingCoins; checked by tests
	rebirths = 0,
	slots = 3, -- incubator slots unlocked
	incubators = {}, -- { { slot, eggId, startedAt } }
	creatures = {}, -- { { uid, speciesId, mutation, slot } }
	shieldUntil = 0,
	traps = {},
	boosts = {}, -- { [boostId] = expiresAt }
	receipts = {}, -- recent purchase ids, capped (core Receipts)
	stats = { raidsWon = 0, raidsLost = 0, playSeconds = 0 },
	meta = { firstJoinAt = 0, lastJoinAt = 0, sessions = 0 }, -- written by the core on join
}

-- One entry per version step: { from = 1, run = function(data) ... end }.
DataTemplate.migrations = {}

return DataTemplate
