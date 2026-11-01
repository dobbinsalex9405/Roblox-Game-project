--!strict
-- What every client view shares: config, the player's own plot, their latest
-- data, the server clock and remotes. The server owns all of it; the client
-- only reads and asks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CoreClient = require(ReplicatedStorage.CoreClient.CoreClient)
local ClientNet = require(ReplicatedStorage.CoreClient.ClientNet)
local Net = require(ReplicatedStorage.Core.Net)
local Schema = require(ReplicatedStorage.Core.Schema)
local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)(Net, Schema)
local Restaurant = require(Shared.Restaurant)

local GameConfig = ReplicatedStorage.GameConfig

export type Context = {
	player: Player,
	config: Restaurant.Config,
	remotes: { [string]: Net.Remote },
	plot: () -> (Model?, number?), -- the player's own plot, once assigned
	data: () -> { [string]: any }?,
	onData: (listener: (data: { [string]: any }) -> ()) -> (),
	serverNow: () -> number,
	perks: () -> Restaurant.Perks,
	autoCollect: () -> boolean,
	fire: (remote: Net.Remote, ...any) -> (),
	on: (remote: Net.Remote, handler: (...any) -> ()) -> (),
}

local Context = {}

function Context.new(): Context
	local player = Players.LocalPlayer
	local plotsFolder = Workspace:WaitForChild("Plots")

	local function plot(): (Model?, number?)
		for _, model in plotsFolder:GetChildren() do
			if model:IsA("Model") and model:GetAttribute("OwnerUserId") == player.UserId then
				return model, model:GetAttribute("PlotIndex") :: number
			end
		end
		return nil, nil
	end

	return {
		player = player,
		config = {
			economy = require(GameConfig.economy) :: any,
			districts = require(GameConfig.districts) :: any,
			stations = require(GameConfig.stations) :: any,
			cooks = require(GameConfig.cooks) :: any,
			monetization = require(GameConfig.monetization) :: any,
		},
		remotes = Remotes,
		plot = plot,
		data = CoreClient.data,
		onData = CoreClient.onData,
		serverNow = function()
			return Workspace:GetServerTimeNow()
		end,
		perks = function()
			return { doubleCash = CoreClient.ownsPass("DoubleCash") }
		end,
		autoCollect = function()
			return CoreClient.ownsPass("AutoCollect")
		end,
		fire = ClientNet.fire,
		on = function(remote: Net.Remote, handler: (...any) -> ())
			ClientNet.on(remote, handler)
		end,
	}
end

return Context
