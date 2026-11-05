# Changelog

## Unreleased

- Hatch reveal: every hatch plays on screen. The egg wobbles, cracks in a
  flash, and the creature turns under its rarity, name, income and exact
  chance, with rays, glow, confetti and screen shake as rarity rises. Tap to
  skip ahead, hold to skip all; small repeat hatches share one reveal.
- Hatchery Book in the side menu: all 33 creatures by tier, "???"
  silhouettes until found, each with its best egg and odds. Every species
  found adds +1% income.
- Daily Rewards in the side menu: a seven-day streak of growing coin
  rewards that scale with income; a missed day starts over.
- Farmyard map: a red barn and silo, a turning windmill, a duck pond, an
  animal pen and crop fields around the ring of bases, with voxel trees and
  terraced hills in place of the round ones.
- Sound effect hooks for the egg, the reveal, the book and rewards (silent
  until sounds are picked).

- Creatures (Alex, Nov 5): 33 voxel creatures in seven tiers, from ten
  small Commons up to two huge Godlies, replacing the coloured balls. Each
  tier moves and shines more than the last: Commons bob and blink; Rares
  flap and flick their ears; Ultra Rares glow and sparkle; Epics stand in a
  rarity ring; Legendaries hover in an aura; Godlies have orbiting lights
  and a rainbow ring. A ridden creature is drawn up to 6 studs tall and a
  carried one up to 4, and guards turn to face where they walk.
- Odds are far rarer: every egg now rolls out of 100,000, so the rarest
  hatch is 1 in 50,000, and the odds card shows each chance as a percentage
  and as "1 in N". A new Moonlit Egg (15,000 coins, 5% of the belt) holds
  the Moon Unicorn and a 1 in 50,000 Nebula Serpent.

- First look (Alex's Nov 4 play test): a welcome screen on a new player's
  first join and a Guide button in a new side menu to reopen it; a goal line
  under the coin bar with a beam and arrow to the next thing to do (first
  egg, hatch, collect, 4th incubator); a sunny sky with haze, clouds, bloom
  and sun rays; a sandy yard with the Golden Nest, fences and flowers on
  every base, trees and a ring of hills hiding the map's edge; background
  music (tracks set in `config/atmosphere.luau`) with a Music on/off button.
- Shop opens on a new Coins tab (incubator, shield, traps, decoy, belt
  eggs), with Robux items on the second tab.
- Prices one rung lower: Double Coins 149, Extra Incubators 99, and a new
  80K Coins pack at 199 between the 30K and 200K packs.

- Fix: the map was buried in the ground. The Baseplate was placed with a
  property Rojo drops when it builds the place, so it sat ten studs too high
  and covered every floor, pad and label. It is now placed with CFrame, and
  the boot check fails when anything is built inside the ground.

- Player analytics (shared core): the daily scoreboard now shows time played
  and session lengths, D7 and D30 returns, players who come with or bring
  friends, Robux by item and by where in the game it was bought, purchase
  prompts, onboarding drop-off and game event counts.

- Error reports (shared core) are stored under dated keys, so the daily
  feedback digest and the post-publish error sweep can read them by day.
- Feedback button in the top bar (shared core): players send a Bug, Idea or
  Other report with an optional fun rating. Reports carry this game's
  progress snapshot (creatures, placed, incubating, mounted, guard, traps, shield) to help reproduce bugs.
- Robux prices and Roblox listings (name, price, description) for every
  pass and product, on the studio price ladder (ops/PRICING.md). The shop's
  catalog moved to `src/shared/Products.luau` so tests check its names.

- Economy tuned from the playtest (Alex approved the playtest set): 200
  starting coins, Basic Egg hatches in 10 s, storage auto-sale pays 20 s of
  income (spam-buying Basic eggs no longer makes coins), first rebirth
  costs 120K and each next one 3×. In the 3-hour bot run the first rebirth
  moved from 106 to 36 minutes; Basic-egg spam now loses about 7 coins/s.
- Playtest fixes:
  - A refused egg purchase no longer leaves an invisible egg on the belt. The
    egg dims until the server answers (`HH:EggResult`).
  - Storage auto-sale notices are summed and sent at most every 20 s.
  - Only creatures on a pad can be ridden.
  - The fixed order for restricted players matches the odds exactly (a
    Turtle once in 50 Basic eggs, not once in 4). The odds card shows the
    wait for each creature.
  - Onboarding funnel gains FirstCollect, FirstSlot, PadsFull and
    FirstRebirth.
- Raids and defenses (M4): steal one creature at a time from a rival base and
  carry it home at carry speed; the owner, the guard or a snare takes it back.
  Shield pylon (free, 90 s, 5-minute recharge), Snare and Slime traps, decoy
  eggs, one guard creature that patrols and chases, 5 minutes of new-player
  protection and a 2-minute cooldown per raided owner.
- Movement check from the shared core: speed hacks and teleports are pulled
  back, and drop anything carried. One module sets walk speed (walk, mount,
  carry, stun, slow).
- Dying or resetting while carrying sends the creature home.
- HUD: carrying banner with time left, red alarm while raiders are on your
  base. Prompts: Steal on rival bases; Make guard, Raise shield, Set snare or
  slime and Place decoy egg on your own.
- Save data v1 gains `guardUid` and `shieldReadyAt`. No live data yet, so no
  migration.
- Analytics: `Raid:Entered`, `Raid:PickedUp`, `Raid:Stolen`, `Raid:Defended`
  and the FirstRaidTried and FirstRaidDefended onboarding steps.
- First playable (M2): an egg conveyor per base on a shared server-time
  schedule, incubators with saved hatch times, hatching onto 20 creature pads
  with storage, coins per second into an uncollected pile, the collect pad,
  incubator slots for coins, rebirth, offline earnings with a welcome-back
  message, Auto-Collect pass support and basic riding.
- Grey-box map built from code: 8 bases around a shared yard, each with a
  belt, 14 incubators, 20 pads, a collect pad, a rebirth stand, an odds board
  and the owner's name.
- Minimal HUD: coins, income, the uncollected pile, rebirths, Get off button,
  notices, hatch reveals and the odds card shown before every egg purchase.
- Save data v1 gains `pendingCoins`, `lastIncomeAt`, `eggsBought`, `nextUid`,
  `mountUid`, `decoys`, `rebirthArchive` and `firsts`; incubators record
  `readyAt` and the outcome paid for. No live data yet, so no migration.
- Analytics: onboarding steps Joined, FirstEggBought, FirstHatch, FirstRide
  (once per player, ever), `Egg:Hatched`, Rebirth progression, and every coin
  change through the economy ledger.
- Project scaffold on the shared core: config files with schemas, save data v1,
  creature income and rebirth math, coin pack and shield refill products
  (not yet created on Roblox), server and client start-up.
