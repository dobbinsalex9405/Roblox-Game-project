--!strict
-- Coins, incubators and rebirth. Every number here is tunable without code
-- changes; any change to a live game's economy needs Alex's approval (brief, Part 1).
return {
	startingCoins = 200,
	coinsMax = 1e15,

	incubators = {
		startingSlots = 3,
		maxSlots = 12,
		-- Coin cost of slot 4, 5, ... (index 1 = the 4th slot).
		slotCosts = { 500, 2500, 10000, 40000, 150000, 500000, 2000000, 8000000, 30000000 },
		-- Slots the Extra Incubators pass adds on top of what the player bought.
		passBonusSlots = 2,
	},

	-- Rebirth sits past the middle of the tower (between floors 6 and 7), so it
	-- is a late-game reset, not something a new player trips over in their
	-- first hour (economy proposal, Nov 7: tools/economy).
	rebirth = {
		baseCost = 50000000,
		costGrowth = 4, -- each rebirth costs this many times the previous one
		incomeBonusPerRebirth = 0.25, -- +25% income per rebirth
	},

	-- Each base's egg conveyor. Eggs appear on a fixed server-time schedule,
	-- so every player sees the same belt and the server can check any purchase.
	-- `weights` picks which egg comes next (the player sees the egg before
	-- buying it); only coin eggs ride the belt.
	-- The Egg Market in the middle of the map (shared/Conveyor.luau): one
	-- belt for everyone, first to buy an egg gets it.
	conveyor = {
		spawnSeconds = 0.5, -- one new egg this often, lanes taking turns
		travelSeconds = 30, -- time an egg takes to ride once round
		lanes = 2, -- rings of the belt (Layout.MARKET_LANES)
		-- How far from an egg (studs, flat) the server still sells it: the Buy
		-- prompt's 10 plus how far an egg rides in the latency allowance.
		buyReach = 20,
		-- The odds sign beside each stop shows one egg at a time, the next
		-- every this many seconds (cheapest first), so its type stays big.
		signSeconds = 4,
		weights = { BasicEgg = 55, MeadowEgg = 30, MoonlitEgg = 15 },
	},

	-- The tower (shared/Tower.luau). Only creatures placed on a floor earn.
	-- Floor 1 is free and earns x1. Floor f (2 to 10) costs `floorPrices[f - 1]`
	-- and earns 1 + floorBonus * (f - 2) + startBonus when bought; each of its
	-- four upgrades adds `upgradeBonus`, so fully upgraded it earns
	-- 1 + floorBonus * (f - 1): x1.25 on floor 2 up to x3.25 on floor 10.
	-- Upgrade n costs upgradeShares[n] of the floor's price.
	-- Each floor has 8 slots (shared/Geometry: the map is built for them).
	tower = {
		-- Steep early (x5, x5, x4), gentler late (x2.5): with x3 throughout a
		-- regular player owned all ten floors by day 7 and then had nothing to
		-- buy; on the 509-creature roster (Nov 12) floor 6 lands on day 3,
		-- floor 9 on day 8 and floor 10 around day 13 (tools/economy/run,
		-- ops/ECONOMY.md).
		floorPrices = { 20000, 100000, 500000, 2000000, 8000000, 25000000, 75000000, 190000000, 475000000 },
		floorBonus = 0.25,
		startBonus = 0.05,
		upgradeBonus = 0.05,
		upgradeShares = { 0.2, 0.35, 0.5, 0.75 },
		-- Floor slots a creature takes, by tier: rarer ones are bigger.
		slotsByRarity = {
			Common = 1,
			Uncommon = 1,
			Rare = 1,
			["Ultra Rare"] = 1,
			Epic = 2,
			Legendary = 3,
			Godly = 3,
		},
		themes = {
			"Cozy Studio",
			"Book Nook",
			"Plant Sunroom",
			"Bakery Kitchen",
			"Games Lounge",
			"Winter Cabin",
			"Art Studio",
			"Rooftop Garden",
			"Starlit Observatory",
			"Golden Sky Penthouse",
		},
	},

	-- Creatures not placed on a floor wait in the inventory. Nothing is ever
	-- auto-sold: when no pad fits a hatch and the inventory holds `slots`,
	-- the egg waits in its incubator. `sellSeconds` prices a creature's sale.
	storage = {
		slots = 300,
		sellSeconds = 20,
	},

	-- With the Auto-Collect pass, earnings move into coins this often (seconds).
	autoCollectSeconds = 30,

	-- Daily Rewards, Day 1 to 7 (then round again; a missed day starts over).
	-- Each is `incomeSeconds` of the player's income, at least `minCoins` and
	-- at most `maxCoins`. The cap keeps the free reward well below the coin
	-- packs: Day 7 (the biggest) is a quarter of the 80K Coins pack, and
	-- Config.spec fails if any day goes over that.
	daily = {
		rewards = {
			{ incomeSeconds = 300, minCoins = 250, maxCoins = 2000 },
			{ incomeSeconds = 450, minCoins = 400, maxCoins = 3000 },
			{ incomeSeconds = 600, minCoins = 600, maxCoins = 4500 },
			{ incomeSeconds = 900, minCoins = 900, maxCoins = 6500 },
			{ incomeSeconds = 1200, minCoins = 1300, maxCoins = 9000 },
			{ incomeSeconds = 1500, minCoins = 1800, maxCoins = 13000 },
			{ incomeSeconds = 2700, minCoins = 3500, maxCoins = 20000 },
		},
	},

	-- Hatchery Book: a full book adds `maxBonus` income (0.25 = +25%), however
	-- many creatures the game has. Each tier owns a share of it, split evenly
	-- between that tier's creatures, so adding Commons lowers each Common's
	-- part instead of raising the ceiling. Shares add up to 1.
	book = {
		maxBonus = 0.25,
		tierShare = {
			Common = 0.2,
			Uncommon = 0.15,
			Rare = 0.15,
			["Ultra Rare"] = 0.15,
			Epic = 0.15,
			Legendary = 0.1,
			Godly = 0.1,
		},
	},

	-- Multiplier for the Double Coins pass.
	doubleCoinsMultiplier = 2,

	-- Offline earnings: a fraction of normal income, for at most this long.
	offline = {
		rate = 0.5,
		maxSeconds = 2 * 60 * 60,
	},
}
