# Depthbound: intended behavior

Working title; check Roblox for name collisions before launch (M7).

A push-your-luck dive game (approved Nov 1, 2026, in place of the full mining
RPG): players dive into a shared mine for ore and must climb out before their
lamp oil runs dry. When a bug report and this spec disagree, the spec wins
until Alex says otherwise.

## Core loop

1. **The mine.** One shaft, `mine.width` x `mine.length` blocks across, three
   layers deep (Clay Shallows, Ironroot Caverns, Ember Deep; `config/mine.luau`).
   Each server builds a fresh mine from a random seed; it is never saved. Each
   block is rolled from its layer's weights out of 10,000, and the layer guide
   at camp shows those exact chances. Only blocks touching open air exist as
   Parts. Mined-out blocks grow back as a fresh roll after `regrowSeconds`,
   once no player is within `regrowClearance` studs.
2. **The lamp.** Stepping onto the mine lights a full lamp (`gear.lamp` tier,
   x1.5 with the Better Lamp pass). Oil burns at the current layer's
   `oilPerSecond`, so deeper burns faster. The oil meter marks how much oil a
   climb from the current row needs.
3. **Mining.** Hold the pickaxe on a block. Each swing deals the pick's
   `power`; a block breaks when its `hp` is used up. The server checks every
   swing: the block must touch air, be within `dive.reach` studs, and come at
   least `swingSeconds` x `swingTolerance` after the last swing. A layer needs
   at least its `minPickTier` pick. Ore (any block worth more than 0) goes in
   the pack; plain rock just breaks. A full pack refuses ore but still digs.
4. **Getting out.** Either walk back onto the camp ground, or press **Climb
   out**: the climb takes `climb.baseSeconds + climb.secondsPerRow` x row and
   burns `climb.oilPerSecond` all the way up. Arriving at camp with oil left
   keeps the whole pack.
5. **Lamp-out.** If the oil runs dry (on the rope too), the player keeps
   `lampOut.keepFraction` of the pack, at least `lampOut.minKeep` pieces
   (spread across stacks in proportion,
   so a rare find is as much at risk as the rest), drops the rest where they
   fell, and wakes up at camp. Dying in the mine (a reset, for example)
   counts as a lamp-out. Leaving the game mid-dive keeps the pack only if the
   oil left could have climbed out from where the player was; otherwise it
   counts as a lamp-out, so quitting never beats the lamp.
6. **Camp.** Sell the whole pack at the sell pad (or automatically on
   arrival with Auto-Sell). Upgrade pick, pack and lamp at their stands; each
   tier costs coins (`config/gear.luau`). Selling and upgrading only work at
   camp.

## After M2 (from the Wave 1 plan)

- M4: dropped hauls stay where the player fell; anyone in the server can find
  one and keeps a finder's share, the rest goes back to its owner, handed out
  once inside one server step. Party dives of up to 4 sharing one oil pool.
  The daily depth board. Movement check against teleports to deep ore (until
  then, a teleport still cannot hit a block that does not touch air).
- M5: passes (Bigger Pack, Better Lamp, Auto-Sell), products (Oil Refill, at
  most one per dive; Ore Boost; Geode Crate), geodes found while mining and
  opened at camp. The Geode Crate is a paid random item: odds screen before
  purchase and a PolicyService check. Found geodes are free but show their
  odds from the same table.
- After the gate: more layers and biomes, classes and skill trees, boss
  floors, pets, expeditions.

## Money

All prices need Alex's approval (M5). Pass and product ids stay 0 in
`config/monetization.luau` until created on Roblox; id 0 is never sold. Each
experience's ids go under `environments` (see ops/SHOP.md). Depthbound sells
no coin packs, so nothing bought with coins is a paid random item.

Wired into the shared shop now (testable in Studio with the Test panel):

- **Oil Refill** (product): a saved item. One pours per dive; bought mid-dive
  it pours at once, otherwise (at camp, after this dive's refill, or with the
  lamp over 90% full) it waits for a later dive. The HUD button pours one
  from stock or buys one.
- **Ore Boost** (product): ore sells for 2x for 15 minutes; more adds time.
- **Bigger Pack, Better Lamp, Auto-Sell** (passes).
- **Geode Crate**: not listed until M5 (paid random: odds table, odds screen,
  policy check).

## Save data

Version 1 is in `src/shared/DataTemplate.luau`. Changes go through a
migration; nothing is ever removed. The pack is saved so a crash or a fair
disconnect never loses a haul.

## Status

- Done (M2): the mine grid (seeded, exposure-only Parts, regrowth), mining
  with every server check, the oil meter by depth, climbing out, lamp-outs,
  selling, pick/pack/lamp upgrades, grey-box camp built from code, layer
  guide with exact chances, minimal phone-first HUD, onboarding analytics.
- Next: the phone performance test (M2 Studio session with Alex), then M3
  (camp layout, first Staging publish and playtest).

## Update backlog

Candidate updates for the weekly loop (`ops/UPDATE_LOOP.md`), grouped by
focus. A brief takes the top item that fits the week's focus; the loop owner
adds new ones from playtests, feedback ideas and what worked elsewhere.

- **fix**: refused swings ("too fast", "out of reach") do nothing on screen;
  add a client swing cooldown matched to the server's.
- **onboarding**: nothing says how to climb out or what the oil bar means
  before the first dive; a 3-step first-dive hint.
- **onboarding**: funnel steps for the first full pack, Layer 3 and the first
  max-tier purchase (the funnel ends at FirstLampOut).
- **depth**: a time-based "climb in 10 s" warning (the x1.3 window shrinks to
  3 s at bedrock); hide the Climb button on the top face.
- **depth**: a full pack blocks ore entirely; break it and drop the ore, or
  show pack-full on the block. Pause regrowth of a column while anyone is
  below it.
- **return**: the daily depth board (M4); the daily bonus already exists.
- **monetization**: Geode Crate with odds screen and PolicyService check
  (M5); Oil Refill placed on the lamp-out moment.
- **social**: party dives of up to 4 sharing one oil pool, dropped hauls
  others can find (M4).
- **content**: more layers and biomes, boss floors (after the gate).
