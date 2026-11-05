--!strict
-- Raids and defenses through the real core services, Actions and Raids.
local Defenses = require("../src/shared/Defenses")
local Fakes = require("../../../packages/core/tests/Fakes")
local Harness = require("./Harness")
local Movement = require("@core/Movement")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local economyConfig = require("../config/economy")
local creaturesConfig = require("../config/creatures")
local raidsConfig = require("../config/raids")

-- Two players on one server: an owner with creatures on pads 1-3 and a
-- raider, both past new-player protection.
local function setup()
	local h = Harness.new()
	local owner = Fakes.player(1)
	local raider = Fakes.player(2)
	h.join(owner)
	h.join(raider)
	h.data:update(owner, function(d)
		d.creatures = {
			{
				uid = "1",
				speciesId = "Penguin",
				mutation = "None",
				slot = 1,
				eggId = "MeadowEgg",
				hatchedAt = 0,
			},
			{
				uid = "2",
				speciesId = "Chick",
				mutation = "None",
				slot = 2,
				eggId = "BasicEgg",
				hatchedAt = 0,
			},
			{
				uid = "3",
				speciesId = "Owlet",
				mutation = "None",
				slot = 3,
				eggId = "MeadowEgg",
				hatchedAt = 0,
			},
		}
		d.nextUid = 4
	end)
	h.clock.advance(raidsConfig.newPlayerProtectionSeconds + 1)
	return h, owner, raider
end

local function uids(d: { [string]: any }): { string }
	local out = {}
	for _, c in d.creatures do
		table.insert(out, c.speciesId)
	end
	table.sort(out)
	return out
end

