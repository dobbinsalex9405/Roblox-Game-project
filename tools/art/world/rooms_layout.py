"""Where every floor's decor goes, upgrade by upgrade, and the check that
nothing is in the creatures' way (plans/hatchery-heist/apartment-upgrade-path.md).

    python3 tools/art/world/rooms_layout.py          # check, then write config/towerDecor.luau
    python3 tools/art/world/rooms_layout.py --check  # check only

Coordinates are a base's own studs, as the game uses them: X right, Z back
(the balcony and the farm are at -Z), Y up from the floor's walking height.
`yaw` is degrees about Y, Roblox's way: 0 faces -Z (out of the balcony),
-90 faces +X (into the room from the left wall), 90 faces -X, 180 faces +Z.

Rules (agreed with the polish and world threads):
- creatures wander in their pad cells, X -20..20, Z 0..20: only flat things
  (rugs, beds) go there, and ceiling lights hang above 8.5 studs;
- the elevator (X -24..-17, Z 17..24) and its door (Z 13..17 in front of it)
  and the ladder doorway (right wall, Z 12.5..16.5) stay clear;
- inner wall faces: back Z 22.0, left X -23.2, right X 23.2; walls 11.4 high;
- under a back-wall window (X -9, 3, 15, 4 wide, sill at 3.6) a prop stays
  under the sill; the little pictures at X -3 and 9 (Y 5 to 6.4) stay seen.
"""
import argparse
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))

import props  # noqa: E402
import decor  # noqa: E402,F401
import apartment  # noqa: E402,F401
import tower  # noqa: E402,F401
import rooms  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
OUT = os.path.join(ROOT, 'games', 'hatchery-heist', 'config', 'towerDecor.luau')

CEILING = 11.4
PADS = [(x, z) for z in (5, 15) for x in (-15, -5, 5, 15)]
LIGHTS = [(-15, 10), (-5, 10), (5, 10), (15, 10)]
GRID = (-20, 0, 20, 20)
ROOM = (-23.2, -2.4, 23.2, 22.0)
SHAFT = (-24, 17, -17, 24)
KEEP_OUT = {
    'elevator door': (-24, 13, -17, 17),
    'ladder door': (20, 11.5, 23.2, 17.5),
}
# The deck opening players climb through beside the ladder (Geometry.LADDER_HOLE_MIN/
# MAX: x 21..24, z 12.5..16.5 on floors 2 to 10). Nothing standing goes within
# 2 studs of it; flat beds and rugs (a player walks over them) keep half a stud.
LADDER_HOLE = (21.0, 12.5, 24.0, 16.5)
BACK_WINDOWS = (-9, 3, 15)
PICTURES = (-3, 9)

# Floor-level slots: centre X, Z, yaw, and the room each one has (X, Z).
SLOT = {
    'L1': (-21.7, 3.0, -90, 3.0, 4.8), 'L2': (-21.7, 7.9, -90, 3.0, 4.0),
    'R1': (21.7, 3.0, 90, 3.0, 4.8), 'R2': (21.7, 8.4, 90, 3.0, 5.4),
    'F1': (-10.0, -1.2, 180, 8.0, 2.2), 'F2': (0.0, -1.2, 180, 6.0, 2.2), 'F3': (10.0, -1.2, 180, 8.0, 2.2),
    'B1': (-14.0, 21.0, 0, 5.6, 2.0), 'B2': (-3.0, 21.0, 0, 5.6, 2.0), 'B3': (9.0, 21.0, 0, 5.6, 2.0),
    'W1': (-9.0, 21.0, 0, 4.4, 2.0), 'W2': (3.0, 21.0, 0, 4.4, 2.0), 'W3': (15.0, 21.0, 0, 4.4, 2.0),
    # plant corners
    'PFL': (-21.8, -1.0, -90, 2.8, 2.8), 'PFR': (21.8, -1.0, 90, 2.8, 2.8),
    'PBR': (21.7, 20.4, 90, 2.8, 3.4), 'PL': (-21.8, 11.3, -90, 2.8, 2.8),
}
PLANT_SLOTS = ('PFL', 'PFR', 'PBR', 'PL')

