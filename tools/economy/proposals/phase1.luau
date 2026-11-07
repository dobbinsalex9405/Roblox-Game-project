--!strict
-- Phase 1 (config only, Nov 7 2026 economy proposal): what the proposed
-- config/ changes do, so the simulator can compare them with main before
-- they are written into the game. Once merged, main and this patch agree.
return function(config: any)
	local e = config.economy
	e.tower.floorPrices =
		{ 25000, 150000, 750000, 3000000, 12000000, 40000000, 120000000, 300000000, 750000000 }
	e.rebirth.baseCost = 50000000
	e.rebirth.costGrowth = 4

	-- Epic/Legendary per floor spot above the tier below (an Epic takes 2
	-- spots, a Legendary 3): Epic 190-260, Legendary 450-700 (to_config BANDS).
	local sp = config.creatures.species
	sp.Dragonling.coinsPerSecond = 190
	sp.CrystalStag.coinsPerSecond = 225
	sp.MoonUnicorn.coinsPerSecond = 260
	sp.Phoenix.coinsPerSecond = 575
	sp.ThunderGriffin.coinsPerSecond = 700

	local byId = {}
	for _, egg in config.eggs do
		byId[egg.id] = egg
	end
	-- Whole weights out of 100,000 (the fixed-order alternative builds one
	-- cycle of `total` eggs, so the total stays 100,000 for now).
	byId.BasicEgg.tiers = {
		Common = 92000,
		Uncommon = 7200,
		Rare = 700,
		["Ultra Rare"] = 90,
		Epic = 8, -- 1 in 12,500
		Legendary = 2, -- 1 in 50,000
	}
	byId.MeadowEgg.priceCoins = 1500
	byId.MeadowEgg.hatchSeconds = 30
	byId.MeadowEgg.tiers = {
		Common = 58000,
		Uncommon = 37000,
		Rare = 4500,
		["Ultra Rare"] = 450,
		Epic = 45, -- 1 in 2,222
		Legendary = 5, -- 1 in 20,000
	}
	byId.MoonlitEgg.priceCoins = 20000
	byId.MoonlitEgg.tiers = {
		Uncommon = 66600,
		Rare = 30000,
		["Ultra Rare"] = 3200,
		Epic = 190, -- 1 in 526
		Legendary = 9, -- 1 in 11,111
		Godly = 1, -- 1 in 100,000
	}
end
