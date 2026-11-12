"""The Giant Golden Egg: Hatchery Heist's daily Robux egg, standing on the
Golden Nest in the middle of the map (config/events.luau `giantEgg`).

A big storybook egg in the Legendary colours (warm gold to amber, a band of
flames round its foot, a ring of gems at its widest, a cream crown of points
near the top) in a bronze cradle of four claws on a round gold plinth. Every
piece is drawn in the props.py format (art frame: x right, y back so the
front is -y, z up, studs, 0.1-stud voxels) and registered in props.REGISTRY
with kind "event", so it never lands in WorldArt.luau:
giantexport.py writes it to games/hatchery-heist/src/shared/GiantEggArt.luau.

The shell is its own part, "shell", which the client rocks now and then, as if
it were about to hatch. No glowing colours: the game lights it with one warm
PointLight (no Neon, studio lighting rule).
"""
import math

import numpy as np

from vkit import col, hnoise, snoise
from styles import pick
from props import prop

# ------------------------------------------------------------------ palette
GOLD = ['#FFC23D', '#FFB72E', '#FFCB52']
GOLD_L = ['#FFE07A', '#FFD866', '#FFE993']
AMBER = ['#F08A24', '#E8801C', '#F5942E']
FLAME = '#E2482B'
FLAME_L = '#FF8A3D'
CREAM = '#FFF3C4'
RUBY = '#D7263D'
TEAL = '#2EC4C8'
BRONZE = ['#8C5A2B', '#7E5025', '#996433']
BRONZE_L = '#B57A3C'
PLINTH = ['#D9A93E', '#CFA036', '#E2B24A']
PLINTH_D = '#9C7424'

W = 7.6  # the shell's widest, studs
H = 10.4  # the shell's height
BASE = 0.7  # plinth height
CRADLE = 0.5  # the shell's foot sits this far above the plinth top
R_PLINTH = 4.4
Z0 = BASE + CRADLE  # bottom of the shell
ZC = Z0 + H * 0.42  # the widest ring
TOP = Z0 + H


def shell_radius(Z):
    """the egg's radius at height Z (numpy), the same profile as the belt eggs"""
    t = (Z - ZC) / np.where(Z > ZC, H * 0.58, H * 0.42)
    return W / 2 * np.sqrt(np.clip(1 - t * t, 0, 1)) * np.where(Z > ZC, 1 - 0.12 * t, 1)


def _angle(X, Y):
    return np.arctan2(Y, X)


@prop('GiantLegendaryEgg', 'event', (-R_PLINTH - 0.1, -R_PLINTH - 0.1, 0), (R_PLINTH + 0.1, R_PLINTH + 0.1, TOP + 0.1),
      budget=600, factors=(3, 4, 5, 6, 8),
      note='the Giant Golden Egg on the Golden Nest: gold egg, flame band, gem ring, bronze claw cradle')
def _giant(p):
    # --- the plinth: a round gold drum with a darker lip and a bronze rim
    g = p.part('body')
    g.cyl(0, 0, 0, BASE, R_PLINTH, pick(PLINTH, 401))
    g.cyl(0, 0, BASE - 0.15, BASE, R_PLINTH + 0.1, col(PLINTH_D))
    g.cyl(0, 0, 0, 0.2, R_PLINTH + 0.1, pick(BRONZE, 402))
    # little gold studs round the drum
    for i in range(16):
        a = i / 16 * 2 * math.pi
        x, y = math.cos(a) * (R_PLINTH + 0.05), math.sin(a) * (R_PLINTH + 0.05)
        g.ell((x, y, BASE * 0.5), (0.22, 0.22, 0.22), col(GOLD_L[0]))
    # --- the cradle: four bronze claws curling up round the shell's foot
    claw = pick(BRONZE, 403)
    for i in range(4):
        a = (i + 0.5) / 4 * 2 * math.pi
        ca, sa = math.cos(a), math.sin(a)
        prev = None
        steps = 9
        for k in range(steps + 1):
            u = k / steps
            z = BASE + u * (H * 0.3)
            r = float(shell_radius(np.array(z))) + 0.25 + 0.35 * math.sin(u * math.pi) - (0.6 if u == 0 else 0)
            pt = (ca * r, sa * r, z)
            if prev is not None:
                g.seg(prev, pt, 0.42 - 0.18 * u, claw)
            prev = pt
        # a talon tip curling inward
        g.ell((prev[0] * 0.9, prev[1] * 0.9, prev[2] + 0.15), (0.3, 0.3, 0.35), col(BRONZE_L))
    # a bronze ring the shell rests in
    g.cyl(0, 0, BASE, Z0 + 0.25, 1.9, pick(BRONZE, 404), r1=1.2)

    # --- the shell
    s = p.part('shell', anim='rock', pivot=(0, 0, Z0))
    gold, light, amber = pick(GOLD, 405), pick(GOLD_L, 406), pick(AMBER, 407)
    flame, flame_l, cream = col(FLAME), col(FLAME_L), col(CREAM)
    ruby, teal = col(RUBY), col(TEAL)

    def inside(X, Y, Z):
        rr = shell_radius(Z)
        return X * X + Y * Y <= rr * rr

    def colour(X, Y, Z):
        h = (Z - Z0) / H
        a = _angle(X, Y)
        # base: amber at the foot, gold in the middle, pale gold at the top
        tone = h + 0.06 * snoise(X, Y, Z, 1.8, 41)
        c = np.where(tone < 0.22, amber(X, Y, Z), np.where(tone > 0.72, light(X, Y, Z), gold(X, Y, Z)))
        # a band of flames: tongues rising from the foot, inner tongues lighter
        tongues = 0.5 + 0.5 * np.cos(a * 9)
        flick = 0.03 * snoise(X, Y, Z, 3.0, 42)
        top_f = 0.12 + 0.13 * tongues + flick
        c = np.where((h > 0.04) & (h < top_f), flame, c)
        c = np.where((h > 0.04) & (h < top_f - 0.055) & (tongues > 0.45), flame_l, c)
        # the widest ring: a cream band set with gems, ruby and teal in turn
        band = np.abs(Z - ZC) < 0.28
        c = np.where(band, cream, c)
        sector = np.mod(a / (2 * math.pi) * 8, 1.0)
        gem_at = band & (np.abs(sector - 0.5) < 0.13)
        which = np.mod(np.floor(a / (2 * math.pi) * 8 + 8), 2)
        c = np.where(gem_at, np.where(which == 0, ruby, teal), c)
        # a crown of cream points near the top
        crown_mid = 0.78
        point = 0.035 + 0.05 * np.abs(np.mod(a / (2 * math.pi) * 10, 1.0) - 0.5) * 2
        c = np.where(np.abs(h - crown_mid) < point * 0.6, cream, c)
        # a few pale sparkle flecks
        fleck = (hnoise(X, Y, Z, 43) > 0.985) & (h > 0.3)
        return np.where(fleck, cream, c)

    s.fill((-W / 2 - 0.1, -W / 2 - 0.1, Z0), (W / 2 + 0.1, W / 2 + 0.1, TOP), inside, colour)
    p.anchor = (0, 0, 0)
