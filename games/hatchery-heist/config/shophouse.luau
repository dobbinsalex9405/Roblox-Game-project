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
	-- Every lamp's brightness is multiplied by this.
	lightScale = 1,
	-- Displays move (bob, spin, glow) only for players this close.
	animateRange = 120,
}
