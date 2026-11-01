--!strict
-- Tide pools: where caught creatures grow. One creature per pool. A creature
-- grows through 5 stages by the saved clock, so it keeps growing while the
-- player is away (up to `offline.maxSeconds` of each absence), and sells for
-- more at every stage.
return {
	startingSlots = 2,
	maxSlots = 8,
	-- Coin cost of pool 3, 4, ... (index 1 = the 3rd pool).
	slotCosts = { 400, 1500, 5000, 15000, 50000, 150000 },
	-- Pools the Extra Pool pass adds on top of the ones bought (milestone M5).
	passBonusSlots = 2,

	-- Stage names and value multipliers, Tiny (as caught) to Giant.
	stages = {
		{ name = "Tiny", valueMultiplier = 1 },
		{ name = "Young", valueMultiplier = 1.8 },
		{ name = "Grown", valueMultiplier = 3 },
		{ name = "Large", valueMultiplier = 5 },
		{ name = "Giant", valueMultiplier = 8 },
	},
	-- Seconds to grow one stage, by rarity.
	stageSeconds = {
		Common = 45,
		Uncommon = 90,
		Rare = 180,
		Epic = 420,
		Legendary = 900,
	},

	-- Feeding a pool adds `stageFraction` of a stage's growth at once, at most
	-- once every `cooldownSeconds` per pool. Feeding is free.
	feed = {
		stageFraction = 0.25,
		cooldownSeconds = 90,
	},

	-- Growth while the player is away counts up to this many seconds per absence.
	offline = {
		maxSeconds = 3 * 60 * 60,
	},
}
