"""The farm hub in the middle of Hatchery Heist's map: the buildings and
street furniture around the Egg Market, in the Storybook Farm style.

Kinds:
    building   big pieces that give the hub its skyline (barn, silo,
               windmill, coop, stalls, Theme Stand, market arch, Book stand,
               well)
    hubprop    small street furniture (fences, lamps, signs, benches,
               planters, mailbox, path stones)

Same conventions as props.py: art frame x right, y back (front is -y), z
up, studs, base at z = 0, 0.1-stud voxels. Animated pieces are their own
part. Text (shop names, odds, the Book's title) is drawn by the game on the
blank sign faces, whose centres are given in each note and, for the main
one, as the prop's anchor. A player is about 5 studs tall: doors are 7+.
"""
import math
import numpy as np

from vkit import VOX, col, hnoise, snoise
from styles import pick
from props import prop, WOOD, WOOD_D, RED, RED_D, CREAM, IRON, STRAW, LAMP

# ------------------------------------------------------------------ palette
BARN = ['#D2483D', '#C8413A', '#DB5247']  # barn red boards
BARN_SEAM = '#A8352E'
SHINGLE = ['#8E3A34', '#863530', '#97403A']  # roofs: dark barn red
SHINGLE_D = '#6E2A26'
STONE = ['#A7A39B', '#9A968E', '#B3AFA6', '#8F8B84']
STONE_D = '#7A766F'
METAL = ['#B9C3CC', '#AEB8C2', '#C4CDD5']
METAL_D = '#8C97A3'
GOLD = '#FFC935'
WINDOW = ('#FFE7A8', 1.6)
SIGN = '#F6EEDC'  # blank sign faces the game writes on
AWNINGS = {
    'Red': ('#D2483D', '#F6EEDC'),
    'Blue': ('#3FA9F5', '#F6EEDC'),
    'Green': ('#5DB13E', '#F6EEDC'),
}
FLOWERS = ['#FF6F91', '#FFE066', '#FFFFFF', '#6FA8FF', '#FF9F1C', '#C9A7FF']
LEAVES = ['#55B947', '#4DB043', '#5CC24F']


def B(pid, w, d, h, note, budget=400, extra=0.0):
    """building footprint centred on x/y, base at z = 0"""
    hw, hd = w / 2 + extra, d / 2 + extra
    return prop(pid, 'building', (-hw, -hd, 0), (hw, hd, h + extra), budget=budget, zone='hub', note=note)


def H(pid, w, d, h, note, budget=80):
    hw, hd = w / 2, d / 2
    return prop(pid, 'hubprop', (-hw, -hd, 0), (hw, hd, h), budget=budget, zone='hub', note=note)


def glow(h, s=3.0):
    return col(h, s)


# ------------------------------------------------------------------ helpers
def boards(g, lo, hi, along, every, base, seam, seed):
    """a block of boards: `along` = 0 (seams run vertically, spaced on x),
    1 (spaced on y) or 2 (horizontal, spaced on z)"""
    g.box(lo, hi, pick(base, seed) if isinstance(base, list) else base)
    o = lo[along]

    def m(X, Y, Z):
        v = (X, Y, Z)[along]
        return np.mod(v - o, every) < VOX
    g.paint(lo, hi, m, col(seam))


def gable_profile(x, half, eave, ridge, kind='gable', knee=0.55, knee_h=0.62):
    """roof surface height over x (ridge along y). gambrel: steep lower
    slope to (knee*half, eave + knee_h*(ridge-eave)), shallow above."""
    ax = np.abs(x)
    if kind == 'gable':
        return eave + (ridge - eave) * np.clip(1 - ax / half, 0, 1)
    kx, kz = knee * half, eave + knee_h * (ridge - eave)
    low = eave + (kz - eave) * np.clip((half - ax) / (half - kx), 0, 1)
    up = kz + (ridge - kz) * np.clip((kx - ax) / kx, 0, 1)
    return np.where(ax > kx, low, up)


def roof(g, half, y0, y1, eave, ridge, thick, c, kind='gable', seed=0, rows=0.5, edge=None, knee=0.55):
    """a pitched roof over x in [-half, half], y in [y0, y1], ridge along y,
    shingle rows every `rows` studs down the slope, with a fascia `edge`"""
    def surf(X):
        return gable_profile(X, half, eave, ridge, kind, knee)

    def slope(X):
        e = 0.05
        return np.abs(surf(X + e) - surf(X - e)) / (2 * e)

    def m(X, Y, Z):
        s = surf(X)
        t = thick * np.sqrt(1 + slope(X) ** 2)
        return (Z <= s) & (Z >= s - t)
    sh = pick(c, seed)
    dark = col(SHINGLE_D)

    def cf(X, Y, Z):
        s = surf(X)
        # distance down the slope from the ridge, for shingle rows
        d = (ridge - s) + np.abs(X) * 0.35
        row = np.floor(d / rows)
        stag = np.mod(Y + row * 0.45, 0.9) < VOX
        line = np.mod(d, rows) < VOX * 1.2
        out = sh(X, Y, Z)
        return np.where(line | stag, dark, out)
    g.fill((-half, y0, eave - thick * 3), (half, y1, ridge + 0.01), m, cf)
    if edge is not None:
        # fascia boards along the gable ends
        for yy in (y0, y1 - 0.25):
            def me(X, Y, Z):
                s = surf(X)
                return (Z <= s + 0.05) & (Z >= s - thick * 1.6)
            g.fill((-half, yy, eave - thick * 3), (half, yy + 0.25, ridge + 0.1), me, col(edge))


def gable_wall(g, half, y0, y1, eave, ridge, c, kind='gable', knee=0.55):
    """fills the wall under a roof (between eave and the roof underside)"""
    def m(X, Y, Z):
        return Z <= gable_profile(X, half, eave, ridge, kind, knee) - 0.05
    g.fill((-half, y0, eave - 0.1), (half, y1, ridge), m, c)


def xdoor(g, x0, x1, y, z0, z1, face, trim, t=0.25, depth=0.4):
    """a barn door panel on the front plane y (facing -y): boards + cream
    frame and an X brace"""
    g.box((x0, y - depth, z0), (x1, y, z1), face)
    tc = col(trim)
    g.box((x0, y - depth - 0.1, z0), (x0 + t, y - depth, z1), tc)
    g.box((x1 - t, y - depth - 0.1, z0), (x1, y - depth, z1), tc)
    g.box((x0, y - depth - 0.1, z1 - t), (x1, y - depth, z1), tc)
    g.box((x0, y - depth - 0.1, z0), (x1, y - depth, z0 + t), tc)
    g.box((x0, y - depth - 0.1, (z0 + z1) / 2 - t / 2), (x1, y - depth, (z0 + z1) / 2 + t / 2), tc)
    w, hgt = x1 - x0, z1 - z0
    for zz0, zz1 in ((z0, (z0 + z1) / 2), ((z0 + z1) / 2, z1)):
        hh = zz1 - zz0

        def m(X, Y, Z, zz0=zz0, hh=hh):
            u = (X - x0) / w
            v = (Z - zz0) / hh
            k = t / min(w, hh) * 0.9
            return (np.abs(u - v) < k) | (np.abs(u - (1 - v)) < k)
        g.fill((x0, y - depth - 0.1, zz0), (x1, y - depth, zz1), m, tc)


def window(g, x0, x1, y, z0, z1, frame, pane=WINDOW, t=0.18, axis='y', sill=True):
    """a framed, glowing window set into the wall plane (axis y: front face
    at y; axis x: side face at x, spans y from x0 to x1)"""
    fc = col(frame)
    pc = glow(*pane)
    if axis == 'y':
        g.box((x0, y - 0.15, z0), (x1, y + 0.1, z1), fc)
        g.box((x0 + t, y - 0.12, z0 + t), (x1 - t, y + 0.12, z1 - t), pc)
        g.box(((x0 + x1) / 2 - t / 2, y - 0.16, z0), ((x0 + x1) / 2 + t / 2, y, z1), fc)
        g.box((x0, y - 0.16, (z0 + z1) / 2 - t / 2), (x1, y, (z0 + z1) / 2 + t / 2), fc)
        if sill:
            g.box((x0 - 0.15, y - 0.35, z0 - 0.15), (x1 + 0.15, y, z0 + 0.05), fc)
    else:
        s = 1 if y > 0 else -1  # y = wall x position; s = outward direction
        lo_x, hi_x = (y - 0.1, y + 0.15) if s > 0 else (y - 0.15, y + 0.1)
        g.box((lo_x, x0, z0), (hi_x, x1, z1), fc)
        g.box((y - 0.12, x0 + t, z0 + t), (y + 0.12, x1 - t, z1 - t), pc)
        ox0, ox1 = (y, y + 0.16) if s > 0 else (y - 0.16, y)
        g.box((ox0, (x0 + x1) / 2 - t / 2, z0), (ox1, (x0 + x1) / 2 + t / 2, z1), fc)
        g.box((ox0, x0, (z0 + z1) / 2 - t / 2), (ox1, x1, (z0 + z1) / 2 + t / 2), fc)
        if sill:
            sx0, sx1 = (y, y + 0.35) if s > 0 else (y - 0.35, y)
            g.box((sx0, x0 - 0.15, z0 - 0.15), (sx1, x1 + 0.15, z0 + 0.05), fc)


