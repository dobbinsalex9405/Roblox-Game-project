--!strict
-- What every client view shares: config, the player's latest data, the dive
-- state the server last sent, the server clock and remotes. The server owns
-- all of it; the client only reads and asks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CoreClient = require(ReplicatedStorage.CoreClient.CoreClient)
local ClientNet = require(ReplicatedStorage.CoreClient.ClientNet)
local Net = require(ReplicatedStorage.Core.Net)
local Schema = require(ReplicatedStorage.Core.Schema)
local Shared = ReplicatedStorage.Shared
local Gear = require(Shared.Gear)
local Lamp = require(Shared.Lamp)
local Layout = require(Shared.Layout)
local Remotes = require(Shared.Remotes)(Net, Schema)

local GameConfig = ReplicatedStorage.GameConfig

export type Dive = {
	phase: string, -- "Camp" | "Diving" | "Climbing"
	meter: Lamp.Meter,
	capacity: number,
	climbEndsAt: number,
}

export type Context = {
	player: Player,
	config: { mine: any, blocks: { [string]: any }, gear: any, dive: any },
	remotes: { [string]: Net.Remote },
	data: () -> { [string]: any }?,
	onData: (listener: (data: { [string]: any }) -> ()) -> (),
	dive: () -> Dive,
	serverNow: () -> number,
	perks: () -> Gear.Perks,
	position: () -> Layout.Point?,
	fire: (remote: Net.Remote, ...any) -> (),
	on: (remote: Net.Remote, handler: (...any) -> ()) -> (),
}

local Context = {}

function Context.new(): Context
	local player = Players.LocalPlayer
	local config = {
		mine = require(GameConfig.mine) :: any,
		blocks = require(GameConfig.blocks) :: any,
		gear = require(GameConfig.gear) :: any,
		dive = require(GameConfig.dive) :: any,
	}
	local current: Dive = {
		phase = "Camp",
		meter = { oil = config.gear.lamp[1].oilSeconds, rate = 0, at = 0 },
		capacity = config.gear.lamp[1].oilSeconds,
		climbEndsAt = 0,
	}

	ClientNet.on(
		Remotes["DB:Dive"],
		function(phase: string, oil: number, rate: number, at: number, capacity: number, climbEndsAt: number)
			current = {
				phase = phase,
				meter = { oil = oil, rate = rate, at = at },
				capacity = capacity,
				climbEndsAt = climbEndsAt,
			}
		end
	)

	return {
		player = player,
		config = config,
		remotes = Remotes,
		data = CoreClient.data,
		onData = CoreClient.onData,
		dive = function()
			return current
		end,
		serverNow = function()
			return Workspace:GetServerTimeNow()
		end,
		perks = function()
			return {
				biggerPack = CoreClient.ownsPass("BiggerPack"),
				betterLamp = CoreClient.ownsPass("BetterLamp"),
				autoSell = CoreClient.ownsPass("AutoSell"),
			}
		end,
		position = function(): Layout.Point?
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local p = root.Position
				return { x = p.X, y = p.Y, z = p.Z }
			end
			return nil
		end,
		fire = ClientNet.fire,
		on = function(remote: Net.Remote, handler: (...any) -> ())
			ClientNet.on(remote, handler)
		end,
	}
end

return Context
