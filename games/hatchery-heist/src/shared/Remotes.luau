--!strict
-- Game remotes. Every client-to-server remote has an argument schema and a rate
-- limit; the server drops anything else before a handler runs, and handlers
-- re-check every rule against saved data (the client only asks).
return function(Net: any, Schema: any)
	local slot = Schema.integer({ min = 1, max = 50 })
	local uid = Schema.string({ maxLength = 12, pattern = "^%d+$" })
	local text = Schema.string({ maxLength = 200 })
	local plot = Schema.integer({ min = 1, max = 8 })
	local spot = Schema.integer({ min = 1, max = 8 })
	local floor = Schema.integer({ min = 1, max = 10 })
	local pad = Schema.integer({ min = 1, max = 80 }) -- across the tower (Geometry.pad)
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
		-- The tower: buy the next floor, upgrade one, move a creature to a
		-- floor or back to the inventory, fill it best-first, ride the
		-- elevator (the server checks the player is in it).
		["HH:BuyFloor"] = Net.toServer("HH:BuyFloor", {}, { count = 2, window = 1 }),
		["HH:UpgradeFloor"] = Net.toServer("HH:UpgradeFloor", { floor }, { count = 3, window = 1 }),
		["HH:Place"] = Net.toServer("HH:Place", { uid, floor }, { count = 6, window = 1 }),
		["HH:TakeBack"] = Net.toServer("HH:TakeBack", { uid }, { count = 6, window = 1 }),
		["HH:PlaceBest"] = Net.toServer("HH:PlaceBest", {}, { count = 1, window = 1 }),
		["HH:GoFloor"] = Net.toServer("HH:GoFloor", { floor }, { count = 2, window = 1 }),
		-- The Merge Station: merge 3 copies of species/mutation at a star,
		-- cancel a running merge (by its id), unlock another merge slot.
		["HH:Merge"] = Net.toServer("HH:Merge", {
			Schema.string({ maxLength = 50 }),
			Schema.string({ maxLength = 20 }),
			Schema.integer({ min = 1, max = 5 }),
		}, { count = 2, window = 1 }),
		["HH:CancelMerge"] = Net.toServer("HH:CancelMerge", { uid }, { count = 2, window = 1 }),
		["HH:BuyMergeSlot"] = Net.toServer("HH:BuyMergeSlot", {}, { count = 1, window = 1 }),
		-- The player opened the Hatchery Book (clears its NEW badges).
		["HH:BookSeen"] = Net.toServer("HH:BookSeen", {}, { count = 1, window = 2 }),
		["HH:ClaimDaily"] = Net.toServer("HH:ClaimDaily", {}, { count = 1, window = 1 }),
		["HH:Rebirth"] = Net.toServer("HH:Rebirth", {}, { count = 1, window = 2 }),
		["HH:Ride"] = Net.toServer("HH:Ride", { uid }, { count = 2, window = 1 }),
		["HH:Dismount"] = Net.toServer("HH:Dismount", {}, { count = 2, window = 1 }),

		-- Raids: steal from base `plot` (the server measures the distance).
		["HH:Steal"] = Net.toServer("HH:Steal", { plot, pad }, { count = 4, window = 1 }),
		["HH:StealDecoy"] = Net.toServer("HH:StealDecoy", { plot, spot }, { count = 4, window = 1 }),
		-- Defenses on the player's own base.
		["HH:Shield"] = Net.toServer("HH:Shield", {}, { count = 1, window = 1 }),
		["HH:BuyTrap"] = Net.toServer(
			"HH:BuyTrap",
			{ spot, Schema.oneOf({ "Snare", "Slime" }) },
			{ count = 2, window = 1 }
		),
		["HH:BuyDecoy"] = Net.toServer("HH:BuyDecoy", { spot }, { count = 2, window = 1 }),
		["HH:Guard"] = Net.toServer("HH:Guard", { uid }, { count = 2, window = 1 }),

		-- The answer to HH:BuyEgg: belt egg `index`, and whether it was bought.
		-- The client hides the egg only once this says yes.
		["HH:EggResult"] = Net.toClient(
			"HH:EggResult",
			{ Schema.integer({ min = 0, max = 2 ^ 40 }), Schema.boolean() }
		),
		-- A short message for the player (a refusal, a reward).
		["HH:Notice"] = Net.toClient("HH:Notice", { text }),
		-- An egg hatched: species id, the egg it came from, and whether it is
		-- new to the player's Hatchery Book (for the reveal).
		["HH:Hatched"] = Net.toClient(
			"HH:Hatched",
			{ Schema.string({ maxLength = 50 }), Schema.string({ maxLength = 50 }), Schema.boolean() }
		),
		-- Coins earned while away, and eggs that finished hatching meanwhile.
		["HH:WelcomeBack"] = Net.toClient(
			"HH:WelcomeBack",
			{ Schema.integer({ min = 0 }), Schema.integer({ min = 0 }) }
		),
	}
end