def lantern(g, li, x, y, z, s=1.0):
    """small iron wall lantern; glass on part `li`"""
    fr = col(IRON)
    g.box((x - 0.35 * s, y - 0.35 * s, z), (x + 0.35 * s, y + 0.35 * s, z + 0.12 * s), fr)
    g.box((x - 0.35 * s, y - 0.35 * s, z + 0.85 * s), (x + 0.35 * s, y + 0.35 * s, z + 0.97 * s), fr)
    g.cyl(x, y, z + 0.97 * s, z + 1.3 * s, 0.32 * s, fr, r1=0.06)
    for dx in (-0.35, 0.25):
        for dy in (-0.35, 0.25):
            g.box((x + dx * s, y + dy * s, z), (x + (dx + 0.1) * s, y + (dy + 0.1) * s, z + 0.9 * s), fr)
    li.box((x - 0.26 * s, y - 0.26 * s, z + 0.12 * s), (x + 0.26 * s, y + 0.26 * s, z + 0.85 * s), glow(*LAMP))


def flowers(g, x0, y0, x1, y1, z, seed, n=None, size=0.16):
    rng = np.random.default_rng(seed)
    n = n or int((x1 - x0) * (y1 - y0) * 5)
    leaf = pick(LEAVES, seed)
    g.fill((x0, y0, z), (x1, y1, z + 0.35), lambda X, Y, Z: Z < z + 0.2 + 0.15 * snoise(X, Y, Z, 5, seed), leaf)
    for _ in range(n):
        fx, fy = rng.uniform(x0 + 0.1, x1 - 0.1), rng.uniform(y0 + 0.1, y1 - 0.1)
        fz = z + rng.uniform(0.3, 0.55)
        c = col(FLOWERS[rng.integers(len(FLOWERS))])
        g.box((fx - size, fy - size, fz), (fx + size, fy + size, fz + size * 1.2), c)
        g.box((fx - 0.05, fy - 0.05, fz - 0.3), (fx + 0.05, fy + 0.05, fz), col('#3E9A3A'))


def stone_band(g, x0, y0, x1, y1, z0, z1, seed):
    """rough stone footing: blocks with mortar lines"""
    st = pick(STONE, seed)
    g.box((x0, y0, z0), (x1, y1, z1), st)

    def m(X, Y, Z):
        row = np.floor((Z - z0) / 0.4)
        off = np.where(np.mod(row, 2) == 0, 0.0, 0.35)
        return (np.mod(Z - z0, 0.4) < VOX) | (np.mod(X + Y + off, 0.7) < VOX)
    g.paint((x0, y0, z0), (x1, y1, z1), m, col(STONE_D))


def egg_shape(g, cx, cy, z0, r, h, c, tilt_y=False):
    """an upright egg, base at z0"""
    zc = z0 + h * 0.42

    def m(X, Y, Z):
        t = (Z - zc) / np.where(Z > zc, h * 0.58, h * 0.42)
        rr = r * np.sqrt(np.clip(1 - t * t, 0, 1)) * np.where(Z > zc, 1 - 0.12 * t, 1)
        return (X - cx) ** 2 + (Y - cy) ** 2 <= rr * rr
    g.fill((cx - r, cy - r, z0), (cx + r, cy + r, z0 + h), m, c)


def egg_flat(g, cx, y0, y1, cz, r, h, c):
    """an egg outline standing in the x-z plane (for emblems on a wall)"""
    def m(X, Y, Z):
        t = (Z - cz) / np.where(Z > cz, h * 0.58, h * 0.42)
        rr = r * np.sqrt(np.clip(1 - t * t, 0, 1)) * np.where(Z > cz, 1 - 0.12 * t, 1)
        return np.abs(X - cx) <= rr
    g.fill((cx - r, y0, cz - h * 0.42), (cx + r, y1, cz + h * 0.58), m, c)


# ================================================================ buildings
@B('HatcheryBarn', 24, 22, 20.5, budget=700, note=
   'the hub landmark: big red gambrel barn, 22 x 16 body, double X doors (8 x 9) on the front, hayloft, '
   'a glowing golden-egg emblem on the gable (the anchor, sign centre for "HATCHERY"), side windows, '
   'cupola with an egg weathervane (part "vane" turns) and lanterns either side of the doors (part "lights" flickers)')
def _barn(p):
    g = p.part()
    li = p.part('lights', anim='flicker', parent='body')
    W, D = 11.0, 8.0  # half width, half depth
    eave, ridge = 10.0, 17.2
    stone_band(g, -W - 0.2, -D - 0.2, W + 0.2, D + 0.2, 0, 0.8, 301)
    # walls: vertical boards
    boards(g, (-W, -D, 0.8), (W, D, eave), 0, 0.6, BARN, BARN_SEAM, 302)
    g.paint((-W, -D, 0.8), (W, D, eave), lambda X, Y, Z: (np.abs(np.abs(X) - W) < VOX * 1.5) & (np.mod(Y + D, 0.6) < VOX), col(BARN_SEAM))
    gable_wall(g, W, -D, D, eave, ridge - 0.5, pick(BARN, 303), 'gambrel')
    g.paint((-W, -D, eave - 0.1), (W, D, ridge), lambda X, Y, Z: np.mod(X + W, 0.6) < VOX, col(BARN_SEAM))
    # cream corner boards and eave band
    cr = col(CREAM[0])
    for sx in (-1, 1):
        for sy in (-1, 1):
            x0 = W - 0.5 if sx > 0 else -W - 0.1
            y0 = D - 0.5 if sy > 0 else -D - 0.1
            g.box((x0, y0, 0.8), (x0 + 0.6, y0 + 0.6, eave), cr)
    g.box((-W - 0.1, -D - 0.1, eave - 0.45), (W + 0.1, -D + 0.3, eave), cr)
    g.box((-W - 0.1, D - 0.3, eave - 0.45), (W + 0.1, D + 0.1, eave), cr)
    # roof: gambrel, ridge along y, overhang
    roof(g, W + 0.9, -D - 0.7, D + 0.7, eave - 0.6, ridge, 0.5, SHINGLE, 'gambrel', 304, edge=CREAM[0])
    # big double doors (front, y = -D), 8 wide, 9 tall, in a cream frame
    g.box((-4.6, -D - 0.3, 0.8), (4.6, -D, 9.8), cr)
    g.carve((-4.0, -D - 0.4, 0.8), (4.0, -D + 0.3, 9.2))
    wd = pick(BARN, 305)
    xdoor(g, -4.0, -0.05, -D + 0.3, 0.8, 9.2, wd, CREAM[0], 0.3)
    xdoor(g, 0.05, 4.0, -D + 0.3, 0.8, 9.2, wd, CREAM[0], 0.3)
    g.box((-0.05, -D - 0.1, 0.8), (0.05, -D + 0.3, 9.2), col('#4A2C1A'))  # the gap between the doors
    # sliding-door track and handles
    g.box((-8.5, -D - 0.55, 9.3), (8.5, -D - 0.3, 9.6), col(IRON))
    for x in (-0.5, 0.3):
        g.box((x, -D - 0.45, 4.2), (x + 0.2, -D - 0.25, 5.4), col(IRON))
    # hayloft door with straw, above the doors
    g.box((-2.2, -D - 0.25, 10.5), (2.2, -D, 13.4), cr)
    g.carve((-1.8, -D - 0.3, 10.8), (1.8, -D + 0.4, 13.1))
    g.box((-1.8, -D + 0.2, 10.8), (1.8, -D + 0.4, 13.1), col('#4A2C1A'))
    g.fill((-1.8, -D - 0.2, 10.8), (1.8, -D + 0.3, 11.9),
           lambda X, Y, Z: Z < 11.2 + 0.5 * (0.5 + 0.5 * snoise(X, Y, Z, 4, 7)), pick(STRAW, 306))
    g.box((-0.15, -D - 1.6, 13.5), (0.15, -D, 13.8), col(IRON))  # hay hoist beam
    g.box((-0.05, -D - 1.5, 12.3), (0.05, -D - 1.4, 13.5), col('#C9A06A'))
    # golden egg emblem on the gable, in a round cream frame (the sign)
    ez = 14.95

    def ring(X, Y, Z):
        return (X ** 2 + (Z - ez) ** 2) <= 1.05 ** 2
    g.fill((-1.1, -D - 0.3, ez - 1.1), (1.1, -D, ez + 1.1), ring, cr)
    egg_flat(g, 0, -D - 0.45, -D - 0.2, ez - 0.08, 0.62, 1.6, glow(GOLD, 1.6))
    p.anchor = (0, -D - 0.45, ez)
    # side windows: two per side, warm glow
    for x in (-W, W):
        for yy in (-4.5, 2.0):
            window(g, yy, yy + 2.5, x, 3.6, 6.6, CREAM[0], axis='x')
    # front windows either side of the doors
    for x0 in (-9.2, 6.2):
        window(g, x0, x0 + 3.0, -D, 4.0, 7.0, CREAM[0])
        # flower box under each
        g.box((x0 - 0.1, -D - 0.8, 3.3), (x0 + 3.1, -D, 3.8), pick(WOOD, 307))
        flowers(g, x0, -D - 0.75, x0 + 3.0, -D - 0.05, 3.7, 308 + int(x0), n=10, size=0.14)
    # lanterns either side of the doors
    for x in (-5.4, 5.4):
        g.box((x - 0.1, -D - 0.6, 7.6), (x + 0.1, -D, 7.8), col(IRON))
        lantern(g, li, x, -D - 0.6, 6.4, 1.1)
    # cupola on the ridge
    cz = ridge - 0.4
    boards(g, (-1.4, -1.4, cz), (1.4, 1.4, cz + 2.0), 0, 0.4, CREAM, '#D8CCB2', 309)
    for x in (-1.4, 1.4):
        for z in np.arange(cz + 0.4, cz + 1.7, 0.3):
            g.box((x - 0.1, -1.0, z), (x + 0.1, 1.0, z + 0.1), col('#4A2C1A'))
    for y in (-1.4, 1.4):
        for z in np.arange(cz + 0.4, cz + 1.7, 0.3):
            g.box((-1.0, y - 0.1, z), (1.0, y + 0.1, z + 0.1), col('#4A2C1A'))

    def cap(X, Y, Z):
        return Z <= cz + 2.0 + 1.3 * (1 - np.maximum(np.abs(X), np.abs(Y)) / 1.8)
    g.fill((-1.8, -1.8, cz + 2.0), (1.8, 1.8, cz + 3.3), cap, pick(SHINGLE, 310))
    g.box((-0.08, -0.08, cz + 3.2), (0.08, 0.08, cz + 3.6), col(IRON))
    # weathervane: an arrow with an egg on it, turns
    v = p.part('vane', anim='turn', parent='body', pivot=(0, 0, cz + 3.6))
    v.box((-0.07, -0.07, cz + 3.6), (0.07, 0.07, 20.3), col(IRON))
    v.box((-1.3, -0.05, 19.6), (1.3, 0.05, 19.75), col(IRON))
    v.fill((1.0, -0.06, 19.3), (1.6, 0.06, 20.05), lambda X, Y, Z: np.abs(Z - 19.67) < (1.6 - X) * 0.6, col(IRON))
    v.fill((-1.6, -0.06, 19.35), (-1.1, 0.06, 20.0), lambda X, Y, Z: np.abs(Z - 19.67) < 0.32, col(IRON))
    egg_flat(v, 0, -0.1, 0.1, 19.95, 0.28, 0.75, col(GOLD))
    for i, (dx, dy) in enumerate(((1, 0), (-1, 0), (0, 1), (0, -1))):
        v.box((dx * 0.7 - 0.04, dy * 0.7 - 0.04, 19.2), (dx * 0.7 + 0.04, dy * 0.7 + 0.04, 19.3), col(IRON))
    # hay bales by the door
    for x, y in ((-7.4, -D - 1.6), (7.4, -D - 1.6)):
        g.rrbox((x - 1.2, y - 0.7, 0), (x + 1.2, y + 0.7, 1.3), 0.2, pick(STRAW, 311))
        g.paint((x - 1.3, y - 0.8, 0), (x + 1.3, y + 0.8, 1.4), lambda X, Y, Z, x=x: np.abs(np.abs(X - x) - 0.6) < 0.08, col('#B5452F'))


