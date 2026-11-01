--!strict
-- What a Tidecatch Cove feedback report carries about the player's progress, so a
-- bug can be reproduced (see ops/FEEDBACK.md). Read from the saved data only;
-- at most 12 numbers or booleans (the core drops anything beyond that).

local FeedbackContext = {}

local function countActive(boosts: any, now: number): number
	local active = 0
	for _, expiresAt in boosts or {} do
		if type(expiresAt) == "number" and expiresAt > now then
			active += 1
		end
	end
	return active
end

function FeedbackContext.from(data: { [string]: any }, now: number): { [string]: any }
	local stats = data.stats or {}
	local meta = data.meta or {}
	local species = 0
	for _ in data.journal or {} do
		species += 1
	end
	local bait = 0
	for _, count in data.bait or {} do
		bait += count
	end
	return {
		coins = math.floor(data.coins or 0),
		rodTier = data.rodTier or 0,
		bait = bait,
		bucket = #(data.bucket or {}),
		pools = #(data.pools or {}),
		poolSlots = data.poolSlots or 0,
		species = species,
		casts = stats.casts or 0,
		catches = stats.catches or 0,
		escapes = stats.escapes or 0,
		boosts = countActive(data.boosts, now),
		sessions = meta.sessions or 0,
	}
end

return FeedbackContext
