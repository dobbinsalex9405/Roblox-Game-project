# Hatchery Heist: store page

What players see before they press Play. Images are made centrally
(`tools/store-art`) so all games match the Loop Lab Games style. Title and
description changes on a live game need Alex's OK.

## Title

**Hatchery Heist: Steal & Ride Pets 🥚** (36 characters; Roblox allows 50)

The subtitle puts the searched words ("steal", "pets") in the title. Short
form if it is ever needed: **Hatchery Heist 🥚**. Check for name collisions on
Roblox before launch (M7).

## Description

Paste as is. Every line describes something the game has today (M2 + M4).
Add a line for passes or products only once they are on sale (M5).

```
Hatch eggs, ride your pets, and steal the rarest creatures from rival bases!

🥚 Buy eggs off the conveyor and hatch 8 creatures, from Chicks to the Legendary Phoenix
💰 Creatures on your pads earn coins every second, and keep earning while you're away
🐉 Ride any creature you own. Rarer pets run faster
🦹 Sneak into rival bases and carry their creatures home before you get caught
🛡️ Defend your base with a shield, traps, decoy eggs and a guard pet
🔁 Rebirth for +25% coins on every rebirth
🎲 Every egg shows its exact odds before you buy

New players get 5 minutes of raid protection to set up their base.

Made by Loop Lab Games. Tap the Feedback button in-game and tell us what to hatch next!
```

(About 690 characters. Drop the Feedback line if the feedback button is not
live yet.)

## Images

In `store/`, rendered from `tools/store-art/src/hatchery-heist/`:

- **Icon**: a sneaky masked Dragonling hatching from a cracked egg, coins
  flying. The masked Dragonling is the game's mascot.
- **Thumbnail 1, "the heist"**: a masked raider runs off with a Legendary
  Phoenix while the owner chases on their Dragonling. RAID! alarm, logo,
  "HATCH · RIDE · STEAL".
- **Thumbnail 2, "hatch it, ride it"**: a golden egg on the conveyor hatches
  a Phoenix; a player rides a Dragonling.

Creature names and rarities match `config/creatures.luau`.
