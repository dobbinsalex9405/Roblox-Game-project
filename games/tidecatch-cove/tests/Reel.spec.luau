--!strict
-- The reel minigame: winnable by a human-like player at every rarity, lost by
-- doing nothing, and never finished faster than the server's minimum.
local Reel = require("../src/shared/Reel")
local fishing = require("../config/fishing")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

local function dice(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 48271) % 2147483647
		return (state - 1) / 2147483646
	end
end

-- Plays one reel like a person: `lag` is how stale their view of the fish is
-- (seconds, a human's reaction time), and they lead the zone a little by
-- its speed. Returns the result and seconds.
local function play(
	rarity: string,
	tier: number,
	seed: number,
	lag: number,
	policy: string?
): (string, number)
	local params = Reel.params(rarity, tier, fishing)
	local random = dice(seed)
	local state = Reel.new(params, random)
	local dt = 1 / 60
	local seen: { number } = {}
	while true do
		table.insert(seen, state.fish)
		local delayed = seen[math.max(1, #seen - math.floor(lag / dt))]
		local holding = if policy == "idle"
			then false
			elseif policy == "hold" then true
			else state.zone + state.zoneVelocity * 0.35 < delayed
		local result = Reel.step(state, params, dt, holding, random)
		if result then
			return result, state.elapsed
		end
	end
end

local function rate(rarity: string, tier: number, lag: number): number
	local caught = 0
	for seed = 1, 200 do
		if play(rarity, tier, seed, lag) == "caught" then
			caught += 1
		end
	end
	return caught / 200
end

describe("Reel", function()
	it("a player with human reactions catches most fish, rarer ones less often", function()
		local previous = 1
		for _, rarity in RARITIES do
			local r = rate(rarity, 1, 0.2)
			expect(r).toBeAtMost(previous)
			previous = r
		end
		expect(rate("Common", 1, 0.25)).toBeAtLeast(0.95)
		expect(rate("Rare", 1, 0.2)).toBeAtLeast(0.8)
	end)

	it("the best rod makes every rarity catchable", function()
		for _, rarity in RARITIES do
			expect(rate(rarity, 3, 0.2)).toBeAtLeast(0.6)
		end
		expect(rate("Legendary", 3, 0.25) > rate("Legendary", 1, 0.25)).toBe(true)
	end)

	it("doing nothing, or holding all the time, mostly loses", function()
		for _, policy in { "idle", "hold" } do
			local caught = 0
			for seed = 1, 100 do
				if play("Rare", 1, seed, 0, policy) == "caught" then
					caught += 1
				end
			end
			expect(caught).toBeAtMost(20)
		end
	end)

	it("never finishes faster than the server's minimum", function()
		for _, rarity in RARITIES do
			local fastest = math.huge
			for seed = 1, 100 do
				local result, seconds = play(rarity, 3, seed, 0)
				if result == "caught" then
					fastest = math.min(fastest, seconds)
				end
			end
			-- The minigame starts after the hook, which takes reactionSeconds.
			expect(fastest + fishing.reel.reactionSeconds + 1e-9).toBeAtLeast(
				Reel.minSeconds(rarity, fishing)
			)
		end
	end)

	it("gives up after the timeout and survives frame hitches", function()
		local params = Reel.params("Common", 1, fishing)
		local state = Reel.new(params, dice(3))
		state.progress = 0.5
		params.drain = 0
		params.fill = 0
		local result: string? = nil
		for _ = 1, 10000 do
			result = Reel.step(state, params, 5, false, dice(4)) -- a 5 s hitch counts as 0.1 s
			if result then
				break
			end
		end
		expect(result).toBe("escaped")
		expect(state.elapsed).toBeCloseTo(params.timeoutSeconds, 0.11)
	end)
end)
