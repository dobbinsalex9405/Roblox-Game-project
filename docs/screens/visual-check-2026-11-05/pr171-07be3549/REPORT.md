# #171 at 07be3549 (creature models turned back the right way round): PASS

Build: `git checkout --detach 07be3549c21a2c60a15e3d12f07aa99dbfc0e53d`, then `BUILD_ENVIRONMENT=staging tools/build.sh hatchery-heist`. Output reads "core started build=07be3549c21a".
- I opened the local .rbxl in Studio, not the cloud place.
- I drove it only through the Studio MCP, in play-solo at desktop size.

## Attributes on the species models (ReplicatedStorage.CreatureMeshes, all 530 loaded)

| Species | ImportYaw | ImportFit (studs) |
|---|---|---|
| AlleyCat | 3.14159 (π) | 0.000067 |
| Quail | π | 0.000067 |
| Peachick (batch 13) | π | 0.000050 |
| Kiwi (batch 13) | π | 0.000060 |
| SeaOtter (batch 13) | π | 0.000072 |
| SharkPup (batch 13) | π | 0.000071 |
| RoboPup (batch 13) | π | 0.000065 |
| Llama | π | 0.000028 |
| Dachshund | π | 0.000056 |
| PolarBearCub (batch 13) | π | 0.000064 |

- Across all 530 species, ImportYaw = π (3.142) on **530/530**.
- 198 species have ImportFit above the 0.01 tolerance; these are the old posed uploads (see check 5).

## Check 1: 10 species on pads, front-left close shots: PASS (10/10)

For each species I checked, from the body's centre, where the head, eyes, ears and tail sit relative to the model's forward. I also took a close front-left shot that follows the creature.

| Species | Face/eyes on front | Ears on top | Tail at back | Legs under, feet near pad | Shot |
|---|---|---|---|---|---|
| AlleyCat | yes | yes | yes | yes | pr171-alleycat.jpg |
| Quail | yes (beak and belly front) | n/a | yes | yes | pr171-quail.jpg |
| Peachick | yes | crest on top | yes | yes | pr171-peachick.jpg |
| Kiwi | yes (beak front) | n/a | n/a | yes | pr171-kiwi.jpg |
| SeaOtter | yes (floats on its back, face on its leading end) | n/a | yes | n/a | pr171-seaotter-sharkpup.jpg |
| SharkPup | yes (snout and eyes front) | n/a | yes (tail fin back) | n/a | pr171-seaotter-sharkpup.jpg |
| RoboPup | yes (visor front) | yes (antenna and ears) | yes | yes | pr171-robopup.jpg |
| Llama | yes | yes | yes | yes | pr171-llama.jpg |
| Dachshund | yes | yes | yes | yes | pr171-dachshund.jpg |
| PolarBearCub | yes | yes | n/a | yes | pr171-polarbearcub.jpg |

Measured: the head lies along the walking direction and the tail opposite it, for every species with those pieces.

## Check 2: walkers: PASS

I sampled each creature 100 times over 10 s (about 10 strides for the faster walkers).

| Species | Travelled | Head leads the motion | Worst leg outside the body's width | Worst foot gap |
|---|---|---|---|---|
| Peachick | 15.3 studs | 46/47 | 0.00 | 0.50 |
| Kiwi | 8.0 | 24/24 | 0.00 | 0.10 |
| RoboPup | 7.5 | 27/27 | 0.00 | 0.50 |
| Quail | 7.1 | 23/23 | 0.00 | 0.49 |
| PolarBearCub | 6.1 | 19/19 | 0.00 | 0.11 |
| Llama | 5.2 | 18/18 | 0.00 | 0.48 |
| Dachshund | 4.3 | 16/16 | 0.00 | 0.09 |
| AlleyCat | 0.5 | 2/2 | 0.00 | 0.09 |

- Overall the head leads in **175/176** moving samples. No leg ever sits outside the body's width, so the hips are at the body and not floating beside it.
- A foot gap of at most 0.5 studs is the lifted foot mid-stride.
- Side shots: pr171-walk-peachick-kiwi.jpg, pr171-walk-robopup.jpg, pr171-walk-polarbear.jpg. Each shows the head leading and the legs under the body.

## Check 3: hatch reveal: PASS (11/11 faces forward)

- I hatched 10 Basic eggs: Cockatoo, Chameleon, MuddyPiglet, Ram, TuxedoKitten, Bunny, BlackLamb, Quail, HuskyPup, Chipmunk.
- In each, the angle between the creature's head and eye direction and the reveal camera was **11 to 13°**; it faces the camera, not its back.
- An 11th hatch (Bantam) read 15° (pr171-reveal-bantam.jpg: face and beak toward the viewer).

