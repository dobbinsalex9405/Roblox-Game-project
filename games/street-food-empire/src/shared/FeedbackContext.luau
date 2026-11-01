--!strict
-- What a Street Food Empire feedback report carries about the player's progress, so a
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
	return {
		cash = math.floor(data.cash or 0),
		pendingCash = math.floor(data.pendingCash or 0),
		queue = math.floor(data.queue or 0),
		rebirths = data.rebirths or 0,
		districts = data.districts or 0,
		stations = #(data.stations or {}),
		cooks = #(data.cooks or {}),
		boosts = countActive(data.boosts, now),
		customersServed = stats.customersServed or 0,
		sessions = meta.sessions or 0,
	}
end

return FeedbackContext