# What each upgrade brings. Plain entries are `(prop, slot)`; the slot's
# yaw is used and the prop is scaled down to fit the slot if it has to.
# Special placements: ('ceiling', prop, x, z) hangs a prop by its top;
# ('wall', prop, x, z, yaw, y) mounts it at height y; ('floor', prop, x, z,
# yaw, scale) puts it anywhere a check allows.
UPGRADES = {
    2: {
        'names': ('Reading cushions', 'Storytime rug', 'Reading lamps', 'Tea and ferns'),
        1: [('ArmchairBed', 'L1'), ('PatchworkCushion', 'L2')],
        2: [('BookStackClimb', 'F1'), ('PaperPlaneMobile', 'F2'), ('RollingGlobe', 'F3')],
        3: [('BookshelfLights', 'B1'), ('TableLamp', 'B3')],
        4: [('TeaTable', 'R1'), ('CookieJar', 'R2')],
    },
    3: {
        'names': ('Moss nests', 'Leafy jute rug', 'Hanging gardens', 'Big green'),
        1: [('PlanterBed', 'L1'), ('MossMound', 'L2')],
        2: [('PlantPotClimb', 'F1'), ('DaisyPinwheel', 'F2'), ('BouncyToadstool', 'F3')],
        3: [('ceiling', 'Skylight', 0, 10, 0.72), ('JarLight', 'W1'), ('JarLight', 'W3')],
        4: [('WateringCanFountain', 'R1'), ('FruitBasket', 'R2')],
    },
    4: {
        'names': ('Bread-basket beds', 'Gingham rug', 'Copper pendants', 'Herb garden'),
        1: [('OvenMittNest', 'L1'), ('BreadBasketBed', 'L2')],
        2: [('RollingPin', 'F1'), ('CupcakeTower', 'F2'), ('DonutRing', 'F3')],
        3: [('OvenGlow', 'B1'), ('PendantLamp', 'W2')],
        4: [('BakeryCounter', 'R1'), ('MilkJugFountain', 'R2')],
    },
    5: {
        'names': ('Gamer cushions', 'Arcade carpet', 'Neon rings', 'Lounge plants'),
        1: [('SofaBed', 'L1'), ('BeanBagPile', 'L2')],
        2: [('ToyTrain', 'F1'), ('BallPit', 'F2'), ('ArcadeCabinet', 'B3')],
        3: [('wall', 'NeonSign', -14, 21.8, 0, 4.2), ('LavaLamp', 'W2')],
        4: [('PizzaTable', 'R1'), ('SodaFountain', 'R2')],
    },
    6: {
        'names': ('Plaid beds', 'Braided rug', 'Lantern chandeliers', 'Little pines'),
        1: [('KnitBlanketBed', 'L1'), ('FiresideRug', 'B2')],
        2: [('Sled', 'F1'), ('SnowballPile', 'F2'), ('IceTop', 'F3')],
        3: [('Fireplace', 'B1'), ('IceLantern', 'W2'), ('IceLantern', 'W3')],
        4: [('HotCocoaPot', 'R1'), ('FishBarrel', 'R2')],
    },
    7: {
        'names': ('Drop-cloth beds', 'Splatter rug', 'Studio spots', 'Paint-pot plants'),
        1: [('PaintSplatCushion', 'L1'), ('CanvasTent', 'L2')],
        2: [('Easel', 'B3'), ('PaintPotStack', 'F1'), ('ClayWheel', 'F3')],
        3: [('wall', 'GalleryLights', -14, 21.8, 0, 6.0), ('SpotLamp', 'B2')],
        4: [('SnackPalette', 'R1'), ('SinkFountain', 'R2')],
    },
    8: {
        'names': ('Petal beds', 'Clover lawn', 'Paper lanterns', 'Sunflowers'),
        1: [('CloudPuffBed', 'L1'), ('Hammock', 'B2')],
        2: [('RainbowSlide', 'F1'), ('BubbleWand', 'F2'), ('KitePost', 'B1')],
        3: [('floor', 'RainbowArch', 10, -1.6, 0, 1.0), ('SunOrbLamp', 'W2')],
        4: [('RaindropFountain', 'R1'), ('SkyBerryBush', 'R2')],
    },
    9: {
        'names': ('Moon cushions', 'Star chart rug', 'Star clusters', 'Moonflowers'),
        1: [('StarQuiltBed', 'L1'), ('MoonCradle', 'L2')],
        2: [('CometBall', 'F2'), ('PlanetMobile', 'F1'), ('Telescope', 'B3')],
        3: [('floor', 'RuneRing', 0, 10, 0, 1.0), ('wall', 'StarPanel', -14, 21.8, 0, 3.6), ('MoonOrb', 'F3')],
        4: [('MoonwaterFountain', 'R1'), ('StardustJar', 'R2')],
    },
    10: {
        'names': ('Royal cushions', 'Gold-key rug', 'Crystal chandeliers', 'Gold topiaries'),
        1: [('CanopyBed', 'L1'), ('GoldPillowPile', 'L2')],
        2: [('Carousel', 'F2'), ('GoldOrb', 'F3'), ('ThroneSteps', 'B2')],
        3: [('LightPillar', 'B1'), ('ceiling', 'GoldChandelier', 0, 10, 0.7)],
        4: [('BanquetTable', 'F1'), ('TieredFountain', 'R2')],
    },
}

