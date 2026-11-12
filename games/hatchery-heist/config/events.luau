--!strict
-- Timed events and the Giant Golden Egg (Alex, Nov 7 2026).
--
-- Every 24-hour cycle has one event window of `windowMinutes`, at a random
-- time between `earliestHour` and `latestHour` hours into the cycle, running
-- one event from `rotation`. The cycle starts at `cycleStartHourUtc` every
-- day. Which time and which event come from a hash of the cycle number and
-- `seed` (src/shared/Events.luau), so every server, and every client's
-- countdown, agrees with no messages between servers. Change `seed` to
-- reshuffle every future day.
--
-- The rotation goes through every event once before any repeats, in an
-- order shuffled per round, and never runs the same event two days in a row.
--
-- The Giant Golden Egg sits on the Golden Nest in the middle of the map
-- all day, every day. It hatches Epic or better on its own odds table
-- (config/eggs.luau GiantEgg, Alex Nov 12), shown on its odds card before
-- anyone buys. Each player can buy it once a cycle: for coins while the
-- day's event runs (giantEgg below), for Robux the rest of the day
-- (monetization.products.GiantEgg).
return {
	seed = 20261107,
	-- 12:00 UTC: 7 am in New York, 4 am in Los Angeles. Cycles, and the Giant
	-- Egg's "once a day", turn over here.
	cycleStartHourUtc = 12,
	windowMinutes = 30,
	-- The window starts between 3 and 15 hours into the cycle: 15:00 to 03:00
	-- UTC, which is 10 am to 10 pm in New York and 7 am to 7 pm in Los Angeles,
	-- so most players' evenings can catch it. 0 and 23.5 would allow any time.
	earliestHour = 3,
	latestHour = 15,
	-- The start lands on a whole number of these minutes (a clean "8:35 pm").
	startStepMinutes = 5,
	-- The banner counts down to the next event once it is this close; before
	-- that it shows the next event's name and how many hours away it is.
	announceMinutes = 60,
	rotation = { "EggSale", "FastHatch", "MoneyRush", "LuckyHatch" },
	kinds = {
		-- Every market egg costs this share of its price (0.5 = half price).
		EggSale = {
			title = "Egg Sale",
			blurb = "Every market egg is half price!",
			color = { 255, 120, 70 },
			priceFactor = 0.5,
		},
		-- Eggs bought during the event hatch in this share of their time.
		FastHatch = {
			title = "Speedy Incubators",
			blurb = "Eggs bought now hatch twice as fast!",
			color = { 80, 170, 255 },
			hatchFactor = 0.5,
		},
		-- Creatures on your floors earn this many times their coins.
		MoneyRush = {
			title = "Money Rush",
			blurb = "Your creatures earn double coins!",
			color = { 255, 196, 40 },
			incomeFactor = 2,
		},
		-- Eggs bought now: each tier's weight is multiplied by its number and
		-- the egg's odds are scaled back to exactly 100% (the odds card shows
		-- the boosted chances). Rising with rarity, so even the Premium Egg,
		-- which has no Commons, gets luckier.
		LuckyHatch = {
			title = "Lucky Hatch",
			blurb = "Up to 3x luck on rare hatches!",
			color = { 180, 110, 255 },
			rarityMultipliers = { Rare = 1.5, ["Ultra Rare"] = 2, Epic = 2.5, Legendary = 3, Godly = 3 },
		},
	},
	giantEgg = {
		-- Where its base stands: on the Golden Nest's bed (1.4 studs up), the
		-- middle of the map.
		position = { 0, 1.4, 0 },
		-- Studs tall, about four times a market egg.
		height = 11,
		promptDistance = 16,
		-- Alex, Nov 7: an event special. While the day's event runs it
		-- costs coins instead of Robux (outside it, the Robux price in
		-- monetization.luau): the larger of coinPriceMin and
		-- coinPriceIncomeHours of the buyer's income right now, so it is
		-- a large sum at every stage (economy thread's proposal, section 5).
		coinPriceMin = 250_000_000,
		coinPriceIncomeHours = 6,
	},
}
