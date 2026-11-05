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

	rebirth = {
		baseCost = 120000,
		costGrowth = 3, -- each rebirth costs this many times the previous one
		incomeBonusPerRebirth = 0.25, -- +25% income per rebirth
	},

	-- Each base's egg conveyor. Eggs appear on a fixed server-time schedule,
	-- so every player sees the same belt and the server can check any purchase.
	-- `weights` picks which egg comes next (the player sees the egg before
	-- buying it); only coin eggs ride the belt.
	conveyor = {
		spawnSeconds = 3, -- one new egg this often
		travelSeconds = 18, -- time an egg takes to ride the whole belt
		weights = { BasicEgg = 70, MeadowEgg = 25, MoonlitEgg = 5 },
	},

	-- Creatures that can earn at once; when every pad is full, a better hatch
	-- takes the weakest creature's pad and the weaker one goes to storage.
	creaturePads = 20,

	-- Hatched creatures that do not fit on a pad wait in storage. When storage
	-- is full, the weakest stored creature sells for `sellSeconds` of its income.
	storage = {
		slots = 30,
		sellSeconds = 20,
	},

	-- With the Auto-Collect pass, earnings move into coins this often (seconds).
	autoCollectSeconds = 30,

	-- Multiplier for the Double Coins pass.
	doubleCoinsMultiplier = 2,

	-- Offline earnings: a fraction of normal income, for at most this long.
	offline = {
		rate = 0.5,
		maxSeconds = 2 * 60 * 60,
	},
}
