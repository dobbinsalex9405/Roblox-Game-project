--!strict
-- Remotes the core itself needs. Games declare their own in their shared folder.

local Net = require("./Net")
local Schema = require("./Schema")

local CoreRemotes = {
	-- Client -> server: an error caught on the client.
	["Core:ClientError"] = Net.toServer("Core:ClientError", {
		Schema.string({ maxLength = 2000 }),
		Schema.string({ maxLength = 4000 }),
	}, { count = 5, window = 10 }),

	-- Client -> server: text from the feedback button.
	["Core:Feedback"] = Net.toServer("Core:Feedback", {
		Schema.string({ maxLength = 2000 }),
	}, { count = 2, window = 60 }),

	-- Client -> server: ask for the current odds screen of one table.
	["Core:RequestOdds"] = Net.toServer("Core:RequestOdds", {
		Schema.string({ maxLength = 50, pattern = "^[%a][%w_]*$" }),
	}, { count = 5, window = 1 }),

	-- Server -> client: odds screen rows for one table (sent on request and whenever a boost changes them).
	["Core:Odds"] = Net.toClient("Core:Odds", { Schema.any() }),

	-- Server -> client: a snapshot of the player's own saved data after it changes.
	["Core:Data"] = Net.toClient("Core:Data", { Schema.any() }),

	-- Server -> client: which passes the player owns.
	["Core:Passes"] = Net.toClient("Core:Passes", { Schema.any() }),
}

return CoreRemotes
