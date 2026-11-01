--!strict
-- The first-session goal line under the HUD's top bar: one short instruction
-- for the step a new player is on (dig, climb out and sell, upgrade), taken
-- from the saved `firsts`. It disappears after the first upgrade. Pure, so
-- the client and the tests share it.

local Gear = require("./Gear")
local Layout = require("./Layout")
local Pack = require("./Pack")

local Guide = {}

-- The cheapest upgrade the player can buy next and its kind, or nil when
-- everything is maxed.
function Guide.cheapestUpgrade(d: { [string]: any }, gear: any): (any?, Gear.Kind?)
	local best: any? = nil
	local bestKind: Gear.Kind? = nil
	for _, kind in Gear.KINDS do
		local nextTier = Gear.nextTier(d, gear, kind)
		if nextTier and (best == nil or nextTier.cost < best.cost) then
			best = nextTier
			bestKind = kind
		end
	end
	return best, bestKind
end

-- The goal line for this moment, or nil once the player knows the loop.
function Guide.objective(d: { [string]: any }, gear: any, phase: string): string?
	local firsts = d.firsts or {}
	local atCamp = phase == "Camp"
	if firsts.FirstBlockMined == nil then
		return if atCamp
			then "Goal: step onto the mine and tap a block to dig"
			else "Goal: tap a block to mine it. Ore goes in your pack"
	end
	if firsts.FirstSale == nil then
		if not atCamp then
			return "Goal: climb out before your lamp runs dry"
		end
		return if Pack.count(d.pack) > 0
			then "Goal: sell your ore at the sell pad"
			else "Goal: dive again and bring some ore back"
	end
	if firsts.FirstUpgrade == nil then
		local upgrade, kind = Guide.cheapestUpgrade(d, gear)
		if upgrade == nil or kind == nil then
			return nil
		end
		if d.coins >= upgrade.cost then
			return if atCamp
				then `Goal: buy the {upgrade.name} at the Upgrade {string.lower(kind)} stand`
				else `Goal: climb out and buy the {upgrade.name}`
		end
		return `Next: {upgrade.name} · {Layout.shortNumber(d.coins)}/{Layout.shortNumber(upgrade.cost)} coins`
	end
	return nil
end

return Guide
