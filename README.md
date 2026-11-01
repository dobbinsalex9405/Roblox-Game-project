# Roblox studio monorepo

One repo for every game in the studio: a shared core framework in
`packages/core` and one folder per game in `games/`. The repo is the source of
truth; Studio is only a view of it (Rojo syncs files into Studio and builds the
place files that get published).

The plan behind this layout is the "Roblox Studio Framework Plan" doc; the
standing rules come from the "Roblox Game Studio — Handoff Brief".

## Layout

```
rokit.toml                pinned tool versions (Rojo, Wally, Lune, Selene, StyLua, luau-lsp)
deps/wally.toml           third-party packages (ProfileStore), installed into deps/
packages/core/
  src/                    pure framework logic, shared by server and client, tested with Lune
  server/                 Roblox server adapters (ProfileStore, MarketplaceService, PolicyService, ...)
  client/                 Roblox client adapters (remotes, error forwarding)
  tests/                  unit tests for src/
games/hatchery-heist/
  default.project.json    Rojo project: core + game
  config/                 every tunable number
  src/server  src/client  src/shared
  tests/                  config, save data and gameplay-math tests
  SPEC.md  CHANGELOG.md
tools/                    test runner, build, type check, publish
ops/
  environments.json       universe and place ids per game (no keys, ever)
  SETUP.md                the steps only Alex can do (accounts, keys)
  DECISIONS.md            why things are the way they are
  digests/                weekly digests
.github/workflows/        ci, publish-staging, publish-production
```

## Daily commands

Install the tools once with [Rokit](https://github.com/rojo-rbx/rokit), then:

```sh
rokit install              # tools at the versions pinned in rokit.toml
(cd deps && wally install) # packages into deps/ServerPackages/

lune run tools/test/run    # all tests (add a word to filter, e.g. "Odds")
stylua packages games tools   # format
selene packages games tools   # lint
tools/build.sh all         # build/<game>.rbxl for every game
tools/typecheck.sh         # strict type check with Roblox API types

rojo serve games/hatchery-heist/default.project.json   # live-sync into Studio
```

CI runs the same checks on every pull request.

## How a change reaches players

1. A pull request: CI must be green (format, lint, tests, build, strict types).
2. Merge to `main`: **Publish to Staging** builds and publishes every game to
   its private Staging experience.
3. Playtest on Staging.
4. Run **Publish to Production** for one game. It waits for Alex's approval in
   GitHub, publishes, and tags the commit `<game>/production/v<version>`.
   Rolling back is the same workflow run with the previous tag.

Publishing uses Roblox Open Cloud with group-owned API keys stored only as
GitHub environment secrets. See `ops/SETUP.md`.

## Rules the code enforces

- The server decides every outcome; remotes are schema-checked and rate-limited.
- Player data is session-locked, versioned and migrated; nothing is ever deleted.
- Developer product purchases are granted exactly once.
- Paid random items show exact odds (totalling exactly 100%) before purchase,
  and the server rolls from the same table, after a PolicyService check.
- Errors and feedback reach the error queue with deduplication and write caps.
