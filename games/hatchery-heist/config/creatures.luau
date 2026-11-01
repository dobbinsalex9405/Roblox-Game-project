--!strict
-- Every creature an egg can hatch. coinsPerSecond is before rebirth and pass
-- multipliers. mountSpeed is the walk speed (studs per second) while riding it;
-- a player on foot walks at 16, and rarer creatures ride faster.
return {
	species = {
		Chick = { rarity = "Common", coinsPerSecond = 1, mountSpeed = 18 },
		Duckling = { rarity = "Common", coinsPerSecond = 2, mountSpeed = 18 },
		Gosling = { rarity = "Uncommon", coinsPerSecond = 5, mountSpeed = 21 },
		Turtle = { rarity = "Uncommon", coinsPerSecond = 8, mountSpeed = 21 },
		Penguin = { rarity = "Rare", coinsPerSecond = 20, mountSpeed = 24 },
		Owlet = { rarity = "Rare", coinsPerSecond = 35, mountSpeed = 24 },
		Dragonling = { rarity = "Epic", coinsPerSecond = 120, mountSpeed = 28 },
		Phoenix = { rarity = "Legendary", coinsPerSecond = 600, mountSpeed = 32 },
	},
	-- Mutations multiply a creature's income. "None" must exist.
	mutations = {
		None = 1,
		Golden = 2,
		Rainbow = 5,
	},
}
