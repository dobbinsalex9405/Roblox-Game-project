# Visual playtest: seeing each game as a player does

Every change to a game must be looked at **from the player's eyes** before
it is accepted. Headless checks (tests, boot check, key flows) passed a build
whose ground covered every base, pad and spawn (Nov 4, PR #41), so they are
never enough on their own. There are three tiers. The first two run in the
cloud with no laptop; the third is the real-pixel gate.

| Tier | What | Where it runs | When | Who |
|---|---|---|---|---|
| 1 | **Player's-eye audit** `lune run tools/audit/run` | GitHub Actions (CI), any cloud thread | every PR, every publish | automatic; the verifier reads it |
| 2 | **Real-engine check** `lune run tools/cloud/run <game>` | a real Roblox server (Open Cloud Luau Execution) | verifier, on the PR head, before its OK; every Staging publish once switched on | verifier (workflow **Real-engine check**) |
| 3 | **Studio play-solo** through Studio's built-in MCP server | the laptop, Roblox Studio | PRs that change a game's world, layout or UI, before the verifier's OK | a laptop thread, on the verifier's request |

## The rule

- **No PR that touches `games/` or `packages/` is OK'd, merged or published
  without its visual playtest report for the PR's head commit.** The
  verifier posts the report (template below) as a PR comment, with links to
  the images. The **Visual playtest gate** workflow sets the commit status
  `visual-playtest` on the PR head: pending until a report from the repo
  owner's account for that exact commit says `Verdict: OK`, red when it says
  `Verdict: not OK`. A push after the report needs a new report. PRs that
  touch neither folder pass the gate on their own.
- A **FAIL** in tier 1 or 2 blocks the PR. A finding that is real but already
  being fixed elsewhere goes into `tools/audit/known.json` with the reason
  and the thread fixing it; it then shows as KNOWN and stops failing. When the
  fix lands, the audit warns `known.stale` and the entry is removed.
- **WARN**s are read and judged: the report says why each is fine or files it.
- Tier 3 is required when the PR changes what a player sees: the world
  (parts, spawn, map), the HUD or any menu. Pure server logic, data or config
  number changes can skip it; the report says so.
- Headless renders are an approximation (boxes, flat colours, a bitmap
  font). Anything that looks wrong in them is confirmed in tier 3 before it is
  called a bug; anything that looks fine in them can still be wrong in tier 3.

## Tier 1: the player's-eye audit

```sh
lune run tools/audit/run all                 # builds each game for Staging into build/audit-places/
lune run tools/audit/run hatchery-heist      # one game
lune run tools/audit/run all --built         # audit build/<game>.rbxl as built (a dev build has no shop)
```

It boots each game headless (the boot shim, with the server and the one
player's client wired together), puts the player on the spawn and looks:

- **World:** parts or labels inside the ground, no spawn, a buried spawn, a
  spawn a player cannot stand on (solid parts where the character goes),
  prompts with nothing under them or too high to reach, the main loop too far
  from the spawn, parts fallen below the world.
- **HUD** at phone (844x390), small phone (667x375), tablet and desktop, with
  Roblox's top bar: buttons off the screen or under Roblox's top-bar buttons,
  buttons or text on top of each other, text too small to read on a phone,
  taps smaller than 28 points, panels covering most of the view.
- **Clicks:** every button on the first screen, each from a fresh join: an
  error, nothing happening, nothing visible changing, a panel with no way to
  close it. Inside each panel it opens, it clicks tabs, odds and Buy buttons
  in reading order (swiping lists to them), so the Robux shop, its odds
  screens and each purchase prompt are seen too.
- Products are priced from the game's `config/monetization.luau` listings,
  exactly as the Staging ids resolve.

Output in `build/audit/<game>/`: `report.md`, `report.json` and the images:

| Image | What it shows |
|---|---|
| `spawn-view.png` | the default camera behind the character on the spawn |
| `wide-view.png` | the same, zoomed out |
| `map.png` | top-down |
| `side-north.png`, `side-east.png` | cuts through the spawn; the red dashed line is the ground's top |
| `phone.png`, `tablet.png`, `desktop.png` | the first screen: HUD over the spawn view |
| `click-NN-<button>.png` | the phone screen after tapping that first-screen button |
| `click-NN-MM-<button>.png` | after tapping a button inside that panel |

Reading the HUD images: the two dark rounded boxes at the top left stand in
for Roblox's own top-bar buttons (menu and chat), not the game's. Grey boxes
with a cross are images (not loaded). Red outlines mark FAIL elements. The
font is a 5x7 bitmap, so text width is approximate; tier 2 measures every
HUD text with Roblox's own fonts.

CI runs the audit on every PR and keeps the images as the run's
`audit-<sha>` artifact for 30 days; the run summary has every report. Both
publish workflows run it (`--built --no-images`) on the exact file before
uploading.

Known limits of the headless harness (tier 3 covers them): no physics, no
meshes, textures or lighting, no real fonts, and a `Destroy()` in game code
becomes a detach so reads of a cleared label work as on Roblox.

## Tier 2: the real-engine check

`tools/cloud/run.luau` saves the built place as a **new Staging version
without publishing it** (players and live servers never see it), then runs
`tools/cloud/probe.luau` inside a real Roblox server through Open Cloud Luau
Execution. The probe starts the server scripts itself (that server has no
players and no physics) and checks with the real engine:

- the tier 1 world rules on real part data (meshes and unions included),
- the spawn with real collision geometry where a character stands,
- a real raycast to the floor under every prompt,
- parts neither anchored nor welded (they fall once physics runs),
- every label and every HUD text tier 1 found, measured with Roblox's own
  font metrics: text cut off, or scaled below 9 px on a phone,
- errors from the game's own server scripts while starting.

Run it with the **Real-engine check** workflow (Actions tab, inputs: the
PR's branch or head commit, and `all` or one game). It needs the Staging
keys to carry Luau Execution access (`ops/SETUP.md` section 2). The workflow
keeps `build/cloud/<game>.md` and the tier 1 images as an artifact. Once the
keys have that access, set the repository variable `CLOUD_CHECK` to `on`
and every Staging publish runs it before uploading.

Locally (a thread with a key in its environment, never in chat):
`BUILD_ENVIRONMENT=staging tools/build.sh <game> && lune run tools/audit/run --built <game> && ROBLOX_API_KEY=... lune run tools/cloud/run <game>`.

## Tier 3: Studio play-solo through Studio's MCP server

Roblox Studio ships an MCP server. Claude Code on the laptop talks to it
directly: start and stop a play-solo test, walk the character, tap the
screen, read the console and **capture the real viewport**. No mouse
clicking with screen control is needed.

One-time setup (laptop thread or Alex):

1. In Studio: Assistant panel, "…" menu, **Settings**, **MCP Servers**: turn
   the Studio MCP server on.
2. Register it with Claude Code for every session, either with Quick connect
   on that same page, or in a terminal:
   `claude mcp add --scope user Roblox_Studio -- cmd.exe /c "%LOCALAPPDATA%\Roblox\mcp.bat"`
   (check the `.bat` exists at that path first).
3. Optional: add `mcp__Roblox_Studio__*` to `permissions.allow` in
   `%USERPROFILE%\.claude\settings.json` so each step does not ask.
4. Check: `claude mcp list` shows Roblox_Studio connected; Studio's MCP page
   shows a connected client.

The tools (names as Roblox documents them; confirm with the first session):
`list_roblox_studios`, `get_studio_state`, `start_stop_play`,
`screen_capture`, `character_navigation`, `user_mouse_input`,
`user_keyboard_input`, `execute_luau` (Edit, Client or Server),
`get_console_output`.

The pass, on the PR's head built for Staging (`BUILD_ENVIRONMENT=staging
tools/build.sh <game>`, open `build/<game>.rbxl` in Studio):

1. `start_stop_play` to start play-solo. `screen_capture` at the spawn: the
   character stands on visible ground, the HUD is readable.
2. Set Studio's device emulator to a phone (landscape) if available, or
   capture the viewport at a small window size; capture the HUD.
3. Play the main loop for two to three minutes with `character_navigation`
   and `user_mouse_input` / `user_keyboard_input`, capturing each step
   (collect, sell or equivalent, upgrade).
4. Open the shop and each menu; capture; close them.
5. `get_console_output`: no errors.
6. `start_stop_play` to stop.

Never sign in, change account settings or buy anything during the pass. A
purchase prompt in Studio is a test prompt and is closed, never confirmed.

## The report (one per PR head)

```md
### Visual playtest: <PR> @ <head sha>

- Tier 1 audit: PASS/FAIL per game, <n> known, <n> warnings; images: <link to the CI artifact or project files folder>
- Tier 2 real engine: PASS/FAIL per game (<workflow run link>), or "not run: <reason>"
- Tier 3 Studio: done/not needed (<why>); screenshots: <link>
- What I looked at: spawn, main loop, HUD at phone size, shop and odds, each menu
- Warnings judged: <rule>: <why it is fine, or the issue filed>
- Verdict: OK            (or: Verdict: not OK, then the blocking finding)
```
