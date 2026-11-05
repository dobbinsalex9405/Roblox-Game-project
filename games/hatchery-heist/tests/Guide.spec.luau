--!strict
-- The first-session guide always has one clear next goal, in order, and goes
-- away once the player unlocks their 4th incubator.
local DataTemplate = require("../src/shared/DataTemplate")
local Guide = require("../src/shared/Guide")
local Util = require("@core/Util")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local economy = require("../config/economy")
local NOW = 1_800_000_000

local function money(n: number): string
	return tostring(n)
end

local function fresh(): { [string]: any }
	local d = Util.deepCopy(DataTemplate.template)
	d.meta.sessions = 1
	d.firsts.Joined = NOW - 10
	return d
end

local function step(d: { [string]: any }): Guide.Step?
	return Guide.next(d, economy, NOW, money)
end

describe("Hatchery Heist guide", function()
	it("starts by sending a new player to the belt", function()
		local s = step(fresh()) :: Guide.Step
		expect(s.id).toBe("BuyEgg")
		expect((s.target :: Guide.Target).kind).toBe("Belt")
	end)

	it("points at the hatching egg with a countdown, then says hatch when ready", function()
		local d = fresh()
		d.firsts.FirstEggBought = NOW - 3
		d.incubators =
			{ { slot = 2, eggId = "BasicEgg", startedAt = NOW - 3, readyAt = NOW + 7, outcome = "Chick" } }
		local waiting = step(d) :: Guide.Step
		expect(waiting.id).toBe("WaitHatch")
		expect((waiting.target :: Guide.Target).slot).toBe(2)
		expect(string.find(waiting.text, "7s", 1, true) ~= nil).toBe(true)
		d.incubators[1].readyAt = NOW
		local ready = step(d) :: Guide.Step
		expect(ready.id).toBe("Hatch")
		expect((ready.target :: Guide.Target).slot).toBe(2)
	end)

	it("sends the player to collect after the first hatch", function()
		local d = fresh()
		d.firsts.FirstEggBought = NOW - 20
		d.firsts.FirstHatch = NOW - 5
		local s = step(d) :: Guide.Step
		expect(s.id).toBe("Collect")
		expect((s.target :: Guide.Target).kind).toBe("CollectPad")
	end)

	it("a ready egg comes before anything else after the first hatch", function()
		local d = fresh()
		d.firsts.FirstEggBought = NOW - 20
		d.firsts.FirstHatch = NOW - 5
		d.incubators =
			{ { slot = 1, eggId = "BasicEgg", startedAt = NOW - 20, readyAt = NOW - 1, outcome = "Chick" } }
		expect((step(d) :: Guide.Step).id).toBe("Hatch")
	end)

	it("then works toward the 4th incubator, showing progress, and ends when it is bought", function()
		local d = fresh()
		d.firsts.FirstEggBought = NOW - 60
		d.firsts.FirstHatch = NOW - 50
		d.firsts.FirstCollect = NOW - 10
		d.coins = 120
		local earn = step(d) :: Guide.Step
		expect(earn.id).toBe("EarnForSlot")
		expect(string.find(earn.text, "120 / 500", 1, true) ~= nil).toBe(true)
		d.coins = 500
		local buy = step(d) :: Guide.Step
		expect(buy.id).toBe("BuySlot")
		expect((buy.target :: Guide.Target).slot).toBe(4)
		d.firsts.FirstSlot = NOW
		d.slots = 4
		expect(step(d)).toBe(nil)
	end)

	it("shows the welcome screen only to brand-new players", function()
		expect(Guide.isNewPlayer(fresh())).toBe(true)
		local back = fresh()
		back.meta.sessions = 2
		expect(Guide.isNewPlayer(back)).toBe(false)
		local bought = fresh()
		bought.firsts.FirstEggBought = NOW
		expect(Guide.isNewPlayer(bought)).toBe(false)
	end)
end)
