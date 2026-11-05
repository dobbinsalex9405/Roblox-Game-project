--!strict
-- Opens a DataStore without letting a missing one stop the server. In an
-- unpublished place (a built .rbxl opened in Studio) GetDataStore throws
-- "You must publish this place to the web to access DataStore", and the error
-- queue, feedback and metrics sinks open theirs while CoreServer starts, so an
-- unguarded call took the whole game down with it. Live servers always get
-- their store, so their behaviour is unchanged.

local Log = require("./Log")

local log = Log.new("Stores")

local Stores = {}

local warned: { [string]: boolean } = {}

-- The store, or nil (with one warning per store name) when DataStores are
-- unavailable. `service` is DataStoreService.
function Stores.open(service: any, name: string): any?
	local ok, result = pcall(function()
		return service:GetDataStore(name)
	end)
	if ok then
		return result
	end
	if not warned[name] then
		warned[name] = true
		log:warn("DataStores unavailable; nothing will be saved to this store", {
			store = name,
			err = result,
		})
	end
	return nil
end

-- Forget which stores already warned (tests).
function Stores.reset()
	table.clear(warned)
end

return Stores
