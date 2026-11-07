--!strict
-- Runs the timed events (config/events.luau, shared/Events.luau) on this
-- server: what the running event changes for Actions (egg prices, hatch
-- time, income), the Lucky Hatch odds boost on every player's egg tables,
-- a notice to everyone when an event is about to start, starts and ends, and
-- the uptake telemetry ("Event:*" analytics events, counted daily by the
-- core's metrics).
--
-- The schedule comes from the clock alone, so every server agrees without
-- talking; clients draw the same countdown from the same module. The only
-- state is a Studio test override, mirrored to clients as ReplicatedStorage
-- attributes (EventOverrideKind, EventOverrideStart, EventOverrideEnd).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Eggs = require(Shared.Eggs)
local Events = require(Shared.Events)

export type Deps = {
	odds: any,
	analytics: any,
	eggs: { any },
	species: { [string]: any },
	notify: (player: Player, text: string) -> (),
	addTestAction: (name: string, title: string, choices: { string }, run: (Player, string) -> string) -> (),
}

export type EventService = {
	effects: () -> Events.Effects,
	incomeSeconds: (from: number, to: number) -> number,
	override: () -> Events.Override?,
	start: (deps: Deps) -> (),
}

local WARN_SECONDS = 300 -- "starts in 5 minutes" notice
local TICK = 1

local EventService = {}

function EventService.new(config: any): EventService
	local override: Events.Override? = nil

	local function now(): number
		return os.time()
	end

	local service = {} :: EventService

	function service.override(): Events.Override?
		if override and now() >= override.endsAt then
			override = nil
		end
		return override
	end

	function service.effects(): Events.Effects
		return Events.effects(now(), config, service.override())
	end

	function service.incomeSeconds(from: number, to: number): number
		return Events.incomeSeconds(from, to, config, override)
	end

	function service.start(deps: Deps)
		local function mirror()
			local o = override
			ReplicatedStorage:SetAttribute("EventOverrideKind", if o then o.kind else nil)
			ReplicatedStorage:SetAttribute("EventOverrideStart", if o then o.startsAt else nil)
			ReplicatedStorage:SetAttribute("EventOverrideEnd", if o then o.endsAt else nil)
		end

		-- Lucky Hatch: one boost on every egg table. setBoosts replaces a
		-- player's whole boost list per table, so a future paid Luck Boost
		-- must be added to this same list, not set on its own.
		local boosted: { [Player]: string } = {}
		local function applyOdds(player: Player, kind: string?)
			local effects = Events.effectsOf(kind, config)
			local key = if effects.rarityMultipliers then kind :: string else ""
			if (boosted[player] or "") == key then
				return
			end
			boosted[player] = key
			for _, egg in deps.eggs do
				local list = {}
				if effects.rarityMultipliers then
					local multipliers = Eggs.boostMultipliers(
						egg,
						{ rarityMultipliers = effects.rarityMultipliers },
						deps.species
					)
					table.insert(list, { id = kind :: string, multipliers = multipliers })
				end
				deps.odds:setBoosts(player, egg.id, list)
			end
		end

		-- Telemetry: each player counted once per event window they saw.
		local seen: { [Player]: string } = {}
		local function noteSeen(player: Player, active: Events.Window?)
			if active == nil then
				return
			end
			local tag = `{active.kind}@{active.startsAt}`
			if seen[player] == tag then
				return
			end
			seen[player] = tag
			deps.analytics:custom(player, "Event:Seen", 1, { active.kind })
		end

		local function everyone(text: string)
			for _, player in Players:GetPlayers() do
				deps.notify(player, text)
			end
		end

		local lastActive: string? = nil -- "kind@startsAt" of the event running at the last tick
		local warned: number? = nil -- startsAt of the window last warned about
		local function tick()
			local t = now()
			local state = Events.state(t, config, service.override())
			local active = state.active
			local tag = if active then `{active.kind}@{active.startsAt}` else nil
			if tag ~= lastActive then
				if active then
					local def = config.kinds[active.kind]
					everyone(`{def.title}! {def.blurb} For {Events.countdown(active.endsAt - t)}.`)
				elseif lastActive then
					everyone("The event is over. See the banner for the next one!")
				end
				lastActive = tag
			end
			local wait = state.nextWindow.startsAt - t
			if
				active == nil
				and wait <= WARN_SECONDS
				and wait > 0
				and warned ~= state.nextWindow.startsAt
			then
				warned = state.nextWindow.startsAt
				everyone(`{config.kinds[state.nextWindow.kind].title} starts in {Events.countdown(wait)}!`)
			end
			for _, player in Players:GetPlayers() do
				applyOdds(player, active and active.kind)
				noteSeen(player, active)
			end
		end

		Players.PlayerRemoving:Connect(function(player: Player)
			boosted[player] = nil
			seen[player] = nil
		end)

		-- Studio test panel: start any event now (for the visual check), one
		-- in two minutes (to see the countdown), or stop.
		local choices = table.clone(config.rotation)
		table.insert(choices, "Next in 2 min")
		table.insert(choices, "Stop")
		deps.addTestAction(
			"event",
			"Timed event (start one now for its full length, or stop)",
			choices,
			function(_player: Player, choice: string): string
				local t = now()
				local length = config.windowMinutes * 60
				if choice == "Stop" then
					override = nil
					mirror()
					return "Test event stopped; the schedule runs again."
				elseif choice == "Next in 2 min" then
					local kind = Events.state(t, config).nextWindow.kind
					override = { kind = kind, startsAt = t + 120, endsAt = t + 120 + length }
					mirror()
					return `{config.kinds[kind].title} starts in 2 minutes.`
				elseif config.kinds[choice] == nil then
					return `No event called {choice}.`
				end
				override = { kind = choice, startsAt = t, endsAt = t + length }
				mirror()
				tick()
				return `{config.kinds[choice].title} runs for {config.windowMinutes} minutes.`
			end
		)

		mirror()
		task.spawn(function()
			while true do
				local ok, err = pcall(function()
					tick()
				end)
				if not ok then
					warn(`[EventService] tick failed: {err}`)
				end
				task.wait(TICK)
			end
		end)
	end

	return service
end

return EventService
