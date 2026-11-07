"""The claw machine in Hatchery Heist's farm hub and the six charms it hands
out (config/charms.luau).

Every piece is drawn in the props.py format (art frame: x right, y back so
the front is -y, z up, studs, 0.1-stud voxels) and registered in
props.REGISTRY with kind "claw" or "charm", so nothing lands in WorldArt.luau:
clawexport.py writes them to games/hatchery-heist/src/shared/ClawArt.luau.

ClawMachine: a storybook-farm cabinet (barn-red boards, cream trim, gold
corners) with a glass case full of round prize capsules, a gantry and a
three-pronged claw (its own part, "claw", which the client lowers and
raises during a pull), a console with a joystick and a big button, a prize
chute, and an arched marquee with a blank cream sign the game writes on
(the anchor). Glass is the colour #BEE6FF, which the game turns into Glass.

Charms: each kind is one small model drawn 2.4 studs tall (the game builds
it at a quarter of that), with a hanging loop on top. The part "trim" is
repainted in the charm's tier colour by the game, so one model serves all
seven tiers; "body" keeps its own colours. No glowing colours anywhere: the
game adds sparkles from Ultra Rare and a soft PointLight from Legendary.
"""
import math

import numpy as np

from vkit import col
from styles import pick
from props import prop

# ------------------------------------------------------------------ palette
RED = ['#D2483D', '#C8413A', '#DB5247']
RED_D = '#A8352E'
CREAM = '#F6EEDC'
GOLD = ['#FFC935', '#F5BE2A', '#FFD24D']
GOLD_D = '#C9962A'
WOOD_D = ['#8B5A33', '#7A4D2B', '#9A6A3F']
GLASS = '#BEE6FF'  # the game makes these boxes Glass
METAL = ['#B9C3CC', '#AEB8C2', '#C4CDD5']
METAL_D = '#8C97A3'
DARK = '#3A2A3A'
CAPSULES = ['#FF6F91', '#FFE066', '#6FA8FF', '#5DD39E', '#C9A7FF', '#FF9F1C']
TRIM = '#C0C8D0'  # repainted per tier in game

# ------------------------------------------------------------------ the machine
W, D = 4.8, 4.4  # footprint, studs
BASE_H = 3.6  # cabinet top
CASE_H = 4.0  # glass case height
TOP = BASE_H + CASE_H


@prop('ClawMachine', 'claw', (-W / 2 - 0.3, -D / 2 - 0.6, 0), (W / 2 + 0.3, D / 2 + 0.3, TOP + 2.2),
      budget=420, factors=(2, 3, 4, 5, 6),
      note='claw machine: red cabinet, glass case of capsules, claw (part "claw" moves), console, chute, '
           'marquee with a blank sign at the anchor')
