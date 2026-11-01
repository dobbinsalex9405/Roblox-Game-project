--!strict
-- The first-minute guide: one short goal at a time, from the player's saved
-- first-time moments, until their first creature is growing in a pool. Pure,
-- so the Lune tests check every step; GuideView draws it.

local Catch = require("./Catch")

export type Step = {
	id: "Cast" | "Reel" | "Place" | "Grow",
	text: string,
	-- Point an arrow at the nearest dock the player can fish from.
	arrowToDock: boolean,
}

local Guide = {}

-- A player who has caught this many without ever pooling one has seen the
-- pool hint long enough: they prefer to sell, and the Pools panel is still
-- there when they want it.
Guide.RETIRE_AFTER_CATCHES = 8

-- The player's next goal, or nil once they are past the first loop. Once nil,
-- it stays nil: it only reads first-time moments and a catch count, which
-- never go back.
function Guide.step(d: { [string]: any }): Step?
	local firsts = d.firsts
	if firsts.FirstCast == nil then
		return {
			id = "Cast",
			text = "Follow the arrow to a dock and cast! Your Worms bring rarer fish.",
			arrowToDock = true,
		}
	end
	if firsts.FirstCatch == nil then
		return {
			id = "Reel",
			text = "When a fish bites, tap fast, then hold to keep the green zone on it.",
			arrowToDock = true,
		}
	end
	if firsts.FirstPlaced == nil then
		local catches = if d.stats then d.stats.catches else 0
		if catches >= Guide.RETIRE_AFTER_CATCHES then
			return nil
		end
		if #d.bucket == 0 then
			-- Sold the first catch: one more, then raise it.
			return {
				id = "Place",
				text = "Catch another and tap Keep: creatures in your tide pools grow into giants.",
				arrowToDock = true,
			}
		end
		return {
			id = "Place",
			text = "Open your Bucket and tap Pool: it grows into a giant worth far more.",
			arrowToDock = false,
		}
	end
	if firsts.FirstGrowth == nil then
		return {
			id = "Grow",
			text = "It grows while you fish, and even while you are away. Catch more!",
			arrowToDock = false,
		}
	end
	return nil
end

-- The dock to point a new player at: the first spot their rod can fish that
-- is always open (Shallows for a new player).
function Guide.dockFor(d: { [string]: any }, fishing: any): string?
	for _, spot in fishing.spots do
		if not spot.lowTideOnly and d.rodTier >= spot.minRod then
			return spot.id
		end
	end
	return nil
end

-- The bait to start a session with: the cheapest coin bait the player owns,
-- so a new player's first casts use their starting Worms.
function Guide.startingBait(d: { [string]: any }, fishing: any): string
	for _, bait in fishing.bait do
		if not bait.robux and (d.bait[bait.id] or 0) > 0 then
			return bait.id
		end
	end
	return Catch.NO_BAIT
end

return Guide
