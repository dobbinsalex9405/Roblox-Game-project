--!strict
-- Charms (the items) and the claw machine that hands them out.
-- Spec: /mnt/project-files/plans/hatchery-heist/charms-claw-build-spec.md
-- (revision 1, Nov 7 2026); design doc for Alex:
-- https://claude.ai/artifact/4YJAcCLyU3R8srSscYCLkf. Code: shared/Charms.luau
-- (equip, stats, fusion), shared/Claw.luau (prices, odds, guarantees, pity),
-- server/CharmService.luau, client/CharmsView, ClawView and CharmView.
--
-- A charm's `id` is what the save stores: never rename one.
return {
	-- The seven creature tiers, lowest first (same names and colours as the
	-- creatures: Layout.RARITIES / Layout.rarityColor).
	tiers = { "Common", "Uncommon", "Rare", "Ultra Rare", "Epic", "Legendary", "Godly" },

	-- The six kinds, in the order the inventory lists them. `stat` is what
	-- the kind changes (Charms.stats); `steal` kinds only matter once Egg
	-- Heist exists and stay out of the claw, the Charm Counter and the
	-- inventory filter while `stealCharms` is false.
	kinds = {
		{ id = "Feeder", stat = "income", steal = false, icon = "🌽", label = "Coins" },
		{ id = "Clover", stat = "luck", steal = false, icon = "🍀", label = "Luck" },
		{ id = "Warmer", stat = "hatchCut", steal = false, icon = "🔥", label = "Hatch" },
		{ id = "Ward", stat = "shieldSeconds", steal = true, icon = "🛡️", label = "Shield" },
		{ id = "Snare", stat = "thiefSlow", steal = true, icon = "🕸️", label = "Snare" },
		{ id = "Sneak", stat = "carryBonus", steal = true, icon = "👟", label = "Sneak" },
	},
	-- Off until Egg Heist reads the Ward, Snare and Sneak stats.
	stealCharms = false,

	-- Every charm, cheapest to rarest within its kind. `value`: income as a
	-- fraction added (0.03 = +3%), luck as a multiplier on Rare-and-rarer
	-- hatch weights, hatchCut as a fraction of hatch time removed, shield in
	-- seconds, thief slow and carry bonus as fractions.
	charms = {
		{ id = "FeedBag", name = "Feed Bag", kind = "Feeder", tier = "Common", value = 0.01 },
		{ id = "CornBucket", name = "Corn Bucket", kind = "Feeder", tier = "Uncommon", value = 0.02 },
		{ id = "HoneyPot", name = "Honey Pot", kind = "Feeder", tier = "Rare", value = 0.03 },
		{ id = "SilverTrough", name = "Silver Trough", kind = "Feeder", tier = "Ultra Rare", value = 0.045 },
		{ id = "GoldenFeeder", name = "Golden Feeder", kind = "Feeder", tier = "Epic", value = 0.06 },
		{ id = "RoyalBanquet", name = "Royal Banquet", kind = "Feeder", tier = "Legendary", value = 0.08 },
		{ id = "Cornucopia", name = "Cornucopia", kind = "Feeder", tier = "Godly", value = 0.12 },

		{ id = "CloverSprig", name = "Clover Sprig", kind = "Clover", tier = "Common", value = 1.02 },
		{
			id = "FourLeafClover",
			name = "Four-Leaf Clover",
			kind = "Clover",
			tier = "Uncommon",
			value = 1.04,
		},
		{ id = "LuckyHorseshoe", name = "Lucky Horseshoe", kind = "Clover", tier = "Rare", value = 1.06 },
		{ id = "RabbitsFoot", name = "Rabbit's Foot", kind = "Clover", tier = "Ultra Rare", value = 1.08 },
		{ id = "Wishbone", name = "Wishbone", kind = "Clover", tier = "Epic", value = 1.11 },
		{ id = "ShootingStar", name = "Shooting Star", kind = "Clover", tier = "Legendary", value = 1.15 },
		{ id = "StarOfFortune", name = "Star of Fortune", kind = "Clover", tier = "Godly", value = 1.2 },

		{ id = "StrawNest", name = "Straw Nest", kind = "Warmer", tier = "Common", value = 0.03 },
		{ id = "WoolBlanket", name = "Wool Blanket", kind = "Warmer", tier = "Uncommon", value = 0.05 },
		{ id = "HeatLamp", name = "Heat Lamp", kind = "Warmer", tier = "Rare", value = 0.07 },
		{ id = "EmberStone", name = "Ember Stone", kind = "Warmer", tier = "Ultra Rare", value = 0.09 },
		{ id = "Sunstone", name = "Sunstone", kind = "Warmer", tier = "Epic", value = 0.12 },
		{
			id = "PhoenixFeather",
			name = "Phoenix Feather",
			kind = "Warmer",
			tier = "Legendary",
			value = 0.15,
		},
		{ id = "DragonsHearth", name = "Dragon's Hearth", kind = "Warmer", tier = "Godly", value = 0.2 },

		{ id = "PicketFence", name = "Picket Fence", kind = "Ward", tier = "Common", value = 10 },
		{ id = "GuardBell", name = "Guard Bell", kind = "Ward", tier = "Uncommon", value = 15 },
		{ id = "IronGate", name = "Iron Gate", kind = "Ward", tier = "Rare", value = 20 },
		{ id = "WardRune", name = "Ward Rune", kind = "Ward", tier = "Ultra Rare", value = 30 },
		{ id = "CrystalDome", name = "Crystal Dome", kind = "Ward", tier = "Epic", value = 40 },
		{ id = "AegisPlume", name = "Aegis Plume", kind = "Ward", tier = "Legendary", value = 60 },
		{ id = "CelestialBastion", name = "Celestial Bastion", kind = "Ward", tier = "Godly", value = 90 },

		{ id = "MudPuddle", name = "Mud Puddle", kind = "Snare", tier = "Common", value = 0.03 },
		{ id = "StickyHoney", name = "Sticky Honey", kind = "Snare", tier = "Uncommon", value = 0.05 },
		{ id = "TangleVine", name = "Tangle Vine", kind = "Snare", tier = "Rare", value = 0.07 },
		{ id = "FrostFloor", name = "Frost Floor", kind = "Snare", tier = "Ultra Rare", value = 0.09 },
		{ id = "QuicksandRug", name = "Quicksand Rug", kind = "Snare", tier = "Epic", value = 0.12 },
		{ id = "GravityBell", name = "Gravity Bell", kind = "Snare", tier = "Legendary", value = 0.15 },
		{ id = "TimeSnare", name = "Time Snare", kind = "Snare", tier = "Godly", value = 0.2 },

		{ id = "SoftSocks", name = "Soft Socks", kind = "Sneak", tier = "Common", value = 0.01 },
		{ id = "QuietBoots", name = "Quiet Boots", kind = "Sneak", tier = "Uncommon", value = 0.02 },
		{ id = "ShadowCloak", name = "Shadow Cloak", kind = "Sneak", tier = "Rare", value = 0.03 },
		{ id = "FoxMask", name = "Fox Mask", kind = "Sneak", tier = "Ultra Rare", value = 0.04 },
		{ id = "SwiftGloves", name = "Swift Gloves", kind = "Sneak", tier = "Epic", value = 0.06 },
		{ id = "PhantomCape", name = "Phantom Cape", kind = "Sneak", tier = "Legendary", value = 0.08 },
		{ id = "MoonwalkSlippers", name = "Moonwalk Slippers", kind = "Sneak", tier = "Godly", value = 0.1 },
	},

	-- Equip slots by floors built: `floors` owned at least -> slots.
	slotsByFloor = {
		{ floors = 1, slots = 3 },
		{ floors = 3, slots = 4 },
		{ floors = 6, slots = 5 },
		{ floors = 9, slots = 6 },
	},
	bagSlots = 300, -- charms a player can hold, equipped ones included
	bagWarnAt = 280, -- the bag count turns amber from here

	-- Every luck source together (charms, the Luck Boost, events) never
	-- multiplies a tier's weight by more than this (economy thread, Nov 7).
	luckCap = 3,
	-- Charms and events together never take more than this share off an
	-- egg's hatch time.
	hatchCutCap = 0.5,

	-- Fusion: `fuseCount` charms of one id make one of the same kind, one
	-- tier up, for `fuseFeeShare` of the player's current 1-pull coin price.
	fuseCount = 5,
	fuseFeeShare = 0.1,

	claw = {
		-- A 1-pull costs `incomeMinutes` of the player's best income ever
		-- (all bonuses included), at least `minCoins`, rounded down to three
		-- significant figures. Bigger pulls cost `multiple` times that.
		minCoins = 5000,
		incomeMinutes = 5,
		pulls = {
			{ count = 1, multiple = 1 },
			{ count = 10, multiple = 9, product = "ClawPull10", atLeast = "Rare" },
			{ count = 100, multiple = 80, product = "ClawPull100", atLeast = "Epic" },
		},
		-- The tier odds of every pull, out of `total`. A charm's share of its
		-- tier is split evenly across the active kinds (largest remainder).
		total = 100000,
		tierWeights = {
			Common = 55000,
			Uncommon = 25000,
			Rare = 12000,
			["Ultra Rare"] = 5000,
			Epic = 2200,
			Legendary = 700,
			Godly = 100,
		},
		-- After `pityAt - 1` pulls in a row with nothing `pityTier` or
		-- better, the next is rolled from `pityTier` and up.
		pityAt = 200,
		pityTier = "Legendary",
		-- Players PolicyService keeps from paid random items buy a chosen
		-- charm at the Charm Counter instead, for this many 1-pull prices
		-- (nothing above Rare).
		counter = { Common = 1, Uncommon = 4, Rare = 10 },
		-- The machine in the farm hub: degrees round the ring and studs from
		-- the middle (the Golden Egg Shop is at 22.5 / 62; the machine stands
		-- in front of it, off the shop door's line). Its Pull prompt reaches
		-- `promptDistance` studs; the server sells within `reach`.
		angle = 15,
		radius = 43,
		height = 9, -- studs, the machine's top
		promptDistance = 9,
		reach = 16,
		-- The reveal: seconds for a 1-pull and a 10-pull (tap to skip).
		revealSeconds = { single = 2.5, ten = 3 },
	},

	-- Charms the player wears: small trinkets in a slow ring behind their
	-- shoulders, drawn by each client (client/CharmView).
	worn = {
		size = 0.6, -- studs, each charm's height
		ringRadius = 2,
		height = 1.5, -- studs above the HumanoidRootPart
		behind = 0.9, -- studs the ring's centre sits behind the player
		degreesPerSecond = 20,
		othersRange = 60, -- other players' charms are drawn this close only
		othersMax = 20, -- and for at most this many other players
		lightBrightness = 0.3, -- Legendary and Godly: a soft warm PointLight
		lightRange = 4,
	},
}
