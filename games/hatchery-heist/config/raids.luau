--!strict
-- Raid rules (plan section 7). Every limit is checked on the server.
return {
	-- New players cannot be raided for their first few minutes.
	newPlayerProtectionSeconds = 300,
	-- A raider must wait this long before raiding the same owner again.
	perOwnerCooldownSeconds = 120,
	-- How close (studs) the raider must stand to pick a creature up.
	pickupReach = 8,
	-- Walk speed while carrying, and how much faster than that the server tolerates
	-- (lag, physics) before it drops the creature back home.
	carryWalkSpeed = 10,
	carrySpeedTolerance = 1.35,
	-- One creature at a time.
	maxCarried = 1,
	-- Shields.
	shieldSeconds = 600,
	shieldCooldownSeconds = 60,
}
