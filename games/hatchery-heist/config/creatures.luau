--!strict
-- Every creature an egg can hatch, in seven rarity tiers from Common to Godly.
-- coinsPerSecond is before rebirth and pass multipliers. Income roughly
-- doubles per tier and tops out at 1,000/s, so a coin pack stays worth
-- minutes of play even to a lucky player (tests/Config.spec checks it). mountSpeed is the walk
-- speed (studs per second) while riding it; a player on foot walks at 16, and
-- rarer creatures ride faster. How each one looks (voxel model, size, glow,
-- animation) is in src/shared/VoxelArt, built from tools/art.
--
-- pools: the eggs' pools it hatches from (config/eggs). An egg rolls a tier
-- first, then a creature from that tier in its pool, so adding a creature
-- to a pool only splits that tier's share: no other tier's chance moves.
-- weight: its share inside its tier and pool, 1 when left out.
-- element: Ember, Glacial, Nature or Storm, or none. No effect yet:
-- elements roll out once the roster is several hundred creatures.
return {
	species = {
		-- Common: small and simple. A big roster, so early hatches stay fresh.
		Chick = { rarity = "Common", coinsPerSecond = 1, mountSpeed = 18, pools = { "Barnyard" } },
		Duckling = { rarity = "Common", coinsPerSecond = 1, mountSpeed = 18, pools = { "Barnyard" } },
		Bunny = { rarity = "Common", coinsPerSecond = 1, mountSpeed = 18, pools = { "Barnyard" } },
		Piglet = { rarity = "Common", coinsPerSecond = 2, mountSpeed = 18, pools = { "Barnyard" } },
		Mouse = { rarity = "Common", coinsPerSecond = 2, mountSpeed = 18, pools = { "Barnyard" } },
		Hamster = { rarity = "Common", coinsPerSecond = 2, mountSpeed = 18, pools = { "Barnyard" } },
		Frog = { rarity = "Common", coinsPerSecond = 2, mountSpeed = 18, pools = { "Meadow" } },
		Snail = { rarity = "Common", coinsPerSecond = 3, mountSpeed = 18, pools = { "Meadow" } },
		Lamb = { rarity = "Common", coinsPerSecond = 3, mountSpeed = 18, pools = { "Meadow" } },
		Ladybug = { rarity = "Common", coinsPerSecond = 3, mountSpeed = 18, pools = { "Meadow" } },
		-- Uncommon
		Gosling = { rarity = "Uncommon", coinsPerSecond = 4, mountSpeed = 20, pools = { "Barnyard" } },
		Turtle = { rarity = "Uncommon", coinsPerSecond = 5, mountSpeed = 20, pools = { "Barnyard" } },
		FoxKit = { rarity = "Uncommon", coinsPerSecond = 6, mountSpeed = 20, pools = { "Meadow" } },
		Hedgehog = { rarity = "Uncommon", coinsPerSecond = 7, mountSpeed = 20, pools = { "Meadow" } },
		Squirrel = { rarity = "Uncommon", coinsPerSecond = 8, mountSpeed = 20, pools = { "Meadow" } },
		Puppy = { rarity = "Uncommon", coinsPerSecond = 9, mountSpeed = 20, pools = { "Meadow", "Moonlit" } },
		Kitten = { rarity = "Uncommon", coinsPerSecond = 10, mountSpeed = 20, pools = { "Moonlit" } },
		-- Rare: more detail, ears and wings that move.
		Raccoon = { rarity = "Rare", coinsPerSecond = 15, mountSpeed = 22, pools = { "Barnyard" } },
		Penguin = {
			rarity = "Rare",
			coinsPerSecond = 20,
			mountSpeed = 22,
			pools = { "Meadow" },
			element = "Glacial",
		},
		Owlet = { rarity = "Rare", coinsPerSecond = 25, mountSpeed = 22, pools = { "Meadow", "Moonlit" } },
		Fennec = {
			rarity = "Rare",
			coinsPerSecond = 30,
			mountSpeed = 22,
			pools = { "Moonlit", "Premium" },
			element = "Ember",
		},
		PandaCub = {
			rarity = "Rare",
			coinsPerSecond = 35,
			mountSpeed = 22,
			pools = { "Moonlit", "Premium" },
			element = "Nature",
		},
		-- Ultra Rare: glowing details.
		EmberFox = {
			rarity = "Ultra Rare",
			coinsPerSecond = 60,
			mountSpeed = 25,
			pools = { "Barnyard" },
			element = "Ember",
		},
		FrostWolf = {
			rarity = "Ultra Rare",
			coinsPerSecond = 70,
			mountSpeed = 25,
			pools = { "Meadow", "Premium" },
			element = "Glacial",
		},
		Axolotl = {
			rarity = "Ultra Rare",
			coinsPerSecond = 80,
			mountSpeed = 25,
			pools = { "Meadow", "Moonlit" },
			element = "Nature",
		},
		StormHawk = {
			rarity = "Ultra Rare",
			coinsPerSecond = 90,
			mountSpeed = 25,
			pools = { "Moonlit", "Premium" },
			element = "Storm",
		},
		-- Epic: glow, a light and sparkles.
		Dragonling = {
			rarity = "Epic",
			coinsPerSecond = 130,
			mountSpeed = 28,
			pools = { "Barnyard", "Moonlit", "Premium" },
			element = "Ember",
		},
		CrystalStag = {
			rarity = "Epic",
			coinsPerSecond = 160,
			mountSpeed = 28,
			pools = { "Meadow", "Premium" },
			element = "Glacial",
		},
		MoonUnicorn = { rarity = "Epic", coinsPerSecond = 200, mountSpeed = 28, pools = { "Moonlit" } },
		-- Legendary: huge, detailed, fully animated.
		Phoenix = {
			rarity = "Legendary",
			coinsPerSecond = 400,
			mountSpeed = 32,
			pools = { "Barnyard", "Moonlit", "Premium" },
			element = "Ember",
		},
		ThunderGriffin = {
			rarity = "Legendary",
			coinsPerSecond = 500,
			mountSpeed = 32,
			pools = { "Meadow", "Premium" },
			element = "Storm",
		},
		-- Godly: the biggest and brightest in the game.
		GoldenGoose = { rarity = "Godly", coinsPerSecond = 800, mountSpeed = 36, pools = { "Premium" } },
		NebulaSerpent = { rarity = "Godly", coinsPerSecond = 1000, mountSpeed = 36, pools = { "Moonlit" } },
	},
	-- Mutations multiply a creature's income. "None" must exist.
	mutations = {
		None = 1,
		Golden = 2,
		Rainbow = 5,
	},
}
