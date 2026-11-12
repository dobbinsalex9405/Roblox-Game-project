--!strict
-- Where the always-on HUD sits: the coin box (client/Hud "Bar"), the goal
-- line (client/GuideView "Goal"), the one-line notices and the raid banner,
-- in pixels of the GUI area (below Roblox's top bar).
--
-- A phone held sideways is short, and its default camera puts the tower's
-- name plaques and the next floor's price sign in the middle of the top half
-- of the screen. Centred up there, the coin box and the goal line hid them
-- (issue #186, Studio gate on #184 at 844x392). So on a short screen the
-- coin box is compact in the top-left corner with the raid banner under it,
-- and the goal line and notices are thin strips at the bottom centre, under
-- the player's feet. Taller screens keep the centred band, which hides
-- nothing there.

local HudLayout = {}

-- Shorter than this (px) counts as a phone held sideways (as Hud's odds
-- card already does).
HudLayout.SHORT = 500

export type Rect = {
	-- UDim2-style: a share of the GUI area plus pixels, and an anchor point.
	sx: number,
	ox: number,
	sy: number,
	oy: number,
	ax: number,
	ay: number,
	width: number,
	height: number,
}

export type Layout = {
	-- Phone: the coin box in three rows (coins and income, the pile,
	-- rebirths) instead of two.
	compact: boolean,
	bar: Rect,
	goal: Rect,
	goalText: number, -- the goal text's size, px
	goalTag: { width: number, height: number, text: number },
	notice: Rect,
	banner: Rect,
}

local function rect(sx, ox, sy, oy, ax, ay, width, height): Rect
	return { sx = sx, ox = ox, sy = sy, oy = oy, ax = ax, ay = ay, width = width, height = height }
end

-- The coin box on a phone: three short rows (coins and income; the pile;
-- rebirths), narrow enough to stay left of the screen's middle on a 667 px
-- phone.
local PHONE_BAR_WIDTH = 190
local PHONE_BAR_HEIGHT = 66
-- The goal strip on a phone: as wide as its longest line at 14 px needs,
-- never wider than the gap between the thumbstick and the jump button.
local PHONE_GOAL_WIDTH = 470
local PHONE_GOAL_HEIGHT = 38 -- two lines of 14 px for the longest goals
local MARGIN = 8

-- The HUD for a screen `width` x `height` px (the camera's ViewportSize).
function HudLayout.forScreen(width: number, height: number): Layout
	if height < HudLayout.SHORT then
		local goalWidth = math.min(PHONE_GOAL_WIDTH, math.floor(width * 0.6))
		return {
			compact = true,
			bar = rect(0, MARGIN, 0, MARGIN, 0, 0, PHONE_BAR_WIDTH, PHONE_BAR_HEIGHT),
			goal = rect(0.5, 0, 1, -MARGIN, 0.5, 1, goalWidth, PHONE_GOAL_HEIGHT),
			goalText = 14,
			goalTag = { width = 44, height = 22, text = 12 },
			notice = rect(0.5, 0, 1, -(MARGIN + PHONE_GOAL_HEIGHT + 6), 0.5, 1, 360, 30),
			banner = rect(0, MARGIN, 0, MARGIN + PHONE_BAR_HEIGHT + 6, 0, 0, PHONE_BAR_WIDTH, 34),
		}
	end
	return {
		compact = false,
		bar = rect(0.5, 0, 0, 8, 0.5, 0, 360, 64),
		goal = rect(0.5, 0, 0, 80, 0.5, 0, math.min(420, width * 0.92), 38),
		goalText = 16,
		goalTag = { width = 46, height = 24, text = 13 },
		notice = rect(0.5, 0, 0, 124, 0.5, 0, 360, 36),
		banner = rect(0.5, 0, 0, 166, 0.5, 0, 360, 40),
	}
end

function HudLayout.apply(r: Rect, frame: GuiObject)
	local position = UDim2.new(r.sx, r.ox, r.sy, r.oy)
	if frame.Position ~= position then
		frame.Position = position
	end
	local anchor = Vector2.new(r.ax, r.ay)
	if frame.AnchorPoint ~= anchor then
		frame.AnchorPoint = anchor
	end
	local size = UDim2.fromOffset(r.width, r.height)
	if frame.Size ~= size then
		frame.Size = size
	end
end

-- The rectangle `r` covers on a GUI area `width` x `height` px: left, top,
-- right, bottom.
function HudLayout.box(r: Rect, width: number, height: number): (number, number, number, number)
	local x = r.sx * width + r.ox - r.ax * r.width
	local y = r.sy * height + r.oy - r.ay * r.height
	return x, y, x + r.width, y + r.height
end

return HudLayout
