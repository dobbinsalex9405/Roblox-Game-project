--!strict
-- Module 2: Net.
-- The only way client and server talk. Each remote is declared once in a
-- shared module with an argument schema (and, for client-to-server remotes, a
-- per-player rate limit). The server dispatcher drops and counts anything that
-- does not match: unknown names, wrong types, extra arguments and floods never
-- reach game code.
--
-- This file is pure logic. The Roblox transport (RemoteEvents) lives in
-- packages/core/server/ServerNet.luau and packages/core/client/ClientNet.luau.

local Log = require("./Log")
local RateLimiter = require("./RateLimiter")
local Schema = require("./Schema")

export type Direction = "toServer" | "toClient"

export type Limit = { count: number, window: number }

export type Remote = {
	name: string,
	direction: Direction,
	args: { Schema.Validator },
	limit: Limit,
}

export type DropReason = "unknown" | "wrong-direction" | "rate" | "schema" | "no-handler" | "error"
export type DispatchResult = "ok" | DropReason

export type Handler = (player: any, ...any) -> ()

export type ServerOptions = {
	now: () -> number,
	onDrop: ((player: any, remoteName: string, reason: DropReason, detail: string?) -> ())?,
}

export type Server = {
	register: (self: Server, remotes: { [string]: Remote }) -> (),
	on: (self: Server, remote: Remote, handler: Handler) -> (),
	dispatch: (self: Server, player: any, name: string, ...any) -> DispatchResult,
	remotes: (self: Server) -> { Remote },
	drops: (self: Server, player: any) -> number,
	forget: (self: Server, player: any) -> (),
}

local DEFAULT_LIMIT: Limit = table.freeze({ count = 10, window = 1 })
local NAME_PATTERN = "^[%a][%w_:]*$"

local log = Log.new("Net")

local Net = {}

local function make(name: string, direction: Direction, args: { Schema.Validator }, limit: Limit?): Remote
	assert(
		type(name) == "string" and string.match(name, NAME_PATTERN),
		`invalid remote name {tostring(name)}`
	)
	assert(#name <= 50, `remote name too long: {name}`)
	assert(type(args) == "table", `remote {name} needs an argument list (use an empty table for none)`)
	local chosen = limit or DEFAULT_LIMIT
	assert(chosen.count >= 1 and chosen.window > 0, `remote {name} has an invalid limit`)
	return table.freeze({
		name = name,
		direction = direction,
		args = table.freeze(table.clone(args)),
		limit = table.freeze(table.clone(chosen)),
	})
end

-- A remote the client fires and the server handles. `limit` defaults to 10 calls per second.
function Net.toServer(name: string, args: { Schema.Validator }, limit: Limit?): Remote
	return make(name, "toServer", args, limit)
end

-- A remote the server fires to one or all clients.
function Net.toClient(name: string, args: { Schema.Validator }): Remote
	return make(name, "toClient", args, nil)
end

-- Checks an argument pack against a remote's schema. Extra arguments are an error.
function Net.validate(remote: Remote, count: number, args: { any }): (boolean, string?)
	if count > #remote.args then
		return false, `expected at most {#remote.args} arguments, got {count}`
	end
	for index, validator in remote.args do
		local ok, err = validator(args[index], `{remote.name} arg {index}`)
		if not ok then
			return false, err
		end
	end
	return true, nil
end

function Net.newServer(options: ServerOptions): Server
	local byName: { [string]: Remote } = {}
	local limiters: { [string]: RateLimiter.RateLimiter } = {}
	local handlers: { [string]: Handler } = {}
	local dropCounts: { [any]: number } = {}

	local server = {}

	local function drop(player: any, name: string, reason: DropReason, detail: string?): DispatchResult
		dropCounts[player] = (dropCounts[player] or 0) + 1
		if options.onDrop then
			options.onDrop(player, name, reason, detail)
		end
		return reason
	end

	function server.register(_self: Server, remotes: { [string]: Remote })
		for key, remote in remotes do
			assert(key == remote.name, `remote registered as {key} but named {remote.name}`)
			assert(byName[remote.name] == nil, `remote {remote.name} registered twice`)
			byName[remote.name] = remote
			if remote.direction == "toServer" then
				limiters[remote.name] = RateLimiter.new(remote.limit.count, remote.limit.window)
			end
		end
	end

	function server.on(_self: Server, remote: Remote, handler: Handler)
		assert(byName[remote.name] == remote, `remote {remote.name} is not registered`)
		assert(remote.direction == "toServer", `remote {remote.name} is server-to-client`)
		assert(handlers[remote.name] == nil, `remote {remote.name} already has a handler`)
		handlers[remote.name] = handler
	end

	function server.dispatch(_self: Server, player: any, name: any, ...: any): DispatchResult
		if type(name) ~= "string" then
			return drop(player, tostring(name), "unknown", nil)
		end
		local remote = byName[name]
		if remote == nil then
			return drop(player, name, "unknown", nil)
		end
		if remote.direction ~= "toServer" then
			return drop(player, name, "wrong-direction", nil)
		end
		-- Rate-limit before validating, so a flood of bad packets is cheap to reject.
		if not limiters[name]:allow(player, options.now()) then
			return drop(player, name, "rate", nil)
		end
		local count = select("#", ...)
		local args = { ... }
		local ok, err = Net.validate(remote, count, args)
		if not ok then
			return drop(player, name, "schema", err)
		end
		local handler = handlers[name]
		if handler == nil then
			return drop(player, name, "no-handler", nil)
		end
		local success, problem = pcall(handler, player, table.unpack(args, 1, #remote.args))
		if not success then
			log:error("handler failed", { remote = name, err = problem })
			return drop(player, name, "error", tostring(problem))
		end
		return "ok"
	end

	function server.remotes(_self: Server): { Remote }
		local list = {}
		for _, remote in byName do
			table.insert(list, remote)
		end
		table.sort(list, function(a, b)
			return a.name < b.name
		end)
		return list
	end

	function server.drops(_self: Server, player: any): number
		return dropCounts[player] or 0
	end

	function server.forget(_self: Server, player: any)
		dropCounts[player] = nil
		for _, limiter in limiters do
			limiter:forget(player)
		end
	end

	return (server :: any) :: Server
end

return Net
