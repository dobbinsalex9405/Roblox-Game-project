# Changelog

## Unreleased

- Feedback button in the top bar (shared core): players send a Bug, Idea or
  Other report with an optional fun rating. Reports carry this game's
  progress snapshot (gear tiers, pack contents, deepest row, dives and lamp-outs) to help reproduce bugs.
- First playable (M2): a shared three-layer mine built per server from a
  seed, with only blocks that touch air drawn as Parts and old tunnels growing
  back; pickaxe mining with server checks for reach, swing speed, exposure
  and pick tier; the lamp-oil meter burning faster by layer; Climb out (time
  and oil by depth) or walk out; lamp-outs keeping a quarter of the pack;
  selling at camp; pick, pack and lamp upgrade tiers.
- Anti-exploit rules: a reset in the mine and leaving mid-dive without the oil
  to climb out both count as lamp-outs; a teleport cannot reach unexposed ore;
  a swing must be in reach and at pick speed.
- Grey-box camp built from code: ground around the shaft, walls and bedrock,
  spawn, sell pad, three upgrade stands and the layer guide board showing
  every block's exact chance.
- Minimal HUD: coins, pack (count and value), depth and layer, the oil meter
  with the climb-out marker and warnings, Climb out button, ore pickups,
  notices; the player's own lamp dims as oil runs low.
- Save data v1: coins, gear tiers, pack, deepest row, layers reached, geodes
  (M5), boosts (M5), receipts, firsts, stats.
- Analytics: onboarding steps Joined, FirstBlockMined, FirstSale,
  FirstUpgrade (first lamp-out and layer 2 are saved in `firsts` and reported
  as their own events, since they can come in any order); `Dive:Start`, `Dive:End` (deepest
  row, how it ended), `Dive:LampOut` (pieces dropped, cause, layer, first or
  repeat), `Gear:Upgrade`, Layer progression, and every coin change.
