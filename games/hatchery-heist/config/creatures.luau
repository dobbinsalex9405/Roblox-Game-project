--!strict
-- Every creature an egg can hatch, in seven rarity tiers from Common to Godly.
-- coinsPerSecond is before rebirth and pass multipliers. mountSpeed is the walk
-- speed (studs per second) while riding it; a player on foot walks at 16, and
-- rarer creatures ride faster. How each one looks (voxel model, size, glow,
-- animation) is in src/shared/VoxelArt, built from tools/art.
return {
	species = {
		-- Common: small and simple. A big roster, so early hatches stay fresh.
		Chick = { rarity = "Common", coinsPerSecond = 1, mountSpeed = 18 },
		Duckling = { rarity = "Common", coinsPerSecond = 1, mountSpeed = 18 },
		Bunny = { rarity = "Common", coinsPerSecond = 2, mountSpeed = 18 },
		Piglet = { rarity = "Common", coinsPerSecond = 2, mountSpeed = 18 },
		Mouse = { rarity = "Common", coinsPerSecond = 2, mountSpeed = 18 },
		Hamster = { rarity = "Common", coinsPerSecond = 3, mountSpeed = 18 },
		Frog = { rarity = "Common", coinsPerSecond = 3, mountSpeed = 18 },
		Snail = { rarity = "Common", coinsPerSecond = 4, mountSpeed = 18 },
		Lamb = { rarity = "Common", coinsPerSecond = 4, mountSpeed = 18 },
		Ladybug = { rarity = "Common", coinsPerSecond = 5, mountSpeed = 18 },
		-- Uncommon
		Gosling = { rarity = "Uncommon", coinsPerSecond = 6, mountSpeed = 20 },
		Turtle = { rarity = "Uncommon", coinsPerSecond = 9, mountSpeed = 20 },
		FoxKit = { rarity = "Uncommon", coinsPerSecond = 10, mountSpeed = 20 },
		Hedgehog = { rarity = "Uncommon", coinsPerSecond = 12, mountSpeed = 20 },
		Squirrel = { rarity = "Uncommon", coinsPerSecond = 14, mountSpeed = 20 },
		Puppy = { rarity = "Uncommon", coinsPerSecond = 16, mountSpeed = 20 },
		Kitten = { rarity = "Uncommon", coinsPerSecond = 20, mountSpeed = 20 },
		-- Rare: more detail, ears and wings that move.
		Raccoon = { rarity = "Rare", coinsPerSecond = 40, mountSpeed = 22 },
		Penguin = { rarity = "Rare", coinsPerSecond = 50, mountSpeed = 22 },
		Owlet = { rarity = "Rare", coinsPerSecond = 60, mountSpeed = 22 },
		Fennec = { rarity = "Rare", coinsPerSecond = 75, mountSpeed = 22 },
		PandaCub = { rarity = "Rare", coinsPerSecond = 90, mountSpeed = 22 },
		-- Ultra Rare: glowing details.
		EmberFox = { rarity = "Ultra Rare", coinsPerSecond = 180, mountSpeed = 25 },
		FrostWolf = { rarity = "Ultra Rare", coinsPerSecond = 220, mountSpeed = 25 },
		Axolotl = { rarity = "Ultra Rare", coinsPerSecond = 260, mountSpeed = 25 },
		StormHawk = { rarity = "Ultra Rare", coinsPerSecond = 320, mountSpeed = 25 },
		-- Epic: glow, a light and sparkles.
		Dragonling = { rarity = "Epic", coinsPerSecond = 900, mountSpeed = 28 },
		CrystalStag = { rarity = "Epic", coinsPerSecond = 1100, mountSpeed = 28 },
		MoonUnicorn = { rarity = "Epic", coinsPerSecond = 1400, mountSpeed = 28 },
		-- Legendary: huge, detailed, fully animated.
		Phoenix = { rarity = "Legendary", coinsPerSecond = 6000, mountSpeed = 32 },
		ThunderGriffin = { rarity = "Legendary", coinsPerSecond = 8000, mountSpeed = 32 },
		-- Godly: the biggest and brightest in the game.
		GoldenGoose = { rarity = "Godly", coinsPerSecond = 30000, mountSpeed = 36 },
		NebulaSerpent = { rarity = "Godly", coinsPerSecond = 40000, mountSpeed = 36 },
	},
	-- Mutations multiply a creature's income. "None" must exist.
	mutations = {
		None = 1,
		Golden = 2,
		Rainbow = 5,
	},
}
