--!strict
-- The Golden Egg Shop: the walk-in Robux shop in the farm hub
-- (src/server/ShopHouse.luau; the art and the room's layout are in
-- src/shared/ShopArt.luau, made by tools/art/world/shop.py).
return {
	-- Where it stands: degrees round the ring (the bases sit at 0, 45, 90 ...,
	-- so 22.5 is the gap between the first two) and studs from the middle of
	-- the map. The door faces the Golden Nest.
	angle = 22.5,
	radius = 62,
	groundY = 0.2, -- the top of the sandy yard
	-- The Buy prompt on each display.
	promptDistance = 8,
	-- What the signs say.
	title = "Golden Egg Shop",
	coinsHeader = "Coins",
	passesHeader = "Passes & Shield",
	-- The room's lamps. Indoors, Roblox adds every overlapping light, so the
	-- art's brightnesses are scaled well down; at 1 the room washed out white.
	lightScale = 0.3, -- every lamp's brightness is multiplied by this
	lightRangeScale = 0.75, -- and every lamp's range by this
	lightColor = { 255, 228, 196 }, -- RGB, a soft warm white
	-- Glowing accents (lamp panes, gems, incubator lights) as Neon. Off:
	-- with the game's bloom, Neon indoors glares; they stay their colour.
	neon = false,
	-- Displays move (bob, spin, glow) only for players this close.
	animateRange = 120,
	-- Inside the shop the camera stays at most this far (studs) behind the
	-- player: the shop's art is not in the camera's way-finding, so a
	-- longer zoom ended up inside the counter and walls (Studio gate, Nov 5).
	indoorZoom = 8,
}
