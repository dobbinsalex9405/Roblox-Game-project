--!strict
-- Whole sessions through the real core services and Actions. The M2 bar is
-- "10 minutes of play survive a rejoin, and pools grew while away".
local Catch = require("../src/shared/Catch")
local Cove = require("../src/shared/Cove")
local Creatures = require("../src/shared/Creatures")
local Fakes = require("../../../packages/core/tests/Fakes")
local Harness = require("./Harness")
local Reel = require("../src/shared/Reel")
local Util = require("@core/Util")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local config = Harness.config
local fishing = config.fishing
local NO_PERKS = { autoReel = false, extraPools = false, sellMultiplier = false }

-- Plays the reel minigame like a decent player: holds while the zone is left
-- of the fish. Returns whether it was caught and how long it took.
local function playReel(h: any, rarity: string, rodTier: number): (boolean, number)
	local params = Reel.params(rarity, rodTier, fishing)
	local state = Reel.new(params, h.random)
	local dt = 1 / 30
	-- The hook: a human taps a little after the bite.
	local elapsed = fishing.reel.reactionSeconds + 0.15
	while true do
		local result = Reel.step(state, params, dt, state.zone < state.fish, h.random)
		elapsed += dt
		if result then
			return result == "caught", elapsed
		end
	end
end

-- One cast to the end: wait for the bite, play the reel, report it.
local function fishOnce(h: any, player: any, spotId: string, baitId: string): boolean
	local bite = h.castAndWait(player, spotId, baitId)
	if bite == nil then
		return false
	end
	local caught, seconds = playReel(h, bite.rarity, h.get(player).rodTier)
	h.wait(seconds)
	return (h.actions:reel(player, bite.id, caught))
end

local function bestSpot(d: { [string]: any }): string
	local best = fishing.spots[1].id
	for _, spot in fishing.spots do
		if not spot.lowTideOnly and d.rodTier >= spot.minRod then
			best = spot.id
		end
	end
	return best
end

-- A simple player: fishes at the best spot it can, keeps catches in pools,
-- feeds them, sells grown ones, sells the bucket when it fills up, and spends
-- coins on pools, rods and worms.
local function play(h: any, player: any, seconds: number)
	local stop = h.time + seconds
	while h.time < stop do
		local d = h.get(player)
		local now = math.floor(h.time)
		for _, pooled in table.clone(d.pools) do
			local stage = Creatures.stage(pooled, now, config.species, config.pools)
			if stage >= 4 then
				h.actions:sellPool(player, pooled.slot)
			elseif Cove.feedCooldown(pooled, now, config.pools) == 0 then
				h.actions:feed(player, pooled.slot)
			end
		end
		d = h.get(player)
		local poolCount = Cove.poolCount(d, config.pools, NO_PERKS)
		for _, creature in table.clone(d.bucket) do
			if Cove.freePool(h.get(player), poolCount) == nil then
				break
			end
			h.actions:place(player, creature.uid)
		end
		if #h.get(player).bucket >= fishing.bucketSlots - 2 then
			h.actions:sellBucket(player)
		end
		d = h.get(player)
		local nextRod = fishing.rods[d.rodTier + 1]
		local poolCost = Cove.nextPoolCost(d, config.pools)
		if nextRod and d.coins >= nextRod.priceCoins + 100 then
			h.actions:buyRod(player, d.rodTier + 1)
		elseif poolCost and d.coins >= poolCost + 100 then
			h.actions:buyPool(player)
		elseif (d.bait.Worm or 0) < 2 and d.coins >= 200 then
			h.actions:buyBait(player, "Worm", 5)
		end
		d = h.get(player)
		local bait = if (d.bait.Worm or 0) > 0 then "Worm" else Catch.NO_BAIT
		fishOnce(h, player, bestSpot(d), bait)
		h.wait(1) -- walk, look at the catch
	end
end

-- The parts of the save a rejoin must keep exactly.
local function kept(d: { [string]: any }): { [string]: any }
	return Util.deepCopy({
		coins = d.coins,
		rodTier = d.rodTier,
		bait = d.bait,
		bucket = d.bucket,
		poolSlots = d.poolSlots,
		journal = d.journal,
		shop = d.shop,
		nextUid = d.nextUid,
		firsts = d.firsts,
		stats = d.stats,
	})
end

