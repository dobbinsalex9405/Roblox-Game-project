--!strict
-- The player's-eye audit (tools/audit): the checks on hand-made worlds and
-- HUDs, and the image pipeline. ops/VISUAL_PLAYTEST.md.
local serde = require("@lune/serde")
local Canvas = require("../audit/Canvas")
local Font = require("../audit/Font")
local Png = require("../audit/Png")
local Report = require("../audit/Report")
local Scene = require("../audit/Scene")
local World = require("../audit/World")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local GREY = { r = 0.5, g = 0.5, b = 0.5 }

local function box(
	name: string,
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	extra: { [string]: any }?
): World.Box
	local b: World.Box = {
		name = name,
		path = `Workspace.{name}`,
		className = "Part",
		cx = x,
		cy = y,
		cz = z,
		rx = 1,
		ry = 0,
		rz = 0,
		ux = 0,
		uy = 1,
		uz = 0,
		bx = 0,
		by = 0,
		bz = 1,
		hx = sx / 2,
		hy = sy / 2,
		hz = sz / 2,
		color = GREY,
		transparency = 0,
		canCollide = true,
		isGround = name == "Baseplate",
		isSpawn = name == "SpawnLocation",
		enabled = true,
	}
	for k, v in extra or {} do
		(b :: any)[k] = v
	end
	return b
end

local function rules(findings: { World.Finding }, severity: string): { string }
	local out = {}
	for _, f in findings do
		if f.severity == severity then
			table.insert(out, f.rule)
		end
	end
	table.sort(out)
	return out
end

local function prompt(x: number, y: number, z: number): World.Label
	return {
		path = "Workspace.Pad.Prompt",
		kind = "Prompt",
		text = "Buy",
		x = x,
		y = y,
		z = z,
		alwaysOnTop = true,
		reach = 10,
	}
end

describe("player's-eye audit: world", function()
	-- The Nov 4 floor bug: a 20-stud Baseplate centred on Y = 0 (top at 10)
	-- over a map built at ground level.
	local function buriedMap(): ({ World.Box }, { World.Label })
		return {
			box("Baseplate", 0, 0, 0, 512, 20, 512),
			box("SpawnLocation", 0, 0.5, 0, 12, 1, 12),
			box("Floor", 40, 0.5, 0, 30, 1, 30),
		}, {
			{
				path = "Workspace.Floor.Label",
				kind = "Billboard",
				text = "Collect",
				x = 40,
				y = 5,
				z = 0,
				alwaysOnTop = false,
				reach = 0,
			},
			prompt(40, 2, 0),
		}
	end

	it("fails the buried map: parts, labels and the spawn under the ground", function()
		local boxes, labels = buriedMap()
		expect(rules(World.check(boxes, labels), "FAIL")).toEqual({
			"ground.buried",
			"labels.buried",
			"spawn.blocked",
			"spawn.buried",
		})
	end)

	it("passes the same map with the Baseplate placed right (top at Y = 0)", function()
		local boxes, labels = buriedMap()
		boxes[1] = box("Baseplate", 0, -10, 0, 512, 20, 512)
		labels[1].y = 15
		expect(rules(World.check(boxes, labels), "FAIL")).toEqual({})
	end)

	it("fails a spawn with a solid part on it, warns for a rotated one", function()
		local boxes = {
			box("Baseplate", 0, -10, 0, 512, 20, 512),
			box("SpawnLocation", 0, 0.5, 0, 12, 1, 12),
			box("Egg", 0, 4, 0, 4, 6, 4),
		}
		expect(rules(World.check(boxes, {}), "FAIL")).toEqual({ "spawn.blocked" })
		boxes[3] = box("Egg", 0, 4, 0, 4, 6, 4, { rx = 0.7071, rz = 0.7071, bx = -0.7071, bz = 0.7071 })
		local findings = World.check(boxes, {})
		expect(rules(findings, "FAIL")).toEqual({})
		expect(rules(findings, "WARN")).toEqual({ "spawn.crowded" })
	end)

	it("fails without a spawn, and prompts with no floor or out of reach", function()
		local boxes = { box("Baseplate", 0, -10, 0, 100, 20, 100) }
		local findings = World.check(boxes, { prompt(500, 3, 0), prompt(0, 30, 0) })
		expect(rules(findings, "FAIL")).toEqual({ "prompt.nofloor", "prompt.unreachable", "spawn.missing" })
	end)

	it("a prompt at hand height over the ground is fine; far from the spawn only warns", function()
		local boxes = {
			box("Baseplate", 0, -10, 0, 1000, 20, 1000),
			box("SpawnLocation", 0, 0.5, 0, 12, 1, 12),
		}
		local findings = World.check(boxes, { prompt(400, 3, 0) })
		expect(rules(findings, "FAIL")).toEqual({})
		expect(rules(findings, "WARN")).toEqual({ "loop.far" })
	end)

	it("notes a map without a Baseplate instead of failing it", function()
		local boxes = { box("SpawnLocation", 0, 0.5, 0, 12, 1, 12), box("Camp", 0, -1, 0, 60, 2, 60) }
		local findings = World.check(boxes, {})
		expect(rules(findings, "FAIL")).toEqual({})
		expect(rules(findings, "NOTE")).toEqual({ "ground.none" })
	end)

	it("computes world bounds of a rotated part", function()
		local b = box("Wedge", 0, 0, 0, 2, 2, 2, { rx = 0.7071, rz = 0.7071, bx = -0.7071, bz = 0.7071 })
		local x0, _, _, x1 = World.bounds(b)
		expect(math.abs(x1 - x0 - 2.8284) < 0.01).toBe(true)
		expect(World.axisAligned(b)).toBe(false)
	end)
end)

