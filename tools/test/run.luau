--!strict
-- Runs every *.spec.luau under packages/*/tests, games/*/tests and tools/tests with Lune.
-- Usage (from the repo root): lune run tools/test/run [filter]
-- Set VERBOSE=1 to see the log lines the code under test writes.
-- Exits non-zero when any test fails, so CI goes red.

local fs = require("@lune/fs")
local process = require("@lune/process")
local Log = require("@core/Log")
local lib = require("./lib")

-- Code under test logs a lot on purpose (failed grants, drops). Keep test
-- output readable unless VERBOSE=1.
if process.env.VERBOSE ~= "1" then
	Log.setSink(function() end)
end

local filter = process.args[1]

local function collect(dir: string, out: { string })
	if not fs.isDir(dir) then
		return
	end
	local entries = fs.readDir(dir)
	table.sort(entries)
	for _, name in entries do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			collect(path, out)
		elseif string.match(name, "%.spec%.luau$") then
			table.insert(out, path)
		end
	end
end

local specs: { string } = {}
collect("tools/tests", specs)
for _, root in { "packages", "games" } do
	if fs.isDir(root) then
		local children = fs.readDir(root)
		table.sort(children)
		for _, child in children do
			collect(`{root}/{child}/tests`, specs)
		end
	end
end

local passed, failed = 0, 0
local failures: { string } = {}

for _, path in specs do
	if filter == nil or string.find(path, filter, 1, true) then
		local modulePath = "../../" .. string.gsub(path, "%.luau$", "")
		local ok, err = pcall(require, modulePath)
		local results = lib.takeResults()
		if not ok then
			failed += 1
			table.insert(failures, `{path}: failed to load: {err}`)
		end
		for _, result in results do
			if result.ok then
				passed += 1
			else
				failed += 1
				table.insert(failures, `{path}: {result.name}\n    {result.err}`)
			end
		end
		print(`{if ok then "ran " else "ERR "}{path} ({#results} tests)`)
	end
end

print("")
for _, failure in failures do
	print("FAIL " .. failure)
end
print(`{passed} passed, {failed} failed, {#specs} spec files`)

if failed > 0 or passed == 0 then
	process.exit(1)
end
