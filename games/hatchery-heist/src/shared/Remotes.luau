--!strict
-- Game remotes. Every client-to-server remote has an argument schema and a rate
-- limit; the server drops anything else before a handler runs, and handlers
-- re-check every rule against saved data (the client only asks).
return function(Net: any, Schema: any)
	local slot = Schema.integer({ min = 1, max = 50 })
	local uid = Schema.string({ maxLength = 12, pattern = "^%d+$" })
	local text = Schema.string({ maxLength = 200 })
	return {
		-- Buy egg number `index` off the player's own conveyor (see Conveyor.luau).
		["HH:BuyEgg"] = Net.toServer(
			"HH:BuyEgg",
			{ Schema.integer({ min = 0, max = 2 ^ 40 }) },
			{ count = 4, window = 1 }
		),
		["HH:Hatch"] = Net.toServer("HH:Hatch", { slot }, { count = 6, window = 1 }),
		["HH:BuySlot"] = Net.toServer("HH:BuySlot", {}, { count = 2, window = 1 }),
		["HH:Collect"] = Net.toServer("HH:Collect", {}, { count = 2, window = 1 }),
		["HH:Rebirth"] = Net.toServer("HH:Rebirth", {}, { count = 1, window = 2 }),
		["HH:Ride"] = Net.toServer("HH:Ride", { uid }, { count = 2, window = 1 }),
		["HH:Dismount"] = Net.toServer("HH:Dismount", {}, { count = 2, window = 1 }),

		-- A short message for the player (a refusal, a reward).
		["HH:Notice"] = Net.toClient("HH:Notice", { text }),
		-- An egg hatched: species id.
		["HH:Hatched"] = Net.toClient("HH:Hatched", { Schema.string({ maxLength = 50 }) }),
		-- Coins earned while away, and eggs that finished hatching meanwhile.
		["HH:WelcomeBack"] = Net.toClient(
			"HH:WelcomeBack",
			{ Schema.integer({ min = 0 }), Schema.integer({ min = 0 }) }
		),
	}
end
