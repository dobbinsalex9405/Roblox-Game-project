--!strict
-- Structured log lines. Every line is one `print`/`warn` with a scope and key=value
-- fields, so server logs stay greppable. Tests swap the sink to capture lines.

export type Level = "info" | "warn" | "error"
export type Fields = { [string]: any }
export type Sink = (level: Level, scope: string, message: string, fields: Fields?) -> ()

export type Logger = {
	info: (self: Logger, message: string, fields: Fields?) -> (),
	warn: (self: Logger, message: string, fields: Fields?) -> (),
	error: (self: Logger, message: string, fields: Fields?) -> (),
}

local Log = {}

local function format(scope: string, message: string, fields: Fields?): string
	local parts = { `[{scope}] {message}` }
	if fields then
		local keys = {}
		for k in fields do
			table.insert(keys, k)
		end
		table.sort(keys)
		for _, k in keys do
			table.insert(parts, `{k}={tostring(fields[k])}`)
		end
	end
	return table.concat(parts, " ")
end

local function defaultSink(level: Level, scope: string, message: string, fields: Fields?)
	local line = format(scope, message, fields)
	if level == "info" then
		print(line)
	else
		-- `error` level must never throw: logging an error is not raising one.
		warn(line)
	end
end

local currentSink: Sink = defaultSink

function Log.setSink(sink: Sink?)
	currentSink = sink or defaultSink
end

Log.format = format

function Log.new(scope: string): Logger
	local logger = {}
	function logger.info(_self: Logger, message: string, fields: Fields?)
		currentSink("info", scope, message, fields)
	end
	function logger.warn(_self: Logger, message: string, fields: Fields?)
		currentSink("warn", scope, message, fields)
	end
	function logger.error(_self: Logger, message: string, fields: Fields?)
		currentSink("error", scope, message, fields)
	end
	return (logger :: any) :: Logger
end

return Log
