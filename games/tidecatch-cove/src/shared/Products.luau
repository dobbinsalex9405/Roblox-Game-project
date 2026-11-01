--!strict
-- What each Robux product does, and what the shop lists, as pure functions so
-- the Lune tests run the exact grants the server registers.
--
-- A grant runs inside the core's receipt handler, in the same data update
-- that records the purchase, so it lands exactly once and must not yield.
-- Only Mystery Bait is random; its roll comes in through `rollMystery` (the
-- server passes Odds.rollPaid, which runs the policy check).

local Catch = require("./Catch")
local Cove = require("./Cove")

export type Grant = (player: any, data: { [string]: any }, ledger: any) -> ()

export type Deps = {
	config: Cove.Config,
	now: () -> number,
	-- Rolls the Mystery Bait table for this player; nil if the policy says no.
	rollMystery: (player: any) -> string?,
	-- Tells the player what they got (after the purchase is saved is fine).
	notify: (player: any, text: string) -> (),
}

-- One shop entry, in the shape of the core's Purchases.CatalogItem.
export type CatalogItem = {
	key: string,
	kind: "product" | "pass",
	name: string,
	description: string,
	oddsTable: string?,
	paidRandom: boolean?,
	oddsLabels: { [string]: string }?,
}

local Products = {}

-- Product key -> grant. Every product in config/monetization.luau has one.
function Products.grants(deps: Deps): { [string]: Grant }
	local config = deps.config
	local products = config.monetization.products
	local name = Catch.displayName

	local function plural(count: number, baitId: string): string
		return `{count} {name(baitId)}{if count == 1 then "" else "s"}`
	end

	return {
		GrowthBoost = function(player, d)
			local grew = Cove.growthBoost(d, products.GrowthBoost.stages, deps.now(), config)
			deps.notify(
				player,
				if grew > 0
					then `Growth Boost! {grew} creature{if grew == 1 then "" else "s"} grew.`
					else "Growth Boost saved: your pools were empty or fully grown."
			)
		end,
		RestockSkip = function(player, d)
			Cove.restockNow(d, deps.now(), config.economy)
			deps.notify(player, "The bait shop restocked for you!")
		end,
		BaitPack = function(player, d)
			local pack = products.BaitPack
			Cove.grantBait(d, pack.bait, pack.count)
			deps.notify(player, `You got {plural(pack.count, pack.bait)}!`)
		end,
		MysteryBait = function(player, d)
			-- The shop refused restricted players before Roblox's prompt, so a
			-- refusal here means the policy changed after paying: give the
			-- smallest outcome rather than nothing, since the Robux is spent.
			local outcomeId = deps.rollMystery(player) or config.monetization.mysteryBait[1].id
			local outcome = Catch.mysteryOutcome(config.monetization, outcomeId)
			assert(outcome, `Mystery Bait rolled unknown outcome {outcomeId}`)
			Cove.grantBait(d, outcome.bait, outcome.count)
			deps.notify(player, `Mystery Bait: {plural(outcome.count, outcome.bait)}!`)
		end,
	}
end

-- What the shop lists: every product and pass, in display order.
function Products.catalog(config: Cove.Config): { CatalogItem }
	local monetization = config.monetization
	local products = monetization.products
	local name = Catch.displayName
	local pack = products.BaitPack
	local labels: { [string]: string } = {}
	local kinds: { string } = {}
	for _, o in monetization.mysteryBait do
		labels[o.id] = `{o.count} {name(o.bait)}{if o.count == 1 then "" else "s"}`
		local kind = `{name(o.bait)}s`
		if not table.find(kinds, kind) then
			table.insert(kinds, kind)
		end
	end
	local stages = products.GrowthBoost.stages
	return {
		{
			key = "BaitPack",
			kind = "product",
			name = `{name(pack.bait)} Pack`,
			description = `{pack.count} {name(pack.bait)}s: strong bait for rare fish. Each cast's odds show on the dock.`,
		},
		{
			key = "MysteryBait",
			kind = "product",
			name = "Mystery Bait",
			description = `A random bundle of {table.concat(kinds, " or ")}. See the odds first.`,
			oddsTable = Catch.MYSTERY_TABLE,
			paidRandom = true,
			oddsLabels = labels,
		},
		{
			key = "GrowthBoost",
			kind = "product",
			name = "Growth Boost",
			description = `Every creature in your pools grows {stages} stage{if stages == 1 then "" else "s"} right now.`,
		},
		{
			key = "RestockSkip",
			kind = "product",
			name = "Restock Skip",
			description = "The bait shop restocks for you right now.",
		},
		{
			key = "AutoReel",
			kind = "pass",
			name = "Auto-reel",
			description = "Bites reel themselves in at an average player's success rate. Skill still pays.",
		},
		{
			key = "ExtraPools",
			kind = "pass",
			name = "Extra Pools",
			description = `{config.pools.passBonusSlots} more tide pools.`,
		},
		{
			key = "SellMultiplier",
			kind = "pass",
			name = "Sell Multiplier",
			description = `Every sale pays x{monetization.sellMultiplier}.`,
		},
	}
end

return Products