## Check 4: other places a creature is drawn: PASS

- **Book:** uses pre-rendered thumbnail pictures (144 on screen, 0 live ViewportFrames), so this PR does not touch it. The found creatures (Bunny, Hamster…) show their faces (pr171-book.jpg).
- **Creatures panel:** text rows only; no creature model is drawn.
- **Riding:** I rode the RoboPup. The mount's head points the same way as the character (**0°**), and it sits 5.3 studs under the rider (pr171-ride-robopup.jpg).
- **Hatch reveal:** see check 3.

## Check 5: panels and Output: PASS

- **Panels:** Book, Creatures, Tower, Shop and Feedback were each opened, then closed with their X in **first person**. For all 5, the cursor was freed, the panel closed and the mouse re-locked.
- **Errors:** 0 on the client (113 warnings, all engine ContentId notices) and 0 on the server.
- **"creature meshes do not sit where CreatureMeshes lists them": 198 warnings.** This matches the expected ~199 old posed uploads.
  - The warned set is exactly the 198 species with ImportFit > 0.01; none is warned without its own fit reading.
  - **No batch-13 species is among them**, and none of the 10 test species.
  - No species list ships with the repo, so I couldn't compare name by name against the 199 the detector found. The 1 difference is the count only.
  - Full list: AbyssJelly Acornling AmberAnt Angelfish AngoraBunny Ant Aphid AtlasMoth AuroraStag BabyKraken BabyOctopus BarnSwallow Beetle BelugaCalf BlazeBunny BlossomBee BlueTang Bobble Bramblet BrassDragonfly BreezeFinch BubblePup Bullfrog Bumblebee Bunny Bunnyfly Butterfly ButterflyEmpress CandyColossus Carrotling Centipede ChronoOwl Cicada CinderCrab ClickBeetle ClockworkBeetle ClockworkLeviathan ClockworkOwl CloudSerpent Cloudlet Clownfish CobwebSpider CocoaBunny Coneling Cornling CosmicWhale Crab Crayfish Cricket CrystalCrab CrystalHydra CrystalSwan Damselfly DandelionPuff DartFrog DiamondBeetle DivingBeetle DolphinCalf DonutSeal Dragonfly Ducktopus DustBunny DutchBunny Eaglet EclipseDragon FiddlerCrab FireAnt Firefly FlameMoth FlowerCrab Fluffernut FlyingSquirrel Frog FrostOwl FrostSprite FruitBat Fuzzball GalaxyOwl GardenSpider GargoylePup GeodeCrab GhostMoth GhostOwl Ghostling GlacierSeal GlasswingButterfly GoldenGoose Goldfish Grasshopper Gumball HerculesBeetle HermitCrab Hippocampus HoneypotAnt Hornbill Hoverfly Hummingbird HurricaneRoc HydraHatchling IceSpider IcicleBat Jackalope JellySlime JellybeanBeetle Jerboa JewelBeetle JumpingSpider KangarooJoey Koi Ladybug Lampwick LanternFrog LanternMoth LeafAnt LeafBat LightningBug Lionfish LionheadBunny Lobster LopBunny LunaMoth MagmaBehemoth MagmaToad ManateeCalf MantaRay Mayfly MechaDragon MimicChest MochiBunny Monarch MoonBunny Mossling Moth Mushling Narwhal NebulaSerpent NeonOctopus OmegaChimera OpalFrog OrigamiFrog PacmanFrog PaperCrane Peapod Pebblet PegasusFoal PetalSprite Phoenix PhoenixChick PillBug PrismAlicorn Puddle Puddlejumper Pufferfish Radishling RainFrog RhinoBeetle SandSerpent SeaSerpent Seahorse SelkiePup ShieldBug Shrimp ShroombackToad SnowHare SnowflakeMoth SolarLion SparkBeetle Sproutling Squid StagBeetle StarFinch StarJelly StarWhaleCalf StickInsect StormCrow SunParrot Tadpole Tardigrade Tarsier Termite ThreeEyedFrog ThunderBunny ThunderGriffin ThunderKraken Thunderbird TidalOtter Toad TreasureCrab TreeFrog TreeKangaroo Turnipling VoidKitsune Wallaby Wasp WaterStrider Weevil WillOWisp WorldTurtle

**Output tail (server).**
- [profilestore]: Roblox API services unavailable - data will not be saved
- [Stores] DataStores unavailable … store=ErrorQueue
- [Stores] DataStores unavailable … store=Feedback
- [TestPanel] Studio test panel is on
- [CoreServer] core started build=07be3549c21a game=hatchery-heist studio=true
- Plus 198 "creature meshes do not sit…" warnings and engine ContentId notices. 0 errors.