@B('Silo', 9.4, 9.4, 21, 'grain silo: 6.4 wide metal drum on a stone base, ribbed, dome cap with a vent, '
   'ladder up the front and a red band with a blank cream sign at the anchor')
def _silo(p):
    g = p.part()
    R = 3.2
    g.cyl(0, 0, 0, 1.0, R + 0.35, pick(STONE, 321))
    g.paint((-4, -4, 0), (4, 4, 1.0), lambda X, Y, Z: (np.mod(Z, 0.5) < VOX) | (np.mod(np.arctan2(Y, X) * 4, 1.0) < 0.06), col(STONE_D))
    g.cyl(0, 0, 1.0, 16.5, R, pick(METAL, 322))
    # rings every 1.5 studs and vertical seams
    g.cyl(0, 0, 1.0, 16.5, R + 0.1, col(METAL_D), cond=lambda X, Y, Z: np.mod(Z - 1.0, 1.5) < 0.15)
    g.paint((-R, -R, 1.0), (R, R, 16.5), lambda X, Y, Z: np.mod(np.arctan2(Y, X) * R, 1.2) < VOX, col(METAL_D))
    # red band with a sign
    g.cyl(0, 0, 11.0, 13.0, R + 0.12, pick(BARN, 323))
    g.box((-1.6, -R - 0.35, 11.2), (1.6, -R + 0.5, 12.8), col(SIGN))
    p.anchor = (0, -R - 0.35, 12.0)
    # dome
    g.ell((0, 0, 16.5), (R + 0.15, R + 0.15, 2.6), pick(METAL, 324), cond=lambda X, Y, Z: Z >= 16.5)
    g.paint((-R, -R, 16.5), (R, R, 19.2), lambda X, Y, Z: np.mod(np.arctan2(Y, X) * 3, 1.0) < 0.07, col(METAL_D))
    g.cyl(0, 0, 18.8, 19.8, 0.5, col(METAL_D))
    g.cyl(0, 0, 19.8, 20.3, 0.8, pick(SHINGLE, 325), r1=0.1)
    # ladder on the front
    ir = col(IRON)
    for x in (-0.55, 0.45):
        g.box((x, -R - 0.55, 1.0), (x + 0.1, -R - 0.45, 17.0), ir)
        for z in np.arange(1.5, 16.6, 1.6):
            g.box((x, -R - 0.5, z), (x + 0.1, -R + 0.05, z + 0.1), ir)
    for z in np.arange(1.6, 16.6, 0.6):
        g.box((-0.55, -R - 0.55, z), (0.55, -R - 0.45, z + 0.1), ir)
    # safety cage hoops
    for z in np.arange(6.0, 16.6, 2.5):
        g.fill((-0.8, -R - 1.2, z), (0.8, -R - 0.3, z + 0.12),
               lambda X, Y, Z: np.abs(np.sqrt(X ** 2 + (Y + R + 0.45) ** 2) - 0.75) < 0.07, ir)
    # chute down the side
    g.seg((R - 0.3, 0, 15.5), (R + 0.6, 0, 14.5), 0.3, col(METAL_D))
    g.seg((R + 0.6, 0, 14.5), (R + 0.6, 0, 2.5), 0.3, col(METAL_D))


@B('Windmill', 14, 10, 22, budget=500, note='farm windmill: tapered cream tower with a red cap, door, two windows; '
   'part "sails" spins about the hub (pivot) facing the front')
def _windmill(p):
    g = p.part()
    # tower: 8-sided feel via a rounded cone
    g.cyl(0, 1.0, 0, 1.0, 3.9, pick(STONE, 331))
    g.paint((-4, -3, 0), (4, 5, 1.0), lambda X, Y, Z: np.mod(Z, 0.5) < VOX, col(STONE_D))

    def octa(r0, r1, z0, z1):
        def m(X, Y, Z):
            r = r0 + (r1 - r0) * np.clip((Z - z0) / (z1 - z0), 0, 1)
            a = np.abs(X)
            b = np.abs(Y - 1.0)
            return np.maximum(np.maximum(a, b), (a + b) / 1.38) <= r
        return m
    g.fill((-3.6, -2.6, 1.0), (3.6, 4.6, 14.0), octa(3.5, 2.4, 1.0, 14.0), pick(CREAM, 332))
    g.paint((-3.6, -2.6, 1.0), (3.6, 4.6, 14.0), lambda X, Y, Z: np.mod(Z, 0.8) < VOX, col('#D8CCB2'))
    # cap
    g.fill((-3.0, -2.0, 14.0), (3.0, 4.0, 14.4), octa(2.9, 2.9, 14, 14.4), col(WOOD_D[0]))
    g.ell((0, 1.0, 14.3), (2.9, 3.2, 3.2), pick(SHINGLE, 333), cond=lambda X, Y, Z: Z >= 14.3)
    g.paint((-3, -2.2, 14.3), (3, 4.2, 17.6), lambda X, Y, Z: np.mod(Z, 0.5) < VOX, col(SHINGLE_D))
    g.cyl(0, 1.0, 17.3, 18.2, 0.25, col(GOLD), r1=0.1)
    # door and windows
    g.box((-1.2, -2.6, 1.0), (1.2, -2.0, 6.0), col(CREAM[1]))
    g.carve((-0.9, -2.7, 1.0), (0.9, -1.8, 5.7))
    g.box((-0.9, -2.0, 1.0), (0.9, -1.8, 5.7), pick(WOOD, 334))
    g.paint((-0.9, -2.0, 1.0), (0.9, -1.8, 5.7), lambda X, Y, Z: np.mod(X + 0.9, 0.45) < VOX, col('#8B5A33'))
    g.box((-0.4, -2.2, 3.0), (0.4, -2.0, 3.6), col(IRON))
    for z in (7.5, 11.0):
        r = 3.5 - 1.1 * (z - 1) / 13 - 0.1
        window(g, -0.7, 0.7, 1.0 - r, z, z + 1.6, '#8B5A33')
    # axle housing on the front, sails spin about it
    hz = 13.0
    g.seg((0, 0.0, hz), (0, -2.0, hz), 0.55, col(WOOD_D[0]))
    s = p.part('sails', anim='spin', parent='body', pivot=(0, -2.3, hz))
    s.seg((0, -1.9, hz), (0, -2.6, hz), 0.75, col(RED))
    s.ell((0, -2.75, hz), (0.45, 0.3, 0.45), col(GOLD))
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 4
        ca, sa = math.cos(a), math.sin(a)
        s.seg((ca * 0.5, -2.3, hz + sa * 0.5), (ca * 6.6, -2.3, hz + sa * 6.6), 0.2, pick(WOOD_D, 335))
        # lattice sail: a frame with cream cloth
        nx, nz = -sa, ca  # across the arm

        def m(X, Y, Z, ca=ca, sa=sa, nx=nx, nz=nz):
            u = (X * ca + (Z - hz) * sa)
            v = (X * nx + (Z - hz) * nz)
            return (u > 1.6) & (u < 6.4) & (v > 0.15) & (v < 1.7) & (np.abs(Y + 2.3) < 0.16)
        s.fill((-6.8, -2.45, hz - 6.8), (6.8, -2.15, hz + 6.8), m,
               lambda X, Y, Z, ca=ca, sa=sa, nx=nx, nz=nz: np.where(
                   (np.mod(X * ca + (Z - hz) * sa, 0.8) < 0.12) | (np.mod(X * nx + (Z - hz) * nz, 0.73) < 0.12),
                   col('#8B5A33'), col(CREAM[0])))


