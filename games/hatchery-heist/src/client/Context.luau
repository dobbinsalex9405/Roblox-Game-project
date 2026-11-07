--!strict
-- What every client view shares: config, the player's own base, their latest
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
local Eggs = require(Shared.Eggs)
local Hatchery = require(Shared.Hatchery)
local Remotes = require(Shared.Remotes)(Net, Schema)

local GameConfig = ReplicatedStorage.GameConfig

export type Context = {
	player: Player,
	config: { economy: any, creatures: any, eggs: { any }, raids: any, charms: any },
	remotes: { [string]: Net.Remote },
	plot: () -> (Model?, number?), -- the player's own base, once assigned
	plotIndexOf: (model: Instance) -> number?,
	data: () -> { [string]: any }?,
	onData: (listener: (data: { [string]: any }) -> ()) -> (),
	serverNow: () -> number,
	perks: () -> Hatchery.Perks,
	autoCollect: () -> boolean,
	restricted: () -> boolean, -- paid random items restricted: show the fixed order instead of odds
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
			creatures = require(GameConfig.creatures) :: any,
			eggs = Eggs.expand(
				require(GameConfig.eggs) :: any,
				(require(GameConfig.creatures) :: any).species
			),
			raids = require(GameConfig.raids) :: any,
			charms = require(GameConfig.charms) :: any,
		},
		remotes = Remotes,
		plot = plot,
		plotIndexOf = function(model: Instance): number?
			local index = model:GetAttribute("PlotIndex")
			return if type(index) == "number" then index else nil
		end,
		data = CoreClient.data,
		onData = CoreClient.onData,
		serverNow = function()
			return Workspace:GetServerTimeNow()
		end,
		perks = function()
			return {
				doubleCoins = CoreClient.ownsPass("DoubleCoins"),
				extraIncubators = CoreClient.ownsPass("ExtraIncubators"),
			}
		end,
		autoCollect = function()
			return CoreClient.ownsPass("AutoCollect")
		end,
		restricted = function()
			return player:GetAttribute("PaidRandomRestricted") == true
		end,
		fire = ClientNet.fire,
		on = function(remote: Net.Remote, handler: (...any) -> ())
			ClientNet.on(remote, handler)
		end,
	}
end

return Context