describe("player's-eye audit: known problems", function()
	it("turns a matching FAIL into KNOWN and reports entries that match nothing", function()
		local findings: { World.Finding } = {
			{ severity = "FAIL", rule = "hud.text-tiny", message = "Hud.Pools.Info draws at 8 px" },
			{ severity = "FAIL", rule = "spawn.blocked", message = "egg on the spawn" },
		}
		local stale = Report.applyKnown("g", findings, {
			{ game = "g", rule = "hud.text-tiny", contains = "Pools", reason = "being fixed" },
			{ game = "g", rule = "ground.buried", contains = "x", reason = "fixed long ago" },
			{ game = "other", rule = "spawn.blocked", contains = "egg", reason = "another game" },
		})
		expect(findings[1].severity).toBe("KNOWN")
		expect(findings[2].severity).toBe("FAIL")
		expect(#stale).toBe(1)
		expect(stale[1].rule).toBe("ground.buried")
		local built = Report.build("g", "abc", findings, {}, {}, {})
		expect(built.failed).toBe(true)
		expect(built.markdown).toContain("1 known")
	end)

	it("the committed known.json parses and every entry says why", function()
		local fs = require("@lune/fs")
		local data = serde.decode("json", fs.readFile("tools/audit/known.json"))
		for _, k in data.known do
			expect(type(k.game)).toBe("string")
			expect(fs.isDir(`games/{k.game}`)).toBe(true)
			expect(type(k.rule)).toBe("string")
			expect(#k.contains > 0).toBe(true)
			expect(#k.reason > 20).toBe(true)
		end
	end)
end)

describe("player's-eye audit: images", function()
	it("writes a valid PNG", function()
		expect(Png.crc32("IEND")).toBe(0xAE426082)
		local c = Canvas.new(4, 3, { r = 1, g = 0, b = 0 })
		local png = Canvas.toPng(c)
		expect(string.sub(png, 1, 8)).toBe("\137PNG\r\n\26\n")
		expect(string.sub(png, 13, 16)).toBe("IHDR")
		expect(string.unpack(">I4", png, 17)).toBe(4)
		expect(string.unpack(">I4", png, 21)).toBe(3)
		expect(string.sub(png, -8, -5)).toBe("IEND")
	end)

	it("the depth buffer keeps the nearer surface", function()
		local c = Canvas.new(10, 10)
		local red, blue = { r = 1, g = 0, b = 0 }, { r = 0, g = 0, b = 1 }
		-- Near (depth 2) red first, then far (depth 1) blue over the same pixels.
		Canvas.triangle(c, 0, 0, 2, 10, 0, 2, 0, 10, 2, red, 1, true)
		Canvas.triangle(c, 0, 0, 1, 10, 0, 1, 0, 10, 1, blue, 1, true)
		expect(buffer.readu8(c.rgb, 0)).toBe(255)
		expect(buffer.readu8(c.rgb, 2)).toBe(0)
	end)

	it("a camera inside the ground sees the ground, not the world above it", function()
		local ground = box("Baseplate", 0, 0, 0, 100, 20, 100, { color = { r = 0, g = 1, b = 0 } })
		local c = Canvas.new(64, 36)
		local cam = Scene.lookAt(0, 5, 20, 0, 5, 0, 70)
		Scene.drawBoxes(c, cam, { ground })
		local mid = (18 * 64 + 32) * 3
		expect(buffer.readu8(c.rgb, mid + 1) > buffer.readu8(c.rgb, mid)).toBe(true)
	end)

	it("the font has every printable ASCII character and draws others as boxes", function()
		for code = 32, 126 do
			local glyphs = Font.layout(string.char(code))
			expect(#glyphs).toBe(1)
		end
		expect(Font.width("AB")).toBe(11)
		expect(#Font.layout(utf8.char(0x1F95A))).toBe(1)
	end)
end)

describe("player's-eye audit: HUD at phone size", function()
	local roblox = require("@lune/roblox")
	local Gui = require("../audit/Gui")
	local Instance, UDim2, UDim, Vector2, Enum =
		roblox.Instance, roblox.UDim2, roblox.UDim, roblox.Vector2, roblox.Enum
	local phone = Gui.SCREENS[1]

	local function playerWith(build: (any) -> ()): any
		local player = Instance.new("Folder")
		player.Name = "Player"
		local pg = Instance.new("Folder")
		pg.Name = "PlayerGui"
		pg.Parent = player
		local gui = Instance.new("ScreenGui")
		gui.Name = "Hud"
		gui.Parent = pg
		build(gui)
		return player
	end

	local function button(parent: any, name: string, text: string, size: any, position: any): any
		local b = Instance.new("TextButton")
		b.Name = name
		b.Text = text
		b.TextSize = 18
		b.Size = size
		b.Position = position
		b.Parent = parent
		return b
	end

	local function failRules(player: any): { string }
		local items = Gui.layout(Gui.snapshot(player), phone)
		local out = {}
		for _, f in Gui.check(items, phone, true) do
			if f.severity == "FAIL" then
				table.insert(out, f.rule)
			end
		end
		table.sort(out)
		return out
	end

	it("a tidy HUD passes", function()
		local player = playerWith(function(gui)
			button(gui, "Shop", "Shop", UDim2.fromOffset(120, 44), UDim2.new(0, 12, 1, -56))
			button(gui, "Bag", "Bag", UDim2.fromOffset(120, 44), UDim2.new(0, 140, 1, -56))
		end)
		expect(failRules(player)).toEqual({})
	end)

	it("fails a button off the edge, overlapping buttons and one under Roblox's top bar", function()
		local player = playerWith(function(gui)
			button(gui, "Off", "Rebirth", UDim2.fromOffset(160, 44), UDim2.new(1, -60, 0.5, 0))
			button(gui, "A", "Sell", UDim2.fromOffset(120, 44), UDim2.fromOffset(200, 200))
			button(gui, "B", "Buy", UDim2.fromOffset(120, 44), UDim2.fromOffset(210, 205))
		end)
		expect(failRules(player)).toEqual({ "hud.buttons-overlap", "hud.offscreen", "hud.text-overlap" })
		local top = playerWith(function(gui)
			gui.IgnoreGuiInset = true
			button(gui, "Menu", "Menu", UDim2.fromOffset(80, 40), UDim2.fromOffset(4, 4))
		end)
		expect(failRules(top)).toEqual({ "hud.topbar" })
	end)

	it("fails scaled text squeezed into a tiny box", function()
		local player = playerWith(function(gui)
			local l = Instance.new("TextLabel")
			l.Text = "Place a catch from your bucket."
			l.TextScaled = true
			l.Size = UDim2.fromOffset(300, 7)
			l.Position = UDim2.fromOffset(100, 300)
			l.Parent = gui
		end)
		expect(failRules(player)).toEqual({ "hud.text-tiny" })
	end)

	it("lays out a vertical list with padding, and anchors from the bottom right", function()
		local player = playerWith(function(gui)
			local f = Instance.new("Frame")
			f.Name = "Menu"
			f.AnchorPoint = Vector2.new(1, 1)
			f.Position = UDim2.new(1, -10, 1, -10)
			f.Size = UDim2.fromOffset(100, 200)
			f.Parent = gui
			local list = Instance.new("UIListLayout")
			list.Padding = UDim.new(0, 5)
			list.SortOrder = Enum.SortOrder.LayoutOrder
			list.Parent = f
			local second = button(f, "Second", "2", UDim2.fromOffset(100, 30), UDim2.fromOffset(0, 0))
			second.LayoutOrder = 2
			local first = button(f, "First", "1", UDim2.fromOffset(100, 30), UDim2.fromOffset(0, 0))
			first.LayoutOrder = 1
		end)
		local items = Gui.layout(Gui.snapshot(player), phone)
		local rects = {}
		for _, item in items do
			rects[item.node.name] = item.rect
		end
		expect(rects.Menu.x).toBe(844 - 10 - 100)
		expect(rects.Menu.y).toBe(390 - 10 - 200)
		expect(rects.First.y).toBe(rects.Menu.y)
		expect(rects.Second.y).toBe(rects.Menu.y + 35)
	end)

	it("a full-screen tap-to-close backdrop is not an overlapping button", function()
		local player = playerWith(function(gui)
			local dim = button(gui, "Dim", "", UDim2.fromScale(1, 1), UDim2.new())
			dim.BackgroundTransparency = 0.5
			button(gui, "Close", "X", UDim2.fromOffset(44, 44), UDim2.fromOffset(400, 150))
		end)
		expect(failRules(player)).toEqual({})
	end)
end)
