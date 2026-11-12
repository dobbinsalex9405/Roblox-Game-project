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
		-- The farm hub in the middle of the map: buildings and street props
		-- from WorldArt.luau (kinds "building" and "hubprop", modelled in
		-- tools/art/world/hub.py), around the Egg Market. Same angles as
		-- `farm`: bases (and the paths to them) sit at 0, 45, 90 ..., so the
		-- wedges between the paths are centred on 22.5, 67.5 .... Each piece
		-- stands at `radius` studs from the centre and faces the centre
		-- (its front, -Z, looks at the Golden Nest), turned `yaw` degrees
		-- more when set. tests/HubLayout.spec.luau checks that every piece
		-- exists, stays between the market and the bases, keeps off the
		-- paths and the shop, and overlaps nothing else.
		hub = {
			innerRadius = 30, -- the belt's outer edge is about r29.2
			outerRadius = 72, -- base fronts are at about r78
			pathWidth = 10, -- the walkway along each base angle
			-- The walk-in Robux shop (built by its own thread, ShopArt.luau):
			-- only its footprint, so nothing here is placed on it.
			-- Mirrors config/shophouse.luau (the shop thread owns it): walls 30
			-- x 24; the eaves reach 0.8 past the sides, over the path edge.
			shop = { angle = 22.5, radius = 62, width = 30, depth = 24 },
			-- One arch over each path, where it leaves the market.
			arch = { id = "MarketArch", radius = 31 },
			-- Lamp posts beside every path where it leaves the market, `side`
			-- studs off its centreline (further out the shop and the barn come
			-- close to the paths, and they carry their own lanterns).
			lamps = { id = "LampPost", radii = { 41 }, side = 6.5 },
			-- A signpost at the market end of every path (left side).
			signposts = { id = "Signpost", radius = 35, side = 7.5 },
			-- The pieces nearest the market stand back from it (r39 and up)
			-- so the odds sign beside each stop (Layout.marketSign) has room.
			pieces = {
				-- 67.5: the Hatchery Barn, the hub's landmark, and the Book stand
				{ id = "BookStand", angle = 67.5, radius = 41 },
				{ id = "HatcheryBarn", angle = 67.5, radius = 56 },
				-- 112.5: the Theme Stand by the market, two market stalls behind
				{ id = "ThemeStand", angle = 112.5, radius = 41 },
				{ id = "StallRed", angle = 106, radius = 54 },
				{ id = "StallBlue", angle = 119, radius = 54 },
				-- 157.5: the Daily Rewards mailbox, the well and the windmill
				{ id = "Mailbox", angle = 157.5, radius = 39 },
				{ id = "Well", angle = 149, radius = 44 },
				{ id = "Windmill", angle = 157.5, radius = 57 },
				-- 202.5: the notice board, the hen house, the egg cart and the silo
				{ id = "NoticeBoard", angle = 202.5, radius = 39 },
				{ id = "EggCart", angle = 194, radius = 45 },
				{ id = "ChickenCoop", angle = 211, radius = 46 },
				{ id = "Silo", angle = 202.5, radius = 60 },
				-- 247.5: the flower stall, a planter and a haystack
				{ id = "StallGreen", angle = 247.5, radius = 42 },
				{ id = "FlowerPlanter", angle = 247.5, radius = 52 },
				{ id = "HayStack", angle = 239, radius = 58 },
				-- 292.5: a little green with benches and the duck pond
				{ id = "Bench", angle = 286, radius = 42 },
				{ id = "Bench", angle = 299, radius = 42 },
				{ id = "DuckPond", angle = 292.5, radius = 57 },
				-- 337.5: benches, the scarecrow and the vegetable patch
				{ id = "Bench", angle = 331, radius = 42 },
				{ id = "Bench", angle = 344, radius = 42 },
				{ id = "Scarecrow", angle = 337.5, radius = 47 },
				{ id = "VegetablePatch", angle = 337.5, radius = 57 },
			},
		},
	},
	-- The Tower window's Build and Upgrade buttons (client/TowerView). After
	-- a tap the row shows "Building..." until the server answers (at most
	-- waitSeconds), then "Built!" for holdSeconds, so a double tap never
	-- buys the next thing (Studio gate, Nov 5). A tap you can't afford shows
	-- how many more coins you need for holdSeconds.
	menus = {
		holdSeconds = 1.5,
		waitSeconds = 3,
	},
	-- The guide's gold arrow and beam hide once you are this close (studs,
	-- flat) to where they point, so they never sit on top of the Buy prompt
	-- you came for (Studio gate, Nov 5).
	-- The Hatchery Book draws only the cards near the screen (client/
	-- BookView). overscanRows past each edge are drawn at once; while the
	-- book is open it then builds more, outward from the view, warmPerFrame
	-- a frame, until warmCards are built, because a new card's picture takes
	-- up to a second to draw its first frame (Studio gate, Nov 5 and 7: a
	-- fast flick showed empty cards). 144 keeps the whole Common tab warm and
	-- covers a 1,400 px flick on a 200-card tab. Warming starts
	-- warmDelaySeconds after a tab is shown (0: at once), and built cards
	-- are kept while the book is closed. Pictures can still take a moment
	-- to draw on a fast flick: Roblox draws a ViewportFrame only while it
	-- is on screen, so a creature with a picture (CreatureThumbs) shows that
	-- instead. The pictures load at join in page order, preloadStreams
	-- requests at a time, preloadBatch pictures each (Studio gate, #125);
	-- a tab the player opens jumps the queue.
	book = {
		overscanRows = 2,
		warmCards = 144,
		warmPerFrame = 8,
		warmDelaySeconds = 0,
		preloadStreams = 4,
		preloadBatch = 6,
	},
	guide = {
		arrivedStuds = 8,
		-- Roblox's player list (top right on desktop) sat over the side
		-- menu's top button, so clicks opened "Examine Avatar" instead of the
		-- Guide (Studio gate, Nov 5). The game has no leaderboard stats, so
		-- it stays off; true brings it back.
		playerList = false,
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
		cullStuds = 180, -- your own tower's creatures farther than this are not drawn
		cullOtherStuds = 100, -- other players' tower creatures: the neighbours either side (84 away)
		animateOtherStuds = 60, -- other players' tower creatures hold still beyond this
	},
	-- A species' meshes reaching the client (shared/MeshArrival).
	creatureMeshes = {
		-- Wait at most this long for all of a species' meshes to replicate
		-- before loading them (they trickle in after the model itself).
		arriveSeconds = 30,
		-- A failed load is tried again after each of these waits: a fresh
		-- upload can fail for a few minutes while Roblox still generates its
		-- texture (Studio gate, #137). About 8 minutes in all, then the
		-- species stays voxel boxes.
		retrySeconds = { 5, 15, 45, 120, 300 },
	},
	-- Creature meshes past this many studs from the camera draw their far
	-- (LOD1) version: a few thousand triangles instead of up to 100,000.
	creatureLod = {
		farStuds = 30,
	},
	-- Sound effects: Roblox audio asset ids, free Creator Store audio, each
	-- loaded in Studio and picked by title and length (Nov 5); Alex listens
	-- on Staging and swaps any by ear. id 0 = silent; the game works the
	-- same either way.
	sounds = {
		eggShake = { id = 9120784504, volume = 0.5 }, -- the egg wobbles before it hatches (0.3 s)
		eggCrack = { id = 9113959343, volume = 0.6 }, -- the shell breaks (1.0 s)
		reveal = { id = 90618709727045, volume = 0.5 }, -- Common to Rare appears (2.5 s)
		revealBig = { id = 85188102085028, volume = 0.7 }, -- Ultra Rare and Epic appear (2.4 s)
		revealLegend = { id = 1840076509, volume = 0.8 }, -- Legendary and Godly appear (2.3 s)
		newEntry = { id = 73774648241042, volume = 0.4 }, -- a new creature in the Hatchery Book (4.2 s, kept soft)
		reward = { id = 100288208393628, volume = 0.6 }, -- a reward claimed (1.4 s sparkle)
		click = { id = 73629124033518, volume = 0.4 }, -- a menu button (0.2 s)
	},
	-- The apartment shells (WorldArt Tower*, tools/art/world/tower.py) the
	-- client draws over each tower's grey box: your own and the nearest
	-- others, up to `towers` in all within `drawStuds` (a full tower is
	-- about 4,700 boxes); the rest keep the grey box.
	-- The egg in an incubator, drawn from its egg art (server/World).
	incubatorEggs = {
		height = 2.6, -- studs, as tall as the plain ball it replaced
	},

	towerShells = {
		drawStuds = 160,
		towers = 4,
		boxesPerFrame = 400, -- built a little each frame, so nothing hitches
	},
}
