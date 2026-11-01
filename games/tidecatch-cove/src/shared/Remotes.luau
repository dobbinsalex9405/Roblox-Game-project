--!strict
-- Game remotes. Every client-to-server remote has an argument schema and a rate
-- limit; the server drops anything else before a handler runs, and handlers
-- re-check every rule against saved data (the client only asks).
return function(Net: any, Schema: any)
	local id = Schema.string({ maxLength = 40, pattern = "^%u%w*$" })
	local uid = Schema.string({ maxLength = 12, pattern = "^%d+$" })
	local slot = Schema.integer({ min = 1, max = 20 })
	local castId = Schema.integer({ min = 1, max = 2 ^ 40 })
	local text = Schema.string({ maxLength = 200 })
	return {
		-- Cast at a spot (by id) with a bait id, or "None" for no bait.
		["TC:Cast"] = Net.toServer("TC:Cast", { id, id }, { count = 2, window = 1 }),
		-- The reel minigame finished: caught (true) or got away (false).
		["TC:Reel"] = Net.toServer("TC:Reel", { castId, Schema.boolean() }, { count = 3, window = 1 }),
		["TC:SellCatch"] = Net.toServer("TC:SellCatch", { uid }, { count = 6, window = 1 }),
		["TC:SellBucket"] = Net.toServer("TC:SellBucket", {}, { count = 1, window = 1 }),
		["TC:Place"] = Net.toServer("TC:Place", { uid }, { count = 4, window = 1 }),
		["TC:Feed"] = Net.toServer("TC:Feed", { slot }, { count = 6, window = 1 }),
		["TC:SellPool"] = Net.toServer("TC:SellPool", { slot }, { count = 4, window = 1 }),
		["TC:BuyPool"] = Net.toServer("TC:BuyPool", {}, { count = 2, window = 1 }),
		["TC:BuyRod"] = Net.toServer(
			"TC:BuyRod",
			{ Schema.integer({ min = 1, max = 10 }) },
			{ count = 2, window = 1 }
		),
		["TC:BuyBait"] = Net.toServer(
			"TC:BuyBait",
			{ id, Schema.integer({ min = 1, max = 50 }) },
			{ count = 4, window = 1 }
		),

		-- A short message for the player (a refusal, a sale).
		["TC:Notice"] = Net.toClient("TC:Notice", { text }),
		-- The line is in the water at a spot.
		["TC:CastStarted"] = Net.toClient("TC:CastStarted", { castId, id }),
		-- A fish bit: start the reel minigame at this rarity's difficulty.
		["TC:Bite"] = Net.toClient("TC:Bite", { castId, id }),
		-- Caught: species, kg, uid, coins if it sold at once (bucket full), new to the journal.
		["TC:Caught"] = Net.toClient(
			"TC:Caught",
			{ castId, id, Schema.number({ min = 0 }), uid, Schema.integer({ min = 0 }), Schema.boolean() }
		),
		-- The line came back empty, with the reason.
		["TC:Escaped"] = Net.toClient("TC:Escaped", { castId, text }),
		-- Creatures that grew a stage while away, and whether the shop restocked.
		["TC:WelcomeBack"] = Net.toClient(
			"TC:WelcomeBack",
			{ Schema.integer({ min = 0 }), Schema.boolean() }
		),
	}
end
