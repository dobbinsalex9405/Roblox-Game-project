--!strict
local Fakes = require("./Fakes")
local Net = require("@core/Net")
local Schema = require("@core/Schema")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local function setup()
	local clock = Fakes.clock()
	local drops = {}
	local server = Net.newServer({
		now = clock.now,
		onDrop = function(_player, name, reason)
			table.insert(drops, `{name}:{reason}`)
		end,
	})
	local remotes = {
		PlaceEgg = Net.toServer(
			"PlaceEgg",
			{ Schema.integer({ min = 1, max = 12 }), Schema.string({ maxLength = 20 }) },
			{ count = 3, window = 1 }
		),
		Notify = Net.toClient("Notify", { Schema.string() }),
	}
	server:register(remotes)
	return server, remotes, clock, drops
end

describe("Net", function()
	it("delivers valid calls to the handler", function()
		local server, remotes = setup()
		local got = {}
		server:on(remotes.PlaceEgg, function(player, slot, egg)
			table.insert(got, { player, slot, egg })
		end)
		local p = Fakes.player(1)
		expect(server:dispatch(p, "PlaceEgg", 2, "basic")).toBe("ok")
		expect(got[1][2]).toBe(2)
		expect(got[1][3]).toBe("basic")
	end)

	it("drops and counts wrong types, extra arguments and unknown names", function()
		local server, remotes, _, drops = setup()
		local calls = 0
		server:on(remotes.PlaceEgg, function()
			calls += 1
		end)
		local p = Fakes.player(1)
		expect(server:dispatch(p, "PlaceEgg", "2", "basic")).toBe("schema")
		expect(server:dispatch(p, "PlaceEgg", 2, "basic", "extra")).toBe("schema")
		expect(server:dispatch(p, "PlaceEgg", 0 / 0, "basic")).toBe("schema")
		expect(server:dispatch(p, "Nope")).toBe("unknown")
		expect(server:dispatch(p, "Notify", "hi")).toBe("wrong-direction")
		expect(calls).toBe(0)
		expect(server:drops(p)).toBe(5)
		expect(#drops).toBe(5)
	end)

	it("rate-limits floods per player and refills over time", function()
		local server, remotes, clock = setup()
		local calls = 0
		server:on(remotes.PlaceEgg, function()
			calls += 1
		end)
		local a, b = Fakes.player(1), Fakes.player(2)
		for _ = 1, 100 do
			server:dispatch(a, "PlaceEgg", 1, "basic")
		end
		expect(calls).toBe(3)
		expect(server:drops(a)).toBe(97)
		-- Another player has their own budget.
		expect(server:dispatch(b, "PlaceEgg", 1, "basic")).toBe("ok")
		clock.advance(1)
		expect(server:dispatch(a, "PlaceEgg", 1, "basic")).toBe("ok")
	end)

	it("contains handler errors", function()
		local server, remotes = setup()
		server:on(remotes.PlaceEgg, function()
			error("boom")
		end)
		expect(server:dispatch(Fakes.player(1), "PlaceEgg", 1, "basic")).toBe("error")
	end)

	it("refuses duplicate names, handlers and bad definitions", function()
		local server, remotes = setup()
		expect(function()
			server:register({ PlaceEgg = remotes.PlaceEgg })
		end).toThrow("registered twice")
		server:on(remotes.PlaceEgg, function() end)
		expect(function()
			server:on(remotes.PlaceEgg, function() end)
		end).toThrow("already has a handler")
		expect(function()
			Net.toServer("bad name!", {})
		end).toThrow("invalid remote name")
	end)
end)
