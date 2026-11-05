--!strict
-- Every creature an egg can hatch, in seven rarity tiers from Common to Godly.
-- coinsPerSecond is before rebirth and pass multipliers. Income roughly
-- doubles per tier and tops out at 1,000/s, so a coin pack stays worth
-- minutes of play even to a lucky player (tests/Config.spec checks it). mountSpeed is the walk
-- speed (studs per second) while riding it; a player on foot walks at 16, and
-- rarer creatures ride faster. How each one looks (voxel model, size, glow,
-- animation) is in src/shared/VoxelArt, built from tools/art.
return {
	species = {
		-- Common: small and simple. A big roster, so early hatches stay fresh.
		Chick = { rarity = "Common", coinsPerSecond = 1, mountSpeed = 18 },
		Duckling = { rarity = "Common", coinsPerSecond = 1, mountSpeed = 18 },
		Bunny = { rarity = "Common", coinsPerSecond = 1, mountSpeed = 18 },
		Piglet = { rarity = "Common", coinsPerSecond = 2, mountSpeed = 18 },
		Mouse = { rarity = "Common", coinsPerSecond = 2, mountSpeed = 18 },
		Hamster = { rarity = "Common", coinsPerSecond = 2, mountSpeed = 18 },
		Frog = { rarity = "Common", coinsPerSecond = 2, mountSpeed = 18 },
		Snail = { rarity = "Common", coinsPerSecond = 3, mountSpeed = 18 },
		Lamb = { rarity = "Common", coinsPerSecond = 3, mountSpeed = 18 },
		Ladybug = { rarity = "Common", coinsPerSecond = 3, mountSpeed = 18 },
		-- Uncommon
		Gosling = { rarity = "Uncommon", coinsPerSecond = 4, mountSpeed = 20 },
		Turtle = { rarity = "Uncommon", coinsPerSecond = 5, mountSpeed = 20 },
		FoxKit = { rarity = "Uncommon", coinsPerSecond = 6, mountSpeed = 20 },
		Hedgehog = { rarity = "Uncommon", coinsPerSecond = 7, mountSpeed = 20 },
		Squirrel = { rarity = "Uncommon", coinsPerSecond = 8, mountSpeed = 20 },
		Puppy = { rarity = "Uncommon", coinsPerSecond = 9, mountSpeed = 20 },
		Kitten = { rarity = "Uncommon", coinsPerSecond = 10, mountSpeed = 20 },
		-- Rare: more detail, ears and wings that move.
		Raccoon = { rarity = "Rare", coinsPerSecond = 15, mountSpeed = 22 },
		Penguin = { rarity = "Rare", coinsPerSecond = 20, mountSpeed = 22 },
		Owlet = { rarity = "Rare", coinsPerSecond = 25, mountSpeed = 22 },
		Fennec = { rarity = "Rare", coinsPerSecond = 30, mountSpeed = 22 },
		PandaCub = { rarity = "Rare", coinsPerSecond = 35, mountSpeed = 22 },
		-- Ultra Rare: glowing details.
		EmberFox = { rarity = "Ultra Rare", coinsPerSecond = 60, mountSpeed = 25 },
		FrostWolf = { rarity = "Ultra Rare", coinsPerSecond = 70, mountSpeed = 25 },
		Axolotl = { rarity = "Ultra Rare", coinsPerSecond = 80, mountSpeed = 25 },
		StormHawk = { rarity = "Ultra Rare", coinsPerSecond = 90, mountSpeed = 25 },
		-- Epic: glow, a light and sparkles.
		Dragonling = { rarity = "Epic", coinsPerSecond = 130, mountSpeed = 28 },
		CrystalStag = { rarity = "Epic", coinsPerSecond = 160, mountSpeed = 28 },
		MoonUnicorn = { rarity = "Epic", coinsPerSecond = 200, mountSpeed = 28 },
		-- Legendary: huge, detailed, fully animated.
		Phoenix = { rarity = "Legendary", coinsPerSecond = 400, mountSpeed = 32 },
		ThunderGriffin = { rarity = "Legendary", coinsPerSecond = 500, mountSpeed = 32 },
		-- Godly: the biggest and brightest in the game.
		GoldenGoose = { rarity = "Godly", coinsPerSecond = 800, mountSpeed = 36 },
		NebulaSerpent = { rarity = "Godly", coinsPerSecond = 1000, mountSpeed = 36 },
	},
	-- Mutations multiply a creature's income. "None" must exist.
	mutations = {
		None = 1,
		Golden = 2,
		Rainbow = 5,
	},
}
