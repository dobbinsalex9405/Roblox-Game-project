# Pricing

Every Robux price in the studio, and the one ladder they all sit on. Prices
are a studio decision (AI-managed project rule), not Alex's: change them here
and in the configs, no approval needed.

**Source of truth:** each game's `config/monetization.luau`, under
`listings` (name on Roblox, Robux price, one-line description). The table at
the bottom is generated from those lines by `lune run tools/pricing/run`, and
`tools/tests/Pricing.spec.luau` fails CI when the table, a price off the
ladder, a missing listing or a shop name that differs from its listing slips
in.

## The ladder

| Robux | Tier | What goes here |
| ---: | --- | --- |
| 25 | Impulse | Small currency or bait pack, a skip, a refill, an instant finish |
| 49 | Boost | A 15-minute boost, a protection window, one paid random roll |
| 99 | Medium | Medium currency pack, a convenience pass, a cosmetic bundle |
| 149 | Capacity | A pass that adds room, or that plays the core action for you |
| 199 | Power | A pass that multiplies earnings |
| 399 | Large | Large currency pack, the best value per Robux. **The ceiling.** |

Why these numbers:

- **Six rungs, the same in every game.** A player who learns that a boost is
  49 and a 2x pass is 199 in one Loop Lab game finds the same in the next,
  and the daily scoreboard can compare games tier by tier.
- **Cheap first purchase.** The first Robux a player spends is the hardest
  one; every game has something useful at 25 (a small pack, a refill, a
  skip). Roblox simulators and tycoons commonly open at 25 to 49.
- **Passes in the middle.** Comparable simulators and tycoons sell
  convenience passes around 75 to 150, capacity passes around 100 to 250 and
  2x earnings passes around 150 to 400. New games with no reviews and little
  social proof convert better at the low end, so ours sit at 99, 149 and 199.
  Passes are bought once, so they can go up later without hurting anyone who
  bought early; lowering a price later reads as a sale.
- **A 399 ceiling while the games are new.** Nothing costs more until a game
  passes the launch gate and its numbers say players want a bigger item.
- **Bigger packs are better value.** Every game's currency packs give more
  per Robux as they get bigger (the test checks it): Hatchery Heist pays 200,
  303, 402 and 501 coins per Robux; Street Food Empire 200, 505 and 1,504 cash per
  Robux (its station costs grow faster, so its large pack has to reach
  further).
- **Hatchery Heist sits one rung lower (Nov 4).** Alex's first look found
  its shop a little dear for a brand-new game, so Double Coins is 149,
  and Extra Incubators 99, and a new 80K Coins pack at 199 fills the gap
  under the 200K pack at 399. A live product's grant never changes while
  its Roblox price is the old one, so a cheaper pack is a new product key
  (id 0 until the laptop creates it; the shop hides it until then), never
  a changed one. Revisit after 7 days of sales.
- **Roblox keeps 30%.** The studio earns about 70% of each price, so a 199
  pass earns about 139 Robux.

## Money rules these prices respect

- **Exact odds before paying for randomness.** Mystery Bait, the Premium Egg
  and the Geode Crate show their exact odds (summing to 100%) before Buy and
  are refused for players PolicyService restricts. Hatchery Heist's coin
  eggs count too, because coins are sold for Robux: their odds screen is
  already marked paid. Depthbound sells no coins, so its coin purchases are
  not paid randomness. Tidecatch Cove's Robux-only bait shows each cast's
  odds on the dock.
- **A paid random item is never the worse deal.** Mystery Bait and the
  Storm Lure Pack are both 25. The pack is 4 Storm Lures for certain; Mystery
  Bait averages about 4.3 Storm Lures' worth (3.3 Storm Lures plus 0.39 Pearl
  Lures, counting a Pearl Lure as 2.5 Storm Lures) and never gives less than
  3. The test checks this. Certainty costs only a little, and the random
  item is never a way to pay more for less.
- **No permanent raid immunity** in Hatchery Heist: Shield Refill is 10
  minutes at 49, and buying again only adds time.

## For the laptop: creating the items on Roblox

1. Create **only the rows marked "In shop now: Yes"**, in the game's
   **Staging** experience first. A "Not yet" item has no code behind it.
   Never create a "Not yet" Game Pass: a pass on sale shows on the
   experience's Store tab and could be bought for nothing.
2. Use the **Name on Roblox**, **Robux** and **Description** columns exactly.
   The shop's name must match what Roblox's purchase window shows.
3. If a Game Pass asks for an image, use the game's icon
   (`store/<game>/icon.png` in the project files) until pass art exists.
4. Put each new id under `environments.staging.passes` or
   `environments.staging.products` in that game's `config/monetization.luau`
   (keyed by the **Key** column), open a PR, and it reaches Staging when it
   merges. Repeat for Production at the game's launch prep.

## When to change a price

- After a game's first 7 days live, compare each item's buyers per 1,000
  players (the daily scoreboard counts purchases per item). An item nobody
  buys drops a rung; an item that sells to many payers can rise one rung.
- Move a price only between rungs. A new rung needs a line in
  `ops/DECISIONS.md` and a change to `tools/pricing/lib.luau`.
- Change the config first, run `lune run tools/pricing/run`, then change the
  price on Roblox (Creator Dashboard) for both experiences.

## Not built yet, worth building

- **A one-time Starter Pack** in every game (a pass or once-only product at
  49 to 99 with a bundle of currency plus a boost). It is usually a
  simulator's best-converting first purchase. Each game needs a grant and a
  "bought once" check, so it ships as its own change.

## Every item

