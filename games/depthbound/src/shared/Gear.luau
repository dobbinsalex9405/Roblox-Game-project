--!strict
-- Pick, pack and lamp tiers as pure functions over saved data. Upgrades move
-- coins only through the Economy ledger passed in, inside DataService:update.

export type Data = { [string]: any }
-- "Pick", "Pack" or "Lamp" (Gear.KINDS). A plain string: the strict checker widens
-- a list of string literals when another module iterates it; field() below checks it.
export type Kind = string

export type Perks = {
	biggerPack: boolean,
	betterLamp: boolean,
	autoSell: boolean,
}

local Gear = {}

Gear.KINDS = table.freeze({ "Pick", "Pack", "Lamp" }) :: { Kind }

local FIELD: { [string]: string } = { Pick = "pick", Pack = "pack", Lamp = "lamp" }

local function field(kind: Kind): string
	local name = FIELD[kind]
	assert(name, `unknown gear kind {kind}`)
	return name
end

function Gear.tiers(gear: any, kind: Kind): { any }
	return gear[field(kind)]
end

function Gear.tier(d: Data, kind: Kind): number
	return d.gear[field(kind)]
end

function Gear.current(d: Data, gear: any, kind: Kind): any
	local tiers = Gear.tiers(gear, kind)
	return tiers[math.clamp(Gear.tier(d, kind), 1, #tiers)]
end

-- The next tier and its cost, or nil at the top tier.
function Gear.nextTier(d: Data, gear: any, kind: Kind): any?
	return Gear.tiers(gear, kind)[Gear.tier(d, kind) + 1]
end

function Gear.pickPower(d: Data, gear: any): number
	return Gear.current(d, gear, "Pick").power
end

function Gear.packCapacity(d: Data, gear: any, perks: Perks): number
	return Gear.current(d, gear, "Pack").capacity
		+ (if perks.biggerPack then gear.passes.biggerPackSlots else 0)
end

function Gear.oilCapacity(d: Data, gear: any, perks: Perks): number
	return Gear.current(d, gear, "Lamp").oilSeconds
		* (if perks.betterLamp then gear.passes.betterLampMultiplier else 1)
end

-- Buys the next tier. Returns true, or false and a message for the player.
function Gear.upgrade(d: Data, ledger: any, gear: any, kind: Kind): (boolean, string?)
	local nextTier = Gear.nextTier(d, gear, kind)
	if nextTier == nil then
		return false, `Your {string.lower(kind)} is already the best there is.`
	end
	if not ledger:spend("coins", nextTier.cost, `Upgrade:{kind}`) then
		local short = nextTier.cost - ledger:balance("coins")
		return false, `You need {short} more coins for the {nextTier.name}.`
	end
	d.gear[field(kind)] += 1
	return true, nil
end

return Gear
