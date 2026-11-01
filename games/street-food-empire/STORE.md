# Street Food Empire: store page

What players see before they press Play, and the art brief for the store
images. Images are made centrally (thread "Make store art for every game") so
all four games match the Loop Lab Games emblem style. Title and description
changes on a live game need Alex's OK.

## Title

**Street Food Empire 🌭** (20 characters; Roblox allows 50)

Spare if testing a second title: **Street Food Empire: Cart Tycoon 🌭**

## Description

Paste as is. Every line describes something in the game today; add the
passes and products lines only once they are on sale.

```
Start with one hot dog cart. End with a whole food street!

🌭 Serve the line at your counter for big tips
🍋 Build 12 food stations: lemonade, tacos, noodles, sushi and more
⬆️ Upgrade every station so each dish sells for more
👨‍🍳 Hire cooks who keep selling, even while you're offline
🏙️ Grow from Cart Corner to Market Row to Downtown
🔁 Rebirth for +50% cash on every sale

New here? Follow the gold arrow: it shows you your next goal.

Made by Loop Lab Games. We update constantly and read every piece of
feedback, so tell us what to cook next!
```

## Art brief

**The hook in one line:** a tiny food cart that grows into a busy food street.

**Style:** the Loop Lab Games emblem (`branding/emblem.svg`): flat vector
shapes, thick rounded outlines in off-white `#EAF2FF`, soft gradients, a deep
indigo radial background (`#2E3380` to `#0D1020`), warm orange-gold accents
(`#FF8A3D` to `#FFD23F`) and cyan highlights (`#7CF0FF` to `#1FB5E8`). No
text on the icon. Bright and readable at phone size.

**Icon (512×512):** one big hot dog cart, three-quarter view, filling most of
the frame. Red-and-cream striped awning, a gold rim, a hot dog with mustard on
top, a puff of steam and two or three gold coins popping out. The emblem's
orange-gold loop arrow can sit behind it as a ring, so it reads as a Loop Lab
game. It has to read at 50 px: the cart and the coins, nothing small.

**Thumbnails (1920×1080, text no larger than a third of the frame):**
1. *Grow it.* Left: the single cart. Right: the same plot full of stations
   under three district signs (Cart Corner, Market Row, Downtown). A gold
   arrow between them. Caption: "CART TO EMPIRE".
2. *Serve the line.* A long queue of blocky customers at a counter, "+$"
   pops above them, the player in front. Caption: "SERVE THE RUSH".
3. *Cooks earn for you.* Cooks at taco, noodle and sushi stations, a
   register overflowing with coins, a moon in the sky (they earn offline).
   Caption: "COOKS EARN WHILE YOU'RE AWAY".

Avoid: real brands or logos, Robux symbols, "free Robux" style claims, and
anything the game doesn't have yet (no festival, no pets).

## First 60 seconds (hook review)

What a new player does, from the guide timeline in `tests/Guide.spec.luau`
(simulated attentive player):

| Time | What happens | Guide line |
| --- | --- | --- |
| 0 s | Spawns by their plot; the cart is already open | "Your food cart is open. Customers are on their way!" (arrow on the counter) |
| 5 s | First customer arrives | "A customer is waiting! Serve them at the counter." |
| ~6 s | First serve pays $6 | Next goal: build a Lemonade Stand ($30, affordable at once) |
| ~20 s | Upgrades the Hot Dog Cart | "Serve customers… Upgrade your Hot Dog Cart: $31 / $60" |
| ~50 s | Hires the first cook | "Hire a cook: $x / $100" |
| 1–14 min | A new small goal every 20–40 s (station, upgrade or cook) | Points at the spot, or at the register when it holds enough |
| ~14.5 min | Opens Market Row | Guide ends |

Before this change the first minute had no direction: the counter's prompt
only shows within 10 studs, and spawn is about 30 studs away. The guide line
and the gold arrow and beam now point at the next thing to do.
