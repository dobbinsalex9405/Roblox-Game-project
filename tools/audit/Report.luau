--!strict
-- The audit's report for one game: markdown for people, a console summary.
-- A FAIL listed in tools/audit/known.json (a problem already being fixed)
-- shows as KNOWN: still reported, but it does not fail the run.

local World = require("./World")

local Report = {}

local ORDER = { FAIL = 1, KNOWN = 2, WARN = 3, NOTE = 4 }

export type Built = { markdown: string, summary: string, failed: boolean }

export type Known = { game: string, rule: string, contains: string, reason: string }

-- Marks FAILs that match a known.json entry as KNOWN. Returns the entries
-- that matched nothing, so a fixed problem's entry can be removed.
function Report.applyKnown(game: string, findings: { World.Finding }, known: { Known }): { Known }
	local used: { [Known]: boolean } = {}
	for _, f in findings do
		if f.severity == "FAIL" then
			for _, k in known do
				if k.game == game and k.rule == f.rule and string.find(f.message, k.contains, 1, true) then
					f.severity = "KNOWN"
					f.message ..= ` (known: {k.reason})`
					used[k] = true
					break
				end
			end
		end
	end
	local stale = {}
	for _, k in known do
		if k.game == game and not used[k] then
			table.insert(stale, k)
		end
	end
	return stale
end

function Report.build(
	game: string,
	commit: string,
	findings: { World.Finding },
	images: { { file: string, title: string } },
	notes: { string },
	gaps: { [string]: number }
): Built
	local sorted = table.clone(findings)
	table.sort(sorted, function(a, b)
		local oa, ob = ORDER[a.severity] or 9, ORDER[b.severity] or 9
		if oa ~= ob then
			return oa < ob
		end
		return a.rule < b.rule
	end)
	local counts = { FAIL = 0, KNOWN = 0, WARN = 0, NOTE = 0 }
	for _, f in sorted do
		counts[f.severity] = (counts[f.severity] or 0) + 1
	end
	local failed = counts.FAIL > 0
	local verdict = if failed then "FAIL" else "PASS"

	local md = {}
	table.insert(md, `# Player's-eye audit: {game} @ {commit}`)
	table.insert(md, "")
	table.insert(
		md,
		`**{verdict}**: {counts.FAIL} fail, {counts.KNOWN} known (tools/audit/known.json), {counts.WARN} warning, {counts.NOTE} note. Headless boot with one player; images are approximate renders (boxes and flat colours, no meshes, textures or lighting). Studio's real view is still the final gate (ops/VISUAL_PLAYTEST.md).`
	)
	table.insert(md, "")
	if #sorted > 0 then
		table.insert(md, "## Findings")
		table.insert(md, "")
		for _, f in sorted do
			table.insert(md, `- **{f.severity}** \`{f.rule}\`: {string.gsub(f.message, "\n", "\n  ")}`)
		end
		table.insert(md, "")
	end
	if #images > 0 then
		table.insert(md, "## Images")
		table.insert(md, "")
		for _, img in images do
			table.insert(md, `- [{img.file}]({img.file}): {img.title}`)
		end
		table.insert(md, "")
	end
	if #notes > 0 then
		table.insert(md, "## What the audit did")
		table.insert(md, "")
		for _, n in notes do
			table.insert(md, `- {n}`)
		end
		table.insert(md, "")
	end
	local gapList = {}
	for name, count in gaps do
		table.insert(gapList, `{name} x{count}`)
	end
	table.sort(gapList)
	if #gapList > 0 then
		table.insert(md, `Shim guessed at: {table.concat(gapList, ", ")}`)
		table.insert(md, "")
	end

	local lines =
		{ `== {game} @ {commit}: {verdict} ({counts.FAIL} fail, {counts.KNOWN} known, {counts.WARN} warn)` }
	for _, f in sorted do
		if f.severity == "FAIL" or f.severity == "WARN" then
			table.insert(lines, `[{f.severity}] {f.rule}: {f.message}`)
		end
	end
	return { markdown = table.concat(md, "\n"), summary = table.concat(lines, "\n"), failed = failed }
end

return Report