local function stages(h: any, d: { [string]: any }): { [string]: number }
	local out = {}
	for _, pooled in d.pools do
		out[pooled.uid] = Creatures.stage(pooled, math.floor(h.time), config.species, config.pools)
	end
	return out
end

describe("Tidecatch Cove sessions", function()
	it("10 minutes of play survive leaving and rejoining", function()
		local h = Harness.new()
		local player = Fakes.player(1)
		h.join(player)
		play(h, player, 600)

		local before = h.get(player)
		expect(before.stats.casts).toBeAtLeast(25)
		expect(before.stats.catches).toBeAtLeast(15)
		expect(#before.pools).toBeAtLeast(2)
		expect(before.stats.sold).toBeAtLeast(1)
		expect(before.stats.playSeconds).toBeAtLeast(590)
		local caught, total = Cove.journalCount(before, config.species)
		expect(caught).toBeAtLeast(5)
		expect(total).toBe(25)
		h.leave(player)
		-- What the store holds after leaving is what the next server must load.
		local _, saved: any = next(h.store.saved)
		local snapshot = kept(saved)
		local pools = Util.deepCopy(saved.pools)
		expect(#pools).toBe(#before.pools)

		-- Rejoin on a different server a moment later: same store, new services.
		local h2 = Harness.new({ store = h.store, start = h.time + 5 })
		h2.join(player)
		local after = h2.get(player)
		local expected = Util.deepCopy(snapshot)
		expect(kept(after)).toEqual(expected)
		-- Same creatures in the same pools, timers intact (5 s of absence credited).
		expect(#after.pools).toBe(#pools)
		for i, pooled in after.pools do
			expect(pooled.uid).toBe(pools[i].uid)
			expect(pooled.slot).toBe(pools[i].slot)
			expect(pooled.fed).toBe(pools[i].fed)
			expect(pooled.placedAt).toBe(pools[i].placedAt)
		end
	end)

	it("pools grow while away, up to the offline cap", function()
		local h = Harness.new()
		local player = Fakes.player(2)
		h.join(player)
		play(h, player, 120)
		local d = h.get(player)
		-- Put fresh creatures in every pool so they have room to grow.
		for _, pooled in table.clone(d.pools) do
			h.actions:sellPool(player, pooled.slot)
		end
		local guard = 0
		while #h.get(player).pools < 2 do
			guard += 1
			assert(guard < 60, "could not fill the pools")
			if #h.get(player).bucket == 0 then
				fishOnce(h, player, "Shallows", Catch.NO_BAIT)
			else
				h.actions:place(player, h.get(player).bucket[1].uid)
			end
		end
		local stagesBefore = stages(h, h.get(player))
		h.leave(player)

		-- Away 10 hours: growth counts 3 hours (pools.offline.maxSeconds).
		local away = 10 * 3600
		local h2 = Harness.new({ store = h.store, start = h.time + away })
		h2.join(player)
		local after = h2.get(player)
		local grewCount = 0
		for uid, stage in stages(h2, after) do
			expect(stage >= stagesBefore[uid]).toBe(true)
			if stage > stagesBefore[uid] then
				grewCount += 1
			end
		end
		expect(grewCount).toBeAtLeast(1)
		expect(h2.welcomes[1].grew).toBe(grewCount)
		expect(h2.welcomes[1].restocked).toBe(true)

		-- The capped part of the absence is never counted later.
		for _, pooled in after.pools do
			local rarity = config.species.species[pooled.speciesId].rarity
			local grown = Creatures.grown(pooled, math.floor(h2.time), rarity, config.pools)
			expect(grown).toBeAtMost(
				math.min(
					Creatures.growthSeconds(rarity, config.pools),
					120 + pooled.fed + config.pools.offline.maxSeconds
				)
			)
		end
	end)

	it("reports the onboarding steps once ever, in order", function()
		local h = Harness.new()
		local player = Fakes.player(3)
		h.join(player)
		play(h, player, 240)
		h.leave(player)
		local h2 = Harness.new({ store = h.store, start = h.time + 60 })
		h2.join(player)
		play(h2, player, 60)

		local steps = {}
		for _, args in h.eventsOf("onboarding") do
			table.insert(steps, args[2])
		end
		expect(steps).toEqual({ "Joined", "FirstCast", "FirstCatch", "FirstPlaced", "FirstGrowth" })
		expect(#h2.eventsOf("onboarding")).toBe(0)
		expect(#h.customEvents("Onboarding:FirstSale")).toBe(1)
		expect(#h2.customEvents("Onboarding:FirstSale")).toBe(0)
	end)

	it("gives new players their starting bait once", function()
		local h = Harness.new()
		local player = Fakes.player(4)
		h.join(player)
		expect(h.get(player).bait.Worm).toBe(config.economy.startingBait.Worm)
		expect(h.get(player).coins).toBe(config.economy.startingCoins)
		for _ = 1, 3 do
			fishOnce(h, player, "Shallows", "Worm")
		end
		local left = h.get(player).bait.Worm
		expect(left).toBe(config.economy.startingBait.Worm - 3)
		h.leave(player)
		local h2 = Harness.new({ store = h.store, start = h.time + 30 })
		h2.join(player)
		expect(h2.get(player).bait.Worm).toBe(left)
	end)

	it("rejects a reel faster than a human and counts it as lost", function()
		local h = Harness.new()
		local player = Fakes.player(5)
		h.join(player)
		local bite = h.castAndWait(player, "Shallows", Catch.NO_BAIT) :: any
		h.wait(0.1) -- far below Reel.minSeconds
		expect(h.actions:reel(player, bite.id, true)).toBeFalsy()
		expect(#h.caught).toBe(0)
		expect(h.get(player).stats.escapes).toBe(1)
		expect(#h.customEvents("Fish:ReelTooFast")).toBe(1)

		-- A reel at the fastest human pace is accepted.
		h.wait(fishing.castCooldownSeconds)
		bite = h.castAndWait(player, "Shallows", Catch.NO_BAIT) :: any
		h.wait(Reel.minSeconds(bite.rarity, fishing))
		expect(h.actions:reel(player, bite.id, true)).toBe(true)
		expect(#h.caught).toBe(1)
		expect(#h.get(player).bucket).toBe(1)
	end)

	it("refuses what the player cannot do and leaves the save alone", function()
		local h = Harness.new()
		local player = Fakes.player(6)
		h.join(player)
		local before = Util.deepCopy(h.get(player))

		expect(h.actions:cast(player, "Reef", Catch.NO_BAIT)).toBeFalsy() -- needs a better rod
		expect(h.actions:cast(player, "TideFlats", Catch.NO_BAIT)).toBeFalsy() -- low tide only
		expect(h.actions:cast(player, "Nowhere", Catch.NO_BAIT)).toBeFalsy()
		expect(h.actions:cast(player, "Shallows", "GoldenLure")).toBeFalsy() -- none owned
		expect(h.actions:cast(player, "Shallows", "Dynamite")).toBeFalsy()
		h.reachable = false
		expect(h.actions:cast(player, "Shallows", Catch.NO_BAIT)).toBeFalsy() -- not on the dock
		h.reachable = true
		expect(h.actions:reel(player, 1, true)).toBeFalsy() -- no line
		expect(h.actions:buyRod(player, 3)).toBeFalsy() -- 100 coins
		expect(h.actions:buyRod(player, 1)).toBeFalsy() -- already owned
		expect(h.actions:buyPool(player)).toBeFalsy()
		expect(h.actions:buyBait(player, "GoldenLure", 1)).toBeFalsy()
		expect(h.actions:sellCatch(player, "999")).toBeFalsy()
		expect(h.actions:sellBucket(player)).toBeFalsy()
		expect(h.actions:place(player, "999")).toBeFalsy()
		expect(h.actions:feed(player, 1)).toBeFalsy()
		expect(h.actions:sellPool(player, 1)).toBeFalsy()

		local after = h.get(player)
		expect(after.coins).toBe(before.coins)
		expect(after.bait).toEqual(before.bait)
		expect(after.stats.casts).toBe(0)
		expect(h.notices[#h.notices]).toBe("That pool is empty.")
		expect(#h.casts).toBe(0)
	end)

	it("lets the low-tide spot open when the tide says so", function()
		local h = Harness.new()
		local player = Fakes.player(7)
		h.join(player)
		h.lowTide = true
		expect(fishOnce(h, player, "TideFlats", Catch.NO_BAIT) ~= nil).toBe(true)
		expect(#h.casts).toBe(1)
	end)

	it("one cast at a time, and casting has a cooldown", function()
		local h = Harness.new()
		local player = Fakes.player(8)
		h.join(player)
		expect(h.actions:cast(player, "Shallows", Catch.NO_BAIT)).toBe(true)
		expect(h.actions:cast(player, "Shallows", Catch.NO_BAIT)).toBeFalsy() -- cooldown
		h.wait(fishing.castCooldownSeconds)
		-- Recasting before a bite replaces the line; the old one never bites.
		expect(h.actions:cast(player, "Shallows", Catch.NO_BAIT)).toBe(true)
		h.wait(fishing.biteSeconds.max + 1)
		expect(#h.bites).toBe(1)
		expect(h.bites[1].id).toBe(2)
		-- With a fish on, no new cast until it is reeled or lost.
		expect(h.actions:cast(player, "Shallows", Catch.NO_BAIT)).toBeFalsy()
		h.wait(Reel.maxSeconds(fishing) + 11)
		expect(h.actions:line(player)).toBeNil() -- the tick forgot it
		expect(h.actions:cast(player, "Shallows", Catch.NO_BAIT)).toBe(true)
	end)

	it("a full bucket sells new catches at once", function()
		local h = Harness.new()
		local player = Fakes.player(9)
		h.join(player)
		local guard = 0
		while #h.get(player).bucket < fishing.bucketSlots do
			guard += 1
			assert(guard < 100, "bucket never filled")
			fishOnce(h, player, "Shallows", Catch.NO_BAIT)
			h.wait(1)
		end
		local coins = h.get(player).coins
		local landed = #h.caught
		guard = 0
		while #h.caught == landed do
			guard += 1
			assert(guard < 20, "nothing caught")
			fishOnce(h, player, "Shallows", Catch.NO_BAIT)
			h.wait(1)
		end
		local last = h.caught[#h.caught]
		expect(last.soldFor > 0).toBe(true)
		expect(h.get(player).coins).toBe(coins + last.soldFor)
		expect(#h.get(player).bucket).toBe(fishing.bucketSlots)
	end)

	it("a better rod changes the odds board and the roll together", function()
		local h = Harness.new()
		local player = Fakes.player(10)
		h.join(player)
		local tableId = Catch.tableId("Shallows", Catch.NO_BAIT)
		local plain = h.odds:display(tableId, player)
		expect(#plain.boosts).toBe(0)
		h.economy:add(player, "coins", 5000, "Admin:Test")
		expect(h.actions:buyRod(player, 2)).toBe(true)
		local boosted = h.odds:display(tableId, player)
		expect(boosted.boosts[1]).toBe("ReefRod")
		local commonBefore, commonAfter = 0, 0
		for i, row in plain.rows do
			if config.species.species[row.id].rarity == "Common" then
				commonBefore += row.weight
				commonAfter += boosted.rows[i].weight
			end
		end
		expect(commonAfter < commonBefore).toBe(true)
		local total = 0
		for _, row in boosted.rows do
			total += row.weight
		end
		expect(total).toBe(10000)
		local progression = h.eventsOf("progression")
		expect(progression[#progression][1]).toBe("Rod")
		-- The Reef is open now.
		expect(fishOnce(h, player, "Reef", Catch.NO_BAIT) ~= nil).toBe(true)
		expect(#h.casts).toBe(1)
	end)
end)

describe("Tidecatch Cove paid bait", function()
	-- A bait sold for Robux (milestone M5) makes its casts paid random rolls.
	local function robuxFishing()
		local f = Util.deepCopy(fishing)
		f.bait[1].robux = true
		return f
	end

	it("restricted players cannot cast with a paid bait, and keep it", function()
		local h = Harness.new({ restricted = true, fishing = robuxFishing() })
		local player = Fakes.player(11)
		h.join(player)
		local worms = h.get(player).bait.Worm
		expect(h.actions:cast(player, "Shallows", "Worm")).toBeFalsy()
		expect(h.get(player).bait.Worm).toBe(worms)
		expect(h.notices[#h.notices]).toContain("not available")
		-- Free casts still work for them.
		expect(h.actions:cast(player, "Shallows", Catch.NO_BAIT)).toBe(true)
	end)

	it("everyone else rolls paid bait through the policy-checked path", function()
		local h = Harness.new({ fishing = robuxFishing() })
		local player = Fakes.player(12)
		h.join(player)
		expect(h.odds:display(Catch.tableId("Shallows", "Worm"), player).paid).toBe(true)
		expect(fishOnce(h, player, "Shallows", "Worm") ~= nil).toBe(true)
		expect(#h.bites).toBe(1)
	end)
end)
