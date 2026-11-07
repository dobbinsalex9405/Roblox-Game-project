--!strict
-- The timed events as this client sees them: the same schedule the servers
-- run (shared/Events.luau, config/events.luau) on the shared server clock,
-- plus a Studio test override the server mirrors as ReplicatedStorage
-- attributes. Display only: the server decides every effect.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Events = require(ReplicatedStorage.Shared.Events)

local EventClock = {}

EventClock.config = require(ReplicatedStorage.GameConfig.events) :: any

function EventClock.now(): number
	return Workspace:GetServerTimeNow()
end

function EventClock.override(): Events.Override?
	local kind = ReplicatedStorage:GetAttribute("EventOverrideKind")
	local startsAt = ReplicatedStorage:GetAttribute("EventOverrideStart")
	local endsAt = ReplicatedStorage:GetAttribute("EventOverrideEnd")
	if type(kind) == "string" and type(startsAt) == "number" and type(endsAt) == "number" then
		return { kind = kind, startsAt = startsAt, endsAt = endsAt }
	end
	return nil
end

function EventClock.effects(): Events.Effects
	return Events.effects(EventClock.now(), EventClock.config, EventClock.override())
end

function EventClock.incomeSeconds(from: number, to: number): number
	return Events.incomeSeconds(from, to, EventClock.config, EventClock.override())
end

function EventClock.banner(): Events.Banner
	return Events.banner(EventClock.now(), EventClock.config, EventClock.override())
end

-- An egg's coin price right now (the Egg Sale halves it).
function EventClock.price(priceCoins: number): number
	return Events.price(priceCoins, EventClock.effects())
end

return EventClock