def _machine(p):
    g = p.part('body')
    red, wd, gold = pick(RED, 801), pick(WOOD_D, 802), pick(GOLD, 803)
    hw, hd = W / 2, D / 2
    # plinth and cabinet
    g.box((-hw - 0.2, -hd - 0.2, 0), (hw + 0.2, hd + 0.2, 0.35), wd)
    g.box((-hw, -hd, 0.35), (hw, hd, BASE_H), red)
    # vertical board seams on the cabinet front and sides
    for x in np.arange(-hw + 0.8, hw, 0.8):
        g.box((x - 0.05, -hd - 0.05, 0.4), (x + 0.05, -hd, BASE_H - 0.3), col(RED_D))
    # cream trim band and gold corner posts
    g.box((-hw - 0.08, -hd - 0.08, BASE_H - 0.35), (hw + 0.08, hd + 0.08, BASE_H), col(CREAM))
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * hw, sy * hd
            g.box((x - 0.22, y - 0.22, 0.35), (x + 0.22, y + 0.22, TOP + 0.3), gold)
    # console: a sloped shelf on the front with joystick and button
    cz = 2.5

    def shelf(X, Y, Z):
        top = cz + 0.4 + (Y + hd + 0.6) * 0.35
        return Z <= top
    g.fill((-hw + 0.2, -hd - 0.6, cz), (hw - 0.2, -hd, cz + 0.8), shelf, col(CREAM))
    g.cyl(-1.0, -hd - 0.3, cz + 0.5, cz + 1.2, 0.08, col(DARK))
    g.ell((-1.0, -hd - 0.3, cz + 1.25), (0.22, 0.22, 0.22), col('#E2482B'))
    g.cyl(0.9, -hd - 0.3, cz + 0.5, cz + 0.75, 0.35, col(GOLD_D))
    g.cyl(0.9, -hd - 0.3, cz + 0.75, cz + 0.9, 0.28, col('#3FA9F5'))
    # coin slot plate
    g.box((-0.3, -hd - 0.06, 1.7), (0.3, -hd, 2.2), col(GOLD_D))
    g.box((-0.06, -hd - 0.08, 1.8), (0.06, -hd - 0.05, 2.1), col(DARK))
    # prize chute: a dark opening with a gold flap frame
    g.box((-1.0, -hd - 0.1, 0.6), (1.0, -hd, 1.6), gold)
    g.box((-0.8, -hd - 0.12, 0.75), (0.8, -hd - 0.05, 1.45), col(DARK))
    # glass case: four panes and a roof, with gold frame bars
    gl = col(GLASS)
    t = 0.12
    g.box((-hw + 0.2, -hd + 0.2, BASE_H), (hw - 0.2, -hd + 0.2 + t, TOP), gl)
    g.box((-hw + 0.2, hd - 0.2 - t, BASE_H), (hw - 0.2, hd - 0.2, TOP), gl)
    g.box((-hw + 0.2, -hd + 0.2, BASE_H), (-hw + 0.2 + t, hd - 0.2, TOP), gl)
    g.box((hw - 0.2 - t, -hd + 0.2, BASE_H), (hw - 0.2, hd - 0.2, TOP), gl)
    g.box((-hw, -hd, TOP), (hw, hd, TOP + 0.35), red)
    g.box((-hw - 0.08, -hd - 0.08, TOP + 0.35), (hw + 0.08, hd + 0.08, TOP + 0.55), col(CREAM))
    # the floor inside the case, and the capsules piled on it
    g.box((-hw + 0.3, -hd + 0.3, BASE_H), (hw - 0.3, hd - 0.3, BASE_H + 0.2), col(DARK))
    caps = p.part('capsules', parent='body')
    rng = np.random.default_rng(7)
    placed = []
    for i in range(60):
        x = rng.uniform(-hw + 0.75, hw - 0.75)
        y = rng.uniform(-hd + 0.75, hd - 0.75)
        if math.hypot(x - 1.1, y + 1.0) < 0.9:  # leave the chute hole clear
            continue
        z = BASE_H + 0.55 + 0.35 * sum(1 for (px, py) in placed if math.hypot(px - x, py - y) < 0.7)
        if z > BASE_H + 1.5:
            continue
        placed.append((x, y))
        c = CAPSULES[i % len(CAPSULES)]
        caps.ell((x, y, z), (0.36, 0.36, 0.36), col(c), cond=lambda X, Y, Z, z=z: Z >= z)
        caps.ell((x, y, z), (0.36, 0.36, 0.36), col(CREAM), cond=lambda X, Y, Z, z=z: Z < z)
    # the chute hole inside the case: a gold ring
    g.cyl(1.1, -1.0, BASE_H + 0.2, BASE_H + 0.45, 0.7, gold)
    g.cyl(1.1, -1.0, BASE_H + 0.2, BASE_H + 0.46, 0.5, col(DARK))
    # gantry rails under the roof
    m = pick(METAL, 804)
    g.box((-hw + 0.4, -hd + 0.5, TOP - 0.35), (hw - 0.4, -hd + 0.7, TOP - 0.15), m)
    g.box((-hw + 0.4, hd - 0.7, TOP - 0.35), (hw - 0.4, hd - 0.5, TOP - 0.15), m)
    g.box((-0.15, -hd + 0.5, TOP - 0.55), (0.15, hd - 0.5, TOP - 0.35), m)
    # the claw: carriage, cable and three prongs, its own part
    cl = p.part('claw', anim='static', parent='body', pivot=(0, 0, TOP - 0.55))
    cl.box((-0.35, -0.35, TOP - 0.9), (0.35, 0.35, TOP - 0.55), col(METAL_D))
    cl.cyl(0, 0, TOP - 2.0, TOP - 0.9, 0.06, col(DARK))
    cl.cyl(0, 0, TOP - 2.3, TOP - 2.0, 0.3, gold)
    for k in range(3):
        a = k / 3 * 2 * math.pi
        ca, sa = math.cos(a), math.sin(a)
        cl.seg((ca * 0.2, sa * 0.2, TOP - 2.3), (ca * 0.55, sa * 0.55, TOP - 2.9), 0.09, pick(METAL, 805))
        cl.seg((ca * 0.55, sa * 0.55, TOP - 2.9), (ca * 0.35, sa * 0.35, TOP - 3.25), 0.09, pick(METAL, 805))
    # marquee: an arched cream sign on the roof, gold border, star on top
    mz = TOP + 0.55

    def arch(X, Y, Z):
        return Z <= mz + 1.1 + 0.35 * np.sqrt(np.clip(1 - (X / (hw - 0.2)) ** 2, 0, 1))
    g.fill((-hw + 0.1, -hd + 0.1, mz), (hw - 0.1, -hd + 0.5, mz + 1.6), arch, gold)

    def face(X, Y, Z):
        return Z <= mz + 0.95 + 0.3 * np.sqrt(np.clip(1 - (X / (hw - 0.4)) ** 2, 0, 1))
    g.fill((-hw + 0.35, -hd + 0.0, mz + 0.15), (hw - 0.35, -hd + 0.12, mz + 1.4), face, col(CREAM))
    p.anchor = (0, -hd, mz + 0.75)
    g.ell((0, -hd + 0.3, mz + 1.75), (0.35, 0.15, 0.35), col('#FFE066'))
    # bulbs round the marquee (warm, not glowing: the game lights it)
    for i in range(9):
        x = -hw + 0.4 + i * (W - 0.8) / 8
        g.ell((x, -hd + 0.05, mz + 0.1), (0.12, 0.08, 0.12), col('#FFF3C4'))