<!-- pricing-table:begin (generated by `lune run tools/pricing/run`; edit the game configs, not this table) -->
| Game | Key | Type | Name on Roblox | Robux | Tier | In shop now | Description |
| --- | --- | --- | --- | ---: | --- | --- | --- |
| Hatchery Heist | AutoCollect | Game Pass | Auto-Collect | 99 | Medium | Yes | Your earnings flow into your coins by themselves. No more trips to the collect pad. |
| Hatchery Heist | ExtraIncubators | Game Pass | Extra Incubators | 99 | Medium | Yes | Two more incubators, so you can hatch more eggs at once. |
| Hatchery Heist | DoubleCoins | Game Pass | Double Coins | 149 | Capacity | Yes | Every creature you own earns twice as many coins, forever. |
| Hatchery Heist | CoinPackSmall | Developer Product | 5K Coins | 25 | Impulse | Yes | 5,000 coins, added right away. |
| Hatchery Heist | FinishMerge | Developer Product | Finish Merge | 25 | Impulse | Yes | Finishes your creature merge right now. |
| Hatchery Heist | InstantHatch | Developer Product | Instant Hatch | 25 | Impulse | Not yet | Finishes hatching an egg right now. |
| Hatchery Heist | LuckBoost | Developer Product | Luck Boost | 49 | Boost | Not yet | Better odds of Rare and rarer hatches for 15 minutes. The boosted odds are shown. |
| Hatchery Heist | PremiumEgg | Developer Product | Premium Egg | 49 | Boost | Not yet | One Premium Egg, with a chance at a Phoenix or the Godly Golden Goose. Exact odds are shown before you buy. |
| Hatchery Heist | ShieldRefill | Developer Product | Shield Refill | 49 | Boost | Yes | Shields your base for 10 more minutes. Raiders can't get in while it's up. |
| Hatchery Heist | CoinPackMedium | Developer Product | 30K Coins | 99 | Medium | Yes | 30,000 coins, added right away. |
| Hatchery Heist | CoinPackBig | Developer Product | 80K Coins | 199 | Power | Yes | 80,000 coins, added right away. |
| Hatchery Heist | CoinPackLarge | Developer Product | 200K Coins | 399 | Large | Yes | 200,000 coins, added right away. The best value per Robux. |
| Tidecatch Cove | AutoReel | Game Pass | Auto-reel | 149 | Capacity | Yes | Bites reel themselves in at an average player's success rate. Skill still pays. |
| Tidecatch Cove | ExtraPools | Game Pass | Extra Pools | 149 | Capacity | Yes | More tide pools, so you can raise more creatures at once. |
| Tidecatch Cove | SellMultiplier | Game Pass | Sell Multiplier | 199 | Power | Yes | Every creature you sell pays double, forever. |
| Tidecatch Cove | BaitPack | Developer Product | Storm Lure Pack | 25 | Impulse | Yes | 4 Storm Lures: strong bait for rare fish. Each cast's exact odds show on the dock. |
| Tidecatch Cove | MysteryBait | Developer Product | Mystery Bait | 25 | Impulse | Yes | A random bundle of Storm Lures or Pearl Lures. Exact odds are shown before you buy. |
| Tidecatch Cove | RestockSkip | Developer Product | Restock Skip | 25 | Impulse | Yes | The bait shop restocks for you right now. |
| Tidecatch Cove | GrowthBoost | Developer Product | Growth Boost | 49 | Boost | Yes | Every creature in your pools grows one stage right now. |
| Street Food Empire | AutoCollect | Game Pass | Auto-Collect | 99 | Medium | Yes | Your register empties into your cash by itself. No more trips to the register. |
| Street Food Empire | FestivalBundle | Game Pass | Festival Bundle | 99 | Medium | Not yet | Festival decorations and outfits for your food empire. |
| Street Food Empire | DoubleCash | Game Pass | 2x Cash | 199 | Power | Yes | Every sale pays double, at the counter and from your cooks, forever. |
| Street Food Empire | CashPackSmall | Developer Product | 5K Cash | 25 | Impulse | Yes | 5,000 cash, added right away. |
| Street Food Empire | InstantBuild | Developer Product | Instant Build | 25 | Impulse | Not yet | Finishes the station you're building right now. |
| Street Food Empire | SpeedBoost | Developer Product | Speed Boost | 49 | Boost | Yes | Customers come twice as fast for 15 minutes. Buying again adds more time. |
| Street Food Empire | CashPackMedium | Developer Product | 50K Cash | 99 | Medium | Yes | 50,000 cash, added right away. |
| Street Food Empire | CashPackLarge | Developer Product | 600K Cash | 399 | Large | Yes | 600,000 cash, added right away. The best value per Robux. |
| Depthbound | AutoSell | Game Pass | Auto-Sell | 99 | Medium | Yes | Your pack sells by itself the moment you're out of the mine. |
| Depthbound | BetterLamp | Game Pass | Better Lamp | 149 | Capacity | Yes | Your lamp holds more oil, so every dive lasts longer. |
| Depthbound | BiggerPack | Game Pass | Bigger Pack | 149 | Capacity | Yes | Carry more ore on every dive. |
| Depthbound | OilRefill | Developer Product | Oil Refill | 25 | Impulse | Yes | Fills your lamp mid-dive. One per dive; bought at camp, it waits for your next dive. |
| Depthbound | GeodeCrate | Developer Product | Geode Crate | 49 | Boost | Not yet | One random geode. Exact odds are shown before you buy. |
| Depthbound | OreBoost | Developer Product | Ore Boost | 49 | Boost | Yes | Ore sells for double for 15 minutes. Buying more adds time. |
<!-- pricing-table:end -->
