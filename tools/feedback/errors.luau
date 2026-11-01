--!strict
-- Reads the error queue (the "ErrorQueue" DataStore that
-- packages/core/src/ErrorReporter.luau writes, one batch per server per
-- minute at most) and turns it into the error sweep of ops/PUBLISH_CHECKS.md:
--
--   - any server error from a build: STOP (fix forward or roll back)
--   - a client error seen 10 or more times in the window: STOP as well
--   - other client errors: open an issue, keep going
--
-- Records are grouped by game, environment, build and signature, so one bug
-- hit on 300 servers is one line with its total count.

local Errors = {}

Errors.STORE = "ErrorQueue"
Errors.CLIENT_STOP_COUNT = 10

export type Record = {
	game: string,
	environment: string,
	build: string,
	server: string,
	at: number,
	signature: string,
	source: string,
	message: string,
	trace: string,
	count: number,
	firstSeen: number,
	lastSeen: number,
}

export type Verdict = "stop" | "issue"

export type Group = {
	game: string,
	environment: string,
	build: string,
	signature: string,
	source: string,
	message: string,
	where: string, -- first line of the trace
	count: number,
	servers: number,
	firstSeen: number,
	lastSeen: number,
	verdict: Verdict,
}

export type Sweep = {
	groups: { Group },
	dropped: number, -- distinct errors servers could not keep (over their per-batch cap)
	stop: boolean,
}

-- Player names can appear in error text ("Players.Name.Backpack"); the issue
-- never shows them.
function Errors.scrub(text: string): string
	local out = string.gsub(text, "Players%.[%w_]+", "Players.*")
	return out
end

-- The error records in one stored batch, or none (with a reason) when the
-- value is not an error batch. `server` comes from the DataStore key.
function Errors.from(batch: any, environment: string, server: string): ({ Record }, string?)
	if type(batch) ~= "table" or type(batch.errors) ~= "table" then
		return {}, "not an error batch"
	end
	local out: { Record } = {}
	for _, e in batch.errors do
		if type(e) == "table" and type(e.signature) == "string" and type(e.count) == "number" then
			table.insert(out, {
				game = tostring(batch.game or "?"),
				environment = environment,
				build = tostring(batch.build or "?"),
				server = server,
				at = tonumber(batch.at) or 0,
				signature = e.signature,
				source = if e.source == "server" then "server" else "client",
				message = tostring(e.message or ""),
				trace = tostring(e.trace or ""),
				count = math.max(0, math.floor(e.count)),
				firstSeen = tonumber(e.firstSeen) or 0,
				lastSeen = tonumber(e.lastSeen) or 0,
			})
		end
	end
	return out, nil
end

-- Which server wrote a batch, from its key "YYYYMMDD-HHMMSS-<server>-<n>".
function Errors.serverFromKey(key: string): string
	return string.match(key, "^%d+%-%d+%-([^%-]+)%-%d+$") or key
end

-- Groups records (optionally only builds starting with `build`) into the sweep.
function Errors.sweep(records: { Record }, build: string?, dropped: number?): Sweep
	local groups: { [string]: Group } = {}
	local servers: { [string]: { [string]: boolean } } = {}
	local order: { string } = {}
	for _, r in records do
		if build == nil or build == "" or string.sub(r.build, 1, #build) == build then
			local key = `{r.game}|{r.environment}|{r.build}|{r.signature}`
			local g = groups[key]
			if g == nil then
				g = {
					game = r.game,
					environment = r.environment,
					build = r.build,
					signature = r.signature,
					source = r.source,
					message = Errors.scrub(r.message),
					where = Errors.scrub(string.match(r.trace, "[^\n]+") or ""),
					count = 0,
					servers = 0,
					firstSeen = r.firstSeen,
					lastSeen = r.lastSeen,
					verdict = "issue",
				}
				groups[key] = g
				servers[key] = {}
				table.insert(order, key)
			end
			local group = g :: Group
			group.count += r.count
			if not servers[key][r.server] then
				servers[key][r.server] = true
				group.servers += 1
			end
			group.firstSeen = math.min(group.firstSeen, r.firstSeen)
			group.lastSeen = math.max(group.lastSeen, r.lastSeen)
		end
	end
	local list: { Group } = {}
	local stop = false
	for _, key in order do
		local g = groups[key]
		if g.source == "server" or g.count >= Errors.CLIENT_STOP_COUNT then
			g.verdict = "stop"
			stop = true
		end
		table.insert(list, g)
	end
	table.sort(list, function(a, b)
		if a.verdict ~= b.verdict then
			return a.verdict == "stop"
		end
		if a.source ~= b.source then
			return a.source == "server"
		end
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.signature < b.signature
	end)
	return { groups = list, dropped = dropped or 0, stop = stop }
end

local function short(build: string): string
	return string.sub(build, 1, 7)
end

-- The "Errors" section of the issue. `escape` is tools/feedback/lib's escape.
function Errors.markdown(sweep: Sweep, escape: (string) -> string): string
	local out = { "## Errors", "" }
	if #sweep.groups == 0 then
		table.insert(out, "No server or client errors in this window.")
	else
		local stops = 0
		for _, g in sweep.groups do
			if g.verdict == "stop" then
				stops += 1
			end
		end
		if sweep.stop then
			table.insert(
				out,
				`**STOP: {stops} error group(s) need action before any promotion**`
					.. " (a server error, or a client error seen 10+ times). See ops/PUBLISH_CHECKS.md step 3."
			)
		else
			table.insert(out, "Only client errors seen fewer than 10 times: open issues, keep going.")
		end
		table.insert(out, "")
		for _, g in sweep.groups do
			local mark = if g.verdict == "stop" then "**STOP**" else "issue"
			table.insert(
				out,
				`- {mark} {g.game} {g.environment} · build {short(g.build)} · {g.source} · \`{g.signature}\``
					.. ` · {g.count}× on {g.servers} server{if g.servers == 1 then "" else "s"}`
					.. ` · {os.date("!%m-%d %H:%M", g.firstSeen)} to {os.date("!%m-%d %H:%M", g.lastSeen)} UTC`
			)
			table.insert(out, `  > {escape(g.message)}`)
			if g.where ~= "" then
				table.insert(out, `  - at {escape(g.where)}`)
			end
		end
	end
	if sweep.dropped > 0 then
		table.insert(out, "")
		table.insert(
			out,
			`_{sweep.dropped} distinct errors were dropped by servers over their per-batch cap; expect more than listed._`
		)
	end
	return table.concat(out, "\n") .. "\n"
end

-- Entries for the machine-readable block: no message text, only ids and counts.
function Errors.blockEntries(sweep: Sweep): { { [string]: any } }
	local out = {}
	for _, g in sweep.groups do
		table.insert(out, {
			game = g.game,
			environment = g.environment,
			build = g.build,
			signature = g.signature,
			source = g.source,
			count = g.count,
			servers = g.servers,
			verdict = g.verdict,
		})
	end
	return out
end

return Errors
