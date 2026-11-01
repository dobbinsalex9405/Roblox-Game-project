--!strict
-- Game passes and developer products (Wave 1 plan, Depthbound: Money). Ids stay
-- 0 until the item is created on Roblox (at M5, after Alex approves prices);
-- an id of 0 is never prompted and never owned (the Studio test panel can
-- still grant it). Robux prices live on Roblox, not here. Each experience has
-- its own ids: put Staging's and Production's under `environments` below.
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
	-- Timed boosts. Buying one while it runs adds its time to what is left.
	boosts = {
		OreBoost = { durationSeconds = 900, sellMultiplier = 2 },
	},
}
