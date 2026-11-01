--!strict
-- Pick, pack and lamp tiers as pure functions over saved data. Upgrades move
-- coins only through the Economy ledger passed in, inside DataService:update.

export type Data = { [string]: any }
export type Kind = "Pick" | "Pack" | "Lamp"

export type Perks = {
	biggerPack: boolean,
	betterLamp: boolean,
	autoSell: boolean,
}

local Gear = {}

-- Cast through any: a frozen literal list would otherwise widen to { string }.
Gear.KINDS = (table.freeze({ "Pick", "Pack", "Lamp" }) :: any) :: { Kind }

local FIELD: { [Kind]: string } = { Pick = "pick", Pack = "pack", Lamp = "lamp" }

function Gear.tiers(gear: any, kind: Kind): { any }
	return gear[FIELD[kind]]
end

function Gear.tier(d: Data, kind: Kind): number
	return d.gear[FIELD[kind]]
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
	d.gear[FIELD[kind]] += 1
	return true, nil
end

return Gear
