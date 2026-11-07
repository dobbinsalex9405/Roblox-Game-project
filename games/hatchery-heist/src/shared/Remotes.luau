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
	local charmId = Schema.string({ maxLength = 30, pattern = "^%u%w*$" })
	local kindId = Schema.string({ maxLength = 12, pattern = "^%a+$" }) -- a charm kind, or "all"
	return {
		-- Buy egg number `index` off the Egg Market (see Conveyor.luau).
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

		-- Charms and the claw machine (shared/Charms, shared/Claw). The server
		-- checks the player stands at the machine, the price, the bag and
		-- PolicyService; ids and kinds are checked against config there.
		["HH:ClawPull"] = Net.toServer(
			"HH:ClawPull",
			{ Schema.oneOf({ 1, 10, 100 }) },
			{ count = 2, window = 3 }
		),
		["HH:CharmCounter"] = Net.toServer("HH:CharmCounter", { charmId }, { count = 2, window = 2 }),
		["HH:CharmEquip"] = Net.toServer("HH:CharmEquip", { charmId }, { count = 4, window = 1 }),
		["HH:CharmUnequip"] = Net.toServer("HH:CharmUnequip", { kindId }, { count = 4, window = 1 }),
		-- Show or hide worn charms: a kind, or "all".
		["HH:CharmShown"] = Net.toServer(
			"HH:CharmShown",
			{ kindId, Schema.boolean() },
			{ count = 4, window = 1 }
		),
		["HH:CharmFuse"] = Net.toServer(
			"HH:CharmFuse",
			{ charmId, Schema.integer({ min = 1, max = 60 }) },
			{ count = 2, window = 1 }
		),
		["HH:CharmFuseAll"] = Net.toServer("HH:CharmFuseAll", {}, { count = 1, window = 2 }),
		-- What a pull gave, for the reveal: charm ids in pull order, and
		-- where it came from ("Coins", "Robux", "Counter").
		["HH:ClawResult"] = Net.toClient("HH:ClawResult", {
			Schema.array(Schema.string({ maxLength = 30 }), { maxLength = 100 }),
			Schema.string({ maxLength = 10 }),
		}),

		-- The answer to HH:BuyEgg: belt egg `index`, and whether it was bought.
		-- The client hides the egg only once this says yes.
		["HH:EggResult"] = Net.toClient(
			"HH:EggResult",
			{ Schema.integer({ min = 0, max = 2 ^ 40 }), Schema.boolean() }
		),
		-- Market egg `index` was just bought by someone: hide it.
		["HH:EggSold"] = Net.toClient("HH:EggSold", { Schema.integer({ min = 0, max = 2 ^ 40 }) }),
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
