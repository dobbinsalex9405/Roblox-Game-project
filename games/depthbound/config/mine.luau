--!strict
-- The shared mine: one shaft, built fresh by every server from a random seed
-- and never saved. Layers stack from the top; each has its own rock, ores,
-- the pick tier it needs and how fast it burns lamp oil.
--
-- `blocks` weights are whole numbers out of 10,000 (1 = 0.01%) and must total
-- exactly 10,000: they are the exact chance that any one block of the layer is
-- that block, and the layer guide at camp shows them as-is. Finding ore is
-- free, so these are not paid random items.
return {
	width = 16, -- blocks across (x)
	length = 16, -- blocks across (z)
	blockSize = 6, -- studs per block edge

	layers = {
		{
			id = "ClayShallows",
			name = "Clay Shallows",
			rows = 12,
			minPickTier = 1,
			oilPerSecond = 1,
			blocks = {
				{ id = "Clay", weight = 8000 },
				{ id = "Coal", weight = 1300 },
				{ id = "Copper", weight = 600 },
				{ id = "Quartz", weight = 100 },
			},
		},
		{
			id = "IronrootCaverns",
			name = "Ironroot Caverns",
			rows = 12,
			minPickTier = 2,
			oilPerSecond = 1.4,
			blocks = {
				{ id = "Slate", weight = 7800 },
				{ id = "Iron", weight = 1250 },
				{ id = "Silver", weight = 700 },
				{ id = "Jade", weight = 250 },
			},
		},
		{
			id = "EmberDeep",
			name = "Ember Deep",
			rows = 12,
			minPickTier = 3,
			oilPerSecond = 1.9,
			blocks = {
				{ id = "Basalt", weight = 7500 },
				{ id = "Gold", weight = 1300 },
				{ id = "Cobalt", weight = 800 },
				{ id = "Sapphire", weight = 300 },
				{ id = "Emberite", weight = 100 },
			},
		},
	},

	-- Mined-out blocks grow back (as a fresh roll of their layer) after this
	-- many seconds, but only when no player is within `regrowClearance` studs,
	-- so nobody is ever sealed in. Keeps a long-running server's mine full.
	regrowSeconds = 300,
	regrowClearance = 24,
}
