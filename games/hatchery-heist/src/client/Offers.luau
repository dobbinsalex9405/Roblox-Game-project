--!strict
-- The Robux items sold from the game's own buttons rather than the Shop
-- window (Instant Hatch on an incubator, Double Offline Earnings on the
-- welcome back, Streak Saver in the daily window). Keeps the shop's catalog
-- so a button only shows for an item that exists on Roblox (or in Studio,
-- for the test panel), and sends the purchase request the shop would.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ClientNet = require(ReplicatedStorage.CoreClient.ClientNet)
local ShopRemotes = require(ReplicatedStorage.Core.ShopRemotes)

local Offers = {}

local available: { [string]: boolean } = {}
local listeners: { () -> () } = {}
local started = false
local received = false -- the catalog has arrived at least once

-- Starts listening (and asks for the catalog once). Safe to call again.
local function start()
	if started then
		return
	end
	started = true
	ClientNet.on(ShopRemotes["Shop:Catalog"], function(entries: { any })
		received = true
		table.clear(available)
		for _, entry in entries do
			if type(entry) == "table" and type(entry.key) == "string" then
				available[`{entry.kind}:{entry.key}`] = entry.available == true
			end
		end
		for _, listener in listeners do
			task.spawn(listener)
		end
	end)
	ClientNet.fire(ShopRemotes["Shop:RequestCatalog"])
end
Offers.start = start

-- Whether product `key` can be bought here: created on Roblox, or in Studio
-- (where the shop answers with a pointer to the test panel).
function Offers.sold(key: string): boolean
	start()
	local entry = available[`product:{key}`]
	if entry == nil then
		return false
	end
	return entry or RunService:IsStudio()
end

-- Waits up to `seconds` for the first catalog. Returns whether it is here.
function Offers.await(seconds: number): boolean
	start()
	local deadline = os.clock() + seconds
	while not received and os.clock() < deadline do
		task.wait(0.2)
	end
	return received
end

-- Calls `fn` each time the catalog arrives (to show or hide a button).
function Offers.onChange(fn: () -> ())
	start()
	table.insert(listeners, fn)
end

-- Asks the server to open Roblox's prompt for product `key`. `source` is
-- where the button is, for the scoreboard (ops/METRICS.md).
function Offers.buy(key: string, source: string)
	ClientNet.fire(ShopRemotes["Shop:Buy"], "product", key, source)
end

return Offers
