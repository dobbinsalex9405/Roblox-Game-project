--!strict
-- Every number the update loop decides with (ops/UPDATE_LOOP.md). Change a
-- threshold here and nowhere else: the plan issue prints the values in force,
-- and tools/tests/UpdateLoop.spec.luau checks the gate still matches the
-- scoreboard's (tools/metrics/lib.luau).

return {
	-- Below these sample sizes a rate is noise: the rule that needs it stays quiet
	-- and the plan says "too few players to judge".
	sample = {
		newPlayers7 = 30, -- new players over 7 days, to judge D1 / D7 / onboarding
		sessions7 = 40, -- sessions over 7 days, to judge session length and friend play
		playerDays7 = 60, -- sum of daily players over 7 days, to judge spending
		prompts = 20, -- purchase prompts of one item over 7 days, to judge its conversion
		baselinePlayers = 20, -- average daily players before a release or a regression check
		baselineRobux = 100, -- average daily Robux before a Robux regression counts
	},

	-- What "good" means. d1 / avgMinutes / risingDays are the launch gate (CLAUDE.md).
	targets = {
		d1 = 0.25,
		avgMinutes = 10,
		risingDays = 3,
		d7 = 0.08, -- pooled D7 return
		payerRate = 0.01, -- payers / players, per day, pooled over 7 days
		robuxPerPlayer = 1.0, -- Robux per daily player, pooled over 7 days
		friendShare = 0.15, -- share of sessions with a friend on the server
		conversion = 0.05, -- purchases / prompts for one item
	},

	-- Below these the problem is urgent enough to lead the week (level "high").
	severe = {
		d1 = 0.20,
		avgMinutes = 6,
	},

	-- A game whose retention is "good enough" to spend a week on money or content.
	retained = {
		d1 = 0.20,
		avgMinutes = 8,
	},

	-- Release checks: post-release days against up to 7 days before.
	release = {
		fastWindowDays = 3, -- days after a release in which a drop is a rollback question
		fastMinDays = 2, -- full days after a release before a drop can raise that question
		reviewAfterDays = 3, -- days of data after a release before the review gives a verdict
		reviewDays = 7, -- days on each side that the review compares
		sessionDrop = 0.33, -- average session down by a third or more
		robuxPerPlayerDrop = 0.30,
		playersDrop = 0.30,
		d1DropPoints = 0.10, -- D1 down 10 percentage points or more
		better = 0.10, -- up 10% or more on a metric counts as better
	},

	-- Day over day: yesterday against the 7 days before it.
	regression = {
		drop = 0.30,
	},

	-- Open tracking issues that make bug fixing the week's focus.
	bugs = {
		sev2 = 3,
	},

	-- Players over the last 7 days against the 7 before: at or below this is "not growing".
	flatTrend = 0.0,

	-- New players over 7 days below this, after `discoveryAfterDays` live: the store page is the problem.
	discoveryAfterDays = 3,

	-- Who can find each game. Every game starts at Ages 16+: opening it to under-16
	-- players takes account steps only Alex can do (ID verification and 2-step
	-- verification, then per game 250 highly engaged players or a refundable 1,000
	-- Robux fee). Set a game to "all" here once Roblox shows it to every age.
	audience = {
		default = "16+",
		games = {} :: { [string]: string },
	},

	-- Days live before D7 is judged (a full week of D7 cohorts behind it).
	returnAfterDays = 14,
}
