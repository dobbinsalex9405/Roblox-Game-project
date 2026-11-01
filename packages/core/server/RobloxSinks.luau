--!strict
-- Roblox implementations of the injected outputs: AnalyticsService for
-- Analytics, a DataStore for the error and feedback queue.

local AnalyticsService = game:GetService("AnalyticsService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Analytics = require(ReplicatedStorage.Core.Analytics)
local ErrorReporter = require(ReplicatedStorage.Core.ErrorReporter)

local CUSTOM_FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

local RobloxSinks = {}

local function customFields(fields: { string }?): { [string]: string }?
	if fields == nil or #fields == 0 then
		return nil
	end
	local out = {}
	for index, value in fields do
		out[CUSTOM_FIELD_KEYS[index]] = value
	end
	return out
end

function RobloxSinks.analytics(): Analytics.Sink
	return {
		economy = function(player, flow, currency, amount, balance, transactionType, sku)
			local flowType = if flow == "Source"
				then Enum.AnalyticsEconomyFlowType.Source
				else Enum.AnalyticsEconomyFlowType.Sink
			AnalyticsService:LogEconomyEvent(
				player,
				flowType,
				currency,
				amount,
				balance,
				transactionType,
				sku
			)
		end,
		onboarding = function(player, step, stepName)
			AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
		end,
		funnel = function(player, funnelName, funnelSessionId, step, stepName)
			AnalyticsService:LogFunnelStepEvent(player, funnelName, funnelSessionId, step, stepName)
		end,
		progression = function(player, path, status, level)
			if status == "Start" then
				AnalyticsService:LogProgressionStartEvent(player, path, level)
			elseif status == "Complete" then
				AnalyticsService:LogProgressionCompleteEvent(player, path, level)
			else
				AnalyticsService:LogProgressionFailEvent(player, path, level)
			end
		end,
		custom = function(player, name, value, fields)
			AnalyticsService:LogCustomEvent(player, name, value, customFields(fields))
		end,
	}
end

-- Writes each batch to its own key, "<unix minute>-<JobId>", in the
-- "ErrorQueue" DataStore. One key per server per minute keeps writes far under
-- the DataStore budget; the nightly reader lists keys newer than its cursor.
function RobloxSinks.errorQueue(storeName: string?): (batch: ErrorReporter.Batch) -> boolean
	local store = DataStoreService:GetDataStore(storeName or "ErrorQueue")
	return function(batch: ErrorReporter.Batch): boolean
		local job = if game.JobId ~= "" then game.JobId else "studio"
		local key = `{math.floor(batch.at / 60)}-{job}`
		local ok = pcall(function()
			store:SetAsync(key, batch)
		end)
		return ok
	end
end

return RobloxSinks
