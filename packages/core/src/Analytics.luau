--!strict
-- Module 11: Analytics.
-- One naming scheme for every event, sent through Roblox's AnalyticsService
-- (the sink is injected so tests can capture events). The launch gate is
-- judged on day-1 return rate and average session length, so this module also
-- emits a session-length event at the end of every session and a
-- "Retention:D1/D7/D30" marker on the first session of those days.
--
-- Names:
--   custom events     "Area:Event" in PascalCase, e.g. "Raid:Started"
--   economy           via Economy changes (one event per balance change)
--   onboarding        steps 1..n, each sent at most once per player session
--   funnels           named funnels with a per-run session id
--   progression       paths like "Rebirth" with a level number

local Log = require("./Log")
local Util = require("./Util")

export type Flow = "Source" | "Sink"
export type ProgressionStatus = "Start" | "Complete" | "Fail"

export type Sink = {
	economy: (
		player: any,
		flow: Flow,
		currency: string,
		amount: number,
		balance: number,
		transactionType: string,
		sku: string
	) -> (),
	onboarding: (player: any, step: number, stepName: string) -> (),
	funnel: (player: any, funnelName: string, funnelSessionId: string, step: number, stepName: string) -> (),
	progression: (player: any, path: string, status: ProgressionStatus, level: number) -> (),
	custom: (player: any, name: string, value: number, fields: { string }?) -> (),
}

export type SessionInfo = {
	firstJoinAt: number, -- unix seconds of the player's first ever join (0 if this is it)
	lastJoinAt: number, -- unix seconds of the previous join (0 if none)
}

export type Analytics = {
	economy: (
		self: Analytics,
		change: {
			player: any,
			flow: Flow,
			currency: string,
			amount: number,
			balance: number,
			transactionType: string,
			sku: string,
		}
	) -> (),
	onboarding: (self: Analytics, player: any, step: number, stepName: string) -> (),
	funnel: (
		self: Analytics,
		player: any,
		funnelName: string,
		funnelSessionId: string,
		step: number,
		stepName: string
	) -> (),
	progression: (self: Analytics, player: any, path: string, status: ProgressionStatus, level: number) -> (),
	custom: (self: Analytics, player: any, name: string, value: number?, fields: { string }?) -> (),
	purchase: (self: Analytics, player: any, productKey: string, robux: number) -> (),
	sessionStart: (self: Analytics, player: any, info: SessionInfo, now: number) -> { string },
	sessionEnd: (self: Analytics, player: any, now: number) -> number?,
}

local EVENT_PATTERN = "^%u%w*:%u%w*$"
local KEY_PATTERN = "^%u%w*$"
local DAY = 86400
local RETENTION_DAYS = { 1, 7, 30 }

local log = Log.new("Analytics")

local Analytics = {}

function Analytics.checkEventName(name: string)
	if type(name) ~= "string" or #name > 50 or not string.match(name, EVENT_PATTERN) then
		error(
			`analytics event "{tostring(name)}" must look like "Area:Event" (PascalCase, at most 50 characters)`,
			3
		)
	end
end

local function checkKey(kind: string, value: string)
	if type(value) ~= "string" or #value > 50 or not string.match(value, KEY_PATTERN) then
		error(`analytics {kind} "{tostring(value)}" must be PascalCase, at most 50 characters`, 3)
	end
end

-- Which retention markers a join at `now` should emit. A marker fires on the
-- first join of calendar day (UTC) 1, 7 or 30 after the first ever join.
function Analytics.retentionMarkers(firstJoinAt: number, lastJoinAt: number, now: number): { string }
	if firstJoinAt <= 0 then
		return {}
	end
	local today = now // DAY
	local firstDay = firstJoinAt // DAY
	local lastDay = if lastJoinAt > 0 then lastJoinAt // DAY else firstDay
	if lastDay >= today then
		return {} -- already played today
	end
	local markers = {}
	for _, n in RETENTION_DAYS do
		if today - firstDay == n then
			table.insert(markers, `Retention:D{n}`)
		end
	end
	return markers
end

function Analytics.new(sink: Sink): Analytics
	local onboardingStep: { [any]: number } = {}
	local sessionStartedAt: { [any]: number } = {}

	local analytics = {}

	local function send(what: string, fn: (...any) -> (), ...: any)
		local ok, err = Util.try(fn, ...)
		if not ok then
			-- Analytics must never break gameplay.
			log:warn("event failed", { event = what, err = err })
		end
	end

	function analytics.economy(_self: Analytics, change)
		send(
			"economy",
			sink.economy,
			change.player,
			change.flow,
			change.currency,
			change.amount,
			change.balance,
			change.transactionType,
			change.sku
		)
	end

	function analytics.onboarding(_self: Analytics, player: any, step: number, stepName: string)
		assert(
			type(step) == "number" and step >= 1 and step // 1 == step,
			"onboarding step must be a whole number from 1"
		)
		checkKey("onboarding step name", stepName)
		local last = onboardingStep[player] or 0
		if step <= last then
			return -- each step once per session, in order
		end
		onboardingStep[player] = step
		send("onboarding", sink.onboarding, player, step, stepName)
	end

	function analytics.funnel(
		_self: Analytics,
		player: any,
		funnelName: string,
		funnelSessionId: string,
		step: number,
		stepName: string
	)
		checkKey("funnel name", funnelName)
		checkKey("funnel step name", stepName)
		assert(
			type(step) == "number" and step >= 1 and step // 1 == step,
			"funnel step must be a whole number from 1"
		)
		send("funnel", sink.funnel, player, funnelName, funnelSessionId, step, stepName)
	end

	function analytics.progression(
		_self: Analytics,
		player: any,
		path: string,
		status: ProgressionStatus,
		level: number
	)
		checkKey("progression path", path)
		send("progression", sink.progression, player, path, status, level)
	end

	function analytics.custom(
		_self: Analytics,
		player: any,
		name: string,
		value: number?,
		fields: { string }?
	)
		Analytics.checkEventName(name)
		assert(fields == nil or #fields <= 3, "Roblox allows at most 3 custom fields")
		send("custom", sink.custom, player, name, value or 1, fields)
	end

	function analytics.purchase(self: Analytics, player: any, productKey: string, robux: number)
		self:custom(player, "Purchase:Product", robux, { productKey })
	end

	-- Call once the player's data has loaded. Returns the retention markers sent.
	function analytics.sessionStart(self: Analytics, player: any, info: SessionInfo, now: number): { string }
		sessionStartedAt[player] = now
		onboardingStep[player] = nil
		self:custom(player, "Session:Start", 1, { if info.firstJoinAt <= 0 then "New" else "Returning" })
		local markers = Analytics.retentionMarkers(info.firstJoinAt, info.lastJoinAt, now)
		for _, marker in markers do
			self:custom(player, marker, 1)
		end
		return markers
	end

	-- Call when the player leaves. Returns the session length in seconds.
	function analytics.sessionEnd(self: Analytics, player: any, now: number): number?
		local started = sessionStartedAt[player]
		sessionStartedAt[player] = nil
		onboardingStep[player] = nil
		if started == nil then
			return nil
		end
		local seconds = math.max(0, math.floor(now - started))
		self:custom(player, "Session:Length", seconds)
		return seconds
	end

	return (analytics :: any) :: Analytics
end

return Analytics
