--!strict
-- Coins and the bait shop. Coins are never sold for Robux in this game, so
-- a free cast or a cast with coin-bought bait is not a paid random item.
-- If coin packs are ever added, every bait cast becomes paid (see
-- src/shared/Catch.luau) and the shop needs Alex's approval first.
return {
	startingCoins = 100,
	coinsMax = 1e15,
	-- Bait a brand-new player starts with (given once, on their first join).
	startingBait = { Worm = 10 },
	-- The bait shop restocks this often, on the server clock, the same moment
	-- in every server. Each bait's `stock` (config/fishing.luau) is how many
	-- a player may buy per restock.
	restockSeconds = 600,
}
