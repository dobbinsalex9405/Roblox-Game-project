# #177 at e46f6021 (go-live batch 13: 21 new Rares): PASS for the creatures (rows 1-4); row 5 not applicable on this base

Build: `git checkout --detach e46f60216d1bc89bcd8038efd52af304aa2791b3`, then `BUILD_ENVIRONMENT=staging tools/build.sh hatchery-heist`. Output reads "core started build=e46f60216d1b".
- I opened the local .rbxl in Studio, not the cloud place.
- I drove it only through the Studio MCP, in play-solo.
- I gave the 21 with the test panel 7 s into play, onto floors 1 to 3 (I bought floors 2 and 3).
- At that moment CreatureMeshes held 145 of 530 models and none of the 21. Raw numbers are in output-log.txt.

## Row 1: the 21 creatures: PASS

How to read the table:
- **Meshed:** seconds from the give until the creature drew with MeshParts.
- **Texture:** textured MeshParts whose texture loaded (ContentProvider: Success).
- **One piece:** the part boxes form one connected group.
- **Glow:** Neon material, a light, a particle emitter, a highlight, a beam or a trail.
- **Gap:** the lowest mesh point above the surface under it.
- **Facing:** movement against facing over 10 s.

| Species | Meshed | Texture | One piece | Glow | Gap | Legs / shape | Facing | Notes |
|---|---|---|---|---|---|---|---|---|
| Kiwi | 16.9 s | 5/5 | yes | none | 0.03 | legs under | forward 5/5 | |
| OrchidMantis | 21.7 s | 8/8 | yes | none | 0.05 | legs under | forward 18/21 | |
| PancakeFrog | 22.2 s | 10/10 | yes | none | 0.07 | squat frog | forward 11/16 | |
| Peachick | 22.0 s | 8/8 | yes | none | 0.03 to 0.44 | legs under, walking | forward 47/47 | The 0.44 reading came from the deck, after it stepped off its pad. |
| PetalBunny | 21.4 s | 10/10 | yes | none | 0.10 | legs under | forward 21/21 | |
| PolarBearCub | 23.6 s | 9/9 | yes | none | 0.10 | legs under, walking | forward 25/25 | |
| PomPom | 21.2 s | 6/6 | yes | none | −0.34 | feet under | forward 7/8 | The feet dip about 0.3 into the pad top. Barely visible: the feet show (pr177-pompom-pterochick.jpg). NOTE |
| PteroChick | 23.1 s | 5/5 | yes | none | 0.00 | crouched, wings spread | forward 9, side 9 | Side-to-side sway (see Facing below) |
| Rabbeetle | 23.6 s | 11/11 | yes | none | 0.46 off pad | legs under | forward 23/23 | |
| RainSnail | 23.3 s | 5/5 | yes | none | 0.07 | snail | forward 24/24 | |
| RaptorChick | 23.3 s | 7/7 | yes | none | 0.04 | upright, legs under | forward when travelling | Sways ±90° while stepping in place (see Facing below) |
| ReindeerCalf | 23.0 s | 10/10 | yes | none | 0.09 | legs under, walking | forward 21/21 | |
| RexHatchling | 22.8 s | 6/6 | yes | none | 0.04 | legs under | forward when travelling | Sways as RaptorChick does |
| RhinoCalf | 22.9 s | 10/10 | yes | none | 0.07 | legs under | forward 28/28 | |
| RoboPup | 23.4 s | 10/10 | yes | none | 0.03 | legs under | forward 22/22 | |
| SandCat | 23.6 s | 9/9 | yes | none | 0.09 | legs under, walking | forward 30/31 | |
| Scorpion | 23.1 s | 13/13 | yes | none | 0.03 | legs under | forward 13/13 | |
| SeaOtter | 23.6 s | 7/7 | yes | none | 0.09 | floats on its back (by design) | forward 7/7 | |
| SharkPup | 24.6 s | 7/7 | yes | none | 0.11 | fins | forward 16/16 | |
| Slugcorn | 25.9 s | 4/4 | yes | none | 0.00 | slug | forward 23/23 | |
| SnowLamb | 26.5 s | 9/9 | yes | none | 0.46 off pad | legs under, mid-stride | forward 16/19 | |