# ------------------------------------------------------------------ charms
S = 2.4  # drawn height of a charm, studs; the game builds it at size / S


def charm(pid, note):
    return prop(pid, 'charm', (-1.3, -1.3, 0), (1.3, 1.3, S + 0.1), budget=34, factors=(2, 3, 4),
                note=note)


def hook(g, z):
    """the little loop every charm hangs from"""
    gold = col(GOLD[0])
    g.box((-0.08, -0.08, z), (0.08, 0.08, z + 0.25), gold)

    def ring(X, Y, Z):
        r = np.sqrt(X * X + (Z - z - 0.45) ** 2)
        return (r <= 0.3) & (r >= 0.14) & (np.abs(Y) <= 0.08)
    g.fill((-0.35, -0.1, z + 0.1), (0.35, 0.1, z + 0.8), ring, gold)


@charm('CharmFeeder', 'Feeder charm: a wooden bucket heaped with corn; "trim" band in the tier colour')
def _feeder(p):
    b = p.part('body')
    tr = p.part('trim', parent='body')
    b.cyl(0, 0, 0.1, 1.2, 0.75, pick(WOOD_D, 811), r1=0.9)
    tr.cyl(0, 0, 0.35, 0.55, 0.85, col(TRIM))
    tr.cyl(0, 0, 0.95, 1.15, 0.92, col(TRIM))
    # corn heaped above the rim
    b.ell((0, 0, 1.25), (0.8, 0.8, 0.45), col('#FFD24D'))
    b.ell((-0.25, 0.1, 1.55), (0.25, 0.25, 0.35), col('#FFE066'))
    b.ell((0.3, -0.1, 1.5), (0.22, 0.22, 0.3), col('#F5BE2A'))
    b.ell((0.05, -0.35, 1.5), (0.35, 0.18, 0.22), col('#5DB13E'))
    hook(b, 1.75)


