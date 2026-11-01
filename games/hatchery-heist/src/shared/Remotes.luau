--!strict
-- Game remotes. Every client-to-server remote has an argument schema and a rate
-- limit; the server ignores anything else. Handlers are added with the M2
-- gameplay (egg conveyor, incubators, collecting, rebirth).
return function(Net: any, Schema: any)
	local eggId = Schema.string({ maxLength = 50, pattern = "^%u%w*$" })
	return {
		["HH:BuyEgg"] = Net.toServer("HH:BuyEgg", { eggId }, { count = 4, window = 1 }),
		["HH:PlaceEgg"] = Net.toServer(
			"HH:PlaceEgg",
			{ Schema.integer({ min = 1, max = 50 }) },
			{ count = 4, window = 1 }
		),
		["HH:Collect"] = Net.toServer("HH:Collect", {}, { count = 2, window = 1 }),
		["HH:Rebirth"] = Net.toServer("HH:Rebirth", {}, { count = 1, window = 2 }),
	}
end
