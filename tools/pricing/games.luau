--!strict
-- Every game's listings and shop catalog, loaded from the repo, for the
-- pricing tool and its test. Add a game here when it gets a shop.
local lib = require("./lib")

local function hatcheryHeist(): lib.Game
	local monetization = require("../../games/hatchery-heist/config/monetization")
	local raids = require("../../games/hatchery-heist/config/raids")
	local Products = require("../../games/hatchery-heist/src/shared/Products")
	return {
		id = "hatchery-heist",
		title = "Hatchery Heist",
		packField = "coins",
		monetization = monetization,
		catalog = Products.catalog(monetization, raids),
	}
end

local function tidecatchCove(): lib.Game
	local config = {
		fishing = require("../../games/tidecatch-cove/config/fishing"),
		species = require("../../games/tidecatch-cove/config/species"),
		pools = require("../../games/tidecatch-cove/config/pools"),
		economy = require("../../games/tidecatch-cove/config/economy"),
		monetization = require("../../games/tidecatch-cove/config/monetization"),
	}
	local Products = require("../../games/tidecatch-cove/src/shared/Products")
	return {
		id = "tidecatch-cove",
		title = "Tidecatch Cove",
		monetization = config.monetization,
		catalog = Products.catalog(config :: any),
	}
end

local function streetFoodEmpire(): lib.Game
	local monetization = require("../../games/street-food-empire/config/monetization")
	local economy = require("../../games/street-food-empire/config/economy")
	local Products = require("../../games/street-food-empire/src/shared/Products")
	-- Registering builds the catalog; nothing is bought here, so the receipt
	-- handler and actions are stand-ins.
	local receipts = { register = function() end }
	local ids: { [string]: number } = {}
	for key in monetization.products do
		ids[key] = 0
	end
	return {
		id = "street-food-empire",
		title = "Street Food Empire",
		packField = "cash",
		monetization = monetization,
		catalog = Products.register(receipts, ids, monetization, economy, nil :: any),
	}
end

local function depthbound(): lib.Game
	local monetization = require("../../games/depthbound/config/monetization")
	local gear = require("../../games/depthbound/config/gear")
	local Products = require("../../games/depthbound/src/shared/Products")
	return {
		id = "depthbound",
		title = "Depthbound",
		monetization = monetization,
		catalog = Products.catalog(monetization, gear),
	}
end

-- In launch order.
return function(): { lib.Game }
	return { hatcheryHeist(), tidecatchCove(), streetFoodEmpire(), depthbound() }
end
