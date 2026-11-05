--!strict
-- What a Depthbound feedback report carries about the player's progress, so a
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
	local gear = data.gear or {}
	local packItems = 0
	for _, count in data.pack or {} do
		packItems += count
	end
	return {
		coins = math.floor(data.coins or 0),
		pick = gear.pick or 0,
		pack = gear.pack or 0,
		lamp = gear.lamp or 0,
		packItems = packItems,
		deepestRow = data.deepestRow or 0,
		layersReached = data.layersReached or 0,
		dives = stats.dives or 0,
		lampOuts = stats.lampOuts or 0,
		blocksMined = stats.blocksMined or 0,
		boosts = countActive(data.boosts, now),
		sessions = meta.sessions or 0,
	}
end

return FeedbackContext
