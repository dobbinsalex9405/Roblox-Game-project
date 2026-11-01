--!strict
-- Starts the core on the client: forwards client errors to the server's error
-- queue, keeps the latest copy of the player's own data and passes, mounts
-- the Feedback button every game gets, and exposes odds screen requests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")

local CoreRemotes = require(ReplicatedStorage.Core.CoreRemotes)
local ClientNet = require(script.Parent.ClientNet)
local FeedbackUi = require(script.Parent.FeedbackUi)
local ShopUi = require(script.Parent.ShopUi)
local TestPanelUi = require(script.Parent.TestPanelUi)

-- Client-side throttle so a render-loop error does not spam the remote
-- (the server rate-limits as well).
local ERROR_COOLDOWN = 5

type Listener<T> = (value: T) -> ()

local CoreClient = {}

local data: { [string]: any }? = nil
local passes: { string } = {}
local dataListeners: { Listener<{ [string]: any }> } = {}
local oddsListeners: { Listener<any> } = {}
local started = false

export type Options = {
	-- The top-bar Feedback button and form. On by default in every game.
	feedback: boolean?,
}

function CoreClient.start(options: Options?)
	assert(not started, "CoreClient.start called twice")
	started = true

	local lastSent: { [string]: number } = {}
	ScriptContext.Error:Connect(function(message: string, trace: string)
		local key = string.sub(message, 1, 200)
		local now = os.clock()
		if lastSent[key] and now - lastSent[key] < ERROR_COOLDOWN then
			return
		end
		lastSent[key] = now
		ClientNet.fire(
			CoreRemotes["Core:ClientError"],
			string.sub(message, 1, 2000),
			string.sub(trace, 1, 4000)
		)
	end)

	ClientNet.on(CoreRemotes["Core:Data"], function(snapshot: { [string]: any })
		data = snapshot
		for _, listener in dataListeners do
			task.spawn(listener, snapshot)
		end
	end)

	ClientNet.on(CoreRemotes["Core:Passes"], function(owned: { string })
		passes = owned
	end)

	ClientNet.on(CoreRemotes["Core:Odds"], function(display: any)
		for _, listener in oddsListeners do
			task.spawn(listener, display)
		end
	end)

	if options == nil or options.feedback ~= false then
		task.spawn(FeedbackUi.start)
	end
	-- The shared shop (shown once the game lists items) and, in Studio only,
	-- the test panel.
	task.spawn(ShopUi.start, {
		requestOdds = CoreClient.requestOdds,
		onOdds = CoreClient.onOdds,
	})
	task.spawn(TestPanelUi.start)
end

-- The latest copy of this player's data (read-only; the server owns it).
function CoreClient.data(): { [string]: any }?
	return data
end

function CoreClient.onData(listener: Listener<{ [string]: any }>)
	table.insert(dataListeners, listener)
	if data then
		task.spawn(listener, data)
	end
end

function CoreClient.ownsPass(passKey: string): boolean
	return table.find(passes, passKey) ~= nil
end

-- Asks the server for one odds table; the answer arrives through onOdds, and
-- again whenever a boost changes it.
function CoreClient.requestOdds(tableId: string)
	ClientNet.fire(CoreRemotes["Core:RequestOdds"], tableId)
end

function CoreClient.onOdds(listener: Listener<any>)
	table.insert(oddsListeners, listener)
end

-- Opens the Feedback form, e.g. from a game's own menu or after a failure
-- ("Something went wrong? Tell us"). `category` may be "bug", "idea" or "other".
function CoreClient.openFeedback(category: string?)
	FeedbackUi.open(category)
end

return CoreClient
