--!strict
-- Game passes and developer products (milestone M5). Ids stay 0 until the
-- item is created on Roblox, after Alex approves prices; an id of 0 is never
-- prompted and never owned (the Studio test panel can still run it). Robux
-- prices live on Roblox, not here. Each experience has its own ids: put
-- Staging's and Production's under `environments` below.
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
		BaitPack = { id = 0, bait = "StormLure", count = 5 },
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
