--!strict
-- Raid and defense rules (plan section 7, Wave 1 plan). Every limit is
-- checked on the server. Tuning these on a live game needs Alex's approval.
return {
	-- New players cannot be raided for their first few minutes.
	newPlayerProtectionSeconds = 300,
	-- A raider must wait this long before raiding the same owner again.
	perOwnerCooldownSeconds = 120,
	-- How close (studs) the raider must stand to pick a creature up.
	pickupReach = 8,
	-- Walk speed while carrying on foot; on a mount, the mount's speed times
	-- carryMountFactor. The owner riding a fast mount can catch a raider.
	carryWalkSpeed = 10,
	carryMountFactor = 0.7,
	-- How much faster than allowed the movement check tolerates (lag, physics).
	carrySpeedTolerance = 1.35,
	-- One creature at a time, for at most this long.
	maxCarried = 1,
	maxCarrySeconds = 60,
	-- The owner (or the guard creature) touching the raider within this many
	-- studs takes the creature back.
	ownerCatchReach = 6,
	guardCatchReach = 5,
	-- Guard creature: chases raiders it can see, at this fraction of its mount speed.
	guardSightRange = 30,
	guardSpeedFactor = 0.85,

	-- Shields. The free shield at the base pylon lasts freeShieldSeconds and
	-- can be raised again shieldCooldownSeconds after it ends. A Shield Refill
	-- (Robux) adds shieldSeconds. There is never a permanent shield.
	freeShieldSeconds = 90,
	shieldCooldownSeconds = 300,
	shieldSeconds = 600,

	-- Traps on the base's trap spots, bought with coins. A trap fires once on
	-- a raider, then re-arms.
	traps = {
		-- Stops the raider and returns a carried creature home.
		Snare = { price = 5000, stunSeconds = 2.5, rearmSeconds = 30 },
		-- Slows the raider.
		Slime = { price = 2000, slowFactor = 0.5, slowSeconds = 4, rearmSeconds = 20 },
	},

	-- Decoy eggs on the decoy spots look like a creature to raiders. Picking
	-- one up pops it, stuns the raider and alerts the owner.
	decoy = { price = 1500, stunSeconds = 1.5 },
}
