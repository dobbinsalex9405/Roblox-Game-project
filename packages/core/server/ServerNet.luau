--!strict
-- Roblox transport for Net: one RemoteEvent per declared remote, in
-- ReplicatedStorage.CoreNet. Every incoming call goes through the pure
-- dispatcher (schema, rate limit, drop counting) before game code sees it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Core.Log)
local Net = require(ReplicatedStorage.Core.Net)

-- Drops per player per session before we flag the player in the logs as a likely exploiter.
local SUSPICIOUS_DROPS = 200

export type ServerNet = {
	dispatcher: Net.Server,
	on: (self: ServerNet, remote: Net.Remote, handler: Net.Handler) -> (),
	fire: (self: ServerNet, remote: Net.Remote, player: Player, ...any) -> (),
	fireAll: (self: ServerNet, remote: Net.Remote, ...any) -> (),
}

local log = Log.new("ServerNet")

local ServerNet = {}

function ServerNet.start(remoteSets: { { [string]: Net.Remote } }): ServerNet
	local flagged: { [Player]: boolean } = {}
	local dispatcher: Net.Server
	dispatcher = Net.newServer({
		now = os.clock,
		onDrop = function(player: Player, name: string, reason: Net.DropReason, detail: string?)
			if reason == "error" or reason == "no-handler" then
				return -- already logged by the dispatcher, or a game wiring bug logged below
			end
			if not flagged[player] and dispatcher:drops(player) >= SUSPICIOUS_DROPS then
				flagged[player] = true
				log:warn("many dropped remote calls; possible exploiter", {
					userId = player.UserId,
					remote = name,
					reason = reason,
					detail = detail,
				})
			end
		end,
	})

	local folder = Instance.new("Folder")
	folder.Name = "CoreNet"
	local events: { [string]: RemoteEvent } = {}

	for _, set in remoteSets do
		dispatcher:register(set)
		for name, remote in set do
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
			events[name] = event
			if remote.direction == "toServer" then
				event.OnServerEvent:Connect(function(player: Player, ...: any)
					dispatcher:dispatch(player, name, ...)
				end)
			end
		end
	end
	folder.Parent = ReplicatedStorage

	Players.PlayerRemoving:Connect(function(player: Player)
		dispatcher:forget(player)
		flagged[player] = nil
	end)

	local net = { dispatcher = dispatcher }

	function net.on(_self: ServerNet, remote: Net.Remote, handler: Net.Handler)
		dispatcher:on(remote, handler)
	end

	local function checkOutgoing(remote: Net.Remote, ...: any)
		assert(remote.direction == "toClient", `{remote.name} is client-to-server`)
		local ok, err = Net.validate(remote, select("#", ...), { ... })
		assert(ok, err)
	end

	function net.fire(_self: ServerNet, remote: Net.Remote, player: Player, ...: any)
		checkOutgoing(remote, ...)
		events[remote.name]:FireClient(player, ...)
	end

	function net.fireAll(_self: ServerNet, remote: Net.Remote, ...: any)
		checkOutgoing(remote, ...)
		events[remote.name]:FireAllClients(...)
	end

	return (net :: any) :: ServerNet
end

return ServerNet
