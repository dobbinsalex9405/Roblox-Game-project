--!strict
-- Connects DataService to ProfileStore (session-locked DataStore saving), and
-- provides the "save now and confirm" step Receipts needs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DataService = require(ReplicatedStorage.Core.DataService)
local ProfileStore = require(ServerStorage.ServerPackages.ProfileStore) :: any

-- How long Receipts waits for a confirmed save before telling Roblox to retry later.
local SAVE_TIMEOUT = 15

local ProfileStoreAdapter = {}

-- `onSessionEnd` runs when another server takes the session or it ends for any
-- other reason, so the caller can remove the player before their data goes stale.
function ProfileStoreAdapter.store(storeName: string, onSessionEnd: (player: Player) -> ()): DataService.Store
	-- An empty template: DataService fills new players from the game's own template.
	local store = ProfileStore.New(storeName, {})

	return {
		startSession = function(key: string, player: Player): DataService.Profile?
			local profile = store:StartSessionAsync(key, {
				Cancel = function()
					return player.Parent ~= Players
				end,
			})
			if profile == nil then
				return nil
			end
			profile:AddUserId(player.UserId) -- GDPR: links the save to the user for deletion requests
			profile.OnSessionEnd:Connect(function()
				onSessionEnd(player)
			end)
			if player.Parent ~= Players then
				profile:EndSession()
				return nil
			end
			return profile :: DataService.Profile
		end,
	}
end

-- Saves now and waits until a save containing `purchaseId` in `field` lands.
function ProfileStoreAdapter.persist(
	data: DataService.DataService,
	player: Player,
	purchaseId: string,
	field: string
): boolean
	local profile = data:profile(player) :: any
	if profile == nil or not profile:IsActive() then
		return false
	end

	local thread = coroutine.running()
	local done = false
	local result = false
	local connections: { RBXScriptConnection } = {}

	local function finish(value: boolean)
		if done then
			return
		end
		done = true
		result = value
		for _, connection in connections do
			connection:Disconnect()
		end
		if coroutine.status(thread) == "suspended" then
			task.spawn(thread)
		end
	end

	table.insert(
		connections,
		profile.OnAfterSave:Connect(function(saved: { [string]: any })
			local list = saved[field]
			if type(list) == "table" and table.find(list, purchaseId) then
				finish(true)
			end
		end)
	)
	table.insert(
		connections,
		profile.OnSessionEnd:Connect(function()
			-- The final save may or may not include the purchase; Roblox retries and
			-- the next server sees the id if it landed.
			finish(false)
		end)
	)
	task.delay(SAVE_TIMEOUT, finish, false)

	profile:Save()
	if not done then
		coroutine.yield()
	end
	return result
end

return ProfileStoreAdapter
