--!strict
-- Game passes and developer products (milestone M5). Ids stay 0 until the
-- item is created on Roblox, after Alex approves prices; an id of 0 is never
-- offered, never registered and never owned. Robux prices live on Roblox.
return {
	passes = {
		AutoReel = 0,
		ExtraPools = 0,
		SellMultiplier = 0,
	},
	products = {
		GrowthBoost = { id = 0 },
		RestockSkip = { id = 0 },
		BaitPack = { id = 0 },
		MysteryBait = { id = 0 },
	},
	-- What the Sell Multiplier pass multiplies sale prices by.
	sellMultiplier = 2,
}
