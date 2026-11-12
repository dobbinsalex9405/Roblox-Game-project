--!strict
-- Raids as the server runs them (spec "Raids"): enter a rival base, pick up one
-- creature, carry it home at carry speed; the owner, the guard creature or a
-- trap takes it back. Raid state lives in server memory only: a creature
-- being carried stays in its owner's save until the raider reaches home, and
-- only then moves, so a crash or a disconnect mid-raid can never lose or
-- duplicate it.
--
-- Positions and touches are measured by the server adapter
-- (src/server/RaidService.luau) and passed in, so every rule here runs in
-- the Lune tests.

local Actions = require("./Actions")
local Defenses = require("./Defenses")
local Hatchery = require("./Hatchery")
local Merge = require("./Merge")

-- "respawn": the raider's character died or reset (respawning at home must
-- never count as a delivery).
export type DropReason = "owner" | "guard" | "trap" | "speed" | "timeout" | "left" | "gone" | "respawn"

export type Carry = {
	uid: string,
	speciesId: string,
	pickedAt: number,
}

export type Raid = {
	owner: any,
	enteredAt: number,
	carrying: Carry?,
}

export type Options = {
	actions: Actions.Actions,
	data: any,
	analytics: any,
	config: { raids: any, creatures: any, economy: any },
	now: () -> number,
	notify: (player: any, text: string) -> (),
	name: (player: any) -> string,
	userId: (player: any) -> number,
	-- Physical effects on a raider (applied by the server adapter).
	stun: (player: any, seconds: number) -> (),
	slow: (player: any, factor: number, seconds: number) -> (),
	-- The raider's carry state changed (speed and the carried model).
	changed: (raider: any) -> (),
}

export type Raids = {
	enter: (self: Raids, raider: any, owner: any) -> (boolean, string?),
	exit: (self: Raids, raider: any) -> (),
	steal: (self: Raids, raider: any, pad: number, distance: number) -> (boolean, string?),
	stealDecoy: (self: Raids, raider: any, spot: number, distance: number) -> (boolean, string?),
	drop: (self: Raids, raider: any, reason: DropReason) -> (),
	deliver: (self: Raids, raider: any) -> (boolean, string?),
	trap: (self: Raids, raider: any, spot: number) -> string?,
	raidOf: (self: Raids, raider: any) -> Raid?,
	carriedFrom: (self: Raids, owner: any) -> { [string]: boolean },
	raidersOf: (self: Raids, owner: any) -> { any },
	tick: (self: Raids) -> (),
	raiseShield: (self: Raids, owner: any) -> (boolean, string?),
	buyTrap: (self: Raids, owner: any, spot: number, kind: string) -> (boolean, string?),
	buyDecoy: (self: Raids, owner: any, spot: number) -> (boolean, string?),
	toggleGuard: (self: Raids, owner: any, uid: string) -> (boolean, string?),
	leave: (self: Raids, player: any) -> (),
}

local DEFENDED: { [string]: boolean } = { owner = true, guard = true, trap = true }

local Raids = {}

