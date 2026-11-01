--!strict
-- Module 1: Config.
-- Each game keeps its tunable numbers in `config/` and a schema for each file.
-- `Config.load` checks every file against its schema once at start-up and
-- freezes the result. The same check runs in the Lune tests, so a bad number
-- fails CI instead of the live game.

local Schema = require("./Schema")
local Util = require("./Util")

export type Section = {
	schema: Schema.Validator,
	value: any,
}

local Config = {}

local loaded: { [string]: any } = {}

-- Validates every section and returns the list of problems (empty when all good).
function Config.validate(sections: { [string]: Section }): { string }
	local problems = {}
	local names = Util.keys(sections)
	table.sort(names)
	for _, name in names do
		local section = sections[name]
		local ok, err = section.schema(section.value, name)
		if not ok then
			table.insert(problems, err :: string)
		end
	end
	return problems
end

-- Validates and installs all sections. Throws one error that lists every problem.
function Config.load(sections: { [string]: Section })
	local problems = Config.validate(sections)
	if #problems > 0 then
		error("Invalid config:\n  " .. table.concat(problems, "\n  "), 2)
	end
	for name, section in sections do
		loaded[name] = Util.deepFreeze(section.value)
	end
end

-- Returns a frozen section. Unknown names throw, because a typo here is a bug.
function Config.get(name: string): any
	local value = loaded[name]
	if value == nil then
		error(`Config section "{name}" was never loaded`, 2)
	end
	return value
end

-- For tests only.
function Config.reset()
	table.clear(loaded)
end

return Config
