--!strict
-- What a Hatchery Heist feedback report carries about the player's progress, so a
-- bug can be reproduced (see ops/FEEDBACK.md). Read from the saved data only;
-- at most 12 numbers or booleans (the core drops anything beyond that).

local FeedbackContext = {}

function FeedbackContext.from(data: { [string]: any }, now: number): { [string]: any }
	local stats = data.stats or {}
	local meta = data.meta or {}
	local creatures = data.creatures or {}
	local placed = 0
	for _, creature in creatures do
		if creature.slot ~= nil then
			placed += 1
		end
	end
	return {
		coins = math.floor(data.coins or 0),
		rebirths = data.rebirths or 0,
		slots = data.slots or 0,
		creatures = #creatures,
		placed = placed,
		incubating = #(data.incubators or {}),
		mounted = (data.mountUid or "") ~= "",
		guard = (data.guardUid or "") ~= "",
		traps = #(data.traps or {}),
		shieldUp = (data.shieldUntil or 0) > now,
		raidsWon = stats.raidsWon or 0,
		sessions = meta.sessions or 0,
	}
end

return FeedbackContext