@B('Well', 5.5, 5.5, 7.6, 'stone wishing well with a little shingle roof, crank and rope; part "bucket" bobs')
def _well(p):
    g = p.part()
    R = 2.0
    g.cyl(0, 0, 0, 2.2, R, pick(STONE, 341))
    g.paint((-R, -R, 0), (R, R, 2.2), lambda X, Y, Z: (np.mod(Z, 0.45) < VOX) |
            (np.mod(np.arctan2(Y, X) * R + np.floor(Z / 0.45) * 0.4, 0.8) < VOX), col(STONE_D))
    g.carve((-R, -R, 0.6), (R, R, 2.3), lambda X, Y, Z: X * X + Y * Y < (R - 0.45) ** 2)
    g.cyl(0, 0, 0.6, 0.9, R - 0.45, lambda X, Y, Z: np.where(hnoise(X, Y, Z, 7) > 0.8, col('#7FD3FF'), col('#3FA9F5')))
    g.cyl(0, 0, 2.2, 2.45, R + 0.1, pick(STONE, 342), cond=lambda X, Y, Z: X * X + Y * Y > (R - 0.5) ** 2)
    w = pick(WOOD_D, 343)
    for x in (-R + 0.1, R - 0.5):
        g.box((x, -0.2, 2.2), (x + 0.4, 0.2, 5.6), w)
    # roof
    roof(g, 2.7, -1.8, 1.8, 5.2, 7.5, 0.3, SHINGLE, 'gable', 344, edge=CREAM[0])
    # axle and crank
    g.seg((-R + 0.3, 0, 4.6), (R + 0.6, 0, 4.6), 0.18, pick(WOOD, 345))
    g.box((R + 0.5, -0.06, 4.0), (R + 0.62, 0.06, 4.7), col(IRON))
    g.box((R + 0.5, -0.5, 3.95), (R + 0.62, 0.06, 4.07), col(IRON))
    g.cyl(0, 0, 4.4, 4.8, 0.3, col('#C9A06A'))
    b = p.part('bucket', anim='bob', parent='body', pivot=(0, 0, 4.4))
    b.box((-0.05, -0.05, 3.0), (0.05, 0.05, 4.4), col('#C9A06A'))
    b.cyl(0, 0, 2.3, 3.0, 0.38, pick(WOOD, 346), r1=0.45)
    b.paint((-0.5, -0.5, 2.3), (0.5, 0.5, 3.0), lambda X, Y, Z: np.abs(Z - 2.65) < 0.06, col(IRON))
    # a few flowers at the foot
    flowers(g, -2.7, -2.7, -1.3, -1.7, 0, 347, n=6)


def stall(p, awning, seed, goods='eggs'):
    g = p.part()
    a, b = AWNINGS[awning] if awning in AWNINGS else awning
    w = pick(WOOD, seed)
    wd = pick(WOOD_D, seed + 1)
    # counter: 7 x 2.4, 3.2 tall, planked front
    boards(g, (-3.5, -1.8, 0), (3.5, 0.6, 3.0), 0, 0.5, WOOD, '#8B5A33', seed + 2)
    g.box((-3.7, -2.0, 3.0), (3.7, 0.8, 3.3), wd)
    g.box((-3.5, -1.9, 0.9), (3.5, -1.8, 1.25), col(a))  # stripe on the counter front
    # back posts and front posts
    for x in (-3.4, 3.0):
        g.box((x, -1.9, 3.3), (x + 0.4, -1.5, 7.0), wd)
        g.box((x, 1.6, 0), (x + 0.4, 2.0, 8.2), wd)
    # back shelf
    g.box((-3.4, 1.2, 4.6), (3.4, 2.0, 4.8), w)
    # striped awning, sloped from the back (8.2) to the front (6.6), scalloped edge
    ca, cb = col(a), col(b)

    def m(X, Y, Z):
        zt = 8.4 + (Y - 2.2) * (1.9 / 4.8)
        return (Z <= zt) & (Z >= zt - 0.25)
    g.fill((-4.0, -2.6, 6.0), (4.0, 2.2, 8.6), m, lambda X, Y, Z: np.where(np.mod(X + 4.0, 1.6) < 0.8, ca, cb))

    def sc(X, Y, Z):
        u = np.mod(X + 4.0, 0.8) - 0.4
        return Z >= 6.0 + 0.4 - np.sqrt(np.maximum(0.16 - u * u, 0))
    g.fill((-4.0, -2.8, 6.0), (4.0, -2.5, 6.55), sc, lambda X, Y, Z: np.where(np.mod(X + 4.0, 1.6) < 0.8, ca, cb))
    # sign board on top of the back posts (blank; the game writes on it)
    g.box((-2.6, 1.7, 8.2), (2.6, 2.0, 9.6), col(SIGN))
    g.box((-2.8, 1.65, 8.0), (2.8, 2.05, 8.2), wd)
    g.box((-2.8, 1.65, 9.6), (2.8, 2.05, 9.8), wd)
    p.anchor = (0, 1.65, 8.9)
    # goods
    if goods == 'eggs':
        for i, x in enumerate((-2.6, -0.9, 0.8, 2.4)):
            g.box((x - 0.7, -1.6, 3.3), (x + 0.7, -0.2, 3.7), pick(STRAW, seed + 10 + i))
            for j in range(3):
                c = col(['#F6EEDC', '#A7E98F', '#FFD166', '#8FD3FF'][(i + j) % 4])
                egg_shape(g, x - 0.4 + j * 0.4, -0.9 + (j % 2) * 0.25, 3.6, 0.2, 0.55, c)
    elif goods == 'veg':
        for i, (x, c1) in enumerate(((-2.6, '#FF9F1C'), (-0.9, '#E8413C'), (0.8, '#A7E98F'), (2.4, '#FFE066'))):
            g.box((x - 0.75, -1.7, 3.3), (x + 0.75, -0.1, 3.8), pick(WOOD, seed + 20))
            g.fill((x - 0.65, -1.6, 3.6), (x + 0.65, -0.2, 4.3),
                   lambda X, Y, Z, x=x: Z < 3.85 + 0.3 * (0.5 + 0.5 * snoise(X * 3, Y * 3, Z, 2, i)), col(c1))
    elif goods == 'flowers':
        for i, x in enumerate((-2.6, -0.9, 0.8, 2.4)):
            g.cyl(x, -0.9, 3.3, 3.9, 0.5, col('#C2603A'), r1=0.6)
            flowers(g, x - 0.55, -1.45, x + 0.55, -0.35, 3.85, seed + 30 + i, n=6, size=0.13)
    # crates beside
    for x, y in ((-4.6, -0.8), (4.6, 0.2)):
        g.box((x - 0.6, y - 0.6, 0), (x + 0.6, y + 0.6, 1.2), pick(WOOD, seed + 40))
        g.paint((x - 0.6, y - 0.6, 0), (x + 0.6, y + 0.6, 1.2), lambda X, Y, Z: np.mod(Z, 0.4) < VOX, col('#8B5A33'))


@B('StallRed', 10.5, 5.6, 10, 'market stall, red and cream awning, egg trays on the counter; blank sign at the anchor', budget=220)
def _stall_r(p):
    stall(p, 'Red', 351, 'eggs')


@B('StallBlue', 10.5, 5.6, 10, 'market stall, blue and cream awning, crates of fruit and veg; blank sign at the anchor', budget=220)
def _stall_b(p):
    stall(p, 'Blue', 361, 'veg')


@B('StallGreen', 10.5, 5.6, 10, 'market stall, green and cream awning, flower pots; blank sign at the anchor', budget=220)
def _stall_g(p):
    stall(p, 'Green', 371, 'flowers')


