--!strict
-- Game remotes. Every client-to-server remote has an argument schema and a rate
-- limit; the server drops anything else before a handler runs, and handlers
-- re-check every rule (reach, swing speed, exposure, pick tier, oil) against
-- server state. Selling and upgrading use server-side ProximityPrompts, so
-- they need no remote. Buying goes through the core shop (Shop:Buy).
return function(Net: any, Schema: any)
	local coord = Schema.integer({ min = 1, max = 1000 })
	local text = Schema.string({ maxLength = 200 })
	local id = Schema.string({ maxLength = 50 })
	local count = Schema.integer({ min = 0 })
	local time = Schema.number({ min = 0 })
	return {
		-- Swing at block (x, y, z) of the mine grid.
		["DB:Hit"] = Net.toServer("DB:Hit", { coord, coord, coord }, { count = 8, window = 1 }),
		-- Start climbing out.
		["DB:Climb"] = Net.toServer("DB:Climb", {}, { count = 2, window = 1 }),
		-- Pour one of the player's bought oil refills (one per dive).
		["DB:Refill"] = Net.toServer("DB:Refill", {}, { count = 2, window = 1 }),

		-- A short message for the player (a refusal, a reward).
		["DB:Notice"] = Net.toClient("DB:Notice", { text }),
		-- The dive state: phase, then the oil meter (oil, rate, server time it
		-- was settled), the oil a full lamp holds, when a climb finishes (0 if not
		-- climbing), and whether this dive's oil refill has been poured.
		["DB:Dive"] = Net.toClient(
			"DB:Dive",
			{ Schema.oneOf({ "Camp", "Diving", "Climbing" }), time, time, time, time, time, Schema.boolean() }
		),
		-- A block broke and its ore went in the pack.
		["DB:Ore"] = Net.toClient("DB:Ore", { id }),
		-- The lamp ran dry: pieces kept, pieces dropped, the row it happened at.
		["DB:LampOut"] = Net.toClient("DB:LampOut", { count, count, count }),
		-- The pack was sold: coins, pieces.
		["DB:Sold"] = Net.toClient("DB:Sold", { count, count }),
	}
end
