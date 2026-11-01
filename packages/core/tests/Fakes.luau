--!strict
-- Test doubles for the Roblox pieces the core depends on.

local DataService = require("@core/DataService")

local Fakes = {}

export type FakeProfile = DataService.Profile & {
	active: boolean,
	ended: number,
}

export type FakeStore = DataService.Store & {
	saved: { [string]: { [string]: any } },
	profiles: { [string]: FakeProfile },
	failNext: boolean,
	locked: { [string]: boolean },
}

-- An in-memory, session-locked store with the same contract as ProfileStore:
-- one live session per key, data persisted when the session ends.
function Fakes.store(seed: { [string]: { [string]: any } }?): FakeStore
	local store = {
		saved = seed or {},
		profiles = {},
		failNext = false,
		locked = {},
	}
	function store.startSession(key: string, _player: any): DataService.Profile?
		if store.failNext then
			store.failNext = false
			return nil
		end
		if store.locked[key] then
			return nil
		end
		store.locked[key] = true
		local profile = {
			Data = table.clone(store.saved[key] or {}),
			active = true,
			ended = 0,
		}
		function profile.IsActive(self: any): boolean
			return self.active
		end
		function profile.EndSession(self: any)
			if self.active then
				self.active = false
				self.ended += 1
				store.saved[key] = self.Data
				store.locked[key] = nil
			end
		end
		store.profiles[key] = profile :: any
		return profile :: any
	end
	return (store :: any) :: FakeStore
end

-- A stand-in Player.
function Fakes.player(userId: number): { UserId: number, Name: string }
	return { UserId = userId, Name = `Player{userId}` }
end

-- A deterministic clock you can move by hand.
function Fakes.clock(start: number?): { now: () -> number, advance: (seconds: number) -> () }
	local t = start or 1000
	return {
		now = function()
			return t
		end,
		advance = function(seconds: number)
			t += seconds
		end,
	}
end

return Fakes