@B('ThemeStand', 11, 6.5, 11.5, 'the Theme Stand for themed eggs: purple and gold awning, glowing Ember and Frost eggs '
   'on velvet cushions (part "eggs" bobs), crown finial, blank sign at the anchor', budget=260)
def _theme(p):
    g = p.part()
    a, b = '#7B4FD8', '#FFD166'
    wd = pick(WOOD_D, 381)
    boards(g, (-3.8, -2.0, 0), (3.8, 0.8, 3.0), 0, 0.5, ['#6A44BE', '#6340B5'], '#4E3291', 382)
    g.box((-4.0, -2.2, 3.0), (4.0, 1.0, 3.3), col(GOLD))
    g.box((-3.8, -2.1, 1.1), (3.8, -2.0, 1.35), col(GOLD))
    for x in (-3.7, 3.3):
        g.box((x, -2.1, 3.3), (x + 0.4, -1.7, 7.4), col(GOLD))
        g.box((x, 1.8, 0), (x + 0.4, 2.2, 8.6), wd)
    ca, cb = col(a), col(b)

    def m(X, Y, Z):
        zt = 8.8 + (Y - 2.4) * (1.9 / 5.2)
        return (Z <= zt) & (Z >= zt - 0.25)
    g.fill((-4.3, -2.9, 6.2), (4.3, 2.4, 9.0), m, lambda X, Y, Z: np.where(np.mod(X + 4.3, 1.72) < 0.86, ca, cb))

    def sc(X, Y, Z):
        u = np.mod(X + 4.3, 0.86) - 0.43
        return Z >= 6.35 + 0.43 - np.sqrt(np.maximum(0.185 - u * u, 0))
    g.fill((-4.3, -3.1, 6.35), (4.3, -2.8, 6.95), sc, lambda X, Y, Z: np.where(np.mod(X + 4.3, 1.72) < 0.86, ca, cb))
    # sign + crown
    g.box((-3.0, 1.9, 8.6), (3.0, 2.2, 10.2), col(SIGN))
    g.box((-3.2, 1.85, 8.4), (3.2, 2.25, 8.6), col(GOLD))
    g.box((-3.2, 1.85, 10.2), (3.2, 2.25, 10.4), col(GOLD))
    p.anchor = (0, 1.85, 9.4)
    g.box((-0.8, 1.9, 10.4), (0.8, 2.2, 10.8), col(GOLD))
    for x in (-0.7, 0, 0.7):
        g.box((x - 0.12, 1.9, 10.8), (x + 0.12, 2.2, 11.3), col(GOLD))
        g.ell((x, 2.05, 11.35), (0.13, 0.13, 0.13), glow('#FF6FA8', 2.0))
    # cushions
    e = p.part('eggs', anim='bob', parent='body', pivot=(0, -0.8, 3.6))
    for x, (c1, gl) in zip((-2.4, 0, 2.4), (('#FF7A2F', '#FFB547'), ('#7FD3FF', '#DFF4FF'), ('#FF7A2F', '#FFB547'))):
        g.rrbox((x - 0.9, -1.6, 3.3), (x + 0.9, 0.0, 3.75), 0.15, col('#B0325A'))
        g.box((x - 0.95, -1.65, 3.3), (x + 0.95, 0.05, 3.4), col(GOLD))
        egg_shape(e, x, -0.8, 3.7, 0.5, 1.4, lambda X, Y, Z, c1=c1, gl=gl: np.where(hnoise(X, Y, Z, 11) > 0.8, glow(gl, 2.2), glow(c1, 1.0)))
    # banners on the posts
    for x in (-3.5, 3.5):
        g.fill((x - 0.5, -2.25, 4.3), (x + 0.5, -2.1, 6.0), lambda X, Y, Z, x=x: Z > 4.3 + 0.5 * np.abs(X - x), ca)


@B('BookStand', 6.2, 5.6, 8.5, 'Hatchery Book kiosk: a lectern with the giant open Book (pages glow softly, part "pages" pulses), '
   'shingle canopy on four posts, blank sign on the canopy front at the anchor', budget=220)
def _book(p):
    g = p.part()
    pg = p.part('pages', anim='pulse', parent='body')
    wd = pick(WOOD_D, 391)
    # round step
    g.cyl(0, 0, 0, 0.4, 2.6, pick(STONE, 392))
    g.cyl(0, 0, 0.4, 0.6, 2.0, pick(WOOD, 393))
    # lectern
    g.box((-0.6, -0.3, 0.6), (0.6, 0.6, 3.2), pick(WOOD, 394))
    g.box((-0.9, -0.6, 0.6), (0.9, 0.9, 0.9), wd)

    def slope(X, Y, Z):
        zt = 3.2 + (Y + 0.9) * 0.45
        return (Z <= zt) & (Z >= zt - 0.3)
    g.fill((-1.6, -1.0, 2.8), (1.6, 1.2, 4.4), slope, wd)
    # the book: two thick page blocks and a red cover
    def tilt(z):
        return lambda X, Y, Z: (Z >= 3.2 + (Y + 0.9) * 0.45) & (Z <= 3.2 + (Y + 0.9) * 0.45 + z)
    g.fill((-1.55, -0.95, 3.0), (1.55, 1.15, 4.6), tilt(0.15), col(RED_D))
    pc = glow('#FFF4D6', 0.6)
    for x0, x1 in ((-1.45, -0.05), (0.05, 1.45)):
        def page(X, Y, Z, x0=x0, x1=x1):
            base = 3.35 + (Y + 0.9) * 0.45
            bulge = 0.25 * np.sin(np.clip((X - x0) / (x1 - x0), 0, 1) * math.pi) ** 0.5
            return (Z >= base) & (Z <= base + bulge)
        pg.fill((x0, -0.85, 3.2), (x1, 1.05, 4.5), page, pc)
    pg.paint((-1.5, -0.9, 3.2), (1.5, 1.1, 4.6), lambda X, Y, Z: np.mod(Y, 0.3) < VOX, col('#E8D9B5'))
    g.box((-0.06, -0.9, 3.3), (0.06, 1.1, 4.4), col(GOLD))  # bookmark ribbon spine
    g.box((0.3, -1.1, 3.0), (0.45, -0.9, 3.35), col(GOLD))
    # canopy
    for x in (-2.4, 2.0):
        for y in (-1.9, 1.5):
            g.box((x, y, 0.4), (x + 0.4, y + 0.4, 6.4), wd)
    roof(g, 3.0, -2.5, 2.5, 6.0, 8.3, 0.35, SHINGLE, 'gable', 395, edge=CREAM[0])
    g.box((-2.6, -2.55, 5.6), (2.6, -2.25, 6.6), col(SIGN))
    p.anchor = (0, -2.55, 6.1)
    lantern(g, pg, 0, 0, 4.9, 0.7)
    g.box((-0.04, -0.04, 5.8), (0.04, 0.04, 6.4), col(IRON))


@B('MarketArch', 14, 3.0, 13, 'Egg Market entrance arch over a path: 10-wide, 9.5-high opening, two posts with '
   'flower boxes, a curved top beam, a hanging blank sign (anchor) and bunting (part "bunting" sways)', budget=100)
def _arch(p):
    g = p.part()
    wd = pick(WOOD_D, 411)
    w = pick(WOOD, 412)
    for x in (-6.5, 5.3):
        g.box((x - 0.2, -1.3, 0), (x + 1.4, 1.3, 1.0), pick(STONE, 413))
        g.box((x, -0.6, 1.0), (x + 1.2, 0.6, 11.0), w)
        g.paint((x, -0.6, 1.0), (x + 1.2, 0.6, 11.0), lambda X, Y, Z: np.mod(Z, 1.5) < VOX, col('#8B5A33'))
        g.box((x - 0.2, -0.8, 11.0), (x + 1.4, 0.8, 11.4), wd)
        egg_shape(g, x + 0.6, 0, 11.4, 0.45, 1.1, col(GOLD))
        # flower box on the post's front
        g.box((x - 0.2, -1.4, 2.5), (x + 1.4, -0.6, 3.1), wd)
        flowers(g, x - 0.1, -1.35, x + 1.3, -0.65, 3.0, 414 + int(x), n=6, size=0.13)

    # curved beam
    def beam(X, Y, Z):
        zt = 10.0 + 1.2 * np.cos(np.clip(X / 7.0, -1, 1) * math.pi / 2)
        return (Z <= zt) & (Z >= zt - 0.9) & (np.abs(X) <= 6.6)
    g.fill((-6.6, -0.5, 9.0), (6.6, 0.5, 11.3), beam, pick(BARN, 415))
    g.paint((-6.6, -0.5, 9.0), (6.6, 0.5, 11.3),
            lambda X, Y, Z: np.abs(Z - (10.0 + 1.2 * np.cos(np.clip(X / 7.0, -1, 1) * math.pi / 2) - 0.45)) < 0.1, col(CREAM[0]))
    # hanging sign
    for x in (-2.0, 1.9):
        g.box((x, -0.05, 9.0), (x + 0.1, 0.05, 10.6), col(IRON))
    g.box((-2.8, -0.2, 7.1), (2.8, 0.2, 9.0), col(SIGN))
    g.box((-3.0, -0.25, 6.9), (3.0, 0.25, 7.1), wd)
    g.box((-3.0, -0.25, 9.0), (3.0, 0.25, 9.2), wd)
    p.anchor = (0, -0.25, 8.05)
    # bunting between the posts, below the beam
    bu = p.part('bunting', anim='sway', parent='body', pivot=(0, 0, 9.6))
    cs = ['#FF6F91', '#FFE066', '#6FA8FF', '#A7E98F', '#FF9F1C']
    for i in range(12):
        x = -5.4 + i * 0.95
        sag = 9.4 - 0.9 * math.cos((x / 5.6) * math.pi / 2)
        if -3.1 < x < 3.1:
            continue
        bu.fill((x - 0.35, -0.08, sag - 0.7), (x + 0.35, 0.08, sag), lambda X, Y, Z, x=x, s=sag: (s - Z) < (0.35 - np.abs(X - x)) * 2.0,
                col(cs[i % len(cs)]))


