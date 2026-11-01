--!strict
-- Game passes and developer products. Each item's name, Robux price and
-- description are in `listings` below; the laptop creates the item on Roblox
-- from them and records its id. Ids stay 0 until then; an id of 0 is never
-- prompted and never owned (the Studio test panel can still grant it). Each
-- experience has its own ids: put Staging's and Production's under
-- `environments` below (ops/SHOP.md).
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
			DoubleCash = {
				name = "2x Cash",
				robux = 199,
				description = "Every sale pays double, at the counter and from your cooks, forever.",
			},
			AutoCollect = {
				name = "Auto-Collect",
				robux = 99,
				description = "Your register empties into your cash by itself. No more trips to the register.",
			},
			FestivalBundle = {
				name = "Festival Bundle",
				robux = 99,
				description = "Festival decorations and outfits for your food empire.",
			},
		},
		products = {
			CashPackSmall = { name = "5K Cash", robux = 25, description = "5,000 cash, added right away." },
			CashPackMedium = { name = "50K Cash", robux = 99, description = "50,000 cash, added right away." },
			CashPackLarge = {
				name = "600K Cash",
				robux = 399,
				description = "600,000 cash, added right away. The best value per Robux.",
			},
			InstantBuild = {
				name = "Instant Build",
				robux = 25,
				description = "Finishes the station you're building right now.",
			},
			SpeedBoost = {
				name = "Speed Boost",
				robux = 49,
				description = "Customers come twice as fast for 15 minutes. Buying again adds more time.",
			},
		},
	},
	-- Timed boosts sold as products. While SpeedBoost runs, customers arrive
	-- `customerMultiplier` times as often.
	boosts = {
		SpeedBoost = { durationSeconds = 900, customerMultiplier = 2 },
	},
}
