--!strict
-- The first-session guide always has a goal and a place to go, its goals come
-- in the funnel's order, and following it gets a new player to Market Row.
local Bot = require("./Bot")
local Fakes = require("../../../packages/core/tests/Fakes")
local Guide = require("../src/shared/Guide")
local Harness = require("./Harness")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local ORDER = { Serve = 1, Build = 2, Upgrade = 3, Hire = 4, Unlock = 5 }

local function money(n: number): string
	return `${math.floor(n)}`
end

local function step(h: any, player: any, autoCollect: boolean?): Guide.Step?
	return Guide.next(h.get(player), h.config, h.perks, h.clock.now(), autoCollect == true, money)
end

describe("Street Food Empire first-session guide", function()
	it("greets a new player and points at the counter within seconds", function()
		local h = Harness.new()
		local player = Fakes.player(1)
		h.join(player)
		local first = step(h, player) :: Guide.Step
		expect(first.id).toBe("Serve")
		expect((first.target :: Guide.Target).kind).toBe("Counter")
		h.wait(player, 10)
		expect((step(h, player) :: Guide.Step).text).toBe("A customer is waiting! Serve them at the counter.")
	end)

	it("walks an attentive player from the first customer to Market Row, in order", function()
		local h = Harness.new()
		local player = Fakes.player(2)
		h.join(player)
		local seen: { string } = {}
		local last = 0
		local finishedAt: number? = nil
		local start = h.clock.now()
		-- Twenty minutes of attentive play, checking the guide every second.
		for second = 1, 20 * 60 do
			local s = step(h, player)
			if s == nil then
				finishedAt = finishedAt or h.clock.now()
			else
				expect(s.target ~= nil).toBe(true)
				expect(#s.text > 0).toBe(true)
				local rank = ORDER[s.id]
				expect(rank ~= nil).toBe(true)
				expect(rank >= last).toBe(true)
				if rank > last then
					table.insert(seen, s.id)
					last = rank
				end
			end
			if second % 30 == 0 then
				h.actions:collect(player)
			end
			Bot.play(h, player, 1)
		end
		-- A quick player can finish a goal between two looks, so steps may be
		-- skipped, but never revisited.
		expect(seen[1]).toBe("Serve")
		expect(seen[#seen]).toBe("Unlock")
		assert(finishedAt, "the guide never finished")
		expect(finishedAt - start).toBeAtMost(20 * 60)
		expect(h.get(player).districts).toBe(2)
	end)

	it("sends a player with cash in the register to collect it", function()
		local h = Harness.new()
		local player = Fakes.player(3)
		h.join(player)
		h.give(player, 10_000)
		h.wait(player, 10)
		h.actions:serve(player)
		assert(h.actions:build(player, "LemonadeStand", 2), "build")
		assert(h.actions:upgrade(player, 1), "upgrade")
		assert(h.actions:hireCook(player, "Trainee", 1), "hire")
		-- Spend down: the cook's register is what pays for the next goal.
		local d = h.get(player)
		h.economy:spend(player, "cash", d.cash, "Admin:Test")
		h.wait(player, 120)
		local s = step(h, player) :: Guide.Step
		expect(s.id).toBe("Unlock")
		expect((s.target :: Guide.Target).kind).toBe("Register")
		-- With Auto-Collect the register empties itself; never send them there.
		local auto = step(h, player, true) :: Guide.Step
		expect((auto.target :: Guide.Target).kind ~= "Register").toBe(true)
	end)
end)
