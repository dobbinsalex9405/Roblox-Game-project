--!strict
-- Game remotes. Every client-to-server remote has an argument schema and a rate
-- limit; the server drops anything else before a handler runs, and handlers
-- re-check every rule against saved data (the client only asks).
return function(Net: any, Schema: any)
	local spot = Schema.integer({ min = 1, max = 50 })
	local id = Schema.string({ maxLength = 50, pattern = "^%u%w*$" })
	local text = Schema.string({ maxLength = 200 })
	return {
		-- Serve the customer at the front of the counter queue.
		["SFE:Serve"] = Net.toServer("SFE:Serve", {}, { count = 8, window = 1 }),
		["SFE:Collect"] = Net.toServer("SFE:Collect", {}, { count = 2, window = 1 }),
		-- Build station `id` on `spot`.
		["SFE:Build"] = Net.toServer("SFE:Build", { id, spot }, { count = 3, window = 1 }),
		["SFE:Upgrade"] = Net.toServer("SFE:Upgrade", { spot }, { count = 3, window = 1 }),
		-- Move the station on the first spot to the second (swapping).
		["SFE:Move"] = Net.toServer("SFE:Move", { spot, spot }, { count = 3, window = 1 }),
		-- Hire a cook of tier `id` for the station on `spot`.
		["SFE:HireCook"] = Net.toServer("SFE:HireCook", { id, spot }, { count = 3, window = 1 }),
		["SFE:UnlockDistrict"] = Net.toServer("SFE:UnlockDistrict", {}, { count = 1, window = 1 }),
		["SFE:Rebirth"] = Net.toServer("SFE:Rebirth", {}, { count = 1, window = 2 }),

		-- A short message for the player (a refusal, a reward).
		["SFE:Notice"] = Net.toClient("SFE:Notice", { text }),
		-- A customer was served by hand: cash earned.
		["SFE:Served"] = Net.toClient("SFE:Served", { Schema.integer({ min = 0 }) }),
		-- Cash the cooks earned while away, and customers now waiting.
		["SFE:WelcomeBack"] = Net.toClient(
			"SFE:WelcomeBack",
			{ Schema.integer({ min = 0 }), Schema.integer({ min = 0 }) }
		),
	}
end