@B('ChickenCoop', 8.4, 11, 8, 'little hen house on legs with a ramp, nest-box hatch, round door and a weathered roof; '
   'part "flag" (a pennant) sways', budget=200)
def _coop(p):
    g = p.part()
    wd = pick(WOOD_D, 421)
    for x in (-2.8, 2.4):
        for y in (-1.8, 1.4):
            g.box((x, y, 0), (x + 0.4, y + 0.4, 1.6), wd)
    boards(g, (-3.0, -2.0, 1.6), (3.0, 2.0, 5.0), 2, 0.45, ['#F2C14E', '#EAB843'], '#C9962E', 422)
    g.box((-3.1, -2.1, 1.5), (3.1, 2.1, 1.8), col('#8B5A33'))
    gable_wall(g, 3.0, -2.0, 2.0, 5.0, 6.6, pick(['#F2C14E', '#EAB843'], 423))
    roof(g, 3.6, -2.5, 2.5, 4.6, 7.1, 0.3, SHINGLE, 'gable', 424, edge=CREAM[0])
    # round door + ramp
    g.fill((-0.8, -2.2, 1.8), (0.8, -1.9, 3.8), lambda X, Y, Z: (X ** 2 + (Z - 2.8) ** 2) < 0.8 ** 2, col(CREAM[0]))
    g.fill((-0.6, -2.3, 1.8), (0.6, -1.8, 3.6), lambda X, Y, Z: (X ** 2 + (Z - 2.8) ** 2) < 0.6 ** 2, col('#4A2C1A'))
    g.carve((-0.6, -2.3, 1.8), (0.6, -2.0, 2.0))

    def ramp(X, Y, Z):
        zt = 1.8 + (Y + 2.0) * (1.8 / 3.0)
        return (Z <= zt) & (Z >= zt - 0.2)
    g.fill((-0.6, -5.0, 0), (0.6, -2.0, 1.85), ramp, pick(WOOD, 425))
    for yy in np.arange(-4.6, -2.0, 0.5):
        zz = 1.8 + (yy + 2.0) * 0.6
        g.box((-0.6, yy, zz), (0.6, yy + 0.1, zz + 0.1), col('#8B5A33'))
    # nest box on the side
    g.box((3.0, -1.4, 2.4), (3.9, 1.4, 4.0), pick(BARN, 426))
    g.fill((3.0, -1.6, 4.0), (4.1, 1.6, 4.6), lambda X, Y, Z: Z <= 4.0 + (4.1 - X) * 0.5, pick(SHINGLE, 427))
    g.fill((3.1, -1.2, 3.9), (3.8, 1.2, 4.3), lambda X, Y, Z: Z < 4.05 + 0.1 * snoise(X, Y, Z, 5, 2), pick(STRAW, 428))
    window(g, -2.6, -1.2, -2.0, 3.0, 4.2, CREAM[0], sill=False)
    window(g, 1.2, 2.6, -2.0, 3.0, 4.2, CREAM[0], sill=False)
    # pennant
    g.box((2.6, 1.0, 6.0), (2.72, 1.12, 8.0), col(IRON))
    f = p.part('flag', anim='sway', parent='body', pivot=(2.66, 1.06, 7.9))
    f.fill((2.72, 1.0, 7.2), (4.0, 1.12, 7.9), lambda X, Y, Z: np.abs(Z - 7.55) < (4.0 - X) * 0.27, col(RED))


# ============================================================ street props
@H('FencePicket', 4, 0.6, 2.4, 'one 4-stud section of white picket fence with a red-capped post at the left end; tile along X', budget=30)
def _picket(p):
    g = p.part()
    c = pick(CREAM, 431)
    g.box((-2.0, -0.25, 0), (-1.5, 0.25, 2.3), c)
    g.box((-2.05, -0.3, 2.3), (-1.45, 0.3, 2.45), col(RED))
    for z in (0.5, 1.5):
        g.box((-1.5, -0.05, z), (2.0, 0.15, z + 0.25), c)
    for i in range(5):
        x = -1.3 + i * 0.7

        def m(X, Y, Z, x=x):
            return Z <= 1.9 + (0.25 - np.abs(X - x - 0.2)) * 1.2
        g.fill((x, -0.18, 0), (x + 0.4, -0.05, 2.25), m, c)


@H('FenceGate', 4, 0.8, 2.6, 'picket gate between two posts; part "gate" turns about the left post (hinge = pivot)', budget=40)
def _gate(p):
    g = p.part()
    c = pick(CREAM, 432)
    for x in (-2.0, 1.5):
        g.box((x, -0.25, 0), (x + 0.5, 0.25, 2.5), c)
        g.box((x - 0.05, -0.3, 2.5), (x + 0.55, 0.3, 2.65), col(RED))
    k = p.part('gate', anim='turn', parent='body', pivot=(-1.5, 0, 0))
    for z in (0.5, 1.6):
        k.box((-1.45, -0.1, z), (1.45, 0.1, z + 0.25), c)
    for i in range(5):
        x = -1.35 + i * 0.6
        k.fill((x, -0.12, 0.2), (x + 0.35, 0.12, 2.2), lambda X, Y, Z, x=x: Z <= 2.0 + (0.18 - np.abs(X - x - 0.17)) * 1.2, c)
    k.fill((-1.45, -0.13, 0.5), (1.45, 0.13, 1.85), lambda X, Y, Z: np.abs((Z - 0.5) / 1.35 - (X + 1.45) / 2.9) < 0.1, c)
    k.box((1.0, -0.2, 1.1), (1.2, -0.12, 1.3), col(IRON))


@H('FenceRail', 4, 0.8, 1.8, 'rustic two-rail split-log fence section for the field edges; tile along X', budget=20)
def _rail(p):
    g = p.part()
    w = pick(WOOD_D, 433)
    g.box((-2.0, -0.3, 0), (-1.4, 0.3, 1.8), w)
    for z in (0.6, 1.3):
        g.seg((-1.6, 0, z), (2.0, 0, z + 0.05), 0.15, pick(WOOD, 434))


@H('LampPost', 1.6, 1.6, 7.6, 'iron street lamp with a warm lantern (part "light" flickers)', budget=40)
def _lamp(p):
    g = p.part()
    li = p.part('light', anim='flicker', parent='body')
    ir = col(IRON)
    g.cyl(0, 0, 0, 0.4, 0.7, ir, r1=0.5)
    g.cyl(0, 0, 0.4, 6.0, 0.17, ir)
    g.cyl(0, 0, 1.0, 1.4, 0.25, ir)
    g.cyl(0, 0, 5.8, 6.1, 0.4, ir)
    lantern(g, li, 0, 0, 6.1, 1.1)


@H('Signpost', 3.6, 1.2, 5.5, 'wooden signpost with three blank arrow boards (game writes "Egg Market", "Shop", "Your Tower")', budget=40)
def _signpost(p):
    g = p.part()
    g.box((-0.2, -0.2, 0), (0.2, 0.2, 5.0), pick(WOOD_D, 441))
    g.fill((-0.3, -0.3, 4.9), (0.3, 0.3, 5.4), lambda X, Y, Z: Z <= 5.4 - np.maximum(np.abs(X), np.abs(Y)) * 1.5, col(RED))
    for z, d, yy in ((4.0, 1, -0.25), (3.0, -1, 0.25), (2.0, 1, -0.25)):
        def m(X, Y, Z, z=z, d=d):
            u = X * d
            return (u <= 1.75) & (u >= -0.6) & (np.abs(Z - z - 0.3) <= np.minimum(0.32, (1.75 - u) * 0.9))
        g.fill((-1.8, yy - 0.08, z - 0.05), (1.8, yy + 0.08, z + 0.65), m, col(SIGN))
        g.paint((-1.8, yy - 0.09, z - 0.05), (1.8, yy + 0.09, z + 0.65),
                lambda X, Y, Z, z=z, d=d: (np.abs(Z - z - 0.3) > np.minimum(0.24, (1.6 - X * d) * 0.9 - 0.08)) | (X * d < -0.5), col('#C98E52'))


