--!strict
-- The lagoon: fishing spots and their catch odds, bait, rods, and the reel
-- minigame. Every number here is tunable without code changes; any change to
-- a live game needs Alex's approval (brief, Part 1).
--
-- Catch odds: each spot lists whole-number weights out of 10,000 (1 = 0.01%)
-- that must total exactly 10,000. Bait and rods multiply weights by rarity,
-- and the result is rescaled to 10,000 again (packages/core/src/Odds.luau), so
-- the odds board always shows exactly what the server rolls.
type Outcome = { id: string, weight: number }
type Spot = { id: string, minRod: number, lowTideOnly: boolean, outcomes: { Outcome } }
type Bait = {
	id: string,
	priceCoins: number,
	stock: number,
	robux: boolean,
	rarityMultipliers: { [string]: number },
}
type Rod = { id: string, priceCoins: number, biteTime: number, zone: number, luck: { [string]: number } }
type ReelRarity = { fill: number, drain: number, fishSpeed: number }
type Fishing = {
	spots: { Spot },
	bait: { Bait },
	rods: { Rod },
	castReach: number,
	castCooldownSeconds: number,
	biteSeconds: { min: number, max: number },
	reel: {
		hookSeconds: number,
		reactionSeconds: number,
		startProgress: number,
		timeoutSeconds: number,
		toleranceSeconds: number,
		rarity: { [string]: ReelRarity },
		autoSeconds: number,
		autoSuccess: { [string]: number },
	},
	bucketSlots: number,
}