# Floor 1 (Cozy Studio) is free and never upgrades: a modest starter room.
STARTER = [('BeanbagBed', 'L1'), ('WickerBasketBed', 'L2'), ('RubberBall', 'F2'), ('YarnBall', 'F3'),
           ('FloorLamp', 'B1'), ('FoodBowlMat', 'R1'), ('PetWaterFountain', 'R2'),
           ('floor', 'StarterRug', 0, 10, 0, 1.0)]

# The ceiling lamps' real lights (client/TowerDecorView). Indoors Roblox adds
# every overlapping light and the game's bloom flares Neon, so the four lamps
# stay soft: a 0.9 / 16-stud light on Neon washed the shop out white (#76).
LIGHTING = {
    'brightness': 0.4,  # each lamp's PointLight
    'range': 10,  # studs; the four lamps sit 10 apart, so the pools just meet
    'color': (255, 228, 196),  # a soft warm white
    'neon': False,  # glowing boxes as Neon; off, they keep their colour
}

# How much each client furnishes (client/TowerDecorView). A full floor is
# 800-1,400 boxes, so a phone keeps fewer floors and builds slower.
VIEW = {
    'maxFloors': 6, 'phoneMaxFloors': 3,  # floors furnished at once, nearest the camera first
    'near': 80, 'far': 100,  # studs from the camera to a floor's middle: furnish, unfurnish
    'boxesPerFrame': 400, 'phoneBoxesPerFrame': 200,
}

BOX = {}


def reg(pid):
    fn, kind, lo, hi, kw = props.REGISTRY[pid]
    return kind, (hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]), kw


def hanging(pid):
    """props drawn hanging (a cord at the top): hung from the ceiling"""
    return pid in ('PendantLamp', 'JarLight', 'GoldChandelier', 'PaperPlaneMobile', 'Skylight') or reg(pid)[0] == 'room' and reg(pid)[2].get('zone') == 'ceiling'


def footprint(w, d, yaw):
    a = abs(math.sin(math.radians(yaw)))
    return (d, w) if a > 0.5 else (w, d)


def item(pid, x, z, yaw=0.0, y=0.0, scale=1.0, how='floor'):
    return dict(prop=pid, x=round(x, 3), z=round(z, 3), yaw=yaw, y=round(y, 3), scale=round(scale, 3), how=how)


def resolve(entry):
    """one UPGRADES entry -> placed items"""
    if entry[0] == 'ceiling':
        _, pid, x, z, s = entry
        h = reg(pid)[1][2] * s
        return [item(pid, x, z, 0, CEILING - h, s, 'ceiling')]
    if entry[0] == 'wall':
        _, pid, x, z, yaw, y = entry
        d = reg(pid)[1][1]
        return [item(pid, x, z - d / 2 if yaw == 0 else z, yaw, y, 1.0, 'wall')]
    if entry[0] == 'floor':
        _, pid, x, z, yaw, s = entry
        return [item(pid, x, z, yaw, 0.0, s)]
    pid, slot = entry[0], entry[1]
    sx, sz, yaw, room_x, room_z = SLOT[slot]
    _, (w, d, h), _ = reg(pid)
    fx, fz = footprint(w, d, yaw)
    s = min(1.0, room_x / fx, room_z / fz)
    if len(entry) > 2 and entry[2]:
        s = entry[2]
    if hanging(pid):
        return [item(pid, sx, sz, yaw, CEILING - h * s if slot[0] != 'W' else 8.6 - h * s, s, 'ceiling' if slot[0] != 'W' else 'hang')]
    # back slots: push the prop against the wall
    if slot[0] in 'BW':
        sz = ROOM[3] - fz * s / 2
    elif slot[0] == 'L':
        sx = ROOM[0] + fx * s / 2
    elif slot[0] == 'R':
        sx = ROOM[2] - fx * s / 2
    return [item(pid, sx, sz, yaw, 0.0, s)]