@H('Mailbox', 1.6, 2.2, 4.4, 'red farm mailbox for Daily Rewards: glowing letter peeks out, part "flag" rocks up when a reward is ready', budget=40)
def _mail(p):
    g = p.part()
    g.box((-0.18, -0.18, 0), (0.18, 0.18, 3.0), pick(WOOD_D, 451))
    g.box((-0.5, -0.8, 2.9), (0.5, 0.8, 3.05), pick(WOOD, 452))

    def m(X, Y, Z):
        return (Z <= 3.5) | (X ** 2 + (Z - 3.5) ** 2 <= 0.55 ** 2)
    g.fill((-0.55, -0.85, 3.05), (0.55, 0.85, 4.1), m, col(RED))
    g.paint((-0.6, -0.9, 3.0), (0.6, 0.9, 4.1), lambda X, Y, Z: (Y < -0.75), col(RED_D))
    g.fill((-0.6, -0.95, 3.0), (0.6, -0.85, 4.15), lambda X, Y, Z: ((Z <= 3.5) | (X ** 2 + (Z - 3.5) ** 2 <= 0.6 ** 2)) &
           ~((Z <= 3.5) & (np.abs(X) < 0.45) & (Z > 3.12) | (X ** 2 + (Z - 3.5) ** 2 <= 0.45 ** 2) & (Z > 3.12)), col(CREAM[0]))
    g.box((-0.12, -1.0, 3.4), (0.12, -0.9, 3.6), col(IRON))
    g.box((-0.3, -0.9, 3.75), (0.3, -0.84, 3.9), glow('#FFF4D6', 1.4))
    f = p.part('flag', anim='rock', parent='body', pivot=(0.6, 0.3, 3.4))
    f.box((0.56, 0.2, 3.3), (0.66, 0.4, 4.3), col('#FFD166'))
    f.box((0.56, 0.2, 3.9), (0.66, 0.75, 4.3), col('#FFD166'))


@H('NoticeBoard', 5, 1.8, 6, 'small roofed notice board with pinned notes (updates, events); blank face at the anchor', budget=80)
def _notice(p):
    g = p.part()
    wd = pick(WOOD_D, 461)
    for x in (-1.9, 1.5):
        g.box((x, -0.2, 0), (x + 0.4, 0.2, 5.0), wd)
    g.box((-1.5, -0.15, 2.0), (1.5, 0.15, 4.4), pick(['#C98E52', '#BF8549'], 462))
    g.box((-1.6, -0.2, 1.9), (1.6, 0.2, 2.0), wd)
    p.anchor = (0, -0.15, 3.2)
    rng = np.random.default_rng(463)
    for i in range(5):
        x, z = rng.uniform(-1.2, 0.6), rng.uniform(2.2, 3.6)
        g.box((x, -0.2, z), (x + 0.6, -0.15, z + 0.7), col(['#FFFFFF', '#FFF4B8', '#FFD6E7', '#D6F0FF'][i % 4]))
        g.box((x + 0.25, -0.24, z + 0.55), (x + 0.35, -0.2, z + 0.65), col(RED))
    roof(g, 2.4, -0.8, 0.8, 4.7, 5.9, 0.25, SHINGLE, 'gable', 464)


@H('Bench', 4, 1.6, 2.4, 'wooden park bench with iron ends', budget=40)
def _bench(p):
    g = p.part()
    ir = col(IRON)
    for x in (-1.8, 1.6):
        g.box((x, -0.6, 0), (x + 0.2, -0.4, 1.0), ir)
        g.box((x, 0.4, 0), (x + 0.2, 0.6, 2.2), ir)
        g.box((x, -0.6, 0.9), (x + 0.2, 0.6, 1.05), ir)
        g.box((x, -0.6, 1.4), (x + 0.2, -0.2, 1.55), ir)
    w = pick(WOOD, 471)
    for y in (-0.6, -0.15, 0.3):
        g.box((-2.0, y, 1.05), (2.0, y + 0.35, 1.25), w)
    for z in (1.5, 1.95):
        g.box((-2.0, 0.45, z), (2.0, 0.65, z + 0.3), w)


@H('FlowerPlanter', 4, 1.6, 1.6, 'long wooden planter box full of flowers', budget=40)
def _planter(p):
    g = p.part()
    g.box((-2.0, -0.8, 0), (2.0, 0.8, 0.9), pick(WOOD, 481))
    g.paint((-2.0, -0.8, 0), (2.0, 0.8, 0.9), lambda X, Y, Z: np.mod(Z, 0.3) < VOX, col('#8B5A33'))
    g.box((-2.1, -0.9, 0.85), (2.1, 0.9, 1.0), pick(WOOD_D, 482))
    g.box((-1.85, -0.65, 0.8), (1.85, 0.65, 0.95), col('#6B4A2E'))
    flowers(g, -1.85, -0.65, 1.85, 0.65, 0.95, 483, n=16)


@H('PathStones', 4, 4, 0.3, 'cluster of flat cobbles for path edges and junctions (lies on the grass)', budget=40)
def _stones(p):
    g = p.part()
    rng = np.random.default_rng(491)
    pts = []
    for _ in range(400):
        x, y = rng.uniform(-1.45, 1.45), rng.uniform(-1.45, 1.45)
        if all((x - a) ** 2 + (y - b) ** 2 > 1.05 ** 2 for a, b in pts):
            pts.append((x, y))
        if len(pts) == 9:
            break
    for i, (x, y) in enumerate(pts):
        r = rng.uniform(0.45, 0.6)
        g.cyl(x, y, 0, 0.18 + 0.06 * (i % 2), r, pick(['#D8B07A', '#CFA36B', '#E0BC8A', '#C9B79A'], 492 + i))


