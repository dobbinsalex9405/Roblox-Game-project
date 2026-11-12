--!strict
-- Issue #186 (Studio gate on #184, phone 844x392): with the default camera
-- from the yard, the tower's name plaques and the next floor's price sign
-- sit in the middle of the top half of the screen, right where the coin box
-- and the GOAL line were centred, so phone players could not read them.
local fs = require("@lune/fs")
local HudLayout = require("../src/shared/HudLayout")
local OddsCard = require("../src/shared/OddsCard")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local INSET = 58 -- Roblox's top bar on a phone (tools/audit/Gui.luau)
local PHONES = { { 844, 392 }, { 844, 390 }, { 667, 375 } }

local function boxes(layout: HudLayout.Layout, width: number, height: number)
	local out = {}
	for _, name in { "bar", "goal", "notice", "banner" } do
		local x0, y0, x1, y1 = HudLayout.box((layout :: any)[name], width, height)
		out[name] = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
	end
	return out
end

local function overlap(a, b): boolean
	return a.x0 < b.x1 and b.x0 < a.x1 and a.y0 < b.y1 and b.y0 < a.y1
end

describe("HUD on a phone held sideways", function()
	-- The signs show at about 0.41 to 0.59 of the width (the gate's shots);
	-- the HUD keeps 0.3 to 0.7 clear above the middle of the screen.
	it("keeps the middle of the top half clear for the tower's signs", function()
		for _, size in PHONES do
			local w, h = size[1], size[2] - INSET
			local layout = HudLayout.forScreen(size[1], size[2])
			for name, b in boxes(layout, w, h) do
				local topHalf = b.y0 < h / 2
				local middle = b.x0 < w * 0.7 and b.x1 > w * 0.3
				if topHalf and middle then
					error(`at {size[1]}x{size[2]} the {name} covers the middle of the top half`)
				end
			end
		end
	end)

	it("stays on screen, apart, and clear of the odds card", function()
		for _, size in PHONES do
			local w, h = size[1], size[2] - INSET
			local b = boxes(HudLayout.forScreen(size[1], size[2]), w, h)
			for name, r in b do
				local on = r.x0 >= 0 and r.y0 >= 0 and r.x1 <= w and r.y1 <= h
				expect(on and "on" or `{name} off a {size[1]}x{size[2]} screen`).toBe("on")
			end
			expect(overlap(b.bar, b.banner)).toBe(false)
			expect(overlap(b.goal, b.notice)).toBe(false)
			-- Hud's odds card on a short screen: 16 px in, from 168 px down.
			local card = { x0 = 16, y0 = 168, x1 = 16 + OddsCard.WIDTH * OddsCard.scale(size[2]), y1 = h }
			expect(overlap(card, b.bar) or overlap(card, b.banner)).toBe(false)
		end
	end)

	it("keeps the coins and the goal readable at a glance", function()
		local layout = HudLayout.forScreen(844, 392)
		expect(layout.compact).toBe(true)
		expect(layout.bar.height >= 60).toBe(true)
		expect(layout.goal.height >= 30).toBe(true)
		expect(layout.goalText >= 12).toBe(true)
		expect(layout.goalTag.text >= 12).toBe(true)
	end)

	it("leaves the desktop band where it was", function()
		local layout = HudLayout.forScreen(1920, 1080)
		expect(layout.compact).toBe(false)
		expect(layout.bar.oy).toBe(8)
		expect(layout.goal.oy).toBe(80)
		expect(layout.notice.oy).toBe(124)
		expect(layout.banner.oy).toBe(166)
	end)

	it("is what the coin box and the goal line use, on every resize", function()
		local hud = fs.readFile("games/hatchery-heist/src/client/Hud.luau")
		local guide = fs.readFile("games/hatchery-heist/src/client/GuideView.luau")
		for _, source in { hud, guide } do
			expect(string.find(source, "HudLayout.forScreen(", 1, true) ~= nil).toBe(true)
			expect(string.find(source, "Viewport.watch(", 1, true) ~= nil).toBe(true)
		end
	end)
end)
