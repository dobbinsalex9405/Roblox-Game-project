--!strict
-- Minimal test library for Lune. Spec files call `describe`/`it`/`expect`
-- and return nothing; the runner in tools/test/run.luau collects results.

export type TestResult = {
	name: string,
	ok: boolean,
	err: string?,
}

local lib = {}

local results: { TestResult } = {}
local prefix: { string } = {}

local function fullName(name: string): string
	local parts = table.clone(prefix)
	table.insert(parts, name)
	return table.concat(parts, " > ")
end

function lib.describe(name: string, body: () -> ())
	table.insert(prefix, name)
	local ok, err = pcall(body)
	table.remove(prefix)
	if not ok then
		table.insert(
			results,
			{ name = fullName(name .. " (describe body)"), ok = false, err = tostring(err) }
		)
	end
end

function lib.it(name: string, body: () -> ())
	local ok, err = xpcall(body, function(e)
		return debug.traceback(tostring(e), 2)
	end)
	table.insert(results, { name = fullName(name), ok = ok, err = if ok then nil else tostring(err) })
end

function lib.takeResults(): { TestResult }
	local out = results
	results = {}
	return out
end

local function show(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	elseif type(value) == "table" then
		local parts = {}
		local count = 0
		for k, v in value do
			count += 1
			if count > 12 then
				table.insert(parts, "...")
				break
			end
			table.insert(parts, `{show(k)}={show(v)}`)
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(value)
end

local function deepEqual(a: any, b: any): (boolean, string?)
	if a == b then
		return true, nil
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false, `{show(a)} ~= {show(b)}`
	end
	for k, v in a do
		local ok, why = deepEqual(v, b[k])
		if not ok then
			return false, `at key {show(k)}: {why}`
		end
	end
	for k in b do
		if a[k] == nil then
			return false, `at key {show(k)}: missing on the left`
		end
	end
	return true, nil
end

export type Expectation = {
	toBe: (expected: any) -> (),
	toEqual: (expected: any) -> (),
	toBeNil: () -> (),
	toBeTruthy: () -> (),
	toBeFalsy: () -> (),
	toBeCloseTo: (expected: number, tolerance: number) -> (),
	toBeAtLeast: (expected: number) -> (),
	toBeAtMost: (expected: number) -> (),
	toThrow: (fragment: string?) -> (),
	toContain: (fragment: string) -> (),
}

function lib.expect(actual: any): Expectation
	local e = {}

	function e.toBe(expected: any)
		if actual ~= expected then
			error(`expected {show(expected)}, got {show(actual)}`, 2)
		end
	end

	function e.toEqual(expected: any)
		local ok, why = deepEqual(actual, expected)
		if not ok then
			error(`values differ: {why}`, 2)
		end
	end

	function e.toBeNil()
		if actual ~= nil then
			error(`expected nil, got {show(actual)}`, 2)
		end
	end

	function e.toBeTruthy()
		if not actual then
			error(`expected a truthy value, got {show(actual)}`, 2)
		end
	end

	function e.toBeFalsy()
		if actual then
			error(`expected a falsy value, got {show(actual)}`, 2)
		end
	end

	function e.toBeCloseTo(expected: number, tolerance: number)
		if type(actual) ~= "number" or math.abs(actual - expected) > tolerance then
			error(`expected {show(actual)} to be within {tolerance} of {expected}`, 2)
		end
	end

	function e.toBeAtLeast(expected: number)
		if type(actual) ~= "number" or actual < expected then
			error(`expected {show(actual)} >= {expected}`, 2)
		end
	end

	function e.toBeAtMost(expected: number)
		if type(actual) ~= "number" or actual > expected then
			error(`expected {show(actual)} <= {expected}`, 2)
		end
	end

	function e.toThrow(fragment: string?)
		assert(type(actual) == "function", "toThrow expects a function")
		local ok, err = pcall(actual)
		if ok then
			error("expected the function to throw, but it returned", 2)
		end
		if fragment and not string.find(tostring(err), fragment, 1, true) then
			error(`expected error containing {show(fragment)}, got {show(tostring(err))}`, 2)
		end
	end

	function e.toContain(fragment: string)
		if type(actual) ~= "string" or not string.find(actual, fragment, 1, true) then
			error(`expected {show(actual)} to contain {show(fragment)}`, 2)
		end
	end

	return (e :: any) :: Expectation
end

return lib
