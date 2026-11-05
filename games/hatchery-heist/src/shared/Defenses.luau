--!strict
-- Base defenses and raid entry rules as pure functions over saved data, like
-- Hatchery.luau: a timed shield, two trap types, decoy eggs, one guard
-- creature, and protection for new players. Coins move only through the
-- ledger passed in.

local Geometry = require("./Geometry")
local Hatchery = require("./Hatchery")

export type Data = Hatchery.Data
export type Ledger = Hatchery.Ledger

local Defenses = {}

-- Until when a player is protected as a new player (unix seconds).
function Defenses.protectedUntil(d: Data, raids: any): number
	local joined = d.firsts.Joined or 0
	return if joined > 0 then joined + raids.newPlayerProtectionSeconds else 0
end

-- Why a raider may not enter this base now, or nil if they may.
-- `cooldownUntil` is when this raider may raid this owner again.
function Defenses.entryRefusal(d: Data, now: number, raids: any, cooldownUntil: number?): string?
	if d.shieldUntil > now then
		return `This base is shielded for {math.ceil(d.shieldUntil - now)}s.`
	end
	local protected = Defenses.protectedUntil(d, raids)
	if protected > now then
		return `This player is new and protected for {math.ceil(protected - now)}s.`
	end
	if cooldownUntil and cooldownUntil > now then
		return `You can raid this base again in {math.ceil(cooldownUntil - now)}s.`
	end
	return nil
end

-- Raises the free shield.
function Defenses.raiseShield(d: Data, now: number, raids: any): (boolean, string?)
	if d.shieldUntil > now then
		return false, `Your shield is already up for {math.ceil(d.shieldUntil - now)}s.`
	end
	if d.shieldReadyAt > now then
		return false, `Your shield recharges in {math.ceil(d.shieldReadyAt - now)}s.`
	end
	d.shieldUntil = now + raids.freeShieldSeconds
	d.shieldReadyAt = d.shieldUntil + raids.shieldCooldownSeconds
	return true, nil
end

local function trapAt(d: Data, spot: number): (any?, number?)
	for index, trap in d.traps do
		if trap.spot == spot then
			return trap, index
		end
	end
	return nil, nil
end
Defenses.trapAt = trapAt

-- Buys a trap of `kind` onto an empty trap spot.
function Defenses.buyTrap(d: Data, ledger: Ledger, spot: number, kind: string, raids: any): (boolean, string?)
	local def = raids.traps[kind]
	if def == nil then
		return false, "unknown trap"
	end
	if spot < 1 or spot > #Geometry.TRAP_SPOTS or spot // 1 ~= spot then
		return false, "unknown trap spot"
	end
	if trapAt(d, spot) then
		return false, "There is already a trap there."
	end
	if not ledger:spend("coins", def.price, `Shop:{kind}`) then
		return false, "Not enough coins."
	end
	table.insert(d.traps, { spot = spot, kind = kind })
	return true, nil
end

local function decoyAt(d: Data, spot: number): (any?, number?)
	for index, decoy in d.decoys do
		if decoy.spot == spot then
			return decoy, index
		end
	end
	return nil, nil
end
Defenses.decoyAt = decoyAt

-- Buys a decoy egg onto an empty decoy spot.
function Defenses.buyDecoy(d: Data, ledger: Ledger, spot: number, raids: any): (boolean, string?)
	if spot < 1 or spot > #Geometry.DECOY_SPOTS or spot // 1 ~= spot then
		return false, "unknown decoy spot"
	end
	if decoyAt(d, spot) then
		return false, "There is already a decoy there."
	end
	if not ledger:spend("coins", raids.decoy.price, "Shop:Decoy") then
		return false, "Not enough coins."
	end
	table.insert(d.decoys, { spot = spot })
	return true, nil
end

-- A raider picked up the decoy: it is used up.
function Defenses.popDecoy(d: Data, spot: number): boolean
	local _, index = decoyAt(d, spot)
	if index == nil then
		return false
	end
	table.remove(d.decoys, index)
	return true
end

-- Makes a placed creature the base's guard, or stands it down if it already is.
function Defenses.toggleGuard(d: Data, uid: string): (boolean, string?)
	if d.guardUid == uid then
		d.guardUid = ""
		return true, nil
	end
	local creature = Hatchery.creatureByUid(d, uid)
	if creature == nil or creature.slot == nil then
		return false, "Only a creature on a pad can guard."
	end
	if uid == d.mountUid then
		return false, "Get off it first."
	end
	d.guardUid = uid
	return true, nil
end

-- The base's guard and its species, or nil and nil when there is none: no
-- guard set (`guardUid == ""`, every new player), a guard that is no longer
-- owned, or a species the config no longer has. Never `false`.
function Defenses.guardOf(d: Data?, species: { [string]: any }): (any?, any?)
	if d == nil or d.guardUid == "" then
		return nil, nil
	end
	local creature = Hatchery.creatureByUid(d, d.guardUid)
	if creature == nil then
		return nil, nil
	end
	local kind = species[creature.speciesId]
	if kind == nil then
		return nil, nil
	end
	return creature, kind
end

-- Walk speed while carrying a stolen creature.
function Defenses.carrySpeed(mountSpeed: number?, raids: any): number
	if mountSpeed then
		return math.max(raids.carryWalkSpeed, mountSpeed * raids.carryMountFactor)
	end
	return raids.carryWalkSpeed
end

return Defenses
