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
reads what players sent, plus the errors the games' servers record, and opens
a digest issue (see `ops/FEEDBACK.md`). The same run is the error check after
each publish (`ops/PUBLISH_CHECKS.md` step 3). It needs one more
**group-owned** key that can only read:

| Key | Permissions | Experiences |
|-----|-------------|-------------|
| Feedback reader | DataStore: **List entry keys** and **Read entry** (`universe-datastores.objects:list`, `universe-datastores.objects:read`). Nothing else. | Every game's **Staging** and **Production** (add each new game when it is created). |

Name it `loop-lab-feedback-reader`, leave the IP list open (GitHub's runners
change address) and give it a 90-day expiry. When it lapses the workflow
fails with HTTP 401 and the daily run flags it; make a new one the same way.

Paste it into GitHub as a **repository** secret (not an environment one, so
the daily run never waits for an approval): Repo → Settings → Secrets and
variables → Actions → **New repository secret** named `ROBLOX_READ_API_KEY`.
It cannot change anything in a game. Until it exists, the workflow skips.

### 2c. Real-engine check: Luau Execution on the Staging keys

Done 2026-11-05: the permission is on all four Staging experiences and
`CLOUD_CHECK` is `on`. The first run on `main` passed for all four games.

The verifier's real-engine check (`ops/VISUAL_PLAYTEST.md` tier 2) runs a
read-only probe inside a real Roblox server for a **saved, unpublished**
Staging version. It uses the existing Staging keys, which need one more
permission. The key values do not change, so nothing in GitHub changes.

For each of the 4 **Staging** publish keys in the Creator Dashboard (Loop Lab
Games → Open Cloud → API Keys → the key → Edit):

1. Under Access Permissions, add the API system **luau-execution-sessions**
   (Luau Execution) for that game's **Staging** experience with **Read** and
   **Write** (`universe.place.luau-execution-session:read` and `:write`).
2. Save. Do not regenerate the key.

Then, to run the check on every Staging publish too: Repo → Settings →
Secrets and variables → Actions → **Variables** → New repository variable
`CLOUD_CHECK` = `on`. Until then it runs only when the verifier starts the
**Real-engine check** workflow.

### Keys in place now (set up 2026-11-01)

| Key on Roblox (Loop Lab Games) | Scope | GitHub secret(s) | Expires |
|---|---|---|---|
| Staging publish (GitHub Actions) | `universe-places` Write on the 4 Staging experiences; Luau Execution read + write (added 2026-11-05) | `staging` environment: `ROBLOX_API_KEY_<GAME>` for all 4 games | No date (60 days unused) |
| Production publish (GitHub Actions) | `universe-places` Write on the 4 Production experiences | `production` environment: `ROBLOX_API_KEY_<GAME>` for all 4 games | No date (60 days unused) |
| Read-only (GitHub Actions) | `universe-datastores.objects` read + list on all 8 experiences | repository: `ROBLOX_READ_API_KEY` | **2027-01-30**: make a new one before then |

Every Roblox key also expires after 60 days without use. The publish keys
have no DataStore read; nothing reads the error queue with them yet.

## 3. Your approval gate on production

Repo → Settings → Environments → `production`:

- **Required reviewers**: add yourself. Every production publish then waits for
  your Approve click.
  Not available while the repo is private on GitHub Free (checked 2026-11-01);
  until then Production only runs when someone starts it by hand.
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

## 7. Create the claw machine's Robux pulls (laptop, after PR #127 merges)

Alex approved these prices on Nov 12, 2026. A Remote Control session on the
laptop may do this in the already signed-in browser. If Roblox asks for a
sign-in, a 2FA code, a CAPTCHA or a payment, stop and ask Alex.

1. Open the Creator Dashboard, then the **Hatchery Heist Staging**
   experience, then **Monetization → Developer Products → Create a
   Developer Product**.
2. Create two products, with names, prices and descriptions exactly as the
   `ClawPull10` and `ClawPull100` rows in `ops/PRICING.md` give them:
   - **10 Claw Pulls**, 100 Robux.
   - **100 Claw Pulls**, 700 Robux.
   For the image, use `store/hatchery-heist/icon.png` in the project files
   until claw art exists.
3. Copy each product's id into `games/hatchery-heist/config/monetization.luau`
   under `environments.staging.products`, as `ClawPull10 = <id>` and
   `ClawPull100 = <id>`. Open a data-only PR. Once it merges, Staging's claw
   window shows the prices instead of "coming soon".
4. Do the same in the **Production** experience at launch prep, putting the
   ids under `environments.production.products`.
