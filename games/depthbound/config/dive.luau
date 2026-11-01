--!strict
-- The dive: the server checks every swing, owns the oil meter and decides
-- every lamp-out. Every number is tunable; changes to a live game need Alex's
-- approval (brief, Part 1).
return {
	-- How close (studs, root to block center) a player must be to hit a block.
	reach = 13,
	-- One swing per this many seconds; the server accepts swings this fraction
	-- of the interval apart to allow for lag.
	swingSeconds = 0.3,
	swingTolerance = 0.8,

	-- "Climb out" takes base + perRow seconds per row of depth, burning oil at
	-- `oilPerSecond` all the way up. Running dry on the rope is a lamp-out.
	climb = {
		baseSeconds = 3,
		secondsPerRow = 0.5,
		oilPerSecond = 1,
	},

	-- When the lamp runs dry, the player keeps this share of the pack (the
	-- rest is dropped where they fell) and wakes up at camp.
	lampOut = {
		keepFraction = 0.25,
		minKeep = 1, -- never come back empty-handed from a small haul
	},

	-- The daily return reward: the first sale each (UTC) day of at least
	-- `minPieces` ore pays `multiplier` times (on top of an Ore Boost).
	dailyHaul = {
		multiplier = 2,
		minPieces = 5,
	},
}
