--!strict
-- Rewrites the pricing table in ops/PRICING.md from every game's
-- config/monetization.luau `listings`, after checking them against the studio
-- price ladder.
--
--   lune run tools/pricing/run           rewrite the table
--   lune run tools/pricing/run --check   only say whether it is up to date (exit 1 if not)

local fs = require("@lune/fs")
local process = require("@lune/process")
local lib = require("./lib")
local loadGames = require("./games")

local PATH = "ops/PRICING.md"
local games = loadGames()

local problems: { string } = {}
for _, g in games do
	for _, problem in lib.problems(g) do
		table.insert(problems, problem)
	end
end
if #problems > 0 then
	for _, problem in problems do
		print(problem)
	end
	process.exit(1)
end

local doc = fs.readFile(PATH)
local updated = lib.render(doc, lib.markdown(games))
if process.args[1] == "--check" then
	if updated ~= doc then
		print(`{PATH} is out of date: run lune run tools/pricing/run`)
		process.exit(1)
	end
	print(`{PATH} is up to date`)
elseif updated ~= doc then
	fs.writeFile(PATH, updated)
	print(`Updated {PATH}`)
else
	print(`{PATH} was already up to date`)
end