def room_set(floor):
    """floor -> [upgrade 1..4 -> items] (floor 1: everything under 0)"""
    if floor == 1:
        out = []
        for e in STARTER:
            out += resolve(e)
        return {0: out}
    bed, rug, light, plant, crest = rooms.THEMES_ROOM[floor]
    u = UPGRADES[floor]
    sets = {n: [] for n in (1, 2, 3, 4)}
    # the pad by the elevator shaft gets a slightly smaller bed, nudged off
    # the shaft's corner (the creature still stands on the pad's centre)
    sets[1] += [item(bed, x, z) if (x, z) != (-15, 15) else item(bed, -14.5, 14.5, 0, 0, 0.84) for x, z in PADS]
    sets[2].append(item(rug, 0, 10))
    _, (_, _, lh), _ = reg(light)
    sets[3] += [item(light, x, z, 0, CEILING - lh, 1.0, 'ceiling') for x, z in LIGHTS]
    for sl in PLANT_SLOTS:
        sets[4] += resolve((plant, sl))
    # the crest over the little picture between the first two back windows,
    # just under the crown moulding
    cs = 1.0
    sets[4].append(item(crest, -3.0, ROOM[3] - 0.25 - reg(crest)[1][1] * cs / 2, 0, 8.7, cs, 'wall'))
    for n in (1, 2, 3, 4):
        for e in u[n]:
            sets[n] += resolve(e)
    return sets


# --------------------------------------------------------------- checks
def rect(it):
    _, (w, d, h), _ = reg(it['prop'])
    fx, fz = footprint(w, d, it['yaw'])
    s = it['scale']
    return (it['x'] - fx * s / 2, it['z'] - fz * s / 2, it['x'] + fx * s / 2, it['z'] + fz * s / 2), h * s


def overlap(a, b, eps=0.05):
    return a[0] < b[2] - eps and b[0] < a[2] - eps and a[1] < b[3] - eps and b[1] < a[3] - eps


def check():
    problems = []
    for floor in range(1, 11):
        sets = room_set(floor)
        placed = []
        for n, items in sets.items():
            for it in items:
                pid = it['prop']
                if pid not in props.REGISTRY:
                    problems.append(f'floor {floor}: no prop {pid}')
                    continue
                kind, _, kw = reg(pid)
                if kind == 'room' and kw.get('floor') not in (floor,):
                    problems.append(f'floor {floor}: {pid} belongs to floor {kw.get("floor")}')
                if kind == 'decor' and kw.get('floor') != floor:
                    problems.append(f'floor {floor}: {pid} belongs to floor {kw.get("floor")}')
                r, h = rect(it)
                top = it['y'] + h
                tag = f'floor {floor} upgrade {n} {pid} at ({it["x"]}, {it["z"]})'
                if r[0] < ROOM[0] - 0.05 or r[2] > ROOM[2] + 0.05 or r[1] < ROOM[1] - 0.05 or r[3] > ROOM[3] + 0.05:
                    problems.append(f'{tag}: outside the room {tuple(round(v, 2) for v in r)}')
                if top > CEILING + 0.01:
                    problems.append(f'{tag}: through the ceiling (top {top:.2f})')
                flat = h <= 1.2 and (kw.get('zone') in ('bed', 'rug') or pid in ('RuneRing',))
                high = it['y'] >= 8.5
                if overlap(r, GRID) and not flat and not high:
                    problems.append(f'{tag}: in the creature grid {tuple(round(v, 2) for v in r)}')
                # rugs are notched round the shaft; beds have soft corners
                zone = kw.get('zone')
                if zone != 'rug' and overlap(r, SHAFT, 0.3 if zone == 'bed' else 0.05) and not high:
                    problems.append(f'{tag}: in the elevator shaft')
                pad = 0.5 if flat else 2.0
                hole = (LADDER_HOLE[0] - pad, LADDER_HOLE[1] - pad, LADDER_HOLE[2] + pad, LADDER_HOLE[3] + pad)
                if overlap(r, hole) and not high:
                    problems.append(f'{tag}: in the ladder opening')
                for name, k in KEEP_OUT.items():
                    if overlap(r, k) and not high and not flat:
                        problems.append(f'{tag}: blocks the {name}')
                if r[3] > ROOM[3] - 2.2 and it['y'] < 8.6:
                    for wx in BACK_WINDOWS:
                        if overlap(r, (wx - 2, 0, wx + 2, 30)) and top > 3.6 and it['how'] != 'hang':
                            problems.append(f'{tag}: in front of the window at X {wx} (top {top:.2f})')
                    for px in PICTURES:
                        if overlap(r, (px - 0.7, 0, px + 0.7, 30)) and top > 5.0 and it['y'] < 6.4:
                            problems.append(f'{tag}: covers the picture at X {px} (top {top:.2f})')
                layer = 'ceiling' if high else ('flat' if flat else 'floor')
                for other, olayer, orect, oy, otop in placed:
                    if layer == olayer and layer != 'flat' and overlap(r, orect) and not (top <= oy or it['y'] >= otop):
                        problems.append(f'{tag}: overlaps {other}')
                placed.append((pid, layer, r, it['y'], top))
    return problems


