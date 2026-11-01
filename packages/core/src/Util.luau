--!strict
-- Small table helpers used across the core.

local Util = {}

function Util.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value :: any do
		out[Util.deepCopy(k)] = Util.deepCopy(v)
	end
	return (out :: any) :: T
end

-- Returns a frozen deep copy, so callers cannot change shared config by accident.
function Util.deepFreeze<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value :: any do
		out[k] = Util.deepFreeze(v)
	end
	return (table.freeze(out) :: any) :: T
end

-- Fills keys missing from `target` with copies from `template`, recursing into
-- tables that exist on both sides. Never overwrites or removes a value.
function Util.reconcile(target: { [any]: any }, template: { [any]: any })
	for k, v in template do
		if target[k] == nil then
			target[k] = Util.deepCopy(v)
		elseif type(target[k]) == "table" and type(v) == "table" and #v == 0 and next(v) ~= nil then
			-- Only recurse into record-like tables; lists in the template are defaults, not shapes.
			Util.reconcile(target[k], v)
		end
	end
end

-- Replaces the contents of `target` with the contents of `source`, keeping the
-- `target` table identity (ProfileStore holds a reference to it).
function Util.replaceContents(target: { [any]: any }, source: { [any]: any })
	for k in target do
		target[k] = nil
	end
	for k, v in source do
		target[k] = v
	end
end

function Util.keys(t: { [any]: any }): { any }
	local out = {}
	for k in t do
		table.insert(out, k)
	end
	return out
end

-- pcall that always returns (ok, message). Plain pcall on a function that
-- returns nothing is typed as returning one value, which strict mode rejects
-- at `local ok, err = pcall(...)`.
function Util.try(fn: (...any) -> ...any, ...: any): (boolean, string?)
	local ok, err = pcall(fn, ...)
	if ok then
		return true, nil
	end
	return false, tostring(err)
end

-- Short, stable hash (djb2, 32 bit) as 8 hex characters. Not cryptographic.
function Util.hash(text: string): string
	local h = 5381
	for i = 1, #text do
		h = (h * 33 + string.byte(text, i)) % 4294967296
	end
	return string.format("%08x", h)
end

return Util