local fishing: Fishing = {
	spots = {
		{
			id = "Shallows",
			minRod = 1,
			lowTideOnly = false,
			outcomes = {
				{ id = "SandShrimp", weight = 1800 },
				{ id = "TideMinnow", weight = 1800 },
				{ id = "PebbleCrab", weight = 1500 },
				{ id = "BubbleGoby", weight = 1300 },
				{ id = "SeaSnail", weight = 1200 },
				{ id = "HermitCrab", weight = 900 },
				{ id = "Starfish", weight = 700 },
				{ id = "Seahorse", weight = 400 },
				{ id = "Lionfish", weight = 250 },
				{ id = "Nautilus", weight = 100 },
				{ id = "GlowSquid", weight = 40 },
				{ id = "PearlWhale", weight = 10 },
			},
		},
		{
			id = "Reef",
			minRod = 2,
			lowTideOnly = false,
			outcomes = {
				{ id = "BubbleGoby", weight = 1500 },
				{ id = "StripedPerch", weight = 1500 },
				{ id = "MoonJelly", weight = 1200 },
				{ id = "Pufferfish", weight = 1100 },
				{ id = "BlueTang", weight = 1100 },
				{ id = "SeaUrchin", weight = 900 },
				{ id = "Seahorse", weight = 700 },
				{ id = "Lionfish", weight = 700 },
				{ id = "MorayEel", weight = 500 },
				{ id = "Nautilus", weight = 400 },
				{ id = "CoralDragon", weight = 300 },
				{ id = "PearlWhale", weight = 100 },
			},
		},
		{
			id = "KelpForest",
			minRod = 3,
			lowTideOnly = false,
			outcomes = {
				{ id = "KelpPipefish", weight = 1600 },
				{ id = "StripedPerch", weight = 1200 },
				{ id = "Octopus", weight = 1300 },
				{ id = "Pufferfish", weight = 900 },
				{ id = "BlueTang", weight = 800 },
				{ id = "MorayEel", weight = 1000 },
				{ id = "MantaRay", weight = 900 },
				{ id = "SeaTurtle", weight = 800 },
				{ id = "GlowSquid", weight = 600 },
				{ id = "GhostShark", weight = 500 },
				{ id = "CoralDragon", weight = 200 },
				{ id = "TideLeviathan", weight = 200 },
			},
		},
		{
			-- Opens only at low tide. The tide cycle arrives in milestone M4;
			-- until then this spot stays closed.
			id = "TideFlats",
			minRod = 1,
			lowTideOnly = true,
			outcomes = {
				{ id = "PebbleCrab", weight = 2000 },
				{ id = "SeaSnail", weight = 1500 },
				{ id = "HermitCrab", weight = 1500 },
				{ id = "Starfish", weight = 1500 },
				{ id = "SeaUrchin", weight = 1300 },
				{ id = "Octopus", weight = 800 },
				{ id = "SeaTurtle", weight = 700 },
				{ id = "Nautilus", weight = 500 },
				{ id = "CoralDragon", weight = 150 },
				{ id = "TideLeviathan", weight = 50 },
			},
		},
	},

	-- Bait is used up by one cast and multiplies the weights of the rarities
	-- listed. Casting with no bait is always allowed. `robux` marks a bait that
	-- only comes from Robux products (Bait Pack, Mystery Bait): it is never
	-- sold for coins (price and stock 0), and every cast with it is a paid
	-- random roll, policy-checked, with its odds on the dock board and the
	-- Cast card. Coin bait and Robux bait never share an id, so a cast is paid
	-- exactly when its bait came from Robux.
	-- Multipliers never fall as rarity rises, so bait can only shift a catch
	-- toward rarer fish. Tuned so each bait pays back about twice its price
	-- at Tiny sale prices on the spot it suits (Worm in the Shallows, Krill on
	-- the Reef, Glow Bait in the Kelp Forest); the Golden Lure breaks even at
	-- Tiny and pays through Legendaries raised in pools (Config.spec checks).
	bait = {
		{
			id = "Worm",
			priceCoins = 6,
			stock = 40,
			robux = false,
			rarityMultipliers = { Uncommon = 2, Rare = 2, Epic = 2, Legendary = 2 },
		},
		{
			id = "Krill",
			priceCoins = 30,
			stock = 20,
			robux = false,
			rarityMultipliers = { Uncommon = 2, Rare = 3, Epic = 3, Legendary = 3 },
		},
		{
			id = "GlowBait",
			priceCoins = 150,
			stock = 6,
			robux = false,
			rarityMultipliers = { Uncommon = 1.5, Rare = 3, Epic = 5, Legendary = 5 },
		},
		{
			id = "GoldenLure",
			priceCoins = 600,
			stock = 2,
			robux = false,
			rarityMultipliers = { Uncommon = 1.5, Rare = 3, Epic = 6, Legendary = 12 },
		},
		{
			id = "StormLure",
			priceCoins = 0,
			stock = 0,
			robux = true,
			rarityMultipliers = { Uncommon = 2, Rare = 4, Epic = 6, Legendary = 8 },
		},
		{
			id = "PearlLure",
			priceCoins = 0,
			stock = 0,
			robux = true,
			rarityMultipliers = { Uncommon = 2, Rare = 4, Epic = 10, Legendary = 20 },
		},
	},

	rods = {
		{ id = "DriftwoodRod", priceCoins = 0, biteTime = 1, zone = 0.28, luck = {} },
		{
			id = "ReefRod",
			priceCoins = 1500,
			biteTime = 0.8,
			zone = 0.33,
			luck = { Uncommon = 1.2, Rare = 1.3 },
		},
		{
			id = "StormRod",
			priceCoins = 15000,
			biteTime = 0.65,
			zone = 0.38,
			luck = { Uncommon = 1.3, Rare = 1.6, Epic = 1.6, Legendary = 1.5 },
		},
	},

	-- How close (studs) a player must stand to a spot's dock to cast there.
	castReach = 16,
	-- Shortest time between two casts, so a script cannot spam the lagoon.
	castCooldownSeconds = 1,
	-- Seconds from cast to bite, picked evenly in [min, max], times the rod's biteTime.
	biteSeconds = { min = 3, max = 8 },

	-- The reel minigame (src/shared/Reel.luau). After the bite the player has
	-- `hookSeconds` to tap and set the hook; then a bar starts at
	-- `startProgress`, fills while the fish is in the catch zone and drains
	-- while it is out. Full = caught, empty or `timeoutSeconds` = it got away.
	reel = {
		hookSeconds = 3,
		-- A hook faster than this after the bite is not a human reaction.
		reactionSeconds = 0.2,
		startProgress = 0.3,
		timeoutSeconds = 30,
		-- Clock and frame slack the server allows on the shortest possible reel.
		toleranceSeconds = 0.25,
		-- Per rarity: progress per second in the zone, drain per second out
		-- of it, and how fast the fish darts (bar widths per second).
		rarity = {
			Common = { fill = 0.4, drain = 0.14, fishSpeed = 0.18 },
			Uncommon = { fill = 0.33, drain = 0.16, fishSpeed = 0.23 },
			Rare = { fill = 0.27, drain = 0.18, fishSpeed = 0.28 },
			Epic = { fill = 0.22, drain = 0.2, fishSpeed = 0.34 },
			Legendary = { fill = 0.18, drain = 0.22, fishSpeed = 0.38 },
		},
		-- The Auto-reel pass: the server lands the fish on its own, at about
		-- an average player's success rate, so skill still pays. It takes
		-- `autoSeconds` longer than the fastest possible human reel.
		autoSeconds = 2,
		autoSuccess = { Common = 0.9, Uncommon = 0.85, Rare = 0.7, Epic = 0.5, Legendary = 0.25 },
	},

	-- Caught creatures wait in the bucket until they are placed in a pool or
	-- sold. A catch that does not fit sells at once.
	bucketSlots = 12,
}

return fishing
