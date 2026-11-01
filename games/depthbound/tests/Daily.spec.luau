--!strict
-- The daily return reward: the first real haul sold each UTC day pays
-- double, once per day across servers, whether sold at the pad or by Auto-Sell.
local Daily = require("../src/shared/Daily")
local Fakes = require("../../../packages/core/tests/Fakes")
local Guide = require("../src/shared/Guide")
local Harness = require("./Harness")
local Pack = require("../src/shared/Pack")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local config = Harness.config
local dailyHaul = config.dive.dailyHaul
local DAY = 24 * 60 * 60
-- 10:00 UTC, so a few hours never cross midnight by accident.
local MORNING = 20_000 * DAY + 10 * 60 * 60

local function sell(h: any, p: any, items: { [string]: number }): number
	h.data:update(p, function(d)
		for id, n in items do
			d.pack[id] = n
		end
	end)
	local before = h.get(p).coins
	expect(h.actions:sell(p)).toBe(true)
	return h.get(p).coins - before
end

describe("Depthbound daily first haul", function()
	it("pays the first real haul of each day double, once", function()
		local h = Harness.new({ start = MORNING })
		local p = Fakes.player(1)
		h.join(p)
		local small = { Coal = dailyHaul.minPieces - 1 }
		local haul = { Coal = dailyHaul.minPieces, Copper = 1 }
		local base = Pack.value(haul, config.blocks)
		-- A small sale does not use it up.
		expect(sell(h, p, small)).toBe(Pack.value(small, config.blocks))
		expect(Daily.available(h.get(p), h.clock.now())).toBe(true)
		expect(sell(h, p, haul)).toBe(base * dailyHaul.multiplier)
		expect(h.notices[#h.notices]).toContain("first haul")
		expect(Daily.available(h.get(p), h.clock.now())).toBe(false)
		-- Same day, even on another server: normal price.
		h.clock.advance(6 * 60 * 60)
		expect(sell(h, p, haul)).toBe(base)
		h.leave(p)
		local h2 = Harness.new({ store = h.store, start = h.clock.now() + 60 })
		h2.join(p)
		expect(sell(h2, p, haul)).toBe(base)
		-- Next UTC day: double again.
		h2.clock.advance(DAY)
		expect(sell(h2, p, haul)).toBe(base * dailyHaul.multiplier)
		local paid = 0
		for _, args in h2.eventsOf("custom") do
			if args[1] == "Daily:FirstHaul" then
				paid += 1
			end
		end
		expect(paid).toBe(1)
	end)

	it("Auto-Sell on the way out takes it too", function()
		local h = Harness.new({ start = MORNING })
		h.perks.autoSell = true
		local p = Fakes.player(1)
		h.join(p)
		h.standOn(p, 8, 8)
		h.wait(p, 0.2)
		local haul = { Coal = dailyHaul.minPieces }
		h.data:update(p, function(d)
			d.pack.Coal = dailyHaul.minPieces
		end)
		h.toCamp(p)
		h.wait(p, 0.2)
		expect(h.get(p).coins).toBe(Pack.value(haul, config.blocks) * dailyHaul.multiplier)
	end)

	it("the goal line advertises it after the first upgrade, until it is taken", function()
		local h = Harness.new({ start = MORNING })
		local p = Fakes.player(1)
		h.join(p)
		local d = h.get(p)
		d.firsts.FirstBlockMined, d.firsts.FirstSale, d.firsts.FirstUpgrade = 1, 2, 3
		local now = h.clock.now()
		expect(Guide.objective(d, config.gear, "Camp", dailyHaul, now)).toContain("first haul")
		expect(Guide.objective(d, config.gear, "Camp")).toBeNil()
		sell(h, p, { Coal = dailyHaul.minPieces })
		expect(Guide.objective(h.get(p), config.gear, "Camp", dailyHaul, now)).toBeNil()
	end)
end)
