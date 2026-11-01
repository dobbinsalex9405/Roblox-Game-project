--!strict
-- Coins, incubators and rebirth. Every number here is tunable without code
-- changes; any change to a live game's economy needs Alex's approval (brief, Part 1).
return {
	startingCoins = 50,
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
		baseCost = 1000000,
		costGrowth = 2.5, -- each rebirth costs this many times the previous one
		incomeBonusPerRebirth = 0.25, -- +25% income per rebirth
	},

	-- Multiplier for the Double Coins pass.
	doubleCoinsMultiplier = 2,

	-- Offline earnings: a fraction of normal income, for at most this long.
	offline = {
		rate = 0.5,
		maxSeconds = 2 * 60 * 60,
	},
}
