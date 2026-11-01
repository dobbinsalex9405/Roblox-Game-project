--!strict
-- Guards the pacing the config was tuned to: an attentive player (tests/Bot)
-- opens Market Row in about a quarter of an hour and Downtown in about an
-- hour, and can afford the rebirth after about six hours. A config change
-- that moves these far needs a second look (and Alex's OK on a live game).
-- The real tuning happens in the M4 playtests.
local Bot = require("./Bot")
local Fakes = require("../../../packages/core/tests/Fakes")
local Harness = require("./Harness")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

describe("Street Food Empire pacing", function()
	it("an attentive player reaches each district and the rebirth on schedule", function()
		local h = Harness.new()
		local player = Fakes.player(1)
		h.join(player)
		local start = h.clock.now()
		local reached = Bot.play(h, player, 8 * 3600)
		local function minutes(key: string): number
			local at = reached[key]
			assert(at, `never reached {key}`)
			return (at - start) / 60
		end
		expect(minutes("District2")).toBeAtLeast(8)
		expect(minutes("District2")).toBeAtMost(25)
		expect(minutes("District3")).toBeAtLeast(40)
		expect(minutes("District3")).toBeAtMost(100)
		expect(minutes("RebirthReady")).toBeAtLeast(4 * 60)
		expect(minutes("RebirthReady")).toBeAtMost(7.5 * 60)
	end)
end)
