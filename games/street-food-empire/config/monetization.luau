--!strict
-- Game passes and developer products. Ids stay 0 until the item is created on
-- Roblox (at M5, after Alex approves prices); an id of 0 is never offered,
-- never registered and never owned. Robux prices live on Roblox, not here.
--
-- Nothing in this game is random, paid or not, so there is no odds screen:
-- every meal's value and every purchase's result is shown before buying.
-- The monthly subscription (daily cash bonus) and private servers are set up
-- on Roblox at M5.
return {
	passes = {
		DoubleCash = 0,
		AutoCollect = 0,
		FestivalBundle = 0, -- festival cosmetics (M4)
	},
	products = {
		CashPackSmall = { id = 0, cash = 5000 },
		CashPackMedium = { id = 0, cash = 50000 },
		CashPackLarge = { id = 0, cash = 600000 },
		InstantBuild = { id = 0 },
		SpeedBoost = { id = 0 },
	},
	-- Timed boosts sold as products. While SpeedBoost runs, customers arrive
	-- `customerMultiplier` times as often.
	boosts = {
		SpeedBoost = { durationSeconds = 900, customerMultiplier = 2 },
	},
}
