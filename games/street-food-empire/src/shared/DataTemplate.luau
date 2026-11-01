--!strict
-- Saved data, version 1 (Wave 1 plan, Street Food Empire). Never remove or
-- rename a field here: add a migration (see packages/core/src/DataService.luau)
-- and bump `version`.

local DataTemplate = {}

DataTemplate.template = {
	version = 1,
	cash = 50, -- matches config/economy.startingCash; checked by tests
	pendingCash = 0, -- earned by cooks into the register, not collected yet (may hold a fraction)
	queue = 0, -- customers waiting at the counter (may hold a fraction: the next one arriving)
	lastIncomeAt = 0, -- unix seconds the restaurant was last brought up to date
	rebirths = 0,
	districts = 1, -- districts unlocked, counted from the first
	-- { { stationId, spot, level, readyAt } }; starts with config/economy.starterStation built on spot 1
	stations = { { stationId = "HotDogCart", spot = 1, level = 1, readyAt = 0 } },
	cooks = {}, -- { { uid, tier, stationId } }
	nextUid = 1, -- next cook uid
	boosts = {}, -- { [boostId] = expiresAt }
	orderBoard = { day = 0, progress = {}, claimed = false }, -- daily order board (M4)
	festival = { week = 0, score = 0, rewards = {} }, -- weekly food festival (M4)
	rebirthArchive = {}, -- the restaurant before each of the last 5 rebirths, kept for support
	receipts = {}, -- recent purchase ids, capped (core Receipts)
	firsts = {}, -- { [moment] = unix seconds } for the onboarding funnel
	stats = { customersServed = 0, playSeconds = 0 },
	meta = { firstJoinAt = 0, lastJoinAt = 0, sessions = 0 }, -- written by the core on join
}

-- One entry per version step: { from = 1, run = function(data) ... end }.
DataTemplate.migrations = {}

return DataTemplate
