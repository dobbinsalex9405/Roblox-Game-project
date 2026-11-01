--!strict
-- Runtime value checking, shared by Config (game numbers) and Net (remote arguments).
-- Every validator returns `true` or `false, "path: reason"`, and never throws.
-- Records reject unknown keys, so a typo in a config file or extra data from a
-- client is caught instead of ignored.

export type Validator = (value: any, path: string) -> (boolean, string?)

local Schema = {}

local function fail(path: string, message: string): (boolean, string?)
	return false, `{path}: {message}`
end

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Schema.any(): Validator
	return function(_value: any, _path: string)
		return true, nil
	end
end

function Schema.number(options: { min: number?, max: number?, integer: boolean? }?): Validator
	local min = options and options.min
	local max = options and options.max
	local integer = options and options.integer or false
	return function(value: any, path: string)
		if not isFiniteNumber(value) then
			return fail(path, `expected a finite number, got {typeof(value)} {tostring(value)}`)
		end
		if integer and value // 1 ~= value then
			return fail(path, `expected a whole number, got {value}`)
		end
		if min ~= nil and value < min then
			return fail(path, `must be at least {min}, got {value}`)
		end
		if max ~= nil and value > max then
			return fail(path, `must be at most {max}, got {value}`)
		end
		return true, nil
	end
end

function Schema.integer(options: { min: number?, max: number? }?): Validator
	return Schema.number({
		min = options and options.min,
		max = options and options.max,
		integer = true,
	})
end

function Schema.string(options: { minLength: number?, maxLength: number?, pattern: string? }?): Validator
	local minLength = options and options.minLength or 0
	local maxLength = options and options.maxLength
	local pattern = options and options.pattern
	return function(value: any, path: string)
		if type(value) ~= "string" then
			return fail(path, `expected a string, got {typeof(value)}`)
		end
		if #value < minLength then
			return fail(path, `must be at least {minLength} characters`)
		end
		if maxLength ~= nil and #value > maxLength then
			return fail(path, `must be at most {maxLength} characters, got {#value}`)
		end
		if pattern ~= nil and not string.match(value, pattern) then
			return fail(path, `does not match {pattern}`)
		end
		return true, nil
	end
end

function Schema.boolean(): Validator
	return function(value: any, path: string)
		if type(value) ~= "boolean" then
			return fail(path, `expected a boolean, got {typeof(value)}`)
		end
		return true, nil
	end
end

-- One of a fixed set of strings or numbers.
function Schema.oneOf(choices: { string | number }): Validator
	local allowed: { [any]: boolean } = {}
	for _, choice in choices do
		allowed[choice] = true
	end
	return function(value: any, path: string)
		if not allowed[value] then
			return fail(
				path,
				`must be one of {table.concat(choices :: { any }, ", ")}, got {tostring(value)}`
			)
		end
		return true, nil
	end
end

function Schema.optional(inner: Validator): Validator
	return function(value: any, path: string)
		if value == nil then
			return true, nil
		end
		return inner(value, path)
	end
end

-- A dense list (1..n with no gaps and no other keys).
function Schema.array(item: Validator, options: { minLength: number?, maxLength: number? }?): Validator
	local minLength = options and options.minLength or 0
	local maxLength = options and options.maxLength
	return function(value: any, path: string)
		if type(value) ~= "table" then
			return fail(path, `expected a list, got {typeof(value)}`)
		end
		local count = 0
		for key in value do
			count += 1
			if type(key) ~= "number" then
				return fail(path, `expected a list, found key {tostring(key)}`)
			end
		end
		if count ~= #value then
			return fail(path, "list has gaps")
		end
		if count < minLength then
			return fail(path, `needs at least {minLength} items, got {count}`)
		end
		if maxLength ~= nil and count > maxLength then
			return fail(path, `allows at most {maxLength} items, got {count}`)
		end
		for index, entry in value do
			local ok, err = item(entry, `{path}[{index}]`)
			if not ok then
				return false, err
			end
		end
		return true, nil
	end
end

-- A table with string keys that all share one value shape (for example creature id -> stats).
function Schema.map(key: Validator, item: Validator, options: { maxEntries: number? }?): Validator
	local maxEntries = options and options.maxEntries
	return function(value: any, path: string)
		if type(value) ~= "table" then
			return fail(path, `expected a table, got {typeof(value)}`)
		end
		local count = 0
		for k, v in value do
			count += 1
			local ok, err = key(k, `{path} key`)
			if not ok then
				return false, err
			end
			ok, err = item(v, `{path}.{tostring(k)}`)
			if not ok then
				return false, err
			end
		end
		if maxEntries ~= nil and count > maxEntries then
			return fail(path, `allows at most {maxEntries} entries, got {count}`)
		end
		return true, nil
	end
end

-- A table with a fixed set of named fields. Unknown keys are an error.
function Schema.record(fields: { [string]: Validator }): Validator
	return function(value: any, path: string)
		if type(value) ~= "table" then
			return fail(path, `expected a table, got {typeof(value)}`)
		end
		for k in value do
			if type(k) ~= "string" or fields[k] == nil then
				return fail(path, `unknown key {tostring(k)}`)
			end
		end
		for name, validator in fields do
			local ok, err = validator(value[name], `{path}.{name}`)
			if not ok then
				return false, err
			end
		end
		return true, nil
	end
end

-- Runs a custom rule after another validator passes.
function Schema.check(inner: Validator, rule: (value: any) -> (boolean, string?)): Validator
	return function(value: any, path: string)
		local ok, err = inner(value, path)
		if not ok then
			return false, err
		end
		local passed, why = rule(value)
		if not passed then
			return fail(path, why or "failed a custom check")
		end
		return true, nil
	end
end

-- Throws with the path and reason when the value does not match.
function Schema.assert(validator: Validator, value: any, path: string)
	local ok, err = validator(value, path)
	if not ok then
		error(err, 2)
	end
end

return Schema
