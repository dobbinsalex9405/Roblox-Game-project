--!strict
-- Remotes the core itself needs. Games declare their own in their shared folder.

local Feedback = require("./Feedback")
local Net = require("./Net")
local Schema = require("./Schema")

local CoreRemotes = {
	-- Client -> server: an error caught on the client.
	["Core:ClientError"] = Net.toServer("Core:ClientError", {
		Schema.string({ maxLength = 2000 }),
		Schema.string({ maxLength = 4000 }),
	}, { count = 5, window = 10 }),

	-- Client -> server: a report from the Feedback form: category, text,
	-- rating (1-5, 0 = none) and the device it came from. Feedback.luau
	-- applies the real per-player limits; this only stops floods.
	["Core:Feedback"] = Net.toServer("Core:Feedback", {
		Schema.oneOf(Feedback.CATEGORIES),
		Schema.string({ maxLength = 2000 }),
		Schema.integer({ min = 0, max = 5 }),
		Schema.record({
			platform = Schema.oneOf(Feedback.PLATFORMS),
			screen = Schema.string({ maxLength = 20, pattern = "^%d+x%d+$" }),
			fps = Schema.number({ min = 0, max = 1000 }),
		}),
	}, { count = 3, window = 60 }),

	-- Server -> client: whether the report was sent, and what to tell the player.
	["Core:FeedbackResult"] = Net.toClient("Core:FeedbackResult", {
		Schema.boolean(),
		Schema.string({ maxLength = 200 }),
	}),

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
