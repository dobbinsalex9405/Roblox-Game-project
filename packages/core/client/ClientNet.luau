--!strict
-- Client side of Net: fire declared remotes at the server and listen to
-- server-to-client remotes. The server re-checks everything, so this side only
-- guards against our own bugs (wrong remote direction).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Core.Net)

local ClientNet = {}

local folder: Folder? = nil

local function event(remote: Net.Remote): RemoteEvent
	if folder == nil then
		folder = ReplicatedStorage:WaitForChild("CoreNet") :: Folder
	end
	return (folder :: Folder):WaitForChild(remote.name) :: RemoteEvent
end

function ClientNet.fire(remote: Net.Remote, ...: any)
	assert(remote.direction == "toServer", `{remote.name} is server-to-client`)
	event(remote):FireServer(...)
end

function ClientNet.on(remote: Net.Remote, handler: (...any) -> ()): RBXScriptConnection
	assert(remote.direction == "toClient", `{remote.name} is client-to-server`)
	return event(remote).OnClientEvent:Connect(handler)
end

return ClientNet
