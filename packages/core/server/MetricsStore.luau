--!strict
-- Roblox side of Metrics: merges each server's daily counts into the
-- "Metrics" DataStore with UpdateAsync, one shard key per server per day.
-- Runs on live servers only; Studio sessions (and the test panel's fake
-- purchases) never reach the scoreboard.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Core.Log)
local Metrics = require(ReplicatedStorage.Core.Metrics)

local log = Log.new("Metrics")

local MetricsStore = {}

-- Returns a writer: given one day's delta, merges it into the store. Returns
-- false when the write failed and the delta should be kept for next time.
function MetricsStore.writer(storeName: string?): (delta: Metrics.Day) -> boolean
	local store = DataStoreService:GetDataStore(storeName or Metrics.STORE)
	local shard = Metrics.shard(if game.JobId ~= "" then game.JobId else "studio")
	return function(delta: Metrics.Day): boolean
		local key = Metrics.key(delta.day, shard)
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(stored: any)
				return Metrics.merge(stored, delta, os.time())
			end)
		end)
		if not ok then
			log:warn("metrics write failed", { key = key, err = err })
		end
		return ok
	end
end

return MetricsStore
