--!strict
-- Saved data, version 1 (plan section 7). Never remove or rename a field here:
-- add a migration (see packages/core/src/DataService.luau) and bump `version`.

local DataTemplate = {}

DataTemplate.template = {
	version = 1,
	coins = 200, -- matches config/economy.startingCoins; checked by tests
	pendingCoins = 0, -- earned but not collected yet (may hold a fraction)
	lastIncomeAt = 0, -- unix seconds income was last added to pendingCoins
	rebirths = 0,
	slots = 3, -- incubator slots unlocked
	incubators = {}, -- { { slot, eggId, startedAt, readyAt, outcome } }
	eggsBought = {}, -- { [eggId] = count }, drives the fixed-order alternative
	creatures = {}, -- { { uid, speciesId, mutation, star?, slot?, eggId, hatchedAt } }; slot = first tower pad, nil = inventory; star nil = 1
	nextUid = 1, -- next creature uid
	mountUid = "", -- creature being ridden ("" = on foot)
	decoys = {}, -- { { spot } } decoy eggs on the decoy spots
	guardUid = "", -- creature guarding the base ("" = none)
	rebirthArchive = {}, -- creatures from the last 5 rebirths, kept for support
	shieldUntil = 0, -- unix seconds the shield lasts until
	shieldReadyAt = 0, -- unix seconds the free shield can be raised again
	traps = {}, -- { { spot, kind } } traps on the trap spots
	boosts = {}, -- { [boostId] = expiresAt }
	receipts = {}, -- recent purchase ids, capped (core Receipts)
	firsts = {}, -- { [moment] = unix seconds } for the onboarding funnel
	-- Hatchery Book: { [speciesId] = unix seconds first owned }. Added after
	-- launch of version 1; reconcile fills it in, and join back-fills it from
	-- the creatures a player already has.
	found = {},
	-- Unix seconds the player last opened the book; species found later show
	-- NEW. Added after launch of version 1 (reconcile fills it in as 0).
	bookSeenAt = 0,
	-- The tower (shared/Tower.luau), added after launch of version 1 like
	-- `found`: floors owned (1 to 10), upgrades bought per floor, and
	-- `towerVersion` 1 once a pre-tower save has been placed best-first.
	floors = 1,
	floorUpgrades = {},
	towerVersion = 0,
	-- The Merge Station (shared/Merge.luau), added after launch of version 1
	-- like `found`: merges running (each holds its copies whole), extra
	-- merge slots bought, and "Finish now" purchases kept for the next merge.
	merges = {},
	mergeSlotsBought = 0,
	mergeRushes = 0,
	daily = { lastDay = 0, streak = 0 }, -- Daily Rewards: UTC day last claimed, reward claimed then
	stats = { raidsWon = 0, raidsLost = 0, playSeconds = 0 },
	meta = { firstJoinAt = 0, lastJoinAt = 0, sessions = 0 }, -- written by the core on join
}

-- One entry per version step: { from = 1, run = function(data) ... end }.
DataTemplate.migrations = {}

return DataTemplate
