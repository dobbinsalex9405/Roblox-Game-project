--!strict
-- Module 3: DataService.
-- Loads and saves each player's data through a session-locked store
-- (ProfileStore in Roblox, a fake in tests). Every save carries `version`; older
-- saves are upgraded one step at a time on load. Rules that protect data:
--
--  * A migration may add or change keys but never drop one. Keys a migration
--    no longer needs are listed in `retire` and moved under `_retired`, so
--    nothing a player earned is ever deleted.
--  * Data from a newer version than this build knows is refused, not
--    downgraded, so rolling a release back can never overwrite newer saves.
--  * `update` runs the change on a copy and commits it only if the callback
--    finishes without error and without yielding, so a failed change leaves
--    the data untouched.

local Log = require("./Log")
local Util = require("./Util")

export type Migration = {
	from: number, -- upgrades data at version `from` to `from + 1`
	run: (data: { [string]: any }) -> (),
	retire: { string }?,
}

-- The parts of a ProfileStore profile this module uses.
export type Profile = {
	Data: { [string]: any },
	IsActive: (self: any) -> boolean,
	EndSession: (self: any) -> (),
}

export type Store = {
	-- Opens a session-locked profile, or returns nil when the lock or the load fails.
	startSession: (key: string, player: any) -> Profile?,
}

export type Options = {
	store: Store,
	template: { [string]: any },
	migrations: { Migration },
	keyPrefix: string?,
}

export type LoadResult = "loaded" | "failed" | "too-new" | "migration-failed"

export type DataService = {
	version: number,
	load: (self: DataService, player: any, userId: number) -> (LoadResult, string?),
	isLoaded: (self: DataService, player: any) -> boolean,
	get: (self: DataService, player: any) -> { [string]: any }?,
	update: (self: DataService, player: any, change: (data: { [string]: any }) -> ()) -> (boolean, string?),
	onChanged: (self: DataService, listener: (player: any, data: { [string]: any }) -> ()) -> (),
	profile: (self: DataService, player: any) -> Profile?,
	release: (self: DataService, player: any) -> (),
}

local log = Log.new("DataService")

local DataService = {}

-- Checks a migration list: one step per version, starting at 1, no gaps.
-- Returns the version that data reaches after all migrations.
function DataService.latestVersion(migrations: { Migration }): number
	local version = 1
	local sorted = table.clone(migrations)
	table.sort(sorted, function(a, b)
		return a.from < b.from
	end)
	for _, migration in sorted do
		assert(
			migration.from == version,
			`migrations must be consecutive from 1; expected from={version}, got from={migration.from}`
		)
		version += 1
	end
	return version
end

-- Upgrades `data` in place to `latest`. Throws if a migration drops a key or fails.
function DataService.migrate(data: { [string]: any }, migrations: { Migration }, latest: number)
	local byFrom: { [number]: Migration } = {}
	for _, migration in migrations do
		byFrom[migration.from] = migration
	end
	local version = data.version
	assert(type(version) == "number", "saved data has no version")
	while version < latest do
		local migration = byFrom[version]
		assert(migration, `no migration from version {version}`)

		-- Retired keys are archived under `_retired` before the migration runs,
		-- so the migration may reuse the name for a new shape.
		if migration.retire then
			data._retired = data._retired or {}
			for _, key in migration.retire do
				if data[key] ~= nil then
					data._retired[`v{version}.{key}`] = data[key]
					data[key] = nil
				end
			end
		end

		local before = Util.keys(data)
		migration.run(data)
		for _, key in before do
			if data[key] == nil then
				error(`migration from v{version} removed key "{tostring(key)}"; list it in retire instead`)
			end
		end

		version += 1
		data.version = version
	end
end

function DataService.new(options: Options): DataService
	local latest = DataService.latestVersion(options.migrations)
	assert(
		options.template.version == latest,
		`template.version must be {latest} (the latest migration target)`
	)
	local prefix = options.keyPrefix or "Player_"

	local profiles: { [any]: Profile } = {}
	local listeners: { (player: any, data: { [string]: any }) -> () } = {}

	local service = {}
	service.version = latest

	function service.load(_self: DataService, player: any, userId: number): (LoadResult, string?)
		assert(profiles[player] == nil, "data already loaded for this player")
		local profile = options.store.startSession(prefix .. tostring(userId), player)
		if profile == nil then
			return "failed", "could not open the player's data session"
		end

		local data = profile.Data
		if next(data) == nil then
			-- Brand new player.
			Util.replaceContents(data, Util.deepCopy(options.template))
		end
		if type(data.version) ~= "number" then
			profile:EndSession()
			return "migration-failed", "saved data has no version"
		end
		if data.version > latest then
			profile:EndSession()
			return "too-new", `saved data is v{data.version} but this build knows v{latest}`
		end
		if data.version < latest then
			-- Migrate a copy, so a failure leaves the stored data exactly as it was.
			local copy = Util.deepCopy(data)
			local ok, err = Util.try(DataService.migrate, copy, options.migrations, latest)
			if not ok then
				profile:EndSession()
				log:error("migration failed", { userId = userId, err = err })
				return "migration-failed", tostring(err)
			end
			Util.replaceContents(data, copy)
		end
		Util.reconcile(data, options.template)

		if not profile:IsActive() then
			return "failed", "session ended while loading"
		end
		profiles[player] = profile
		return "loaded", nil
	end

	function service.isLoaded(_self: DataService, player: any): boolean
		local profile = profiles[player]
		return profile ~= nil and profile:IsActive()
	end

	-- Returns the live data table. Read it, never write to it: use `update`.
	function service.get(_self: DataService, player: any): { [string]: any }?
		local profile = profiles[player]
		if profile == nil or not profile:IsActive() then
			return nil
		end
		return profile.Data
	end

	function service.update(
		self: DataService,
		player: any,
		change: (data: { [string]: any }) -> ()
	): (boolean, string?)
		local data = self:get(player)
		if data == nil then
			return false, "data not loaded"
		end
		local copy = Util.deepCopy(data)
		local thread = coroutine.create(change)
		local ok, err = coroutine.resume(thread, copy)
		if not ok then
			return false, tostring(err)
		end
		if coroutine.status(thread) ~= "dead" then
			-- A yield inside `change` could interleave with another update and lose one of them.
			coroutine.close(thread)
			return false, "update callback yielded; do async work before calling update"
		end
		Util.replaceContents(data, copy)
		for _, listener in listeners do
			local fine, problem = Util.try(listener, player, data)
			if not fine then
				log:error("onChanged listener failed", { err = problem })
			end
		end
		return true, nil
	end

	function service.onChanged(_self: DataService, listener: (player: any, data: { [string]: any }) -> ())
		table.insert(listeners, listener)
	end

	function service.profile(_self: DataService, player: any): Profile?
		return profiles[player]
	end

	function service.release(_self: DataService, player: any)
		local profile = profiles[player]
		profiles[player] = nil
		if profile and profile:IsActive() then
			profile:EndSession()
		end
	end

	return (service :: any) :: DataService
end

return DataService
