--!strict
-- Guards the pacing the config was tuned to (SPEC.md, Pacing). The game
-- leans idle: cooks carry a real share of the income, so a player who only
-- looks in now and then still gets to the rebirth. A config change that moves
-- these far needs a second look (and Alex's OK on a live game). The real
-- tuning happens in the M4 playtests.
local Bot = require("./Bot")
local Fakes = require("../../../packages/core/tests/Fakes")
local Harness = require("./Harness")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local function play(hours: number, options: Bot.Options?)
	local h = Harness.new()
	local player = Fakes.player(1)
	h.join(player)
	local start = h.clock.now()
	local run = Bot.play(h, player, hours * 3600, options)
	local function minutes(key: string): number
		local at = run.reached[key]
		assert(at, `never reached {key}`)
		return (at - start) / 60
	end
	return run, minutes, start
end

describe("Street Food Empire pacing", function()
	it("an attentive player reaches each district and the rebirth on schedule", function()
		local run, minutes, start = play(6)
		expect(minutes("District2")).toBeAtLeast(10)
		expect(minutes("District2")).toBeAtMost(20)
		expect(minutes("District3")).toBeAtLeast(40)
		expect(minutes("District3")).toBeAtMost(80)
		expect(minutes("RebirthReady")).toBeAtLeast(3.5 * 60)
		expect(minutes("RebirthReady")).toBeAtMost(5.5 * 60)
		-- Cooks earn a real share even for a player serving every customer.
		local handShare = run.served / (run.served + run.collected)
		expect(handShare).toBeAtLeast(0.3)
		expect(handShare).toBeAtMost(0.55)
		-- Something new to buy at least every few minutes in the first hour.
		expect(Bot.longestGap(run, start, start + 3600)).toBeAtMost(7 * 60)
	end)

	it("a player who looks in once a minute keeps up with an attentive one", function()
		local _, minutes = play(6, { checkInSeconds = 60 })
		expect(minutes("District2")).toBeAtMost(20)
		expect(minutes("RebirthReady")).toBeAtMost(5.5 * 60)
	end)

	it("a player who looks in every 5 minutes still reaches the rebirth in a long day", function()
		local run, minutes = play(9, { checkInSeconds = 300 })
		expect(minutes("District2")).toBeAtMost(40)
		expect(minutes("District3")).toBeAtMost(2 * 60)
		expect(minutes("RebirthReady")).toBeAtMost(8.5 * 60)
		-- They live on their cooks.
		expect(run.collected).toBeAtLeast(run.served * 3)
	end)
end)
