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
			gapTrees = { "PuffOakM", "BlossomM" }, -- one in each gap between bases, alternating
			gapRadius = 152,
			wood = {
				count = 42, -- trees round the outside of the ring
				radiusMin = 166,
				radiusMax = 245,
				scaleMin = 0.9,
				scaleMax = 1.15,
				minSpacing = 9, -- studs between trunks at least
				-- how often each species is picked (relative)
				species = {
					PuffOak = 30,
					StarPine = 24,
					Blossom = 14,
					Willow = 12,
					AmberOak = 10,
					Toadstool = 10,
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
			hillPines = 6, -- big Star Pines on top of every other hill (up to this many)
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
			clearAngle = 13, -- degrees round each farm spot kept free of trees
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
	-- Creatures on tower floors wander their own spot (shared/Walk).
	wander = {
		speed = 2.4, -- studs per second while walking
		segmentSeconds = 7, -- each turn, walk and stand
		turnSeconds = 0.6, -- turning on the spot before a walk
		faceFrontAfter = 1.5, -- stand this long, then turn to face the centre
		margin = 0.6, -- studs kept clear of the spot's edge
		cullFloors = 1, -- creatures more floors than this from you are not drawn
	},
	-- Creature meshes past this many studs from the camera draw their far
	-- (LOD1) version: a few thousand triangles instead of up to 100,000.
	creatureLod = {
		farStuds = 30,
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