- **Meshes:** all 21 drew with meshes within **16.9 to 26.5 s** of the give, under 30 s, even though none of their models had arrived at the give. None stayed on boxes, so no manual preload was needed.
- **Textures:** every MeshPart is textured and loaded; none is grey.
- **Shape:** every creature is one piece. None glows.
- **Facing:**
  - Each species' head lies along its model's forward (yaw −11° to +8°), and they walk head-first.
  - There is **no 180° turn** on any of them.
  - RaptorChick, RexHatchling and, less so, PteroChick show "sideways" samples. Step by step these alternate +90°/−90° while stepping in place: a side-to-side waddle of the body. While actually travelling the angle is 0 ± 30°.
  - RaptorChick standing upright with its legs under it is in pr177-robopup-raptorchick.jpg.
- **Screenshots:** every species is shown.
  - Caught while walking: SnowLamb (mid-stride), Peachick, SandCat, ReindeerCalf, PolarBearCub and Rabbeetle (all moving in the 10 s sample).
  - Files: pr177-rainsnail-raptorchick, -rhinocalf-rexhatchling, -polarbearcub-petalbunny, -kiwi-petalbunny-orchidmantis-pancakefrog, -pompom-pterochick, -reindeercalf-sandcat-robopup, -robopup-raptorchick, -rabbeetle, -snowlamb-scorpion, -sharkpup-slugcorn, -seaotter, -peachick, -f2-overview.

## Row 2: Book: PASS

- The Book reads "Found 21/530", with the Rare tab at **21/81**.
- All 21 cards show the right name, a NEW badge, the Rare border colour (3fa9f5) and a picture. All 21 pictures were loaded after scrolling; Peachick and Polar Bear Cub were last.
- The 12 Meadow species read "Meadow Egg 1 in 3,058" and the 9 Moonlit species read "Moonlit Egg 1 in 76.3".
- Screens: pr177-book-rare-top.jpg, pr177-book-rare-bottom.jpg.

## Row 3: odds: PASS

- **Meadow list:** 273 rows (was 261) summing to 100.0000%, Rare 52 (was 40).
  - The 12 new ones (Kiwi, OrchidMantis, PancakeFrog, Peachick, PolarBearCub, PomPom, ReindeerCalf, RhinoCalf, SandCat, Scorpion, SeaOtter, SharkPup) are listed under Rare at "0.0327% · 1 in 3,058".
- **Moonlit list:** 167 rows (was 158) summing to 100.0000%, Rare 29 (was 20).
  - The 9 new ones (PetalBunny, PteroChick, Rabbeetle, RainSnail, RaptorChick, RexHatchling, RoboPup, Slugcorn, SnowLamb) are listed under Rare at "1.31034% · 1 in 76.3" (pr177-odds-moonlit.jpg).
- **Cards:** Meadow 100.0000% and Moonlit 100.0000%. The Basic card is unchanged at 92.0018 / 6.9996 / 0.7986 / 0.1800 / 0.0180 / 0.0020 = 100.0000%.

## Row 4: sanity: PASS

- Feedback button visible.
- 0 script errors (client and server).
- **0** CreatureView or CreatureAssets warnings on the client or the server.

## Row 5: #172/#174/#175 behaviour: NOT APPLICABLE on this head

This head's base, cb639e39, predates #175 (cc9ec59), #174 (c54e6ce) and #172 (9de8f84). `git merge-base --is-ancestor` confirms none of the three is in the head. As expected for that base, the incubator egg is the old ball. These checks belong to the re-check after the remerge.

Screens: 16 .jpg in this folder.
