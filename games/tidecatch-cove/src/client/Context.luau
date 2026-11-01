--!strict
-- What every client view shares: config, the player's own cove, their latest
-- data, the server clock, the bait they have picked and remotes. The server
-- owns all of it but the bait choice; the client only reads and asks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CoreClient = require(ReplicatedStorage.CoreClient.CoreClient)
local ClientNet = require(ReplicatedStorage.CoreClient.ClientNet)
local Net = require(ReplicatedStorage.Core.Net)
local Schema = require(ReplicatedStorage.Core.Schema)
local Shared = ReplicatedStorage.Shared
local Catch = require(Shared.Catch)
local Cove = require(Shared.Cove)
local Remotes = require(Shared.Remotes)(Net, Schema)

local GameConfig = ReplicatedStorage.GameConfig

export type Context = {
	player: Player,
	config: Cove.Config,
	remotes: { [string]: Net.Remote },
	cove: () -> (Model?, number?), -- the player's own cove, once assigned
	data: () -> { [string]: any }?,
	onData: (listener: (data: { [string]: any }) -> ()) -> (),
	serverNow: () -> number,
	perks: () -> Cove.Perks,
	restricted: () -> boolean, -- paid random items restricted for this player
	bait: () -> string, -- the bait picked for the next cast ("None" = no bait)
	setBait: (baitId: string) -> (),
	onBait: (listener: (baitId: string) -> ()) -> (),
	fire: (remote: Net.Remote, ...any) -> (),
	on: (remote: Net.Remote, handler: (...any) -> ()) -> (),
}

local Context = {}

function Context.new(): Context
	local player = Players.LocalPlayer
	local map = Workspace:WaitForChild("Map")
	local covesFolder = map:WaitForChild("Coves")
	local config: Cove.Config = {
		species = require(GameConfig.species) :: any,
		fishing = require(GameConfig.fishing) :: any,
		pools = require(GameConfig.pools) :: any,
		economy = require(GameConfig.economy) :: any,
		monetization = require(GameConfig.monetization) :: any,
	}

	local function cove(): (Model?, number?)
		for _, model in covesFolder:GetChildren() do
			if model:IsA("Model") and model:GetAttribute("OwnerUserId") == player.UserId then
				return model, model:GetAttribute("CoveIndex") :: number
			end
		end
		return nil, nil
	end

	local selected = Catch.NO_BAIT
	local baitListeners: { (string) -> () } = {}

	return {
		player = player,
		config = config,
		remotes = Remotes,
		cove = cove,
		data = CoreClient.data,
		onData = CoreClient.onData,
		serverNow = function()
			return Workspace:GetServerTimeNow()
		end,
		perks = function()
			return {
				autoReel = CoreClient.ownsPass("AutoReel"),
				extraPools = CoreClient.ownsPass("ExtraPools"),
				sellMultiplier = CoreClient.ownsPass("SellMultiplier"),
			}
		end,
		restricted = function()
			return player:GetAttribute("PaidRandomRestricted") == true
		end,
		bait = function()
			return selected
		end,
		setBait = function(baitId: string)
			if baitId ~= selected then
				selected = baitId
				for _, listener in baitListeners do
					task.spawn(listener, baitId)
				end
			end
		end,
		onBait = function(listener: (string) -> ())
			table.insert(baitListeners, listener)
		end,
		fire = ClientNet.fire,
		on = function(remote: Net.Remote, handler: (...any) -> ())
			ClientNet.on(remote, handler)
		end,
	}
end

return Context
