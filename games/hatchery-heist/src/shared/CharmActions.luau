--!strict
-- Every charm and claw machine action as the server runs it: pull 1, 10 or
-- 100 at the machine, buy at the Charm Counter, equip, unequip, show or hide,
-- fuse, and the Robux pulls' grant. Each check runs against saved data
-- inside one atomic update (Actions:change), so a refusal changes nothing
-- and coins only move through the Economy ledger.
--
-- Runs only on the server; lives in Shared, like Actions, so the Lune tests
-- load the same code. Roblox-specific effects come in as callbacks.

local Actions = require("./Actions")
local Charms = require("./Charms")
local Claw = require("./Claw")

export type Options = {
	actions: Actions.Actions,
	odds: any, -- core Odds
	policy: any, -- core Policy
	analytics: any,
	charms: any, -- config/charms.luau
	now: () -> number,
	-- Whether the player stands at a claw machine (nil in tests = always).
	nearClaw: ((player: any) -> boolean)?,
	notify: (player: any, text: string) -> (),
	-- What a pull gave, for the reveal: charm ids in pull order, and where
	-- it came from ("Coins", "Robux", "Counter").
	result: (player: any, ids: { string }, source: string) -> (),
	-- The player's equipped charms changed (redraw what they wear, re-set
	-- their luck on the eggs).
	changed: (player: any) -> (),
}

export type CharmActions = {
	pull: (self: CharmActions, player: any, count: number) -> (boolean, string?),
	counter: (self: CharmActions, player: any, charmId: string) -> (boolean, string?),
	equip: (self: CharmActions, player: any, charmId: string) -> (boolean, string?),
	unequip: (self: CharmActions, player: any, kindId: string) -> (boolean, string?),
	setShown: (self: CharmActions, player: any, which: string, shown: boolean) -> (boolean, string?),
	fuse: (self: CharmActions, player: any, charmId: string, times: number) -> (boolean, string?),
	fuseAll: (self: CharmActions, player: any) -> (boolean, string?),
	-- A Robux pull's grant, inside the receipt's own data update: the pulls
	-- run like coin pulls of that size (same guarantee, same pity). Returns
	-- the ids pulled. Paid for already, so a full bag still takes them.
	grantInside: (self: CharmActions, player: any, d: any, count: number) -> { string },
	-- Studio test panel: one charm of any id.
	grant: (self: CharmActions, player: any, charmId: string) -> (boolean, string),
}

local CharmActions = {}

-- The bag is full: what the player is told.
local function bagFull(charms: any): string
	return `Your charm bag is full ({charms.bagSlots}). Fuse charms to make room.`
end

