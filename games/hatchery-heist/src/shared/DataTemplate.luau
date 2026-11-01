--!strict
-- Saved data, version 1 (plan section 7). Never remove or rename a field here:
-- add a migration (see packages/core/src/DataService.luau) and bump `version`.

local DataTemplate = {}

DataTemplate.template = {
	version = 1,
	coins = 50, -- matches config/economy.startingCoins; checked by tests
	pendingCoins = 0, -- earned but not collected yet (may hold a fraction)
	lastIncomeAt = 0, -- unix seconds income was last added to pendingCoins
	rebirths = 0,
	slots = 3, -- incubator slots unlocked
	incubators = {}, -- { { slot, eggId, startedAt, readyAt, outcome } }
	eggsBought = {}, -- { [eggId] = count }, drives the fixed-order alternative
	creatures = {}, -- { { uid, speciesId, mutation, slot?, eggId, hatchedAt } }; slot nil = storage
	nextUid = 1, -- next creature uid
	mountUid = "", -- creature being ridden ("" = on foot)
	decoys = {}, -- decoy eggs placed (M4)
	rebirthArchive = {}, -- creatures from the last 5 rebirths, kept for support
	shieldUntil = 0,
	traps = {},
	boosts = {}, -- { [boostId] = expiresAt }
	receipts = {}, -- recent purchase ids, capped (core Receipts)
	firsts = {}, -- { [moment] = unix seconds } for the onboarding funnel
	stats = { raidsWon = 0, raidsLost = 0, playSeconds = 0 },
	meta = { firstJoinAt = 0, lastJoinAt = 0, sessions = 0 }, -- written by the core on join
}

-- One entry per version step: { from = 1, run = function(data) ... end }.
DataTemplate.migrations = {}

return DataTemplate
