# #184 re-gate at 7b151117 (tower signs, phone fix): FAIL on check 1 (default 3rd-person camera on phone); checks 2-5 PASS

Build: `git checkout --detach 7b1511173c0c0a613f060cf44b49cf90b3623ee1`, then `BUILD_ENVIRONMENT=staging tools/build.sh hatchery-heist`. Output reads "core started build=7b1511173c0c".
- I opened the local .rbxl in Studio, not the cloud place.
- I drove it only through the Studio MCP, in play-solo, on a fresh save.
- Phone is 844×392 (Studio window resized); desktop is 1350×672.

## Layout read from the live place

| Sign | y | x (8.5 studs out from the wall) | Text | Size | Colour |
|---|---|---|---|---|---|
| Floor1.Plaque | 10.8 | 98.5 | "1. Cozy Studio  x1.00" | 12×1.8 | white |
| Floor2.PriceSign | 8.8 | 98.5 | "Floor 2: 20K coins" | 12×1.8 | gold (ffdc5a) |

The price sign hangs 2 studs under the top floor's plaque, as specified.

## Check 1: phone, GOAL banner showing: FAIL

| Camera | "Floor 2: 20K coins" | "1. Cozy Studio x1.00" | Shot |
|---|---|---|---|
| Yard, close (78, 6, 0) | whole, below the banner | **behind the GOAL banner** | pr184-phone-close.jpg |
| Default third person, 12.5 studs behind the player, about 20° down | **behind the coin box** (only a faint outline) | **behind the coin box** | pr184-phone-default-3rdperson.jpg |
| 39 studs back (60, 12, 0) | whole (small) | whole (small) | pr184-phone-39-back.jpg |

- The brief needs all three cameras whole, but at the default third-person framing both signs land in the HUD's top band (coin box plus GOAL banner).
- After buying floors 2 and 3 the signs are higher still: at the default framing on phone they are behind the HUD or above the screen (pr184-phone-default-after-floor3.jpg).
- **Why:** on a phone at this camera, everything above roughly the first-floor window line falls under the coin box and GOAL banner. Raising the signs by 8.5 studs moved them into that band rather than below it.
- **Possible fixes:** place the sign below the HUD band (lower on the facade, or on a post in the yard), or make the HUD top band smaller on phones.

## Check 2: desktop: PASS

- **0°:** both signs whole (pr184-desk-0deg.jpg).
- **30°:** both whole (pr184-desk-30deg.jpg).
- **−60°:** both whole. A turret post passes behind the "o" of "Studio", but every letter is visible (pr184-desk-minus60.jpg).
- **+60°:** both whole (pr184-desk-plus60.jpg). **The door awning no longer cuts the plaque**: the 44f6fe8b finding is fixed.
- **From the spawn side:** the tower's back wall hides the signs (pr184-spawn-side.jpg).
- **Near the pads:** the camera was too close to frame the signs, and the desk-30deg view already shows them from the yard. As billboards they are 6.5 studs or more above the floor and never in the player's face.

## Check 3: buying floors: PASS

- **Floor 2 bought:** "2. Book Nook x1.05" appears at y 22.8, and the price sign moves to "Floor 3: 100K coins" at y 20.8, under it (pr184-floor2-bought.jpg; the "Floor 2 built" toast briefly covers the new plaque).
- **Floor 3 bought:** "3. Plant Sunroom x1.30" appears at y 34.8, with "Floor 4: 500K coins" at y 32.8 under it (pr184-floor3-bought.jpg).
- On desktop at that framing the GOAL banner overlaps the floor-3 plaque.
- On phone: see check 1.

## Check 4: head height: PASS

- The lowest sign bottom is the floor-1 plaque, **8.9 studs** above the floor-1 walking height.
- The price signs, after the buys, are at 18.9 studs and up.
- Billboards don't collide, and none is at head height.

## Check 5: rebirth, panels, Output: PASS

- **Rebirth sign:** "Rebirth: 50M coins" reads whole from the yard (pr184-rebirth-yard.jpg); it is unchanged since 44f6fe8b, where it also read whole from behind.
- **Rebirth prompt:** shown 3/3. Each use answered "Not enough coins to rebirth."
- **Panels:** Tower, Book, Shop and Feedback each opened, then closed with their X in first person. For all 4 the cursor was freed, the panel closed and the mouse re-locked.
- **Errors:** 0 on the client (108 warnings, engine ContentId notices) and 0 on the server.

**Output tail (server).**
- [profilestore]: Roblox API services unavailable - data will not be saved
- [Stores] DataStores unavailable … store=ErrorQueue
- [Stores] DataStores unavailable … store=Feedback
- [TestPanel] Studio test panel is on
- [CoreServer] core started build=7b1511173c0c game=hatchery-heist studio=true
