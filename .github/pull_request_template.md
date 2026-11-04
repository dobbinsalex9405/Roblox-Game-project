## What and why

<!-- One paragraph: what changes for players or for the studio, and why. -->

## Checks run locally

- [ ] `lune run tools/test/run`
- [ ] `stylua --check packages games tools playtests` and `selene packages games tools playtests`
- [ ] `tools/build.sh all`, `lune run tools/boot/run all --built`, `tools/keyflows.sh all`
- [ ] `lune run tools/audit/run all` (player's-eye audit; images in `build/audit/`)
- [ ] `tools/typecheck.sh`

## Visual playtest

<!--
Required when this PR touches games/ or packages/ (ops/VISUAL_PLAYTEST.md).
The verifier posts the report for the PR's head commit as a comment:

### Visual playtest: #<PR> @ <head sha>
- Tier 1 audit: ...
- Tier 2 real engine: ...
- Tier 3 Studio: ...
- Verdict: OK

Builders: list here what a player should notice, so the verifier knows where
to look (screens, menus, places in the world).
-->

## Notes for the verifier
