--!strict
-- Module 8: Policy.
-- Reads each player's PolicyService rules once per session. Fails closed: if
-- the rules cannot be read, or a player has not loaded yet, paid random items
-- and paid-item trading are treated as restricted. Odds.rollPaid calls
-- `paidRandomAllowed`, so a restricted player can never reach a paid roll.

local Log = require("./Log")

-- The fields of PolicyService:GetPolicyInfoForPlayerAsync this module reads.
export type PolicyInfo = {
	ArePaidRandomItemsRestricted: boolean,
	IsPaidItemTradingAllowed: boolean,
	[string]: any,
}

export type Options = {
	fetch: (player: any) -> PolicyInfo, -- may yield or throw
	retries: number?,
}

export type Policy = {
	load: (self: Policy, player: any) -> boolean,
	isLoaded: (self: Policy, player: any) -> boolean,
	paidRandomAllowed: (self: Policy, player: any) -> boolean,
	tradingAllowed: (self: Policy, player: any) -> boolean,
	release: (self: Policy, player: any) -> (),
}

local log = Log.new("Policy")

local Policy = {}

function Policy.new(options: Options): Policy
	local retries = options.retries or 3
	local infos: { [any]: PolicyInfo } = {}

	local policy = {}

	-- Returns true when the rules were read. On failure the player stays restricted.
	function policy.load(_self: Policy, player: any): boolean
		for attempt = 1, retries do
			local ok, result = pcall(options.fetch, player)
			if ok and type(result) == "table" then
				infos[player] = table.freeze(table.clone(result))
				return true
			elseif attempt == retries then
				log:warn("could not read policy; restricting paid random items and trading", { err = result })
			end
		end
		return false
	end

	function policy.isLoaded(_self: Policy, player: any): boolean
		return infos[player] ~= nil
	end

	function policy.paidRandomAllowed(_self: Policy, player: any): boolean
		local info = infos[player]
		return info ~= nil and info.ArePaidRandomItemsRestricted == false
	end

	function policy.tradingAllowed(_self: Policy, player: any): boolean
		local info = infos[player]
		return info ~= nil and info.IsPaidItemTradingAllowed == true
	end

	function policy.release(_self: Policy, player: any)
		infos[player] = nil
	end

	return (policy :: any) :: Policy
end

return Policy