function CharmActions.new(options: Options): CharmActions
	local charms = options.charms
	local actions = options.actions
	local analytics = options.analytics

	-- A paid roll: the core odds service checks PolicyService first.
	local function roller(player: any, policy: any): (tableId: string) -> string?
		return function(tableId: string): string?
			return (options.odds:rollPaid(tableId, player, policy))
		end
	end
	-- The Robux pulls were policy-checked when the core shop opened the
	-- purchase prompt (paidRandom); a paid receipt is always delivered.
	local delivered = {
		paidRandomAllowed = function(_self: any, _player: any): boolean
			return true
		end,
	}

	local function tierName(rank: number): string
		return charms.tiers[rank] or "None"
	end

	local api = {}

	function api.pull(_self: CharmActions, player: any, count: number): (boolean, string?)
		local size = Claw.size(charms, count)
		if size == nil then
			return false, "unknown pull size"
		end
		if not options.policy:paidRandomAllowed(player) then
			options.notify(player, "The claw machine isn't available where you live. Try the Charm Counter.")
			return false, "restricted"
		end
		if options.nearClaw and not options.nearClaw(player) then
			options.notify(player, "Walk up to the claw machine to pull.")
			return false, "too far from the claw machine"
		end
		local got: { Charms.Owned } = {}
		local price = 0
		local ok, err = actions:change(player, function(d, ledger)
			if not Charms.hasRoom(d, charms, count) then
				return bagFull(charms)
			end
			price = Claw.price(d.incomePeak or 0, charms, count)
			if ledger:balance("coins") < price then
				return `Not enough coins: {count} {if count == 1 then "pull costs" else "pulls cost"} {price}.`
			end
			-- Roll before paying: a refused roll must change nothing.
			local pulled, refusal =
				Claw.pull(d, charms, count, roller(player, options.policy), options.now(), "claw")
			if pulled == nil then
				return refusal
			end
			ledger:spend("coins", price, `Shop:ClawPull{count}`)
			got = pulled
			return nil
		end)
		if not ok then
			return false, err
		end
		local ids = {}
		for _, owned in got do
			table.insert(ids, owned.id)
		end
		analytics:custom(player, "Claw:Pull", count, { "Coins", tierName(Claw.bestRank(charms, got)) })
		options.result(player, ids, "Coins")
		return true, nil
	end

	function api.grantInside(_self: CharmActions, player: any, d: any, count: number): { string }
		local pulled = Claw.pull(d, charms, count, roller(player, delivered), options.now(), "claw")
		assert(pulled, "a paid claw pull rolled nothing")
		local ids = {}
		for _, owned in pulled do
			table.insert(ids, owned.id)
		end
		analytics:custom(player, "Claw:Pull", count, { "Robux", tierName(Claw.bestRank(charms, pulled)) })
		return ids
	end

	function api.counter(_self: CharmActions, player: any, charmId: string): (boolean, string?)
		local def = Charms.def(charms, charmId)
		if def == nil or not Charms.isActive(charms, def.kind) then
			return false, "unknown charm"
		end
		if options.policy:paidRandomAllowed(player) then
			options.notify(player, "Pull at the claw machine for charms.")
			return false, "the Charm Counter is for players the claw is closed to"
		end
		if options.nearClaw and not options.nearClaw(player) then
			options.notify(player, "Walk up to the claw machine to buy.")
			return false, "too far from the claw machine"
		end
		local ok, err = actions:change(player, function(d, ledger)
			local price = Claw.counterPrice(d.incomePeak or 0, charms, def.tier)
			if price == nil then
				return `The Charm Counter doesn't sell {def.tier} charms.`
			end
			if not Charms.hasRoom(d, charms, 1) then
				return bagFull(charms)
			end
			if not ledger:spend("coins", price, "Shop:CharmCounter") then
				return `Not enough coins: {def.name} costs {price}.`
			end
			Charms.add(d, def.id, options.now(), "counter")
			return nil
		end)
		if ok then
			analytics:custom(player, "Claw:Counter", 1, { def.tier })
			options.result(player, { def.id }, "Counter")
		end
		return ok, err
	end

	-- Changes to what the player wears.
	local function wearing(player: any, fn: (d: any) -> string?, event: string?, fields: { string }?)
		local ok, err = actions:change(player, function(d)
			return fn(d)
		end)
		if ok then
			if event then
				analytics:custom(player, event, 1, fields)
			end
			options.changed(player)
		end
		return ok, err
	end

	function api.equip(_self: CharmActions, player: any, charmId: string): (boolean, string?)
		local def = Charms.def(charms, charmId)
		if def == nil then
			return false, "unknown charm"
		end
		return wearing(player, function(d)
			local _, refusal = Charms.equip(d, charms, charmId)
			return refusal
		end, "Charm:Equip", { def.kind, def.tier })
	end

	function api.unequip(_self: CharmActions, player: any, kindId: string): (boolean, string?)
		if Charms.kind(charms, kindId) == nil then
			return false, "unknown kind"
		end
		return wearing(player, function(d)
			local _, refusal = Charms.unequip(d, kindId)
			return refusal
		end, "Charm:Unequip", { kindId })
	end

	function api.setShown(_self: CharmActions, player: any, which: string, shown: boolean): (boolean, string?)
		if which ~= "all" and Charms.kind(charms, which) == nil then
			return false, "unknown kind"
		end
		return wearing(player, function(d)
			local _, refusal = Charms.setShown(d, charms, which, shown)
			return refusal
		end, "Charm:Shown", { which :: string, if shown then "On" else "Off" } :: { string })
	end

	function api.fuse(_self: CharmActions, player: any, charmId: string, times: number): (boolean, string?)
		local def = Charms.def(charms, charmId)
		if def == nil or not Charms.isActive(charms, def.kind) then
			return false, "unknown charm"
		end
		local made: { Charms.Owned } = {}
		local ok, err = actions:change(player, function(d, ledger)
			local fee = Claw.fuseFee(d.incomePeak or 0, charms)
			local result, refusal = Charms.fuse(d, ledger, charms, charmId, times, fee, options.now())
			if result == nil then
				return refusal
			end
			made = result
			return nil
		end)
		if ok and #made > 0 then
			local into = Charms.def(charms, made[1].id)
			analytics:custom(player, "Charm:Fuse", times, { def.id, if into then into.tier else "?" })
			options.notify(
				player,
				`Fused {times * charms.fuseCount} {def.name} into {times} {if into then into.name else "charm"}!`
			)
			options.changed(player)
		end
		return ok, err
	end

	function api.fuseAll(_self: CharmActions, player: any): (boolean, string?)
		local steps: { Charms.FuseStep } = {}
		local ok, err = actions:change(player, function(d, ledger)
			local fee = Claw.fuseFee(d.incomePeak or 0, charms)
			local done, refusal = Charms.fuseAll(d, ledger, charms, fee, options.now())
			if done == nil then
				return refusal
			end
			steps = done
			return nil
		end)
		if ok then
			local made = 0
			for _, step in steps do
				made += step.times
				analytics:custom(player, "Charm:Fuse", step.times, { step.from, step.to })
			end
			options.notify(player, `Fused {made} new {if made == 1 then "charm" else "charms"}!`)
			options.changed(player)
		end
		return ok, err
	end

	function api.grant(_self: CharmActions, player: any, charmId: string): (boolean, string)
		local def = Charms.def(charms, charmId)
		if def == nil then
			return false, `No charm called {charmId}.`
		end
		local ok, err = actions:change(player, function(d)
			if not Charms.hasRoom(d, charms, 1) then
				return bagFull(charms)
			end
			Charms.add(d, charmId, options.now(), "grant")
			return nil
		end)
		if not ok then
			return false, `Could not add {def.name}: {err or "unknown"}.`
		end
		return true, `{def.name} added to your charm bag.`
	end

	return (api :: any) :: CharmActions
end

return CharmActions
