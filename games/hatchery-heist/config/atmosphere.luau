--!strict
-- How the world looks and sounds: light, sky, haze, scenery and music.
-- Nothing here changes gameplay; tune freely.
return {
	lighting = {
		clockTime = 14.5, -- 0-24; early afternoon sun
		geographicLatitude = 35,
		brightness = 2.6,
		ambient = { 70, 64, 58 }, -- RGB, light in shadow indoors
		outdoorAmbient = { 140, 128, 110 }, -- RGB, light in shadow outdoors
		environmentDiffuseScale = 1,
		environmentSpecularScale = 0.6,
		exposureCompensation = 0.1,
		shadowSoftness = 0.25,
	},
	atmosphere = {
		density = 0.32,
		offset = 0.25,
		color = { 199, 214, 230 },
		decay = { 120, 140, 110 },
		glare = 0.3,
		haze = 1.4,
	},
	sky = {
		sunAngularSize = 14,
		moonAngularSize = 11,
		starCount = 1500,
	},
	-- Once the uploaded storybook skybox loads (tools/art/env/sky.py), its
	-- painted clouds and mountains need thinner moving clouds and less haze.
	skybox = {
		cloudCover = 0.3, -- 0-1, replaces clouds.cover
		atmosphereDensity = 0.24, -- replaces atmosphere.density
		haze = 0.6, -- replaces atmosphere.haze
	},
	ground = {
		grassTileStuds = 32, -- the uploaded grass tile (tools/art/env/grass.py) repeats every this many studs
	},
	clouds = {
		cover = 0.55, -- 0-1
		density = 0.6,
		color = { 255, 255, 255 },
	},
	effects = {
		bloomIntensity = 0.35,
		bloomSize = 24,
		bloomThreshold = 1.6,
		sunRaysIntensity = 0.06,
		sunRaysSpread = 0.8,
		saturation = 0.12, -- color correction
		contrast = 0.06,
		tint = { 255, 250, 240 },
	},
	scenery = {
		hillRadius = 320, -- studs from the centre; hides the edge of the map
		hillCount = 22,
		seed = 7, -- the same scenery on every server
		-- Trees, bushes, rocks and flowers (shared/NaturePlan.luau; models in
		-- shared/EnvArt.luau from tools/art/env). Radii in studs from the
		-- centre; bases fill 78 to 145, the hub stays inside 72.
		nature = {
			seed = 11,
			-- Each gap between bases holds a piece of the farm; a small tree
			-- stands on each side of it, with a bush at the foot of one.
			gap = {
				trees = { "PuffOakS", "BlossomS" }, -- alternating round the ring
				bushes = { "BerryBush", "HydrangeaBush" },
				radius = 186, -- studs from the centre, level with the farm
				degrees = 12, -- each side of the gap's middle
			},
			wood = {
				count = 42, -- trees round the outside of the ring
				radiusMin = 166,
				radiusMax = 245,
				scaleMin = 0.9,
				scaleMax = 1.15,
				minSpacing = 9, -- studs between trunks at least
				-- how often each species is picked (relative)
				-- (Star Pines stand on the hills, not in the wood)
				species = {
					PuffOak = 40,
					AmberOak = 18,
					Blossom = 18,
					Willow = 14,
					Toadstool = 12,
				},
			},
			scatter = {
				radiusMin = 150,
				radiusMax = 250,
				bushes = 26,
				rocks = 18,
				flowers = 24,
				tufts = 80,
				mushroomRings = 8,
			},
			hillPines = 11, -- big Star Pines on top of every other hill (up to this many)
			hillPine = "StarPineM", -- scaled up 1.2 to 1.7 times with the hill
		},
		-- The farmyard outside the ring of bases (src/server/Farm.luau).
		-- Angles in degrees round the ring; bases sit at 0, 45, 90 ..., so
		-- 22.5, 67.5 ... are the gaps between them. Radii in studs.
		farm = {
			barn = { angle = 22.5, radius = 190 },
			windmill = { angle = 112.5, radius = 186 },
			pond = { angle = 202.5, radius = 180 },
			pen = { angle = 292.5, radius = 182 },
			fields = { 67.5, 157.5, 247.5, 337.5 },
			fieldRadius = 188,
			clearRadius = 32, -- studs round each farm spot kept free of trees and props
			windmillTurnSeconds = 9, -- one full turn of the sails
		},
	},
	music = {
		-- Roblox audio asset ids (numbers), played in order and looped. Only
		-- tracks from Roblox's own licensed library (Creator Store, Audio,
		-- by Roblox): uploads by others may be private or unlicensed. Empty
		-- = no music. Fantasy picks for Alex's "lord of the rings themed" ask
		-- (Roblox's licensed APM library, found in Studio's Creator Store,
		-- Nov 5): Magical Surprise, Magic Castle, Wildflower Meadows. Chosen
		-- from the library's titles and descriptions, not by ear: listen once
		-- on Staging. Alternates if one jars: 1840511859, 1838199820,
		-- 1839975977.
		tracks = { 1840017271, 1846499154, 9048460919 },
		volume = 0.25,
		fadeSeconds = 2, -- the Music button fades it out and in
		startDelaySeconds = 1, -- after the player first spawns
		startFadeSeconds = 4, -- from silence at join, slow at first
		crossfadeSeconds = 3, -- each track fades into the next
	},
	-- Sound effects: Roblox audio asset ids from Roblox's own licensed
	-- library (Creator Store, Audio, by Roblox), picked by ear in Studio.
	-- id 0 = silent until one is picked; the game works the same either way.
	sounds = {
		eggShake = { id = 0, volume = 0.5 }, -- the egg wobbles before it hatches
		eggCrack = { id = 0, volume = 0.6 }, -- the shell breaks
		reveal = { id = 0, volume = 0.5 }, -- Common to Rare appears
		revealBig = { id = 0, volume = 0.7 }, -- Ultra Rare and Epic appear
		revealLegend = { id = 0, volume = 0.8 }, -- Legendary and Godly appear
		newEntry = { id = 0, volume = 0.5 }, -- a new creature in the Hatchery Book
		reward = { id = 0, volume = 0.6 }, -- a daily reward claimed
		click = { id = 0, volume = 0.4 }, -- a menu button
	},
}