describe("Raids", function()
	it("protects new players, shielded bases and recently raided owners", function()
		local h = Harness.new()
		local owner, raider = Fakes.player(1), Fakes.player(2)
		h.join(owner)
		h.join(raider)
		local ok, why = h.raids:enter(raider, owner)
		expect(ok).toBe(false)
		expect(string.find(why :: string, "new and protected", 1, true) ~= nil).toBe(true)

		h.clock.advance(raidsConfig.newPlayerProtectionSeconds + 1)
		expect(h.raids:raiseShield(owner)).toBe(true)
		local shielded, why2 = h.raids:enter(raider, owner)
		expect(shielded).toBe(false)
		expect(string.find(why2 :: string, "shielded", 1, true) ~= nil).toBe(true)
		expect(h.raids:raiseShield(owner)).toBe(false) -- already up

		h.clock.advance(raidsConfig.freeShieldSeconds + 1)
		expect((h.raids:enter(raider, owner))).toBe(true)
		expect(h.lastNotice(owner)).toBe("Player2 is raiding your base!")
		expect(h.raids:raiseShield(owner)).toBe(false) -- recharging
		expect(h.raids:enter(raider, raider)).toBe(false) -- own base is not a raid
	end)

	it("a delivered creature changes owner, and a cooldown follows", function()
		local h, owner, raider = setup()
		assert(h.raids:enter(raider, owner))
		expect(h.raids:steal(raider, 9, 2)).toBe(false) -- empty pad
		expect(h.raids:steal(raider, 1, raidsConfig.pickupReach + 1)).toBe(false) -- too far
		expect(h.raids:steal(raider, 1, 3)).toBe(true)
		expect(h.raids:steal(raider, 2, 3)).toBe(false) -- one at a time
		expect(h.raids:carriedFrom(owner)["1"]).toBe(true)
		expect(#h.get(owner).creatures).toBe(3) -- still the owner's until delivered

		expect(h.raids:deliver(raider)).toBe(true)
		expect(uids(h.get(owner))).toEqual({ "Chick", "Owlet" })
		local mine = h.get(raider)
		expect(#mine.creatures).toBe(1)
		expect(mine.creatures[1].speciesId).toBe("Penguin")
		expect(mine.creatures[1].uid).toBe("1") -- a fresh uid in the raider's save
		expect(mine.creatures[1].slot).toBe(1)
		expect(mine.stats.raidsWon).toBe(1)
		expect(h.get(owner).stats.raidsLost).toBe(1)
		expect(h.raids:raidOf(raider)).toBeNil()

		local again, why = h.raids:enter(raider, owner)
		expect(again).toBe(false)
		expect(string.find(why :: string, "again in", 1, true) ~= nil).toBe(true)
		h.clock.advance(raidsConfig.perOwnerCooldownSeconds + 1)
		expect((h.raids:enter(raider, owner))).toBe(true)
	end)

	it("the owner catching the raider keeps the creature and counts as a defense", function()
		local h, owner, raider = setup()
		assert(h.raids:enter(raider, owner))
		assert(h.raids:steal(raider, 3, 2))
		h.raids:drop(raider, "owner")
		expect(uids(h.get(owner))).toEqual({ "Chick", "Owlet", "Penguin" })
		expect(#h.get(raider).creatures).toBe(0)
		expect(h.lastNotice(raider)).toBe("The owner caught you and took it back!")
		expect(h.get(owner).firsts.FirstRaidDefended).toBeTruthy()
		local defended = false
		for _, args in h.eventsOf("custom") do
			if args[1] == "Raid:Defended" then
				defended = true
			end
		end
		expect(defended).toBe(true)
	end)

	it("never lets the ridden creature or the guard be taken", function()
		local h, owner, raider = setup()
		assert(h.actions:ride(owner, "1"))
		assert(h.raids:toggleGuard(owner, "3"))
		expect(h.actions:ride(owner, "3")).toBe(false) -- the guard cannot be ridden
		assert(h.raids:enter(raider, owner))
		local ridden, why = h.raids:steal(raider, 1, 2)
		expect(ridden).toBe(false)
		expect(why).toBe("Its owner is riding it.")
		local guard, why2 = h.raids:steal(raider, 3, 2)
		expect(guard).toBe(false)
		expect(why2).toBe("That creature is guarding the base.")
		expect(h.raids:steal(raider, 2, 2)).toBe(true)
	end)

	it("a snare stuns and returns the creature; slime slows; traps re-arm", function()
		local h, owner, raider = setup()
		h.economy:add(owner, "coins", 100000, "Admin:Test")
		assert(h.raids:buyTrap(owner, 1, "Snare"))
		assert(h.raids:buyTrap(owner, 2, "Slime"))
		expect(h.raids:buyTrap(owner, 1, "Slime")).toBe(false) -- spot taken
		expect(h.raids:buyTrap(owner, 99, "Slime")).toBe(false)
		expect(h.raids:buyTrap(owner, 3, "Laser")).toBe(false)
		assert(h.raids:enter(raider, owner))
		assert(h.raids:steal(raider, 1, 2))
		expect(h.raids:trap(raider, 1)).toBe("Snare")
		expect(h.stuns[#h.stuns].seconds).toBe(raidsConfig.traps.Snare.stunSeconds)
		expect(h.raids:raidOf(raider)).toBeNil() -- the raid ended with the drop
		expect(#h.get(owner).creatures).toBe(3)

		h.clock.advance(raidsConfig.perOwnerCooldownSeconds + 1)
		assert(h.raids:enter(raider, owner))
		expect(h.raids:trap(raider, 2)).toBe("Slime")
		expect(h.slows[#h.slows].factor).toBe(raidsConfig.traps.Slime.slowFactor)
		expect(h.raids:trap(raider, 2)).toBeNil() -- not re-armed yet
		h.clock.advance(raidsConfig.traps.Slime.rearmSeconds)
		expect(h.raids:trap(raider, 2)).toBe("Slime")
		expect(h.raids:trap(raider, 4)).toBeNil() -- no trap there
	end)

	it("decoy eggs pop, stun the raider and are used up", function()
		local h, owner, raider = setup()
		h.economy:add(owner, "coins", 10000, "Admin:Test")
		assert(h.raids:buyDecoy(owner, 1))
		expect(h.get(owner).coins).toBe(economyConfig.startingCoins + 10000 - raidsConfig.decoy.price)
		assert(h.raids:enter(raider, owner))
		expect(h.raids:stealDecoy(raider, 1, 2)).toBe(true)
		expect(h.stuns[#h.stuns].seconds).toBe(raidsConfig.decoy.stunSeconds)
		expect(#h.get(owner).decoys).toBe(0)
		expect(h.raids:stealDecoy(raider, 1, 2)).toBe(false)
	end)

	it("a player leaving mid-raid never loses or duplicates the creature", function()
		local h, owner, raider = setup()
		assert(h.raids:enter(raider, owner))
		assert(h.raids:steal(raider, 1, 2))
		h.leave(raider)
		expect(#h.get(owner).creatures).toBe(3)
		expect(next(h.raids:carriedFrom(owner))).toBeNil()

		local raider2 = Fakes.player(3)
		h.join(raider2)
		h.clock.advance(raidsConfig.newPlayerProtectionSeconds + 1)
		assert(h.raids:enter(raider2, owner))
		assert(h.raids:steal(raider2, 1, 2))
		h.leave(owner)
		expect(h.raids:raidOf(raider2)).toBeNil()
		expect(#h.get(raider2).creatures).toBe(0)
	end)

	it("respawning while carrying sends the creature home, not to the raider", function()
		local h, owner, raider = setup()
		assert(h.raids:enter(raider, owner))
		assert(h.raids:steal(raider, 1, 2))
		h.raids:drop(raider, "respawn")
		expect(h.raids:raidOf(raider)).toBeNil()
		expect(h.raids:deliver(raider)).toBe(false)
		expect(#h.get(owner).creatures).toBe(3)
		expect(#h.get(raider).creatures).toBe(0)
		expect(h.lastNotice(raider)).toBe("You were knocked out; the creature ran home.")
		expect(h.get(owner).firsts.FirstRaidDefended).toBeNil() -- not a defense
	end)

	it("a carry that takes too long ends, and a rebirth mid-carry means it got away", function()
		local h, owner, raider = setup()
		assert(h.raids:enter(raider, owner))
		assert(h.raids:steal(raider, 1, 2))
		h.clock.advance(raidsConfig.maxCarrySeconds + 1)
		h.raids:tick()
		expect(h.raids:raidOf(raider)).toBeNil()
		expect(h.lastNotice(raider)).toBe("You took too long; the creature ran home.")

		h.clock.advance(raidsConfig.perOwnerCooldownSeconds + 1)
		assert(h.raids:enter(raider, owner))
		assert(h.raids:steal(raider, 2, 2))
		h.economy:add(owner, "coins", 10_000_000, "Admin:Test")
		assert(h.actions:rebirth(owner))
		expect(h.raids:deliver(raider)).toBe(false)
		expect(#h.get(raider).creatures).toBe(0)
		expect(h.lastNotice(raider)).toBe("It slipped away.")
	end)

	it("a scripted speed hack or teleport while carrying is caught by the movement check", function()
		local h, owner, raider = setup()
		assert(h.raids:enter(raider, owner))
		assert(h.raids:steal(raider, 1, 2))
		local speed = Defenses.carrySpeed(nil, raidsConfig)
		local movement =
			Movement.new({ tolerance = raidsConfig.carrySpeedTolerance, burstSeconds = 2, slackStuds = 4 })
		movement:reset(raider, 0, 0, 0)
		-- Honest carrying for 3 seconds passes.
		local x, time = 0, 0
		for _ = 1, 12 do
			x += speed * 0.25
			time += 0.25
			expect((movement:check(raider, x, 0, time, speed))).toBe("ok")
		end
		-- Speed hack: three times the carry speed.
		local caught = false
		for _ = 1, 12 do
			x += speed * 3 * 0.25
			time += 0.25
			if movement:check(raider, x, 0, time, speed) == "violation" then
				h.raids:drop(raider, "speed")
				caught = true
				break
			end
		end
		expect(caught).toBe(true)
		expect(#h.get(owner).creatures).toBe(3)

		-- Teleport.
		h.clock.advance(raidsConfig.perOwnerCooldownSeconds + 1)
		assert(h.raids:enter(raider, owner))
		assert(h.raids:steal(raider, 1, 2))
		movement:reset(raider, 0, 0, 100)
		expect((movement:check(raider, 0, 200, 100.25, speed))).toBe("violation")
	end)

	it("the guard must be on a pad, and toggles off", function()
		local d: any = {
			creatures = { { uid = "1", speciesId = "Chick", mutation = "None", slot = nil } },
			guardUid = "",
			mountUid = "",
		}
		expect(Defenses.toggleGuard(d, "1")).toBe(false)
		d.creatures[1].slot = 4
		expect(Defenses.toggleGuard(d, "1")).toBe(true)
		expect(d.guardUid).toBe("1")
		expect(Defenses.toggleGuard(d, "1")).toBe(true)
		expect(d.guardUid).toBe("")
		expect(Defenses.carrySpeed(32, raidsConfig)).toBe(32 * raidsConfig.carryMountFactor)
		expect(Defenses.carrySpeed(nil, raidsConfig)).toBe(raidsConfig.carryWalkSpeed)
	end)

	-- #49: a base with no guard (every new player) made the guard loop index
	-- `false` on every frame, because `d and d.guardUid ~= "" and ...` is
	-- `false`, not nil, and the loop only skipped nil.
	it("a base with no guard has no guard, as nil, never false", function()
		local species = creaturesConfig.species
		local d: any = {
			creatures = { { uid = "1", speciesId = "Chick", mutation = "None", slot = 2 } },
			guardUid = "",
			mountUid = "",
		}
		for _, data in { d, nil } do
			local creature, kind = Defenses.guardOf(data, species)
			expect(creature).toBeNil()
			expect(kind).toBeNil()
		end
		d.guardUid = "9" -- a guard that was sold or stolen
		expect((Defenses.guardOf(d, species))).toBeNil()
		d.guardUid = "1"
		local creature, kind = Defenses.guardOf(d, species)
		expect(creature.uid).toBe("1")
		expect(kind).toBe(species.Chick)
		d.creatures[1].speciesId = "Retired" -- a species removed from the config
		expect((Defenses.guardOf(d, species))).toBeNil()
	end)
end)
