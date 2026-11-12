# #184 at 44f6fe8b (tower signs polish, issue #183): FAIL on check 1 at phone size (price sign hidden behind the HUD GOAL banner); checks 2-5 PASS, with 1 NOTE

Build: `git checkout --detach 44f6fe8b36d31703585ea8303784dab1773ea545`, then `BUILD_ENVIRONMENT=staging tools/build.sh hatchery-heist`. Output reads "core started build=44f6fe8b36d3".
- I opened the local .rbxl in Studio, not the cloud place.
- I drove it only through the Studio MCP, in play-solo: desktop 1350×672, plus a phone pass at 844×392 (Studio window resized).
- This is a fresh save on floor 1, so the next floor to buy is floor 2.

## Placement read from the live place

- **Floor2.PriceSign:** an anchor at (100.5, 17.8, 0), 6.5 studs in front of the front wall (outer face x ≈ 107) and above the roof. Its billboard is 32×2.2 and reads "Floor 2: 20K coins".
- **Floor1.Plaque:** at (100.5, 10.8, 0), 12×1.8, reading "1. Cozy Studio  x1.00". Floors 2 and up have no plaque until they are built.
- **RebirthStand:** a 4×6×4 Part at plot-local x = **29**. Its half-width of 2 puts its outer face at 31, inside the 32-stud edge. The label reads "Rebirth: 50M coins", 8×1.6, 4.5 studs above the stand.

## Check 1: price sign: desktop PASS, phone FAIL

- **Desktop, from the yard:** "Floor 2: 20K coins" reads whole at 0° (pr184-yard-0deg.jpg), 30° (pr184-yard-30deg.jpg), −60° (pr184-yard-minus60-low.jpg, -minus60-high.jpg) and +60° (pr184-yard-plus60-low.jpg). It hangs clear in front of the roof.
- **Hidden from spawn, by design:** confirmed. A ray from the plot spawn (134, 8, 0) to the sign is blocked by Floor2.Deck. From the yard in front of the tower the sign is in view.
- **Phone 844×392: FAIL.**
  - The onboarding **GOAL banner** ("Walk to the Egg Market…") and the coin box sit in the top band of the screen. The sign projects into that band from every yard camera I tried:
    - low and close (pr184-phone-0deg-low.jpg): only the top of "Floor 2: 20K coins" peeks out above the banner;
    - third-person height (pr184-phone-0deg.jpg): behind the banner, visible only faintly through its translucent background;
    - 39 studs back (pr184-phone-far.jpg): fully behind the banner.
  - The GOAL banner shows during onboarding, which is exactly when the floor-2 price matters.
  - Possible fixes: hang the price sign lower (in front of the floor-1 roof band), shrink or hide the GOAL banner on small screens, or move the HUD.

## Check 2: floor-1 plaque: PASS (front), NOTE (side)

- From the front, "1. Cozy Studio  x1.00" reads whole, like the upper floors' plaques (pr184-yard-0deg.jpg), and also at 30° (pr184-yard-30deg.jpg).
- **NOTE:** at about 60° to either side, the ground-floor door awning (and the tower's front corner) cut the start or end of the label:
  - "Cozy Studio x1.00" at −60° (pr184-yard-minus60-low.jpg, -minus60-high.jpg);
  - "1. Cozy Studio x1.0…" at +60° (pr184-yard-plus60-low.jpg).
- The plaques on floors 2 and 3 stayed whole at ±60° in the #179 re-gate. Floor 1's plaque sits lower, at the awning's height.

## Check 3: rebirth sign: PASS

- "Rebirth: 50M coins" reads whole from the yard side (pr184-rebirth-yard.jpg) and from behind the stand (pr184-rebirth-behind.jpg). Before this PR it was cut to "Rebirth: 50M coi".
- The stand is inside the plot fence and does not poke through the 32-stud edge.

## Check 4: rebirth stand: PASS

- 10 approaches: I walked away to (96, 3, −20) and back to (112, 3, −29), then held E for 2.3 s each time.
- The Rebirth prompt appeared **10/10**. Each use answered "Not enough coins to rebirth." (with 200 coins nothing was reset; rebirths stayed 0).
- No errors.

## Check 5: panels and Output: PASS

- Book, Tower, Creatures, Daily, Shop, Feedback and Guide were each opened and then closed with their X (Guide: "Let's go!") in **first person**.
- For all 7, the cursor was freed while the panel was open, the panel closed, and the mouse re-locked.
- **Output:** 0 errors on the client and the server.

**Output log tail.**
- Client: 122 lines, all MessageWarning. These are engine "ContentId … No asset content representation found" fetch notices, plus the Studio MCP's "The execute_luau changed camera type" notices.
- Server: Warning 115, Output 3, Info 2, 0 errors. The lines were:
  - [profilestore]: Roblox API services unavailable - data will not be saved
  - [Stores] DataStores unavailable … store=ErrorQueue
  - [Stores] DataStores unavailable … store=Feedback
  - [TestPanel] Studio test panel is on
  - [CoreServer] core started build=44f6fe8b36d3 game=hatchery-heist studio=true