@charm('CharmClover', 'Clover charm: a four-leaf clover on a round medallion; "trim" rim in the tier colour')
def _clover(p):
    b = p.part('body')
    tr = p.part('trim', parent='body')
    zc = 1.05

    def disc(X, Y, Z):
        return X * X + (Z - zc) ** 2 <= 0.95 ** 2
    tr.fill((-1.0, -0.12, zc - 1.0), (1.0, 0.12, zc + 1.0), disc, col(TRIM))

    def inner(X, Y, Z):
        return X * X + (Z - zc) ** 2 <= 0.72 ** 2
    b.fill((-0.8, -0.2, zc - 0.8), (0.8, -0.1, zc + 0.8), inner, col(CREAM), only_empty=False)
    for k in range(4):
        a = k / 4 * 2 * math.pi + math.pi / 4
        x, z = math.cos(a) * 0.3, zc + math.sin(a) * 0.3
        b.ell((x, -0.25, z), (0.26, 0.1, 0.26), pick(['#55B947', '#4DB043'], 812))
    b.box((-0.05, -0.3, zc - 0.65), (0.05, -0.2, zc - 0.2), col('#3E8E35'))
    hook(b, zc + 0.92)


@charm('CharmWarmer', 'Warmer charm: a flame in a little iron brazier; "trim" rim in the tier colour')
def _warmer(p):
    b = p.part('body')
    tr = p.part('trim', parent='body')
    b.cyl(0, 0, 0.1, 0.35, 0.3, col(DARK))
    b.cyl(0, 0, 0.35, 0.8, 0.6, col('#4A3A40'), r1=0.75)
    tr.cyl(0, 0, 0.75, 0.92, 0.8, col(TRIM))
    # flame: three stacked tongues, orange to yellow
    b.ell((0, 0, 1.15), (0.5, 0.5, 0.45), col('#E2482B'))
    b.ell((0, 0, 1.45), (0.35, 0.35, 0.45), col('#FF8A3D'))
    b.ell((0, 0, 1.75), (0.18, 0.18, 0.3), col('#FFE066'))
    hook(b, 1.95)


@charm('CharmWard', 'Ward charm: a little round-topped shield; "trim" rim and boss in the tier colour')
def _ward(p):
    b = p.part('body')
    tr = p.part('trim', parent='body')

    def shield(X, Y, Z, r=0.85):
        top = Z >= 0.9
        return np.where(top, X * X + (Z - 0.9) ** 2 * 1.4 <= r * r, np.abs(X) <= r * np.clip(Z / 0.9, 0, 1) ** 0.6)
    tr.fill((-0.95, -0.12, 0.1), (0.95, 0.12, 1.75), lambda X, Y, Z: shield(X, Y, Z, 0.9), col(TRIM))
    b.fill((-0.8, -0.2, 0.25), (0.8, -0.12, 1.6), lambda X, Y, Z: shield(X, Y, Z, 0.7), col('#3FA9F5'))
    tr.ell((0, -0.25, 1.0), (0.22, 0.1, 0.22), col(TRIM))
    hook(b, 1.68)


@charm('CharmSnare', 'Snare charm: a coiled vine knot with leaves; "trim" binding in the tier colour')
def _snare(p):
    b = p.part('body')
    tr = p.part('trim', parent='body')
    vine = col('#4DB043')
    prev = None
    for i in range(40):
        u = i / 39
        a = u * 4 * math.pi
        r = 0.7 - 0.35 * u
        pt = (math.cos(a) * r, math.sin(a) * r * 0.5, 0.3 + u * 1.2)
        if prev:
            b.seg(prev, pt, 0.12, vine)
        prev = pt
    b.ell((0.6, -0.2, 0.7), (0.25, 0.08, 0.15), col('#5CC24F'))
    b.ell((-0.5, -0.2, 1.1), (0.22, 0.08, 0.14), col('#5CC24F'))
    tr.cyl(0, 0, 0.75, 1.0, 0.55, col(TRIM))
    hook(b, 1.5)


@charm('CharmSneak', 'Sneak charm: a soft pointed boot; "trim" cuff in the tier colour')
def _sneak(p):
    b = p.part('body')
    tr = p.part('trim', parent='body')
    boot = col('#5B4A8A')
    b.rbox((-0.35, -0.3, 0.3), (0.35, 0.3, 1.4), 0.15, boot)
    b.rbox((-0.35, -0.95, 0.3), (0.35, 0.3, 0.7), 0.15, boot)
    b.ell((0, -0.95, 0.65), (0.2, 0.2, 0.2), boot)  # the curled toe
    b.box((-0.38, -1.0, 0.2), (0.38, 0.35, 0.32), col(DARK))
    tr.box((-0.42, -0.36, 1.25), (0.42, 0.36, 1.55), col(TRIM))
    hook(b, 1.55)