@H('EggCart', 5, 3.0, 3.2, 'two-wheeled wooden hand cart piled with eggs in straw; parked by the stalls', budget=80)
def _cart(p):
    g = p.part()
    w = pick(WOOD, 501)
    g.box((-1.8, -1.1, 1.0), (1.6, 1.1, 1.2), w)
    for y in (-1.1, 0.95):
        g.box((-1.8, y, 1.2), (1.6, y + 0.15, 2.0), w)
    for x in (-1.8, 1.45):
        g.box((x, -1.1, 1.2), (x + 0.15, 1.1, 2.0), w)
    g.box((-1.8, -1.15, 1.55), (1.6, 0.95 + 0.25, 1.7), col(RED))
    for y in (-1.3, 1.3):
        g.fill((-0.9, y - 0.18, 0), (0.9, y + 0.18, 1.8),
               lambda X, Y, Z: np.abs(np.sqrt(X ** 2 + (Z - 0.9) ** 2) - 0.72) < 0.18, pick(WOOD_D, 502))
        g.fill((-0.9, y - 0.08, 0), (0.9, y + 0.08, 1.8),
               lambda X, Y, Z: (np.sqrt(X ** 2 + (Z - 0.9) ** 2) < 0.7) & ((np.abs(X) < 0.07) | (np.abs(Z - 0.9) < 0.07)), pick(WOOD_D, 503))
    g.box((-0.1, -1.3, 0.8), (0.1, 1.3, 1.0), col(IRON))
    for y in (-0.8, 0.8):
        g.seg((1.6, y, 1.4), (2.5, y, 1.0), 0.09, pick(WOOD_D, 504))
    g.box((-2.0, -0.08, 0), (-1.8, 0.08, 1.0), pick(WOOD_D, 505))
    g.fill((-1.65, -0.95, 1.2), (1.45, 0.95, 1.9), lambda X, Y, Z: Z < 1.6 + 0.15 * snoise(X, Y, Z, 4, 3), pick(STRAW, 506))
    rng = np.random.default_rng(507)
    for i in range(9):
        x, y = -1.2 + (i % 3) * 1.1 + rng.uniform(-0.1, 0.1), -0.55 + (i // 3) * 0.55
        egg_shape(g, x, y, 1.55, 0.24, 0.65, col(['#F6EEDC', '#A7E98F', '#8FD3FF', '#FFD166'][i % 4]))


# ================================================= farm corners (west side)
@B('DuckPond', 13, 10, 2.6, 'little duck pond: water with sparkles, a pebble rim, reeds and cattails, lily pads '
   '(part "lilies" bobs) and a short wooden dock on the front', budget=380)
def _pond(p):
    g = p.part()
    lil = p.part('lilies', anim='bob', parent='body')

    def shape(X, Y, k=0.0):
        d = np.sqrt((X / 5.6) ** 2 + ((Y - 0.4) / 3.9) ** 2)
        return d <= 1.0 + k + 0.08 * np.sin(np.arctan2(Y, X) * 3 + 1.0)
    # pebble rim, then water a touch lower so the rim reads
    rim = pick(['#B9B2A6', '#A7A39B', '#C9C2B4', '#9A968E'], 601)
    g.fill((-6.5, -4.6, 0), (6.5, 5.2, 0.45), lambda X, Y, Z: shape(X, Y, 0.12) & ~shape(X, Y, -0.02) & (Z < 0.25 + 0.2 * hnoise(np.floor(X / 0.4), np.floor(Y / 0.4), 0 * Z, 3)), rim)
    g.fill((-6.0, -4.0, 0), (6.0, 4.8, 0.2), lambda X, Y, Z: shape(X, Y),
           lambda X, Y, Z: np.where(hnoise(X, Y, Z, 602) > 0.86, col('#BFE9FF', 0.6), np.where(np.sqrt(X * X + (Y - 0.4) ** 2) < 2.6, col('#2F8FD8'), col('#3FA9F5'))))
    # reeds and cattails at the back left and right
    rng = np.random.default_rng(603)
    for cx, cy in ((-4.2, 2.6), (4.4, 2.2), (-1.0, 4.0)):
        for _ in range(9):
            x, y = cx + rng.uniform(-0.9, 0.9), cy + rng.uniform(-0.6, 0.6)
            h = rng.uniform(1.4, 2.5)
            g.box((x - 0.06, y - 0.06, 0), (x + 0.06, y + 0.06, h), col(['#4DB043', '#3E9A3A', '#5CC24F'][rng.integers(3)]))
            if rng.random() < 0.45:
                g.box((x - 0.12, y - 0.12, h - 0.1), (x + 0.12, y + 0.12, h + 0.45), col('#7A4D2B'))
    # lily pads with a pink flower on some
    for i, (x, y) in enumerate(((-2.0, 0.0), (1.4, 1.6), (2.8, -0.8), (-3.4, 1.4), (0.2, -1.6))):
        lil.fill((x - 0.6, y - 0.6, 0.2), (x + 0.6, y + 0.6, 0.3),
                 lambda X, Y, Z, x=x, y=y: ((X - x) ** 2 + (Y - y) ** 2 < 0.5 ** 2) & ~((np.abs(Y - y) < 0.07) & (X > x)), col('#5DB13E'))
        if i % 2 == 0:
            lil.box((x - 0.15, y - 0.15, 0.3), (x + 0.15, y + 0.15, 0.5), col('#FF9EC7'))
            lil.box((x - 0.05, y - 0.05, 0.5), (x + 0.05, y + 0.05, 0.55), col('#FFE066'))
    # dock on the front edge
    w = pick(WOOD, 604)
    g.box((-1.2, -4.9, 0.35), (1.2, -2.2, 0.6), w)
    g.paint((-1.2, -4.9, 0.35), (1.2, -2.2, 0.6), lambda X, Y, Z: np.mod(Y, 0.5) < VOX, col('#8B5A33'))
    for x in (-1.2, 0.95):
        for y in (-2.5, -4.9):
            g.box((x, y, 0), (x + 0.25, y + 0.25, 0.9), pick(WOOD_D, 605))


@B('VegetablePatch', 10, 8, 1.6, 'raised vegetable bed in a plank frame: rows of cabbages, carrots, lettuces and pumpkins', budget=200)
def _veg(p):
    g = p.part()
    g.box((-4.8, -3.8, 0), (4.8, 3.8, 0.45), pick(WOOD, 611))
    g.paint((-4.8, -3.8, 0), (4.8, 3.8, 0.45), lambda X, Y, Z: np.mod(X + Y, 1.2) < VOX, col('#8B5A33'))
    g.box((-4.5, -3.5, 0.2), (4.5, 3.5, 0.5), pick(['#6B4A2E', '#5E4028', '#77543A'], 612))
    g.paint((-4.5, -3.5, 0.2), (4.5, 3.5, 0.5), lambda X, Y, Z: np.mod(Y + 3.5, 1.75) < 0.35, col('#4F3520'))
    rows = (-2.6, -0.9, 0.85, 2.6)
    for r, y in enumerate(rows):
        for i, x in enumerate(np.arange(-3.9, 4.0, 1.1)):
            if r == 0:  # cabbages
                g.ell((x, y, 0.75), (0.42, 0.42, 0.32), pick(['#7AD35E', '#86DA66', '#55B947'], 613 + i))
                g.ell((x, y, 0.85), (0.22, 0.22, 0.2), col('#B7EB8F'))
            elif r == 1:  # carrots: orange shoulders and leafy tops
                g.box((x - 0.15, y - 0.15, 0.4), (x + 0.15, y + 0.15, 0.62), col('#FF9F1C'))
                for dx in (-0.12, 0.0, 0.12):
                    g.box((x + dx - 0.04, y - 0.04, 0.62), (x + dx + 0.04, y + 0.04, 1.1 - abs(dx)), col('#3E9A3A'))
            elif r == 2:  # lettuces
                g.blob((x, y, 0.6), (0.38, 0.38, 0.25), pick(['#A7E98F', '#8EE068', '#B8F0A0'], 620 + i), amp=0.2, f=6, seed=i)
            elif i % 2 == 0:  # pumpkins
                g.ell((x + 0.3, y, 0.8), (0.55, 0.5, 0.42), lambda X, Y, Z, x=x: np.where(np.mod(np.arctan2(Y - y, X - x - 0.3) * 4, 2) < 0.25, col('#E06A24'), col('#F08A2E')))
                g.box((x + 0.25, y - 0.05, 1.18), (x + 0.35, y + 0.05, 1.45), col('#5E4028'))
    # a watering can at the corner
    g.cyl(4.2, -3.2, 0.45, 1.1, 0.3, col('#5BB0E8'))
    g.seg((4.0, -3.2, 0.8), (3.5, -3.5, 1.15), 0.06, col('#5BB0E8'))


@B('HayStack', 5.5, 5.5, 5.6, 'big round haystack with a pitchfork stuck in it', budget=120)
def _hay(p):
    g = p.part()
    st = pick(STRAW, 631)
    g.blob((0, 0, 0), (2.5, 2.5, 4.3), st, amp=0.06, f=1.8, seed=4)
    g.carve((-4, -4, -5), (4, 4, 0))
    g.paint((-3, -3, 0), (3, 3, 5), lambda X, Y, Z: np.mod(Z + 0.3 * np.sin(np.arctan2(Y, X) * 5), 0.7) < 0.1, col('#DDB040'))
    # loose straw at the foot
    g.fill((-2.8, -2.8, 0), (2.8, 2.8, 0.35), lambda X, Y, Z: (np.sqrt(X * X + Y * Y) < 2.75) & (Z < 0.15 + 0.2 * hnoise(X, Y, 0 * Z, 5)), pick(STRAW, 632))
    # pitchfork
    g.seg((0.6, -1.2, 3.2), (1.4, -2.6, 5.4), 0.08, pick(WOOD, 633))
    for d in (-0.18, 0, 0.18):
        g.seg((0.6 + d, -1.2, 3.2), (0.4 + d, -0.8, 2.5), 0.05, col(IRON))
    g.box((0.35, -1.25, 3.1), (0.85, -1.15, 3.25), col(IRON))


@B('Scarecrow', 4.2, 1.6, 6.6, 'friendly scarecrow: plaid shirt, straw hands, sack head with a stitched smile, straw hat; '
   'part "arms" sways', budget=90)
def _scarecrow(p):
    g = p.part()
    g.box((-0.15, -0.15, 0), (0.15, 0.15, 5.0), pick(WOOD_D, 641))
    # body: plaid shirt and patched trousers
    plaid = lambda X, Y, Z: np.where((np.mod(X + 5, 0.5) < 0.15) | (np.mod(Z, 0.5) < 0.15), col('#A8352E'), col(RED))
    g.rrbox((-0.7, -0.4, 2.4), (0.7, 0.4, 4.1), 0.15, plaid)
    g.box((-0.6, -0.35, 1.5), (-0.1, 0.35, 2.5), col('#3F6FB0'))
    g.box((0.1, -0.35, 1.5), (0.6, 0.35, 2.5), col('#3F6FB0'))
    g.box((0.2, -0.38, 1.8), (0.45, -0.34, 2.1), col('#FFD166'))  # patch
    for x in (-0.35, 0.35):
        g.fill((x - 0.25, -0.3, 1.0), (x + 0.25, 0.3, 1.5), lambda X, Y, Z, x=x: np.abs(X - x) < 0.1 + (1.5 - Z) * 0.25, pick(STRAW, 642))
    a = p.part('arms', anim='sway', parent='body', pivot=(0, 0, 3.8))
    a.box((-2.0, -0.12, 3.65), (2.0, 0.12, 3.9), pick(WOOD_D, 643))
    a.box((-1.8, -0.3, 3.45), (1.8, 0.3, 4.05), plaid)
    for s in (-1, 1):
        a.fill((s * 1.8 - 0.4, -0.25, 3.3), (s * 1.8 + 0.4, 0.25, 4.2),
               lambda X, Y, Z, s=s: (s * X > 1.8) & (np.abs(Z - 3.75) < 0.1 + (s * X - 1.8) * 0.6), pick(STRAW, 644))
    # head: a sack with a stitched face and a straw hat
    g.ell((0, 0, 4.65), (0.6, 0.55, 0.6), pick(['#D9B98A', '#CFAE7E', '#E2C497'], 645))
    for x in (-0.22, 0.22):
        g.box((x - 0.08, -0.6, 4.75), (x + 0.08, -0.5, 4.91), col('#3B3B44'))
    g.fill((-0.3, -0.62, 4.35), (0.3, -0.48, 4.6), lambda X, Y, Z: np.abs(Z - (4.4 + 1.2 * X * X)) < 0.05, col('#3B3B44'))
    g.box((-0.06, -0.62, 4.6), (0.06, -0.5, 4.72), col('#E8782A'))
    g.cyl(0, 0, 5.05, 5.15, 1.05, pick(STRAW, 646))
    g.cyl(0, 0, 5.15, 5.75, 0.55, pick(STRAW, 647), r1=0.45)
    g.cyl(0, 0, 5.15, 5.3, 0.57, col(RED))
