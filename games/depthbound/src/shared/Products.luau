--!strict
-- What Depthbound sells for Robux and what each product gives. The server's
-- Shop registers these grants with the core's receipt handler (exactly once
-- per purchase, saved before Roblox hears "granted") and lists the catalog.
-- Lives in Shared so the Lune tests run the same grants through the real
-- receipt path.
--
-- Grants run inside a data update, so they only change saved data. Anything
-- that touches the live dive (pouring a refill, a message) is handed to
-- `after`, which runs it once the update has finished.

local Boosts = require("./Boosts")

export type Grant = (player: any, data: { [string]: any }, ledger: any) -> ()

export type CatalogItem = {
	key: string,
	kind: "product" | "pass",
	name: string,
	description: string,
	oddsTable: string?,
	paidRandom: boolean?,
}

export type Options = {
	monetization: any,
	actions: any, -- Actions.Actions (any here so this file stays free of a require cycle)
	now: () -> number,
	after: (fn: () -> ()) -> (), -- task.defer on the server
}

local Products = {}

-- Products the game can deliver today. The Geode Crate waits for M5, with
-- geodes, its odds table and the policy check.
Products.SOLD = table.freeze({ "OilRefill", "OreBoost" })

function Products.grants(options: Options): { [string]: Grant }
	local oreBoost = options.monetization.boosts.OreBoost
	local actions = options.actions
	return {
		OilRefill = function(player: any, d: { [string]: any })
			d.oilRefills = (d.oilRefills or 0) + 1
			-- Bought mid-dive, it pours right away (if this dive has not had one).
			options.after(function()
				actions:refill(player, true)
			end)
		end,
		OreBoost = function(player: any, d: { [string]: any })
			local now = options.now()
			local endsAt = Boosts.extend(d, "OreBoost", oreBoost.durationSeconds, now)
			options.after(function()
				actions:notice(
					player,
					`Ore Boost! Ore sells for {oreBoost.sellMultiplier}x for {Boosts.clock(endsAt - now)}.`
				)
			end)
		end,
	}
end

function Products.catalog(monetization: any, gear: any): { CatalogItem }
	local oreBoost = monetization.boosts.OreBoost
	local passes = gear.passes
	return {
		{
			key = "OilRefill",
			kind = "product",
			name = "Oil Refill",
			description = "Fills your lamp mid-dive. One per dive; bought at camp, it waits for your next dive.",
		},
		{
			key = "OreBoost",
			kind = "product",
			name = "Ore Boost",
			description = `Ore sells for {oreBoost.sellMultiplier}x for {oreBoost.durationSeconds // 60} minutes. Buying more adds time.`,
		},
		{
			key = "BiggerPack",
			kind = "pass",
			name = "Bigger Pack",
			description = `Carry {passes.biggerPackSlots} more ore on every dive.`,
		},
		{
			key = "BetterLamp",
			kind = "pass",
			name = "Better Lamp",
			description = `Your lamp holds {passes.betterLampMultiplier}x the oil, so every dive lasts longer.`,
		},
		{
			key = "AutoSell",
			kind = "pass",
			name = "Auto-Sell",
			description = "Your pack sells by itself the moment you're out of the mine.",
		},
	}
end

return Products
