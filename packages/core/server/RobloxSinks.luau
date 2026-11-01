--!strict
-- Roblox implementations of the injected outputs: AnalyticsService for
-- Analytics, a DataStore for the error queue, and a DataStore plus
-- TextService for player feedback.

local AnalyticsService = game:GetService("AnalyticsService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Analytics = require(ReplicatedStorage.Core.Analytics)
local ErrorReporter = require(ReplicatedStorage.Core.ErrorReporter)
local Feedback = require(ReplicatedStorage.Core.Feedback)

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

-- Player feedback batches, one key per write (see Feedback.batchKey), in the
-- "Feedback" DataStore. tools/feedback reads them through Open Cloud.
function RobloxSinks.feedbackStore(storeName: string?): (key: string, batch: Feedback.Batch) -> boolean
	local store = DataStoreService:GetDataStore(storeName or "Feedback")
	return function(key: string, batch: Feedback.Batch): boolean
		local ok = pcall(function()
			store:SetAsync(key, batch)
		end)
		return ok
	end
end

-- Roblox's text filter, in the strictest non-chat mode, so names, numbers and
-- other personal information are removed before a report is stored.
function RobloxSinks.textFilter(): (userId: number, text: string) -> (boolean, string?)
	return function(userId: number, text: string): (boolean, string?)
		local ok, filtered = pcall(function(): string
			local result = TextService:FilterStringAsync(text, userId, Enum.TextFilterContext.PublicChat)
			return result:GetNonChatStringForBroadcastAsync()
		end)
		if not ok then
			return false, nil
		end
		return true, filtered
	end
end

return RobloxSinks
