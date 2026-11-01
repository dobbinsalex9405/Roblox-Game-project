# Setup steps only Alex can do

These need your Roblox or GitHub account, so Claude never does them and never
asks for a password, cookie, 2FA code or API key. Nothing here blocks code
work; the publish workflows skip any game whose environment is not set up yet.

## 1. Roblox group and experiences (milestone M0)

1. Turn on two-step verification on your Roblox account.
2. Create the group (100 Robux) and add the account that should receive payouts.
3. Under the group, create three experiences for Hatchery Heist: **Dev**,
   **Staging** and **Production**. Keep Staging and Production private until launch.
4. On all three: Avatar Settings → **R15 Only**; Place Copying **off**;
   Places → Server Size **8** (the map has 8 bases).
   On Dev only: turn on **Studio access to API services** (so DataStores work in Studio).
5. Copy each experience's **universe id** and **start place id** into
   `ops/environments.json` (or paste them in the project thread and Claude
   will open a PR). Ids are not secret.

## 2. API keys (before the first Staging publish, milestone M3)

In the Creator Dashboard, create **group-owned** Open Cloud API keys:

| Key | Permissions | Experience |
|-----|-------------|------------|
| Hatchery Heist Staging | `universe-places` Write; DataStore read (for the error queue) | Staging only |
| Hatchery Heist Production | `universe-places` Write; DataStore read (for the error queue) | Production only |

Leave "Accepted IP addresses" open (GitHub's runners change IP) and set an
expiry you will remember to renew.

Paste each key **directly into GitHub**, never into chat:

1. Repo → Settings → Environments → **New environment** `staging` →
   Add environment secret named `ROBLOX_API_KEY_HATCHERY_HEIST` with the Staging key.
2. Same for an environment named `production` with the Production key.

Each future game gets its own pair, named `ROBLOX_API_KEY_<GAME_NAME>`.

### 2b. One read-only key for player feedback

Every game has a Feedback button; the daily **Player feedback** workflow
reads what players sent and opens a digest issue (see `ops/FEEDBACK.md`). It
needs one more **group-owned** key that can only read:

| Key | Permissions | Experiences |
|-----|-------------|-------------|
| Feedback reader | DataStore: **List entry keys** and **Read entry** (`universe-datastores.objects:list`, `universe-datastores.objects:read`). Nothing else. | Every game's **Staging** and **Production** (add each new game when it is created) |

Paste it into GitHub as a **repository** secret (not an environment one, so
the daily run never waits for an approval): Repo → Settings → Secrets and
variables → Actions → **New repository secret** named `ROBLOX_READ_API_KEY`.
It cannot change anything in a game. Until it exists, the workflow skips.

## 3. Your approval gate on production

Repo → Settings → Environments → `production`:

- **Required reviewers**: add yourself. Every production publish then waits for
  your Approve click.
- **Deployment branches and tags**: "Selected branches and tags", add `main`.

## 4. Protect main

Repo → Settings → Rules → New branch ruleset for `main`:

- Require a pull request before merging.
- Require status checks to pass: **Format, lint, test, build, type check**.
- Block force pushes.

## 5. Studio sessions (from milestone M3)

Install Roblox Studio and the Claude desktop app, turn on Studio's MCP server,
and install the Rojo Studio plugin. During a session:

```sh
rokit install && (cd deps && wally install)
rojo serve games/hatchery-heist/default.project.json
```

## Playing the latest build in Studio (any time)

On a computer with Roblox Studio and the tools above:

```sh
git pull
rokit install && (cd deps && wally install)
rojo serve games/hatchery-heist/default.project.json
```

Open a new Baseplate in Studio, connect the Rojo plugin, and press Play. To
build a file instead: `tools/build.sh hatchery-heist`, then open
`build/hatchery-heist.rbxl`. Saving progress in Studio needs the Dev
experience's **Studio access to API services** (step 1.4) and the place
published to it; without that, play works but nothing is kept between runs.
Passes and products stay off until their ids are set (M5).

## 6. Payout check (M0)

Have a friend (not you) buy a 5 Robux pass in a group game, then check
whether Group → Finances → Payouts unlocks.
