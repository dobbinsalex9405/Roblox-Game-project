--!strict
-- Starts the core on the client: forwards client errors to the server's error
-- queue, keeps the latest copy of the player's own data and passes, and
-- exposes the feedback button and odds screen requests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")

local CoreRemotes = require(ReplicatedStorage.Core.CoreRemotes)
local ClientNet = require(script.Parent.ClientNet)

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

function CoreClient.start()
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

function CoreClient.submitFeedback(text: string)
	ClientNet.fire(CoreRemotes["Core:Feedback"], string.sub(text, 1, 2000))
end

return CoreClient
