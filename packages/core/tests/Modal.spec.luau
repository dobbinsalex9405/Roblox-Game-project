--!strict
-- Staging playtest, Nov 12: the Tower window opened from the elevator in
-- first person, where Roblox locks the mouse to the middle of the screen.
-- Its X could not be reached and nothing else closed it, so the player was
-- stuck behind it. client/Modal frees the mouse while a window shows and
-- gives three more ways out: tap outside, gamepad B, and the Roblox menu
-- (Escape / Android Back).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

-- Loads client/Modal with Roblox's data types, outside Roblox.
local function loadModal(): any
	local source = fs.readFile("packages/core/client/Modal.luau")
	local env = {
		Color3 = roblox.Color3,
		Vector2 = roblox.Vector2,
		UDim2 = roblox.UDim2,
		UDim = roblox.UDim,
		Instance = roblox.Instance,
	}
	return luau.load(source, { debugName = "Modal", environment = env })()
end

-- A fake Roblox for one guarded window: property watchers, the backdrop's
-- click, the menu and the gamepad binding, all fired by hand.
local function setup()
	local Modal = loadModal()
	local watchers: { [any]: { () -> () } } = {}
	local clicks: { () -> () } = {}
	local menu: { () -> () } = {}
	local bound: { [string]: () -> () } = {}
	local env = {
		new = function(className: string): any
			return roblox.Instance.new(className)
		end,
		watch = function(instance: any, property: string, fn: () -> ())
			local key = `{tostring(instance)}.{property}`
			watchers[key] = watchers[key] or {}
			table.insert(watchers[key], fn)
		end,
		activated = function(_button: any, fn: () -> ())
			table.insert(clicks, fn)
		end,
		menuOpened = function(fn: () -> ())
			table.insert(menu, fn)
		end,
		bindBack = function(name: string, fn: () -> ())
			bound[name] = fn
		end,
		unbindBack = function(name: string)
			bound[name] = nil
		end,
	}
	local gui = roblox.Instance.new("ScreenGui")
	gui.Enabled = false
	local window = roblox.Instance.new("Frame")
	window.Parent = gui
	local closes = 0
	local guard = Modal.attach(gui, window, function()
		closes += 1
		gui.Enabled = false
		for _, fn in watchers[`{tostring(gui)}.Enabled`] or {} do
			fn()
		end
	end, env)
	local function set(instance: any, property: string, value: any)
		instance[property] = value
		for _, fn in watchers[`{tostring(instance)}.{property}`] or {} do
			fn()
		end
	end
	local function count(): number
		local n = 0
		for _ in bound do
			n += 1
		end
		return n
	end
	return {
		gui = gui,
		window = window,
		guard = guard,
		set = set,
		closes = function()
			return closes
		end,
		click = function()
			for _, fn in clicks do
				fn()
			end
		end,
		menu = function()
			for _, fn in menu do
				fn()
			end
		end,
		pressB = function()
			for _, fn in bound do
				fn()
			end
		end,
		bindings = count,
	}
end

describe("Modal windows can always be closed", function()
	it("frees the mouse while the window shows, and only then", function()
		local s = setup()
		local backdrop = s.guard.backdrop
		expect(backdrop.Parent == s.gui).toBe(true)
		expect(backdrop.Modal).toBe(true) -- Roblox frees the mouse while a Modal button shows
		expect(backdrop.Visible).toBe(false)
		s.set(s.gui, "Enabled", true)
		expect(backdrop.Visible).toBe(true)
		expect(backdrop.ZIndex < s.window.ZIndex).toBe(true) -- behind the window
		expect(s.window.Active).toBe(true) -- a click on the window stays in it
		s.set(s.gui, "Enabled", false)
		expect(backdrop.Visible).toBe(false)
	end)

	it("follows a window shown and hidden by Visible as well as Enabled", function()
		local s = setup()
		s.set(s.window, "Visible", false)
		s.set(s.gui, "Enabled", true)
		expect(s.guard.backdrop.Visible).toBe(false)
		s.set(s.window, "Visible", true)
		expect(s.guard.backdrop.Visible).toBe(true)
		expect(s.guard.isOpen()).toBe(true)
	end)

	it("closes on a tap outside the window", function()
		local s = setup()
		s.click()
		expect(s.closes()).toBe(0) -- closed already: nothing to do
		s.set(s.gui, "Enabled", true)
		s.click()
		expect(s.closes()).toBe(1)
		expect(s.guard.backdrop.Visible).toBe(false)
	end)

	it("closes when the Roblox menu opens (Escape, Android Back)", function()
		local s = setup()
		s.menu()
		expect(s.closes()).toBe(0)
		s.set(s.gui, "Enabled", true)
		s.menu()
		expect(s.closes()).toBe(1)
	end)

	it("binds the gamepad's B button only while open, and B closes", function()
		local s = setup()
		expect(s.bindings()).toBe(0)
		s.set(s.gui, "Enabled", true)
		expect(s.bindings()).toBe(1)
		s.pressB()
		expect(s.closes()).toBe(1)
		expect(s.bindings()).toBe(0)
	end)
end)

-- Every window a player opens over the game goes through the guard: a
-- ScreenGui built with a "Close" button must also call Modal.attach (core
-- windows from UiKit.window get it there).
describe("Every window with an X is guarded", function()
	local DIRS = { "packages/core/client", "games/hatchery-heist/src/client" }
	it("calls Modal.attach wherever a Close button or UiKit.window is made", function()
		local missing = {}
		local checked = 0
		for _, dir in DIRS do
			local files = fs.readDir(dir)
			table.sort(files)
			for _, name in files do
				if not string.match(name, "%.luau$") or name == "Modal.luau" then
					continue
				end
				local source = fs.readFile(`{dir}/{name}`)
				local hasX = string.find(source, '%.Name = "Close"') ~= nil
					or string.find(source, "function UiKit%.window") ~= nil
				if hasX then
					checked += 1
					if string.find(source, "Modal%.attach%(") == nil then
						table.insert(missing, `{dir}/{name}`)
					end
				end
			end
		end
		expect(checked >= 5).toBe(true)
		expect(table.concat(missing, ", ")).toBe("")
	end)

	-- Screens that cover the game without a "Close"-named X.
	it("guards the feedback form, the welcome card and the hatch reveal", function()
		local missing = {}
		for _, path in
			{
				"packages/core/client/FeedbackUi.luau",
				"games/hatchery-heist/src/client/GuideView.luau",
				"games/hatchery-heist/src/client/HatchReveal.luau",
			}
		do
			local source = fs.readFile(path)
			if
				string.find(source, "Modal%.attach%(") == nil
				and string.find(source, "%.Modal = true") == nil
			then
				table.insert(missing, path)
			end
		end
		expect(table.concat(missing, ", ")).toBe("")
	end)
end)
