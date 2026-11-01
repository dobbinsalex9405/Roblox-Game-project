--!strict
-- Cash, customers, rebirth and offline earnings. Every number here is tunable
-- without code changes; any change to a live game's economy needs Alex's
-- approval (brief, Part 1).
return {
	startingCash = 50,
	cashMax = 1e15,

	-- The station every new restaurant (and every rebirth) starts with, built,
	-- at spot 1. It must be a Cart Corner station.
	starterStation = "HotDogCart",

	customers = {
		-- Counter customers (foot traffic, config/districts) wait for the player
		-- to serve them. Past this many, new arrivals walk on by. Long enough
		-- that a player who looks in every couple of minutes loses nobody.
		queueMax = 30,
		-- A counter customer pays for the whole menu, plus this bonus (0.25 = +25%).
		handServeBonus = 0.25,
	},

	rebirth = {
		-- Needs every district open. Tuned with tests/Bot.luau: an attentive
		-- player gets here after about 4.5 hours of play, one who looks in
		-- every 5 minutes after about 7.5 (tests/Pacing.spec.luau).
		cost = 100000000,
		-- Launch scope has one rebirth tier (Wave 1 plan); more come after the gate.
		maxRebirths = 1,
		incomeBonusPerRebirth = 0.5, -- +50% cash from every customer
	},

	-- With the Auto-Collect pass, the register's cash moves into the wallet this often (seconds).
	autoCollectSeconds = 30,

	-- Multiplier for the 2x Cash pass.
	doubleCashMultiplier = 2,

	-- Offline earnings: a fraction of what the cooks sell, for at most this long.
	-- The counter queue keeps filling while away (up to queueMax), so a full
	-- line is waiting on return.
	offline = {
		rate = 0.5,
		maxSeconds = 2 * 60 * 60,
	},
}
