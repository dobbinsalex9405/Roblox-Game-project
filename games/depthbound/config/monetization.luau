--!strict
-- Game passes and developer products (Wave 1 plan, Depthbound: Money). Ids stay
-- 0 until the item is created on Roblox (at M5, after Alex approves prices);
-- an id of 0 is never offered, never registered and never owned. Robux prices
-- live on Roblox, not here.
--
-- No coin packs: coins are never sold for Robux, so nothing bought with coins
-- is a paid random item. The Geode Crate is, and gets an odds screen and a
-- policy check when it arrives at M5.
return {
	passes = {
		BiggerPack = 0,
		BetterLamp = 0,
		AutoSell = 0,
	},
	products = {
		OilRefill = { id = 0 }, -- at most one per dive (plan recommendation; Alex approves at M5)
		OreBoost = { id = 0 },
		GeodeCrate = { id = 0 },
	},
}
