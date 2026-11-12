# Economy: pacing targets and the simulator

How fast Hatchery Heist should go, and how to check that it does before a
number in `config/` changes. Prices in Robux are in `ops/PRICING.md`; this
file is about coins, eggs, odds and the tower.

## The simulator

`tools/economy/sim.luau` plays the game's economy for a simulated player.
It loads the real config files and uses the real income, tower, book and
daily-reward code. The player hatches what is ready, presses Place best,
buys the incubator, floor or upgrade that pays off best against eggs over
the next 8 hours of play, and buys the eggs that raise income most for the
coins and incubator time they cost. Walking to the belt, buying and hatching
take real seconds. Each belt egg type reaches the player at its share of the
belt split between 3 other shoppers. The daily timed event (one random
30-minute window a day) applies when a session overlaps it.

```sh
lune run tools/economy/run                       # every player type, 14 days, 60 runs each
lune run tools/economy/run --profile regular --runs 200
lune run tools/economy/run --values              # what each rarity costs from each egg
lune run tools/economy/run --patch tools/economy/proposals/phase2 --shop   # try a change first
```

Player types (`Sim.PROFILES`):

| Type | Play | Notes |
| --- | --- | --- |
| casual | 25 min on day 1, then 20 min a day | |
| regular | 40 min on day 1, then 2 x 30 min a day | the one targets are set for |
| grinder | 90 min on day 1, then 3 x 60 min a day | |
| charms | regular with a full set of Godly charms | items design, Nov 7 |
| payer | regular with Double Coins + Extra Incubators | |

A patch (`tools/economy/proposals/*.luau`) is a function that edits the raw
config before eggs are expanded. Write the change there first, compare the
tables with main, then copy the numbers into `config/`.

`tools/tests/EconomySim.spec.luau` keeps two promises on a short run: the
first Rare comes inside the first session, and nobody owns the whole tower
after two days.

## Pacing targets (regular player, Nov 7 2026)

Alex wants the game "a bit of a grind on purpose". The targets:

| Moment | Target |
| --- | --- |
| First Rare | first session (10 to 20 min) |
| First Ultra Rare | day 1 |
| First Epic | day 2 to 3 |
| First Legendary | a 2 to 3 week goal (about a third by day 14) |
| First Godly | a 1 to 2 month dream (a few % by day 14) |
| Floor 4 / 6 / 8 | day 1 / day 3 / day 6 |
| Floor 10 | about day 13 (grinder about day 6) |
| Paying players | 1.5 to 2 times faster, never 5 times |
| Income | still rising at day 14 |

The Nov 12 numbers (509-creature roster, floors 20K to 475M, 40 runs)
meet every target except floor 8, which lands a day late (day 7). Income
still rises at day 14 (1.2K, 4.8K, 11K and 18K coins a second on days 1,
3, 7 and 14) but stops once the tower is full. The fix is new eggs that
unlock with the tower (phase 2 in the economy proposal), which needs egg
art and code.

## Rules for odds

- Coin-egg tier weights are written by `tools/economy/even_eggs.py`, never
  by hand: edit its `TARGETS` (the tier chances per egg) and run it after
  every pool change (`to_config.py` first). CI runs it with `--check`.
- Totals are powers of ten (Basic and Meadow 1,000,000, Moonlit
  10,000,000, Premium 100,000), so the odds screen's percentages add up to
  exactly 100%. Each tier's weight is a whole multiple of its member count,
  so every creature in a tier shows the same "1 in N". The few points left
  over move to the tiers where they shift the odds least. If no even split
  is close, scale the total by 10 rather than move the odds (rule i).
- Each Godly is a fixed chance per creature (1 in 2,000,000 in the Moonlit
  Egg), so the Godly tier grows with every Godly added.
- Each step up the egg ladder must be the better buy for its tier. Check
  with `--values` that no dearer egg costs more coins per creature of the
  tier it is for.
- Income per floor spot must rise with every tier, because an Epic takes
  2 spots and a Legendary or Godly 3. `tools/art/to_config.py` BANDS and
  the hand-written creatures in `config/creatures.luau` follow it.
