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
		treeCount = 36, -- around the outside of the ring of bases
		treeRadiusMin = 172,
		treeRadiusMax = 215,
		seed = 7, -- the same scenery on every server
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
		-- = no music. Provisional picks (Roblox's licensed APM library, chosen
		-- in Studio's Creator Store, Nov 4); confirm by ear in the next
		-- playtest: Beautiful Morning, Mellow Landscape, Castle Reel.
		tracks = { 1846167658, 1842262737, 1845861718 },
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
