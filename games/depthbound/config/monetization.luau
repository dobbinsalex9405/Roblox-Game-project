--!strict
-- Game passes and developer products (Wave 1 plan, Depthbound: Money). Each
-- item's name, Robux price and description are in `listings` below; the
-- laptop creates the item on Roblox from them and records its id. Ids stay 0
-- until then; an id of 0 is never prompted and never owned (the Studio test
-- panel can still grant it). Each experience has its own ids: put Staging's
-- and Production's under `environments` below.
--
-- No coin packs: coins are never sold for Robux, so nothing bought with coins
-- is a paid random item. The Geode Crate is, and joins the shop at M5 with its
-- odds table, the odds screen and the policy check.
return {
	passes = {
		BiggerPack = 0,
		BetterLamp = 0,
		AutoSell = 0,
	},
	products = {
		-- A full lamp. Kept until used; at most one is poured per dive (plan
		-- recommendation, Alex approves the limit at M5), so diving stays a
		-- choice and not a purchase.
		OilRefill = { id = 0 },
		OreBoost = { id = 0 }, -- see boosts.OreBoost
		GeodeCrate = { id = 0 }, -- M5: not sold until geodes and their odds exist
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
			BiggerPack = {
				name = "Bigger Pack",
				robux = 149,
				description = "Carry more ore on every dive.",
			},
			BetterLamp = {
				name = "Better Lamp",
				robux = 149,
				description = "Your lamp holds more oil, so every dive lasts longer.",
			},
			AutoSell = {
				name = "Auto-Sell",
				robux = 99,
				description = "Your pack sells by itself the moment you're out of the mine.",
			},
		},
		products = {
			OilRefill = {
				name = "Oil Refill",
				robux = 25,
				description = "Fills your lamp mid-dive. One per dive; bought at camp, it waits for your next dive.",
			},
			OreBoost = {
				name = "Ore Boost",
				robux = 49,
				description = "Ore sells for double for 15 minutes. Buying more adds time.",
			},
			GeodeCrate = {
				name = "Geode Crate",
				robux = 49,
				description = "One random geode. Exact odds are shown before you buy.",
			},
		},
	},
	-- Timed boosts. Buying one while it runs adds its time to what is left.
	boosts = {
		OreBoost = { durationSeconds = 900, sellMultiplier = 2 },
	},
}