# --------------------------------------------------------------- output
def lua_num(v):
    v = round(float(v), 3)
    return str(int(v)) if v == int(v) else repr(v)


def write():
    lines = [
        '--!strict',
        '-- GENERATED by tools/art/world/rooms_layout.py: the apartment decor of every',
        '-- tower floor, upgrade by upgrade (plans in the PR and tools/art/world/README).',
        '-- Change the layout there and run `python3 tools/art/world/rooms_layout.py`.',
        '--',
        '-- Each item: a WorldArt prop, its base-local x and z (studs), yaw (degrees',
        '-- about Y; 0 faces -Z, the balcony), y above the floor\'s walking height (the',
        '-- prop\'s base, its bottom centre) and a uniform scale about that point.',
        '-- Floor 1 never upgrades: its starter room is upgrade 0.',
        '',
        'export type Item = { prop: string, x: number, z: number, yaw: number, y: number, scale: number }',
        'export type Floor = { names: { string }, upgrades: { [number]: { Item } } }',
        'export type Lighting = { brightness: number, range: number, color: { number }, neon: boolean }',
        'export type View = {',
        '\tmaxFloors: number,',
        '\tphoneMaxFloors: number,',
        '\tnear: number,',
        '\tfar: number,',
        '\tboxesPerFrame: number,',
        '\tphoneBoxesPerFrame: number,',
        '}',
        '',
        'local towerDecor: { lighting: Lighting, view: View, floors: { [number]: Floor } } = {',
        '\t-- the ceiling lamps: one soft PointLight each; glowing boxes as Neon or not',
        f'\tlighting = {{ brightness = {lua_num(LIGHTING["brightness"])}, range = {lua_num(LIGHTING["range"])}, '
        f'color = {{ {", ".join(str(c) for c in LIGHTING["color"])} }}, neon = {str(LIGHTING["neon"]).lower()} }},',
        '\t-- how much each client furnishes; phones keep fewer floors and build slower',
        '\tview = { ' + ', '.join(f'{k} = {lua_num(v)}' for k, v in VIEW.items()) + ' },',
        '\tfloors = {',
    ]
    for floor in range(1, 11):
        sets = room_set(floor)
        names = UPGRADES[floor]['names'] if floor > 1 else ()
        lines.append(f'\t\t[{floor}] = {{')
        lines.append('\t\t\tnames = { ' + ', '.join(f'"{n}"' for n in names) + ' },' if names else '\t\t\tnames = {},')
        lines.append('\t\t\tupgrades = {')
        for n, items in sorted(sets.items()):
            lines.append(f'\t\t\t\t[{n}] = {{')
            for it in items:
                lines.append(
                    f'\t\t\t\t\t{{ prop = "{it["prop"]}", x = {lua_num(it["x"])}, z = {lua_num(it["z"])}, '
                    f'yaw = {lua_num(it["yaw"])}, y = {lua_num(it["y"])}, scale = {lua_num(it["scale"])} }},'
                )
            lines.append('\t\t\t\t},')
        lines.append('\t\t\t},')
        lines.append('\t\t},')
    lines += ['\t},', '}', '', 'return towerDecor', '']
    with open(OUT, 'w') as fh:
        fh.write('\n'.join(lines))
    return OUT


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true')
    a = ap.parse_args()
    probs = check()
    for p in probs:
        print('!', p)
    if probs:
        sys.exit(1)
    if not a.check:
        print('wrote', os.path.relpath(write(), ROOT))