function Raids.new(options: Options): Raids
	local raidsConfig = options.config.raids
	local actions = options.actions
	local analytics = options.analytics

	local active: { [any]: Raid } = {}
	-- cooldowns[raider][ownerUserId] = unix seconds
	local cooldowns: { [any]: { [number]: number } } = {}
	-- trapFiredAt[owner][spot] = unix seconds
	local trapFiredAt: { [any]: { [number]: number } } = {}

	local raids = {}

	local function startCooldown(raider: any, owner: any)
		local list = cooldowns[raider] or {}
		cooldowns[raider] = list
		list[options.userId(owner)] = options.now() + raidsConfig.perOwnerCooldownSeconds
	end

	local function ownerData(owner: any): Hatchery.Data?
		return options.data:get(owner)
	end

	-- Called when the server sees `raider` step onto `owner`'s base.
	function raids.enter(_self: Raids, raider: any, owner: any): (boolean, string?)
		if raider == owner then
			return false, "own base"
		end
		local current = active[raider]
		if current and current.owner == owner then
			return true, nil
		end
		if current and current.carrying then
			return false, "You are already carrying a creature."
		end
		local d = ownerData(owner)
		if d == nil then
			return false, "That base is not ready."
		end
		local now = options.now()
		local list = cooldowns[raider]
		local refusal = Defenses.entryRefusal(d, now, raidsConfig, list and list[options.userId(owner)])
		if refusal then
			return false, refusal
		end
		active[raider] = { owner = owner, enteredAt = now, carrying = nil }
		options.notify(owner, `{options.name(raider)} is raiding your base!`)
		analytics:custom(raider, "Raid:Entered", 1)
		local step: number? = nil
		actions:change(raider, function(rd)
			step = Hatchery.markFirst(rd, "FirstRaidTried", now)
			return nil
		end)
		actions:onboarding(raider, step)
		return true, nil
	end

	-- The raider stepped off the base without carrying anything.
	function raids.exit(_self: Raids, raider: any)
		local raid = active[raider]
		if raid and raid.carrying == nil then
			active[raider] = nil
		end
	end

	function raids.steal(self: Raids, raider: any, pad: number, distance: number): (boolean, string?)
		local raid = active[raider]
		if raid == nil then
			return false, "not raiding"
		end
		if raid.carrying then
			return false, "You can only carry one creature."
		end
		if distance > raidsConfig.pickupReach then
			return false, "Get closer to pick it up."
		end
		local d = ownerData(raid.owner)
		if d == nil then
			return false, "That base is not ready."
		end
		local target: any = nil
		for _, c in d.creatures do
			if c.slot == pad then
				target = c
			end
		end
		if target == nil then
			return false, "There is nothing there."
		end
		if target.uid == d.mountUid then
			return false, "Its owner is riding it."
		end
		if target.uid == d.guardUid then
			return false, "That creature is guarding the base."
		end
		if Merge.stars(target) > raidsConfig.maxStealStars then
			return false, "Merged creatures cannot be stolen."
		end
		if self:carriedFrom(raid.owner)[target.uid] then
			return false, "Someone is already carrying it."
		end
		raid.carrying = { uid = target.uid, speciesId = target.speciesId, pickedAt = options.now() }
		options.notify(raid.owner, `{options.name(raider)} grabbed your {target.speciesId}! Catch them!`)
		options.notify(raider, "Run home! Touch your own base to keep it.")
		analytics:custom(raider, "Raid:PickedUp", 1, { target.speciesId })
		options.changed(raider)
		return true, nil
	end

	function raids.stealDecoy(_self: Raids, raider: any, spot: number, distance: number): (boolean, string?)
		local raid = active[raider]
		if raid == nil or raid.carrying then
			return false, "not raiding"
		end
		if distance > raidsConfig.pickupReach then
			return false, "Get closer to pick it up."
		end
		local popped = false
		local ok = actions:change(raid.owner, function(d)
			popped = Defenses.popDecoy(d, spot)
			return nil
		end)
		if not ok or not popped then
			return false, "There is nothing there."
		end
		options.stun(raider, raidsConfig.decoy.stunSeconds)
		options.notify(raider, "It was a decoy!")
		options.notify(raid.owner, `{options.name(raider)} fell for your decoy egg!`)
		analytics:custom(raid.owner, "Raid:Defended", 1, { "decoy" })
		startCooldown(raider, raid.owner)
		active[raider] = nil
		return true, nil
	end

	-- The carried creature goes back to its owner (it never left their save).
	function raids.drop(_self: Raids, raider: any, reason: DropReason)
		local raid = active[raider]
		if raid == nil or raid.carrying == nil then
			return
		end
		local carry = raid.carrying :: Carry
		raid.carrying = nil
		active[raider] = nil
		startCooldown(raider, raid.owner)
		options.changed(raider)
		local messages: { [string]: string } = {
			owner = "The owner caught you and took it back!",
			guard = "The guard caught you and took it back!",
			trap = "A trap caught you; the creature ran home.",
			speed = "You moved too fast; the creature ran home.",
			timeout = "You took too long; the creature ran home.",
			left = "The creature ran home.",
			gone = "It slipped away.",
			respawn = "You were knocked out; the creature ran home.",
		}
		options.notify(raider, messages[reason] or "The creature ran home.")
		if DEFENDED[reason] then
			options.notify(raid.owner, `You saved your {carry.speciesId}!`)
			analytics:custom(raid.owner, "Raid:Defended", 1, { reason })
			local now = options.now()
			local step: number? = nil
			actions:change(raid.owner, function(d)
				step = Hatchery.markFirst(d, "FirstRaidDefended", now)
				return nil
			end)
			actions:onboarding(raid.owner, step)
		else
			options.notify(raid.owner, `Your {carry.speciesId} came back home.`)
		end
	end

	-- The raider reached their own base: the creature changes owner.
	function raids.deliver(self: Raids, raider: any): (boolean, string?)
		local raid = active[raider]
		if raid == nil or raid.carrying == nil then
			return false, "not carrying"
		end
		local carry = raid.carrying :: Carry
		local owner = raid.owner
		local taken: any = nil
		local okTake = actions:change(owner, function(d)
			taken = Hatchery.takeCreature(d, carry.uid)
			if taken then
				d.stats.raidsLost += 1
			end
			return nil
		end)
		if not okTake or taken == nil then
			self:drop(raider, "gone")
			return false, "gone"
		end
		local received: any = nil
		local okGive = actions:change(raider, function(d, ledger)
			received = Hatchery.receive(d, ledger, taken, options.config.creatures, options.config.economy)
			d.stats.raidsWon += 1
			return nil
		end)
		if not okGive then
			-- The raider's save is gone (left at this instant): give it back.
			actions:change(owner, function(d, ledger)
				Hatchery.receive(d, ledger, taken, options.config.creatures, options.config.economy)
				d.stats.raidsLost -= 1
				return nil
			end)
			raid.carrying = nil
			active[raider] = nil
			return false, "raider data not loaded"
		end
		raid.carrying = nil
		active[raider] = nil
		startCooldown(raider, owner)
		options.changed(raider)
		options.notify(raider, `You stole a {carry.speciesId}!`)
		options.notify(owner, `{options.name(raider)} stole your {carry.speciesId}.`)
		analytics:custom(raider, "Raid:Stolen", 1, { carry.speciesId })
		return received ~= nil, nil
	end

	-- A raider stepped on `spot` in the base they are raiding. Returns the
	-- trap kind that fired, if one was armed there.
	function raids.trap(self: Raids, raider: any, spot: number): string?
		local raid = active[raider]
		if raid == nil then
			return nil
		end
		local d = ownerData(raid.owner)
		if d == nil then
			return nil
		end
		local placed = Defenses.trapAt(d, spot)
		if placed == nil then
			return nil
		end
		local def = raidsConfig.traps[placed.kind]
		local now = options.now()
		local fired = trapFiredAt[raid.owner] or {}
		trapFiredAt[raid.owner] = fired
		if fired[spot] and now - fired[spot] < def.rearmSeconds then
			return nil
		end
		fired[spot] = now
		if placed.kind == "Snare" then
			options.stun(raider, def.stunSeconds)
			self:drop(raider, "trap")
		else
			options.slow(raider, def.slowFactor, def.slowSeconds)
		end
		options.notify(raider, `You hit a {placed.kind} trap!`)
		return placed.kind
	end

	function raids.raidOf(_self: Raids, raider: any): Raid?
		return active[raider]
	end

	-- Uids of the owner's creatures being carried right now.
	function raids.carriedFrom(_self: Raids, owner: any): { [string]: boolean }
		local out = {}
		for _, raid in active do
			if raid.owner == owner and raid.carrying then
				out[(raid.carrying :: Carry).uid] = true
			end
		end
		return out
	end

	function raids.raidersOf(_self: Raids, owner: any): { any }
		local out = {}
		for raider, raid in active do
			if raid.owner == owner then
				table.insert(out, raider)
			end
		end
		return out
	end

	-- Ends carries that ran too long. Call every second or so.
	function raids.tick(self: Raids)
		local now = options.now()
		for raider, raid in active do
			if raid.carrying and now - (raid.carrying :: Carry).pickedAt > raidsConfig.maxCarrySeconds then
				self:drop(raider, "timeout")
			end
		end
	end

	-- Owner-side defenses. Each is one atomic update; refusals reach the
	-- owner as a notice.
	local function ownerChange(
		owner: any,
		fn: (d: Hatchery.Data, ledger: any) -> (boolean, string?)
	): (boolean, string?)
		return actions:change(owner, function(d, ledger)
			local done, refusal = fn(d, ledger)
			return if done then nil else refusal
		end)
	end

	function raids.raiseShield(_self: Raids, owner: any): (boolean, string?)
		local now = options.now()
		local ok, err = ownerChange(owner, function(d)
			return Defenses.raiseShield(d, now, raidsConfig)
		end)
		if ok then
			options.notify(owner, `Shield up for {raidsConfig.freeShieldSeconds}s.`)
		end
		return ok, err
	end

	function raids.buyTrap(_self: Raids, owner: any, spot: number, kind: string): (boolean, string?)
		return ownerChange(owner, function(d, ledger)
			return Defenses.buyTrap(d, ledger, spot, kind, raidsConfig)
		end)
	end

	function raids.buyDecoy(_self: Raids, owner: any, spot: number): (boolean, string?)
		return ownerChange(owner, function(d, ledger)
			return Defenses.buyDecoy(d, ledger, spot, raidsConfig)
		end)
	end

	function raids.toggleGuard(_self: Raids, owner: any, uid: string): (boolean, string?)
		return ownerChange(owner, function(d)
			return Defenses.toggleGuard(d, uid)
		end)
	end

	-- A player is leaving: end their raid, and every raid on their base.
	function raids.leave(self: Raids, player: any)
		self:drop(player, "left")
		active[player] = nil
		for raider, raid in active do
			if raid.owner == player then
				self:drop(raider, "left")
				active[raider] = nil
			end
		end
		cooldowns[player] = nil
		trapFiredAt[player] = nil
	end

	return (raids :: any) :: Raids
end

return Raids
