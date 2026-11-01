--!strict
-- Cooks sell for you. Each station can have one cook, who sells that
-- station's dish to walk-up customers at `servesPerMinute`, whether or not the
-- player is at the counter (and, at the offline rate, while they are away).
-- Their sales go into the register. A cook at a station that is still being
-- built waits for it; during an upgrade they keep selling at the old price.
--
-- Hiring costs `cost`, times `costGrowth` for every cook of that tier already
-- working. Tiers are listed from the first to the best; hiring a better tier
-- for a station replaces the cook there.
return {
	tiers = {
		{ id = "Trainee", cost = 100, costGrowth = 1.5, servesPerMinute = 12 },
		{ id = "LineCook", cost = 8000, costGrowth = 1.5, servesPerMinute = 24 },
		{ id = "Chef", cost = 500000, costGrowth = 1.5, servesPerMinute = 48 },
	},
}
