--!strict
-- Screens that change size mid-session (a window resized, a phone turned,
-- Studio's device emulator) refit what is drawn for them.
local Viewport = require("../src/shared/Viewport")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

-- A stand-in for an Instance with property-changed signals.
local function fake(props: { [string]: any }): any
	local listeners: { [string]: { () -> () } } = {}
	local object = setmetatable({}, {
		__index = props,
		__newindex = function(_, key, value)
			props[key] = value
			for _, fn in listeners[key] or {} do
				fn()
			end
		end,
	})
	function props.GetPropertyChangedSignal(_self: any, key: string)
		return {
			Connect = function(_signal: any, fn: () -> ())
				listeners[key] = listeners[key] or {}
				table.insert(listeners[key], fn)
			end,
		}
	end
	return object
end

describe("Viewport.watch", function()
	it("refits now, on every resize and on a new camera, never for an old one", function()
		-- Studio gate (#126): the odds card stayed at phone scale after the
		-- emulator went from phone to desktop.
		local first = fake({ ViewportSize = { X = 844, Y = 392 } })
		local world = fake({ CurrentCamera = first })
		local calls = 0
		Viewport.watch(world, function()
			calls += 1
		end)
		expect(calls).toBe(1)
		first.ViewportSize = { X = 1350, Y = 672 }
		expect(calls).toBe(2)
		local second = fake({ ViewportSize = { X = 1350, Y = 672 } })
		world.CurrentCamera = second
		expect(calls).toBe(3)
		second.ViewportSize = { X = 844, Y = 392 }
		expect(calls).toBe(4)
		first.ViewportSize = { X = 100, Y = 100 } -- the old camera: ignored
		expect(calls).toBe(4)
	end)
end)
