--!strict
-- Every creature an egg can hatch. coinsPerSecond is before rebirth and pass multipliers.
return {
	species = {
		Chick = { rarity = "Common", coinsPerSecond = 1 },
		Duckling = { rarity = "Common", coinsPerSecond = 2 },
		Gosling = { rarity = "Uncommon", coinsPerSecond = 5 },
		Turtle = { rarity = "Uncommon", coinsPerSecond = 8 },
		Penguin = { rarity = "Rare", coinsPerSecond = 20 },
		Owlet = { rarity = "Rare", coinsPerSecond = 35 },
		Dragonling = { rarity = "Epic", coinsPerSecond = 120 },
		Phoenix = { rarity = "Legendary", coinsPerSecond = 600 },
	},
	-- Mutations multiply a creature's income. "None" must exist.
	mutations = {
		None = 1,
		Golden = 2,
		Rainbow = 5,
	},
}
