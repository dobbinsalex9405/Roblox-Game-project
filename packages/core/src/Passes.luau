--!strict
-- Module 6: Passes.
-- Game pass ownership by short key ("DoubleCoins") instead of raw ids. Checked
-- once on join and updated the moment a purchase finishes, so a pass bought
-- mid-session works without rejoining. A pass whose id is still 0 (not created
-- on Roblox yet) is never owned.

local Log = require("./Log")

export type Options = {
	passes: { [string]: number }, -- key -> game pass id
	-- Roblox's MarketplaceService:UserOwnsGamePassAsync, wrapped. May yield or throw.
	ownsAsync: (player: any, passId: number) -> boolean,
	onOwned: ((player: any, passKey: string) -> ())?,
	retries: number?,
}

export type Passes = {
	load: (self: Passes, player: any) -> (),
	owns: (self: Passes, player: any, passKey: string) -> boolean,
	onPurchaseFinished: (self: Passes, player: any, passId: number, purchased: boolean) -> (),
	keyFor: (self: Passes, passId: number) -> string?,
	release: (self: Passes, player: any) -> (),
}

local log = Log.new("Passes")

local Passes = {}

function Passes.new(options: Options): Passes
	local retries = options.retries or 3
	local keyById: { [number]: string } = {}
	for key, id in options.passes do
		assert(type(id) == "number" and id >= 0 and id // 1 == id, `pass {key} has an invalid id`)
		if id > 0 then
			assert(keyById[id] == nil, `pass id {id} used by both {keyById[id]} and {key}`)
			keyById[id] = key
		end
	end

	local owned: { [any]: { [string]: boolean } } = {}

	local passes = {}

	local function grant(player: any, key: string)
		local set = owned[player]
		if set == nil or set[key] then
			return
		end
		set[key] = true
		if options.onOwned then
			local ok, err = pcall(options.onOwned, player, key)
			if not ok then
				log:error("onOwned failed", { pass = key, err = err })
			end
		end
	end

	function passes.load(_self: Passes, player: any)
		owned[player] = owned[player] or {}
		for key, id in options.passes do
			if id > 0 then
				for attempt = 1, retries do
					local ok, result = pcall(options.ownsAsync, player, id)
					if ok then
						if result == true then
							grant(player, key)
						end
						break
					elseif attempt == retries then
						log:warn(
							"ownership check failed; treating as not owned this session",
							{ pass = key, err = result }
						)
					end
				end
				if owned[player] == nil then
					return -- player left while we were checking
				end
			end
		end
	end

	function passes.owns(_self: Passes, player: any, passKey: string): boolean
		local id = options.passes[passKey]
		if id == nil then
			error(`unknown pass "{tostring(passKey)}"`, 2)
		end
		local set = owned[player]
		return set ~= nil and set[passKey] == true
	end

	function passes.onPurchaseFinished(_self: Passes, player: any, passId: number, purchased: boolean)
		if not purchased then
			return
		end
		local key = keyById[passId]
		if key == nil then
			log:warn("purchase finished for an unknown pass", { passId = passId })
			return
		end
		grant(player, key)
	end

	function passes.keyFor(_self: Passes, passId: number): string?
		return keyById[passId]
	end

	function passes.release(_self: Passes, player: any)
		owned[player] = nil
	end

	return (passes :: any) :: Passes
end

return Passes
