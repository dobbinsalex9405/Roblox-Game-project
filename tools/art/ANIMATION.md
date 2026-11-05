# Creature animation: rig and gait conventions

Read this before modelling a new creature. Every creature must be able to
walk in the game (Alex, Nov 5: "legs move, not tilt"). The game's walk is
`games/hatchery-heist/src/shared/Walk.luau`; the design viewer's walk clip
is the same maths (`tools/art/blender/walkpose.py`, checked by
`tests/WalkMirror.luau`). You do not write animation code: you name parts
and pick a gait, and both the game and the viewer animate them.

Until PR #74 merges, branch new creature work from
`claude/project-thread-cgk37d` (it carries `rig.leg_part` and the leg,
wing and fin conventions below).

## 1. Parts that move, and their names

Each moving piece is its own part; its name is also its anim. Positions are
voxels, x right, y back (front is -y), z up; L is at negative x.

| Part | Names | Pivot (hinge) |
|---|---|---|
| Four legs | `legFL` `legFR` `legBL` `legBR` | the hip: middle of the leg's top, where it meets the body |
| Two legs (birds, upright) | `legL` `legR` | the hip |
| Bug, crab, spider legs | `leg1L` .. `leg6L`, `leg1R` .. `leg6R`, front to back | the hip |
| Wings | `wingL` `wingR` | the shoulder |
| Tail | `tail` | its root |
| Fins (fish) | `finL` `finR` | the root; `tail` is the tail fin |
| Head, ears | `head`, `ears` | neck / crown |
| Orbiting extras (Godly) | `orbit` | the centre it turns about (vertical axis, one turn per 9 s) |

Everything else (`shell`, `crest`, `spines`, `mane`, accessories) is static
and rides the part it touches.

**How to make legs:**

- If your body plan knows where the legs are, draw each leg straight into
  its own part: `rig.leg_part(c, 'L' or 'R', i, n, hip)` gives the part for
  leg `i` (0 = front) of `n` on that side, named as above. `kit_pond.legs(...,
  c=c)` and `kit_pond.bent_legs(..., c=c)` already do this for rods and
  arched bug legs.
- Otherwise draw legs into the body and `rig.split_legs` finds them after
  the build (it works for quadrupeds and lizards with separate feet on the
  ground). It skips any creature that already has leg parts.
- **Legs must be visible to step.** A leg of one or two voxels does not read
  as walking. Birds in the finer build stand on short legs (`bird_legs`).
  Raise a body that sits flat on the ground a few voxels (ladybug, pill
  bug) so its legs show.
- The body keeps any voxel it shares with a leg or wing, so a swinging limb
  never opens a hole. Draw legs from inside the body outward.
- Small wings folded on a body: make them `wingL`/`wingR` parts holding only
  the voxels outside the body (see `bird`).
- Every leg on the left needs its mirror on the right (the specs check).

## 2. Gaits

`CreatureMeshes.gait`, from `rig.gait(c)`. Pick by setting `SPECIES_GAIT`
(hand-made creatures) or `KIND_GAIT` (roster kinds) in `rig.py`, or
`c.gait_hint` in a body plan.

| Gait | For | What moves |
|---|---|---|
| `trot` | four-legged animals, lizards | diagonal leg pairs; body dips to keep feet planted; tail and ears swing |
| `waddle` | two-legged birds, seals, penguins | legs alternate; body rolls; head pecks; folded wings flick out |
| `hop` | bunnies, frogs, grasshoppers | all legs kick back and tuck; body arcs, 60% of the cycle in the air |
| `scuttle` | bugs, crabs, spiders, turtles, axolotls | numbered legs swing about the vertical axis in two alternating sets, lifting as they reach; four-leg sprawlers swing like a trot |
| `slither` | worms, slugs, snails, caterpillars, starfish | no legs: a gentle body sway and surge, head and tail follow |
| `hover` | **every Legendary and Godly** (automatic, unless `swim`), bees, butterflies, moths, dragonflies, fireflies, bats | body leans and bobs, wings beat faster, legs trail and paddle, tail streams and sways |
| `swim` | fish, whales, rays, jellyfish, octopus-in-the-air: anything with fins or a tail fin and no legs | tail sweeps, `finL`/`finR` paddle in turn, body sways. The game plays it (Walk.pose + CreatureView), so judge it like any gait |

### Rulings for new body plans

- **Legendary and Godly** always float in the game, so their gait is `hover`,
  or `swim` when the sheet says swim (drakes, dinos and griffins hover with
  legs trailing; whales, rays, fish and sea serpents swim). Never `trot`.
- **puff** (round, legless): `hop` with no leg parts; the body bounces.
  With little feet as parts, `hop` still, feet as `legL`/`legR`.
- **bat**: `hover`; wings `wingL`/`wingR`, feet `legL`/`legR` hanging below.
- **jelly**: `swim`; tentacles are the `tail` (one part) so they sweep;
  bell edges can be `finL`/`finR`.
- **octopus**: `scuttle` on its arms, arms as `leg1L`..`leg4R` (4 a side),
  hinged at the body; or `swim` if it has no arms on the ground.
- **scorpion**: `scuttle`, eight legs `leg1L`..`leg4R`; claws and the tail
  are static parts riding the body (`tail` if it should sway).
- **fish** (Common/Uncommon/Rare): `swim`, body off the ground is fine (it
  bobs on its pad); `finL`/`finR` and `tail` as parts.
- **snake/serpent below Legendary**: `slither`, no legs, `tail` part.
- **upright** (stands on two legs like a person): `waddle`, legs `legL`/`legR`
  at least 3 voxels tall, arms static or `wingL`/`wingR` if they swing.
- Set the gait in the roster entry (`"gait"`) or `KIND_GAIT`; the sheet's
  gait wins except the Legendary/Godly rule above.

## 3. Check your creature before the PR goes ready

1. `python3 tools/art/blender/luau.py` and `lune run tools/test/run` pass
   (specs check anim names, mirrored legs, budgets).
2. Build it with clips: `PYTHONPATH=/opt/bpy python3 tools/art/blender/build.py
   out --only YourCreature --designs /mnt/project-files/designs` and look at
   `walk.gif`: legs visibly step, nothing detaches or leaves a hole, the
   body does not spin. The `.glb` carries `idle` and `walk` clips; the
   viewer plays them.
3. New anim names or a gait that does not fit: ask the thread "Animate the
   finished creature designs" first; do not add anims the game does not
   know (they would sit still).
