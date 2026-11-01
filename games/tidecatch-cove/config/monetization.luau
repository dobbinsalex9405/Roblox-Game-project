--!strict
-- Game passes and developer products (milestone M5). Each item's name, Robux
-- price and description are in `listings` below; the laptop creates the item
-- on Roblox from them and records its id. Ids stay 0 until then; an id of 0
-- is never prompted and never owned (the Studio test panel can still run
-- it). Each experience has its own ids: put Staging's and Production's under
-- `environments` below.
return {
	passes = {
		AutoReel = 0,
		ExtraPools = 0,
		SellMultiplier = 0,
	},
	products = {
		-- Every creature in your pools grows `stages` growth stages at once.
		GrowthBoost = { id = 0, stages = 1 },
		-- The bait shop restocks for you right now.
		RestockSkip = { id = 0 },
		-- A fixed bundle of Robux-only bait (config/fishing.luau). Not random
		-- itself, but each cast with it is a paid roll with its odds shown.
		-- Same price as Mystery Bait, whose average bundle is worth a little
		-- more, so the random buy is never the worse deal (ops/PRICING.md).
		BaitPack = { id = 0, bait = "StormLure", count = 4 },
		-- A random bundle from `mysteryBait` below: a paid random item, with
		-- its odds shown before Buy and refused for restricted players.
		MysteryBait = { id = 0 },
	},
	-- Ids in the Staging and Production experiences. A key left out keeps the
	-- id above (0 = not created there yet).
	environments = {
		staging = { passes = {}, products = {} },
		production = { passes = {}, products = {} },
	},
	-- What each item is called, costs and says on Roblox. The laptop creates
	-- the Game Passes and Developer Products from these lines, so `name`
	-- matches the shop's name exactly. Prices follow the studio price ladder
	-- (ops/PRICING.md); `lune run tools/pricing/run` rewrites that file's table
	-- from here, and a test fails if the two disagree.
	listings = {
		passes = {
			AutoReel = {
				name = "Auto-reel",
				robux = 149,
				description = "Bites reel themselves in at an average player's success rate. Skill still pays.",
			},
			ExtraPools = {
				name = "Extra Pools",
				robux = 149,
				description = "More tide pools, so you can raise more creatures at once.",
			},
			SellMultiplier = {
				name = "Sell Multiplier",
				robux = 199,
				description = "Every creature you sell pays double, forever.",
			},
		},
		products = {
			BaitPack = {
				name = "Storm Lure Pack",
				robux = 25,
				description = "4 Storm Lures: strong bait for rare fish. Each cast's exact odds show on the dock.",
			},
			MysteryBait = {
				name = "Mystery Bait",
				robux = 25,
				description = "A random bundle of Storm Lures or Pearl Lures. Exact odds are shown before you buy.",
			},
			GrowthBoost = {
				name = "Growth Boost",
				robux = 49,
				description = "Every creature in your pools grows one stage right now.",
			},
			RestockSkip = {
				name = "Restock Skip",
				robux = 25,
				description = "The bait shop restocks for you right now.",
			},
		},
	},
	-- What Mystery Bait gives, out of 10,000. The odds screen shows exactly
	-- this table (odds table id "MysteryBait"); each outcome is `count` of a
	-- Robux-only bait.
	mysteryBait = {
		{ id = "StormLureX3", bait = "StormLure", count = 3, weight = 6000 },
		{ id = "StormLureX6", bait = "StormLure", count = 6, weight = 2500 },
		{ id = "PearlLureX2", bait = "PearlLure", count = 2, weight = 1200 },
		{ id = "PearlLureX5", bait = "PearlLure", count = 5, weight = 300 },
	},
	-- What the Sell Multiplier pass multiplies sale prices by.
	sellMultiplier = 2,
}
