"""The Golden Egg Shop: Hatchery Heist's walk-in Robux shop in the farm hub.

A cozy storybook shop (cream plaster, dark timber, red shingle roof with
cream trim, warm lanterns) that holds every Robux item as something you can
walk up to: coin packs from a little pouch to a treasure hoard along the
left wall, the passes and the shield along the right wall, a counter with a
shopkeeper at the back.

Every piece is a prop in the props.py format (art frame: x right, y back so
the front is -y, z up, studs, 0.1-stud voxels) registered in props.REGISTRY
with kind "shop", plus LAYOUT: where the game puts each piece inside the
building. shopexport.py writes both to games/hatchery-heist/src/shared/
ShopArt.luau; shopbuild.py makes the .glb meshes, renders and the 3D viewer
copies; shopscene.py renders the whole building.

Every prop's anchor is the point the game places: the base centre for most
pieces, the top of a
hanging lamp, the wall-side base of a wall lamp. A plinth's item stands on
its PLINTH_TOP.
"""
import math

import numpy as np

from vkit import VOX, col, hnoise, snoise
from styles import pick, egg as draw_egg
from props import prop, WOOD, WOOD_D, RED, RED_D, CREAM, IRON, STRAW, LAMP


def speck(h, base):
    """a speckle colour of `base` (folded into it in the Parts export, when
    vkit supports that)"""
    try:
        return col(h, of=base)
    except TypeError:
        return col(h)

# ------------------------------------------------------------------ palette
GLASS = '#BEE6FF'  # window glass; the game draws this colour as Glass
GOLD = '#F4C542'
GOLD_D = '#D9A92E'
GOLD_L = '#FFE07A'
BRASS = '#C9A24A'
STONE = ['#B8B0A2', '#ACA493', '#C3BCAF']
STONE_D = '#8E8676'
PAPER = ['#F8E4B8', '#F3DCAD']  # inside wallpaper, warm butter
VELVET = ['#B8324A', '#AD2C43']
SHINGLE = [RED, '#DB5247']
SHINGLE_D = [RED_D, '#B53B33']
SILVER = '#D8DEE8'
SKY_BLUE = ['#3FA9F5', '#3AA0EA']
HALO = ('#7FF7FF', 2.5)
GEM_RED = ('#FF4F7A', 2.0)
GEM_CYAN = ('#5CF2FF', 2.0)
GEM_GREEN = ('#5FE08A', 2.0)
FLOWERS = ['#FF6F91', '#FFE066', '#FFFFFF']
LEAF = ['#55B947', '#4DB043', '#3E9A3A']
CLAY = ['#C8653B', '#BB5C35']

# -------------------------------------------------------------- the building
W, D = 30.0, 24.0  # outside, x and y
T = 1.0  # wall thickness
X0, X1 = -W / 2, W / 2
Y0, Y1 = -D / 2, D / 2
FLOOR = 0.4  # floor top
WALL_H = 12.0  # wall top, where the roof starts
RIDGE = 18.5
EAVE_OUT = 1.4  # roof overhang past the front and back walls
GABLE_OUT = 0.8  # roof overhang past the side walls
DOOR_W, DOOR_H = 6.4, 8.4  # arched doorway, front centre
SLOPE = (RIDGE - WALL_H) / (D / 2 + EAVE_OUT)


def gold_heap(g, cx, cy, z0, rx, ry, h, seed=0):
    """a lumpy heap of coins: half an ellipsoid, speckled gold"""
    def m(X, Y, Z):
        d = ((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2 + ((Z - z0) / h) ** 2
        return (d <= 1.0 + 0.12 * snoise(X, Y, Z, 5, seed)) & (Z >= z0)
    g.fill((cx - rx * 1.15, cy - ry * 1.15, z0), (cx + rx * 1.15, cy + ry * 1.15, z0 + h * 1.15), m,
           pick([GOLD, GOLD_D, GOLD_L, GOLD], seed + 300))


def coin(g, c, r, axis='z', thick=0.2, face=GOLD, rim=GOLD_D):
    """one coin: a disc with a darker rim. axis = the direction its faces look"""
    cx, cy, cz = c
    ax = {'x': 0, 'y': 1, 'z': 2}[axis]

    def dist(X, Y, Z):
        P = [X - cx, Y - cy, Z - cz]
        return np.sqrt(sum(P[i] ** 2 for i in range(3) if i != ax)), np.abs(P[ax])
    lo = [cx - r, cy - r, cz - r]
    hi = [cx + r, cy + r, cz + r]
    lo[ax], hi[ax] = c[ax] - thick / 2, c[ax] + thick / 2

    def disc(X, Y, Z):
        rr, t = dist(X, Y, Z)
        return (rr <= r) & (t <= thick / 2)
    g.fill(lo, hi, disc, col(face))
    g.paint(lo, hi, lambda X, Y, Z: dist(X, Y, Z)[0] > r - 0.12, col(rim))


def scatter_coins(g, pts, r=0.22):
    for (x, y) in pts:
        coin(g, (x, y, 0.06), r, 'z', 0.12)


# ------------------------------------------------------------------ the shell
@prop('ShopFloor', 'shop', (X0 - 0.2, Y0 - 2.2, 0), (X1 + 0.2, Y1 + 0.2, FLOOR), budget=60, factors=(2, 4),
      note='30 x 24 floor: a stone footing, warm plank floor inside and a stone step at the door (front, -Z)')
def _floor(p):
    g = p.part('body')
    g.box((X0, Y0, 0), (X1, Y1, FLOOR), pick(STONE, 401))
    planks = lambda X, Y, Z: np.mod(np.floor((Y + 0.01) / 1.2), 2).astype(bool)
    inner_lo, inner_hi = (X0 + T, Y0 + T, FLOOR - 0.2), (X1 - T, Y1 - T, FLOOR)
    g.fill(inner_lo, inner_hi, None, lambda X, Y, Z: np.where(planks(X, Y, Z), col(WOOD[0]), col('#D39A5E')))
    # dark seams between plank rows, and staggered plank ends
    g.paint(inner_lo, inner_hi, lambda X, Y, Z: np.mod(Y + 0.01, 1.2) < 0.2, col(WOOD_D[0]))
    # stone step at the door
    g.box((-4.2, Y0 - 2.0, 0), (4.2, Y0, 0.24), pick(STONE, 402))
    g.box((-4.2, Y0 - 2.0, 0), (4.2, Y0 - 1.8, 0.24), col(STONE_D))
    p.anchor = (0, 0, 0)


def wall_skin(g, lo, hi, inside_axis, inside_sign):
    """plaster outside, wainscot + wallpaper inside, stone footing course.
    inside_axis 0 (x) or 1 (y); inside_sign +1/-1 is the room side."""
    g.box(lo, hi, pick(CREAM, 410))
    g.box((lo[0], lo[1], 0), (hi[0], hi[1], 1.6), pick(STONE, 411))
    a, b = list(lo), list(hi)
    if inside_sign > 0:
        a[inside_axis] = hi[inside_axis] - 0.4
    else:
        b[inside_axis] = lo[inside_axis] + 0.4
    g.box((a[0], a[1], FLOOR), (b[0], b[1], hi[2]), pick(PAPER, 412))
    g.box((a[0], a[1], FLOOR), (b[0], b[1], 3.6), pick(WOOD, 413))
    g.box((a[0], a[1], 3.6), (b[0], b[1], 3.9), col(RED_D))
    g.box((a[0], a[1], FLOOR), (b[0], b[1], FLOOR + 0.3), col(WOOD_D[0]))
    return a, b


def window(g, x0, x1, z0, z1, y0, y1, out_sign, shutters=True, box=True):
    """window through a wall that runs along x: opening, glass, cross frame,
    red shutters and a flower box on the outside (out_sign: -1 = outside at -y)"""
    g.carve((x0, y0, z0), (x1, y1, z1))
    ym = (y0 + y1) / 2
    g.box((x0, ym - 0.1, z0), (x1, ym + 0.1, z1), col(GLASS))
    g.box((x0 - 0.3, y0, z0 - 0.3), (x1 + 0.3, y1, z0), col(WOOD_D[0]))  # sill
    g.box((x0 - 0.3, y0, z1), (x1 + 0.3, y1, z1 + 0.3), col(WOOD_D[0]))  # head
    g.box((x0 - 0.3, y0, z0), (x0, y1, z1), col(WOOD_D[0]))
    g.box((x1, y0, z0), (x1 + 0.3, y1, z1), col(WOOD_D[0]))
    xm, zm = (x0 + x1) / 2, (z0 + z1) / 2
    g.box((xm - 0.12, ym - 0.2, z0), (xm + 0.12, ym + 0.2, z1), col(WOOD_D[0]))
    g.box((x0, ym - 0.2, zm - 0.12), (x1, ym + 0.2, zm + 0.12), col(WOOD_D[0]))
    yo = y0 if out_sign < 0 else y1
    face = (yo - 0.2, yo) if out_sign < 0 else (yo, yo + 0.2)
    if shutters:
        sw = (x1 - x0) / 2 * 0.55
        for sx0, sx1 in ((x0 - 0.3 - sw, x0 - 0.3), (x1 + 0.3, x1 + 0.3 + sw)):
            g.box((sx0, face[0], z0), (sx1, face[1], z1), col(RED))
            g.paint((sx0, face[0] - 0.05, z0), (sx1, face[1] + 0.05, z1),
                    lambda X, Y, Z: np.mod(Z - z0, 0.8) < 0.2, col(RED_D))
    if box:
        by = (yo - 0.8, yo) if out_sign < 0 else (yo, yo + 0.8)
        g.box((x0 - 0.2, by[0], z0 - 0.9), (x1 + 0.2, by[1], z0 - 0.3), pick(WOOD, 414))
        for i, x in enumerate(np.arange(x0 + 0.2, x1 - 0.1, 0.55)):
            g.ell((x + 0.2, (by[0] + by[1]) / 2, z0 - 0.15), (0.32, 0.3, 0.3), pick(LEAF, 415 + i))
            g.ell((x + 0.2, (by[0] + by[1]) / 2 + 0.05 * out_sign, z0 + 0.1), (0.2, 0.2, 0.2), col(FLOWERS[i % 3]))


@prop('ShopWallFront', 'shop', (X0, Y0 - 1.0, 0), (X1, Y0 + T, WALL_H), budget=330, factors=(2, 4),
      note='front wall: arched doorway (6.4 x 8.4, open), two shuttered windows with flower boxes, timber frame; '
           'outside cream plaster on a stone footing, inside wainscot and warm wallpaper')
def _front(p):
    g = p.part('body')
    lo, hi = (X0, Y0, 0), (X1, Y0 + T, WALL_H)
    wall_skin(g, lo, hi, 1, +1)
    out = (Y0, Y0 + 0.25)
    # timber: corner posts, door posts, sill beam, top plate
    for x0, x1 in ((X0, X0 + 0.9), (X1 - 0.9, X1), (-4.4, -3.6), (3.6, 4.4), (-13.0, -12.3), (12.3, 13.0)):
        g.box((x0, out[0], 1.6), (x1, out[1], WALL_H), pick(WOOD_D, 420))
    g.box((X0, out[0], 1.6), (X1, out[1], 2.0), pick(WOOD_D, 421))
    g.box((X0, out[0], WALL_H - 0.8), (X1, out[1], WALL_H), pick(WOOD_D, 422))
    g.box((X0, out[0], 9.2), (X1, out[1], 9.6), pick(WOOD_D, 423))
    # windows either side of the door
    for sx in (-1, 1):
        a, b = sorted((sx * 6.4, sx * 10.6))
        window(g, a, b, 3.6, 8.0, Y0, Y0 + T, -1)
    # arched doorway, red frame
    r = DOOR_W / 2
    zc = DOOR_H - r

    def opening(X, Y, Z):
        return (np.abs(X) <= r) & ((Z <= zc) | (X ** 2 + (Z - zc) ** 2 <= r * r))

    def frame(X, Y, Z):
        return (np.abs(X) <= r + 0.5) & ((Z <= zc) | (X ** 2 + (Z - zc) ** 2 <= (r + 0.5) ** 2)) & ~opening(X, Y, Z)
    g.fill((-r - 0.6, Y0 - 0.2, FLOOR), (r + 0.6, Y0 + T, DOOR_H + 0.6), frame, col(RED))
    g.fill((-r - 0.6, Y0 - 0.2, FLOOR), (r + 0.6, Y0 + T, DOOR_H + 0.6),
           lambda X, Y, Z: frame(X, Y, Z) & (Z > zc) & (np.abs(X) < 0.35), col(GOLD))  # keystone
    g.carve((-r, Y0 - 1, 0.0), (r, Y0 + T + 0.1, DOOR_H), opening)
    p.anchor = (0, 0, 0)


@prop('ShopWallBack', 'shop', (X0, Y1 - T, 0), (X1, Y1, WALL_H), budget=200, factors=(2, 4, 5),
      note='back wall: timber frame, two high windows either side of the counter shelf; plaster outside, wallpaper inside')
def _back(p):
    g = p.part('body')
    lo, hi = (X0, Y1 - T, 0), (X1, Y1, WALL_H)
    wall_skin(g, lo, hi, 1, -1)
    out = (Y1 - 0.25, Y1)
    for x0, x1 in ((X0, X0 + 0.9), (X1 - 0.9, X1), (-0.4, 0.4), (-9.6, -8.9), (8.9, 9.6)):
        g.box((x0, out[0], 1.6), (x1, out[1], WALL_H), pick(WOOD_D, 430))
    g.box((X0, out[0], 1.6), (X1, out[1], 2.0), pick(WOOD_D, 431))
    g.box((X0, out[0], WALL_H - 0.8), (X1, out[1], WALL_H), pick(WOOD_D, 432))
    for sx in (-1, 1):
        a, b = sorted((sx * 10.6, sx * 13.0))
        window(g, a, b, 6.4, 9.6, Y1 - T, Y1, +1, shutters=False, box=False)
    p.anchor = (0, 0, 0)


@prop('ShopWallSide', 'shop', (X0 - 0.1, Y0 + T, 0), (X0 + T, Y1 - T, WALL_H), budget=180, factors=(2, 4),
      note='side wall (drawn as the left one, outside at -X; the right wall is the same piece turned round): '
           'two round windows high up, timber frame')
def _side(p):
    g = p.part('body')
    lo, hi = (X0, Y0 + T, 0), (X0 + T, Y1 - T, WALL_H)
    wall_skin(g, lo, hi, 0, +1)
    out = (X0, X0 + 0.25)
    for y0, y1 in ((-4.0, -3.3), (3.3, 4.0), (-0.35, 0.35)):
        g.box((out[0], y0, 1.6), (out[1], y1, WALL_H), pick(WOOD_D, 440))
    g.box((out[0], Y0 + T, 1.6), (out[1], Y1 - T, 2.0), pick(WOOD_D, 441))
    g.box((out[0], Y0 + T, WALL_H - 0.8), (out[1], Y1 - T, WALL_H), pick(WOOD_D, 442))
    # round windows at y = +-8, high up
    for yc in (-7.6, 7.6):
        zc, r = 9.0, 1.5

        def ring(X, Y, Z, yc=yc):
            return (Y - yc) ** 2 + (Z - zc) ** 2 <= (r + 0.35) ** 2

        def hole(X, Y, Z, yc=yc):
            return (Y - yc) ** 2 + (Z - zc) ** 2 <= r * r
        g.fill((X0 - 0.1, yc - r - 0.4, zc - r - 0.4), (X0 + T, yc + r + 0.4, zc + r + 0.4), ring, col(WOOD_D[0]))
        g.carve((X0 - 0.2, yc - r, zc - r), (X0 + T + 0.1, yc + r, zc + r), hole)
        g.fill((X0 + 0.4, yc - r, zc - r), (X0 + 0.6, yc + r, zc + r), hole, col(GLASS))
        g.fill((X0 + 0.3, yc - r, zc - r), (X0 + 0.7, yc + r, zc + r),
               lambda X, Y, Z, yc=yc: hole(X, Y, Z, yc) & ((np.abs(Y - yc) < 0.12) | (np.abs(Z - zc) < 0.12)), col(WOOD_D[0]))
    p.anchor = (0, 0, 0)


def roof_z(Y):
    return RIDGE - SLOPE * np.abs(Y)


@prop('ShopRoof', 'shop', (X0 - GABLE_OUT - 0.4, Y0 - EAVE_OUT - 0.3, WALL_H - 0.6), (X1 + GABLE_OUT + 0.4, Y1 + EAVE_OUT + 0.3, 21.4),
      budget=380, factors=(4, 5, 6, 8),
      note='red shingle gable roof with cream bargeboards and gable ends and a stone chimney; open over the door for ShopGable')
def _roof(p):
    g = p.part('body')
    xo = X1 + GABLE_OUT
    yo = D / 2 + EAVE_OUT
    th = 0.7

    def slab(X, Y, Z):
        rz = roof_z(Y)
        return (Z <= rz) & (Z >= rz - th) & (np.abs(Y) <= yo)

    def shingle(X, Y, Z):
        row = np.floor((RIDGE - Z) / 0.9).astype(int)
        lap = np.mod(RIDGE - Z, 0.9) < 0.2
        h = hnoise(np.floor(X / 0.9 + 0.5 * (row % 2)), row, 0, 450)
        base = np.where(h > 0.55, speck(SHINGLE[1], col(SHINGLE[0])), col(SHINGLE[0]))
        return np.where(lap, col(SHINGLE_D[0]), base)
    g.fill((-xo, -yo, WALL_H - 1.2), (xo, yo, RIDGE + 0.1), slab, shingle)
    # gable ends: cream plaster with a timber king post and a round vent
    for sx in (-1, 1):
        x0, x1 = (X0, X0 + T) if sx < 0 else (X1 - T, X1)

        def tri(X, Y, Z):
            return Z <= roof_z(Y) - th + 0.05
        g.fill((x0, Y0, WALL_H), (x1, Y1, RIDGE), tri, pick(CREAM, 451))
        xf = (x0, x0 + 0.25) if sx < 0 else (x1 - 0.25, x1)
        g.fill((xf[0], -0.35, WALL_H), (xf[1], 0.35, RIDGE), tri, pick(WOOD_D, 452))
        g.fill((xf[0], Y0, WALL_H), (xf[1], Y1, WALL_H + 0.5), tri, pick(WOOD_D, 453))
        for sy in (-1, 1):
            g.seg((xf[0] + 0.12, sy * 0.4, WALL_H + 0.5), (xf[0] + 0.12, sy * 5.0, WALL_H + 3.6), 0.18, col(WOOD_D[0]))
        vent = lambda X, Y, Z: Y ** 2 + (Z - 15.6) ** 2 <= 1.0
        g.fill((x0 - 0.05, -1.2, 14.4), (x1 + 0.05, 1.2, 16.8), lambda X, Y, Z: Y ** 2 + (Z - 15.6) ** 2 <= 1.35 ** 2,
               col(WOOD_D[0]))
        g.fill((x0 - 0.1, -1.2, 14.4), (x1 + 0.1, 1.2, 16.8), vent, col(*LAMP))
        # cream bargeboards along the roof edge, a little proud of the shingles
        xb = (-xo - 0.3, -xo + 0.1) if sx < 0 else (xo - 0.1, xo + 0.3)

        def barge(X, Y, Z):
            rz = roof_z(Y)
            return (Z <= rz + 0.25) & (Z >= rz - th - 0.35) & (np.abs(Y) <= yo + 0.2)
        g.fill((xb[0], -yo - 0.3, WALL_H - 1.5), (xb[1], yo + 0.3, RIDGE + 0.4), barge, pick(CREAM, 454))
    # eave boards: cream fascia along the front and back
    for sy in (-1, 1):
        y0, y1 = sorted((sy * yo, sy * (yo - 0.3)))
        z = roof_z(np.array(yo))
        g.box((-xo - 0.3, y0, z - th - 0.4), (xo + 0.3, y1, z + 0.1), pick(CREAM, 455))
    # the front cross gable (ShopGable) stands here: no eave in front of it
    g.carve((-GABLE_HW - 0.2, -yo - 0.5, WALL_H - 1.6), (GABLE_HW + 0.2, Y0 + T, RIDGE),
            lambda X, Y, Z: Z <= np.maximum(gable_z(X) + 0.3, WALL_H))
    # ridge cap
    g.fill((-xo - 0.3, -0.6, RIDGE - 0.6), (xo + 0.3, 0.6, RIDGE + 0.45),
           lambda X, Y, Z: Z <= RIDGE + 0.45 - 0.6 * np.abs(Y), col(RED_D))
    # stone chimney through the back slope
    cx, cy = 9.0, 5.0
    g.box((cx - 0.9, cy - 0.9, roof_z(np.array(cy + 0.9)) - 0.8), (cx + 0.9, cy + 0.9, 20.6), pick(STONE, 456))
    g.box((cx - 1.1, cy - 1.1, 20.4), (cx + 1.1, cy + 1.1, 20.9), col(STONE_D))
    g.carve((cx - 0.5, cy - 0.5, 20.0), (cx + 0.5, cy + 0.5, 20.95))
    p.anchor = (0, 0, 0)


GABLE_HW = 8.0  # the cross gable over the door: half width of its wall
GABLE_RIDGE = 18.0
CROSS_OUT = 0.8
GABLE_SLOPE = (GABLE_RIDGE - WALL_H) / (GABLE_HW + CROSS_OUT)


def gable_z(X):
    return GABLE_RIDGE - GABLE_SLOPE * np.abs(X)


@prop('ShopGable', 'shop', (-GABLE_HW - CROSS_OUT - 0.4, Y0 - EAVE_OUT - 0.4, WALL_H - 0.2), (GABLE_HW + CROSS_OUT + 0.4, 0.5, GABLE_RIDGE + 0.6),
      budget=260, factors=(4, 5, 6),
      note='cross gable over the door: a cream plaster gable (the shop sign hangs on it) under its own red roof, '
           'which runs back into the main roof; cream bargeboards')
def _gable(p):
    g = p.part('body')
    th = 0.7

    def wall(X, Y, Z):
        return Z <= gable_z(X) - th + 0.05
    g.fill((-GABLE_HW, Y0, WALL_H - 0.2), (GABLE_HW, Y0 + T, GABLE_RIDGE), wall, pick(CREAM, 456))
    g.fill((-GABLE_HW, Y0, WALL_H - 0.2), (GABLE_HW, Y0 + 0.25, WALL_H + 0.4), wall, pick(WOOD_D, 457))
    for sx in (-1, 1):
        g.seg((sx * 6.2, Y0 + 0.12, WALL_H + 0.4), (sx * 6.2, Y0 + 0.12, 13.6), 0.2, col(WOOD_D[0]))
    yo = -(D / 2 + EAVE_OUT)

    def slab(X, Y, Z):
        rz = gable_z(X)
        return (Z <= rz) & (Z >= rz - th) & (Z >= roof_z(Y) - th)

    def shingle(X, Y, Z):
        row = np.floor((GABLE_RIDGE - Z) / 0.9).astype(int)
        lap = np.mod(GABLE_RIDGE - Z, 0.9) < 0.2
        h = hnoise(np.floor(Y / 0.9 + 0.5 * (row % 2)), row, 1, 458)
        base = np.where(h > 0.55, speck(SHINGLE[1], col(SHINGLE[0])), col(SHINGLE[0]))
        return np.where(lap, col(SHINGLE_D[0]), base)
    xo = GABLE_HW + CROSS_OUT
    g.fill((-xo, yo, WALL_H - 0.2), (xo, 0.0, GABLE_RIDGE + 0.1), slab, shingle)
    # ridge cap and cream bargeboards on the front edge
    g.fill((-0.6, yo - 0.3, GABLE_RIDGE - 0.6), (0.6, 0.0, GABLE_RIDGE + 0.45),
           lambda X, Y, Z: (Z <= GABLE_RIDGE + 0.45 - 0.6 * np.abs(X)) & (Z >= roof_z(Y) - 0.3), col(RED_D))

    def barge(X, Y, Z):
        rz = gable_z(X)
        return (Z <= rz + 0.25) & (Z >= rz - th - 0.4)
    g.fill((-xo - 0.3, yo - 0.3, WALL_H - 0.6), (xo + 0.3, yo + 0.1, GABLE_RIDGE + 0.4), barge, pick(CREAM, 459))
    # a gold egg finial on the gable peak
    g.box((-0.2, yo - 0.2, GABLE_RIDGE + 0.2), (0.2, yo + 0.2, GABLE_RIDGE + 0.8), col(GOLD_D))
    g.ell((0, yo, GABLE_RIDGE + 1.5), (0.5, 0.5, 0.7), col(GOLD))
    p.anchor = (0, 0, 0)


@prop('ShopCeiling', 'shop', (X0 + T, Y0 + T, WALL_H - 1.4), (X1 - T, Y1 - T, WALL_H), budget=45, factors=(2, 4),
      note='plank ceiling under the roof with dark beams across the room')
def _ceiling(p):
    g = p.part('body')
    g.box((X0 + T, Y0 + T, WALL_H - 0.4), (X1 - T, Y1 - T, WALL_H), pick(['#E2B273', '#D9A766'], 460))
    g.paint((X0 + T, Y0 + T, WALL_H - 0.4), (X1 - T, Y1 - T, WALL_H), lambda X, Y, Z: np.mod(X + 0.01, 1.6) < 0.2,
            col('#B9844E'))
    for x in (-10.0, -5.0, 0.0, 5.0, 10.0):
        g.box((x - 0.4, Y0 + T, WALL_H - 1.2), (x + 0.4, Y1 - T, WALL_H - 0.4), pick(WOOD_D, 461))
    p.anchor = (0, 0, 0)


@prop('ShopAwning', 'shop', (-4.6, -2.4, 0), (4.6, 0.2, 2.0), budget=90, factors=(2, 4, 5),
      note='striped red and cream awning over the door, on two iron brackets; base centre is on the wall face')
def _awning(p):
    g = p.part('body')

    def canopy(X, Y, Z):
        top = 1.6 + 0.5 * (Y + 2.2) / 2.2  # rises toward the wall
        return (Z <= top) & (Z >= top - 0.3)

    def stripes(X, Y, Z):
        return np.where(np.mod(np.floor((X + 4.4) / 0.8), 2) == 0, col(RED), col(CREAM[0]))
    g.fill((-4.4, -2.2, 0.8), (4.4, 0, 2.2), canopy, stripes)
    # scalloped front valance
    g.fill((-4.4, -2.3, 0.6), (4.4, -2.0, 1.35),
           lambda X, Y, Z: Z >= 1.35 - 0.45 * np.abs(np.sin((X + 4.4) / 0.8 * math.pi)) - 0.3, stripes)
    for sx in (-1, 1):
        g.seg((sx * 4.1, -0.1, 0.0), (sx * 4.1, -2.0, 1.4), 0.14, col(IRON))
        g.box((sx * 4.1 - 0.25, -0.2, -0.2), (sx * 4.1 + 0.25, 0.1, 0.3), col(IRON))
    p.anchor = (0, 0, 0)


@prop('ShopSign', 'shop', (-5.2, -0.8, 0), (5.2, 0.1, 2.9), budget=80, factors=(2, 4),
      note='9 x 2 shop sign for the cross gable over the door: red frame, cream board (the game writes the '
           'name on its front, -Z), a gold egg at each end and a crest on top')
def _sign(p):
    g = p.part('body')
    g.box((-4.5, -0.5, 0), (4.5, 0, 2.0), col(RED_D))
    g.box((-4.2, -0.6, 0.25), (4.2, -0.4, 1.75), pick(CREAM, 470))
    g.box((-4.5, -0.65, 1.85), (4.5, -0.3, 2.05), col(GOLD_D))
    g.box((-4.5, -0.65, -0.05), (4.5, -0.3, 0.15), col(GOLD_D))
    for sx in (-1, 1):
        g.ell((sx * 4.75, -0.35, 1.0), (0.4, 0.3, 0.6), col(GOLD))
    g.ell((0, -0.3, 2.4), (0.32, 0.28, 0.42), col(GOLD))
    for sx in (-1, 1):
        g.ell((sx * 0.65, -0.3, 2.2), (0.32, 0.22, 0.2), col(GOLD_D))
    p.anchor = (0, 0, 0)


# sign text area: front face of the board, (x, z) centre and size, studs
SIGN_BOARD = dict(face_y=-0.6, x=0.0, z=1.0, w=8.2, h=1.4)


# -------------------------------------------------------------------- inside
@prop('ShopCounter', 'shop', (-6.4, -1.4, 0), (6.4, 1.3, 4.6), budget=130, factors=(2, 4, 5),
      note='12 x 2 counter: panelled front with a gold egg emblem, marble top, a brass till with a glowing window, '
           'a bell, a coin stack and a basket of eggs')
def _counter(p):
    g = p.part('body')
    g.box((-6, -1, 0), (6, 1, 3.0), pick(WOOD, 480))
    g.box((-6.1, -1.1, 0), (6.1, 1.1, 0.35), pick(WOOD_D, 481))
    for x0 in (-5.4, -1.6, 2.2):
        g.box((x0, -1.1, 0.8), (x0 + 3.2, -1.0, 2.6), pick(WOOD_D, 482))
        g.box((x0 + 0.2, -1.15, 1.0), (x0 + 3.0, -1.05, 2.4), pick(WOOD, 483))
    g.ell((0, -1.15, 1.7), (0.55, 0.12, 0.72), col(GOLD))
    g.box((-6.3, -1.3, 3.0), (6.3, 1.25, 3.35), pick(['#F3EBDD', '#ECE2D1'], 484))
    g.box((-6.3, -1.35, 3.0), (6.3, -1.25, 3.35), col(GOLD_D))
    # brass till
    g.box((2.6, -0.5, 3.35), (4.2, 0.7, 4.0), col(BRASS))
    g.fill((2.6, -0.5, 4.0), (4.2, 0.7, 4.6), lambda X, Y, Z: Z <= 4.6 - 0.5 * (0.7 - Y), col(BRASS))
    g.box((3.0, -0.62, 3.55), (3.8, -0.5, 3.8), col('#BFF5C8', 1.2))
    for i in range(3):
        g.box((2.8 + i * 0.45, -0.4 - 0.0, 4.02), (3.1 + i * 0.45, -0.1, 4.12), col(CREAM[0]))
    # bell
    g.ell((-1.6, 0.0, 3.55), (0.32, 0.32, 0.3), col(GOLD))
    g.box((-1.7, -0.1, 3.82), (-1.5, 0.1, 4.0), col(GOLD_D))
    # coin stack
    for i in range(4):
        coin(g, (0.6, -0.2, 3.42 + i * 0.13), 0.28, 'z', 0.12)
    # basket of eggs
    g.fill((-5.2, -0.6, 3.35), (-3.4, 0.6, 3.9), lambda X, Y, Z: ((X + 4.3) / 0.9) ** 2 + (Y / 0.6) ** 2 <= 1,
           pick(STRAW, 485))
    for (ex, ey, k) in ((-4.7, -0.1, 'basic'), (-4.1, 0.15, 'meadow'), (-4.0, -0.3, 'basic')):
        draw_egg(g, ex, ey, 3.6, k, 0.45)
    p.anchor = (0, 0, 0)


@prop('ShopShelf', 'shop', (-9.2, -0.2, 0), (9.2, 1.4, 9.0), budget=300, factors=(2, 4),
      note='back-wall shelves behind the counter: jars of eggs and coins, gift boxes, plants, and the shop\'s '
           'big Golden Egg on the top middle shelf; front is -Z, back against the wall')
def _shelf(p):
    g = p.part('body')
    for x in (-9.0, -3.0, 3.0, 9.0):
        g.box((x - 0.2, 0, 0), (x + 0.2, 1.2, 8.6), pick(WOOD_D, 490))
    g.box((-9.2, 0, 8.6), (9.2, 1.3, 9.0), pick(WOOD_D, 491))
    for z in (0.0, 2.4, 4.8, 7.0):
        g.box((-9.0, 0, z), (9.0, 1.2, z + 0.25), pick(WOOD, 492))
    g.box((-9.0, 1.0, 0), (9.0, 1.2, 8.6), pick(['#E2B273', '#D9A766'], 493))
    rng = np.random.default_rng(7)

    def jar(x, z, inside, k=None):
        g.box((x - 0.45, 0.25, z), (x + 0.45, 0.95, z + 1.1), col(GLASS))
        g.box((x - 0.5, 0.2, z + 1.1), (x + 0.5, 1.0, z + 1.3), col(RED if k else BRASS))
        if inside == 'coins':
            g.box((x - 0.4, 0.3, z + 0.05), (x + 0.4, 0.9, z + 0.6), pick([GOLD, GOLD_D, GOLD_L], 494))
        else:
            draw_egg(g, x, 0.6, z + 0.1, inside, 0.42)

    def gift(x, z, w, h, c, ribbon):
        g.box((x - w / 2, 0.2, z), (x + w / 2, 1.0, z + h), col(c))
        g.box((x - 0.1, 0.15, z), (x + 0.1, 1.05, z + h + 0.05), col(ribbon))
        g.box((x - w / 2, 0.55, z + h * 0.45), (x + w / 2, 0.75, z + h * 0.45 + 0.2), col(ribbon))
        g.ell((x, 0.6, z + h + 0.15), (0.3, 0.15, 0.15), col(ribbon))

    def plant(x, z):
        g.cyl(x, 0.6, z, z + 0.6, 0.38, pick(CLAY, 495), r1=0.45)
        g.blob((x, 0.6, z + 1.0), (0.55, 0.45, 0.5), pick(LEAF, 496), amp=0.25, f=4, seed=int(x * 10) % 97)

    # bottom shelf (behind the counter, mostly hidden): stock boxes
    for x in (-7.6, -5.4, 5.4, 7.6):
        g.box((x - 0.9, 0.15, 0.25), (x + 0.9, 1.05, 1.5), pick(WOOD, 497))
        g.box((x - 0.9, 0.12, 0.8), (x + 0.9, 0.18, 0.95), col(WOOD_D[0]))
    # middle shelves
    for z, row in ((2.65, ('coins', 'basic', 'gift', 'meadow', 'coins', 'plant')),
                   (5.05, ('plant', 'moonlit', 'coins', 'gift', 'premium', 'coins'))):
        xs = (-7.8, -5.6, -4.1, 4.1, 5.6, 7.8)
        for x, kind in zip(xs, row):
            if kind == 'gift':
                gift(x, z, 1.0, 0.9, RED if x < 0 else '#3FA9F5', GOLD)
            elif kind == 'plant':
                plant(x, z)
            else:
                jar(x, z, kind)
        for x in (-1.6, 1.6):
            jar(x, z, 'coins' if z < 4 else 'basic')
        g.box((-0.7, 0.2, z), (0.7, 1.0, z + 0.25), col(GOLD_D))
        for i in range(3):
            coin(g, (0, 0.6, z + 0.33 + i * 0.13), 0.45, 'z', 0.12)
    # top shelf: the Golden Egg on a velvet cushion, gift boxes either side
    g.ell((0, 0.6, 7.45), (1.2, 0.55, 0.3), pick(VELVET, 498))
    draw_egg(g, 0, 0.6, 7.45, 'premium', 0.62)
    for x in (-6.0, 6.0):
        gift(x, 7.25, 1.3, 1.0, RED if x < 0 else '#8E5CD9', GOLD)
        plant(x + (1.8 if x < 0 else -1.8), 7.25)
    p.anchor = (0, 0, 0)


@prop('ShopStool', 'shop', (-1.0, -0.8, 0), (1.0, 0.8, 2.4), budget=20, factors=(2, 4),
      note='a sturdy step behind the counter, so the shopkeeper can see over it')
def _stool(p):
    g = p.part('body')
    g.box((-0.9, -0.7, 0), (0.9, 0.7, 2.0), pick(WOOD_D, 500))
    g.box((-1.0, -0.8, 2.0), (1.0, 0.8, 2.4), pick(WOOD, 501))
    p.anchor = (0, 0, 0)


# ------------------------------------------------------------------ plinths
PLINTH = 1.5  # half width
PLINTH_H = 2.4
CARD = dict(face_y=-PLINTH - 0.06, x=0.0, z=1.25, w=2.5, h=1.3)  # price card on the plinth front


@prop('ShopPlinth', 'shop', (-1.8, -1.8, 0), (1.8, 1.8, 2.5), budget=70, factors=(2, 4),
      note='3 x 3 wooden display plinth for coin packs: a cream top with a gold band and a red-framed card on the '
           'front, where the game shows the item\'s name and price; its item stands on top (PLINTH_TOP)')
def _plinth(p):
    g = p.part('body')
    g.box((-1.7, -1.7, 0), (1.7, 1.7, 0.35), pick(WOOD_D, 510))
    g.box((-PLINTH, -PLINTH, 0.35), (PLINTH, PLINTH, 2.1), pick(WOOD, 511))
    for sx in (-1, 1):
        for sy in (-1, 1):
            g.box((sx * PLINTH - 0.15 - 0.15 * sx, sy * PLINTH - 0.15 - 0.15 * sy, 0.35),
                  (sx * PLINTH + 0.15 - 0.15 * sx, sy * PLINTH + 0.15 - 0.15 * sy, 2.1), pick(WOOD_D, 512))
    g.box((-1.7, -1.7, 2.1), (1.7, 1.7, 2.4), pick(CREAM, 513))
    g.box((-1.72, -1.72, 2.05), (1.72, 1.72, 2.2), col(GOLD_D))
    # the card frame on the front
    g.box((-1.35, -PLINTH - 0.1, 0.5), (1.35, -PLINTH, 2.0), col(RED_D))
    g.box((-1.2, -PLINTH - 0.15, 0.62), (1.2, -PLINTH - 0.05, 1.88), pick(CREAM, 514))
    p.anchor = (0, 0, 0)


@prop('ShopPlinthVelvet', 'shop', (-1.8, -1.8, 0), (1.8, 1.8, 2.9), budget=80, factors=(2, 4),
      note='3 x 3 dark wood plinth with a red velvet cushion and gold tassels, for the passes and the shield; '
           'red-framed card on the front; its item stands on the cushion (PLINTH_TOP)')
def _plinth_velvet(p):
    g = p.part('body')
    g.box((-1.7, -1.7, 0), (1.7, 1.7, 0.35), pick(WOOD_D, 520))
    g.box((-PLINTH, -PLINTH, 0.35), (PLINTH, PLINTH, 2.1), pick(WOOD_D, 521))
    for z in (0.35, 1.95):
        g.box((-PLINTH - 0.05, -PLINTH - 0.05, z), (PLINTH + 0.05, PLINTH + 0.05, z + 0.15), col(GOLD_D))
    g.box((-1.7, -1.7, 2.1), (1.7, 1.7, 2.3), col(GOLD_D))
    g.fill((-1.55, -1.55, 2.3), (1.55, 1.55, 2.75),
           lambda X, Y, Z: Z <= 2.75 - 0.25 * (np.maximum(np.abs(X), np.abs(Y)) / 1.55) ** 4, pick(VELVET, 522))
    for sx in (-1, 1):
        for sy in (-1, 1):
            g.box((sx * 1.55 - 0.12, sy * 1.55 - 0.12, 1.8), (sx * 1.55 + 0.12, sy * 1.55 + 0.12, 2.35), col(GOLD))
    g.box((-1.35, -PLINTH - 0.1, 0.5), (1.35, -PLINTH, 1.9), col(GOLD_D))
    g.box((-1.2, -PLINTH - 0.15, 0.62), (1.2, -PLINTH - 0.05, 1.78), pick(CREAM, 523))
    p.anchor = (0, 0, 0)


# ------------------------------------------------------------ the displays
@prop('ShopCoinPouch', 'shopdisplay', (-1.1, -1.1, 0), (1.1, 1.1, 1.6), budget=60, factors=(2,),
      note='5K Coins: a little purple pouch tied with gold cord, a few coins spilled in front')
def _pouch(p):
    g = p.part('body')
    g.blob((0, 0.1, 0.55), (0.6, 0.55, 0.55), pick(['#8E5CD9', '#8352CC'], 530), amp=0.08, f=3, seed=2)
    g.cyl(0, 0.1, 0.95, 1.2, 0.28, pick(['#8E5CD9', '#8352CC'], 531))
    g.cyl(0, 0.1, 1.03, 1.15, 0.33, col(GOLD))
    g.blob((0, 0.1, 1.32), (0.38, 0.32, 0.2), pick(['#A374E6', '#8E5CD9'], 532), amp=0.2, f=6, seed=3)
    g.ell((0, -0.42, 0.62), (0.2, 0.1, 0.2), col(GOLD))  # coin emblem
    scatter_coins(g, ((-0.55, -0.7), (0.3, -0.8), (0.75, -0.35), (-0.1, -0.95)))
    p.anchor = (0, 0, 0)


@prop('ShopCoinSack', 'shopdisplay', (-1.3, -1.3, 0), (1.3, 1.3, 2.3), budget=80, factors=(2,),
      note='30K Coins: a burlap sack heaped with coins')
def _sack(p):
    g = p.part('body')
    burlap = ['#C9A46A', '#BE9A5F', '#D2AE76']
    g.blob((0, 0.1, 0.8), (0.95, 0.85, 0.85), pick(burlap, 540), amp=0.07, f=3, seed=4)
    g.carve((-1, -0.9, 1.45), (1, 1.1, 2.0))
    g.fill((-1.0, -0.8, 1.3), (1.0, 1.0, 1.6), lambda X, Y, Z: np.abs(np.sqrt((X / 0.85) ** 2 + ((Y - 0.1) / 0.75) ** 2) - 0.92) < 0.16,
           col('#A88550'))
    gold_heap(g, 0, 0.1, 1.35, 0.78, 0.7, 0.7, 5)
    g.ell((0, -0.78, 0.8), (0.32, 0.1, 0.32), col(GOLD))
    g.ell((0, -0.83, 0.8), (0.18, 0.08, 0.18), col(GOLD_D))
    scatter_coins(g, ((-0.9, -0.95), (0.7, -1.0), (1.0, -0.4), (-0.2, -1.1), (0.25, -0.85)))
    p.anchor = (0, 0, 0)


def chest(g, w, d, h, seed, lid=True):
    g.box((-w / 2, -d / 2, 0), (w / 2, d / 2, h), pick(WOOD, seed))
    g.paint((-w / 2, -d / 2, 0), (w / 2, d / 2, h), lambda X, Y, Z: np.mod(Z, 0.45) < 0.08, col(WOOD_D[0]))
    for x in (-w / 2 + 0.25, w / 2 - 0.25):
        g.box((x - 0.12, -d / 2 - 0.05, 0), (x + 0.12, d / 2 + 0.05, h + 0.02), col(IRON))
    g.box((-w / 2 - 0.05, -d / 2 - 0.05, h - 0.18), (w / 2 + 0.05, d / 2 + 0.05, h), col(IRON))
    g.box((-0.25, -d / 2 - 0.12, h - 0.7), (0.25, -d / 2, h - 0.15), col(GOLD))
    g.box((-0.06, -d / 2 - 0.16, h - 0.55), (0.06, -d / 2 - 0.1, h - 0.35), col(IRON))
    if lid:
        # open lid leaning back
        g.box((-w / 2, d / 2 - 0.05, h), (w / 2, d / 2 + 0.25, h + 1.2), pick(WOOD, seed + 1))
        g.box((-w / 2 - 0.05, d / 2 - 0.08, h + 0.95), (w / 2 + 0.05, d / 2 + 0.28, h + 1.2), col(IRON))
        for x in (-w / 2 + 0.25, w / 2 - 0.25):
            g.box((x - 0.12, d / 2 - 0.08, h), (x + 0.12, d / 2 + 0.28, h + 1.2), col(IRON))


@prop('ShopCoinChest', 'shopdisplay', (-1.4, -1.4, 0), (1.4, 1.4, 2.6), budget=110, factors=(2,),
      note='80K Coins: an open wooden chest with iron bands, heaped with coins and two gems')
def _chest(p):
    g = p.part('body')
    chest(g, 2.2, 1.4, 1.1, 550)
    gold_heap(g, 0, -0.05, 1.0, 1.0, 0.62, 0.55, 6)
    g.ell((-0.4, -0.3, 1.4), (0.16, 0.16, 0.2), col(*GEM_RED))
    g.ell((0.5, 0.0, 1.45), (0.15, 0.15, 0.18), col(*GEM_CYAN))
    scatter_coins(g, ((-1.0, -1.0), (0.9, -1.05), (0.1, -1.15)))
    p.anchor = (0, 0, 0)


@prop('ShopCoinHoard', 'shopdisplay', (-1.6, -1.6, 0), (1.6, 1.6, 3.9), budget=150, factors=(2,),
      note='200K Coins, the best value: a big chest overflowing onto a heap of coins, gems, a little gold crown, '
           'and three coins floating above ("sparkle", bob)')
def _hoard(p):
    g = p.part('body')
    gold_heap(g, 0, -0.2, 0.0, 1.45, 1.35, 0.55, 7)
    chest(g, 2.5, 1.5, 1.3, 562)
    gold_heap(g, 0, -0.1, 1.18, 1.15, 0.72, 0.85, 8)
    # coins spilling over the front edge
    for i, (x, z) in enumerate(((-0.5, 1.05), (0.1, 0.8), (0.55, 0.55), (-0.2, 0.35))):
        coin(g, (x, -0.85 - 0.05 * i, z), 0.24, 'y', 0.12)
    for c, (x, y, z) in ((GEM_RED, (-0.6, -0.35, 1.75)), (GEM_GREEN, (0.65, -0.25, 1.65)), (GEM_CYAN, (0.1, -0.55, 1.55)),
                         (GEM_RED, (1.1, -1.2, 0.25)), (GEM_CYAN, (-1.15, -1.05, 0.25))):
        g.ell((x, y, z), (0.17, 0.17, 0.2), col(*c))
    # little crown on the top of the heap
    cz = 2.0
    g.cyl(0.1, 0.0, cz, cz + 0.3, 0.42, col(GOLD))
    g.carve((-0.3, -0.3, cz + 0.05), (0.5, 0.3, cz + 0.32), lambda X, Y, Z: (X - 0.1) ** 2 + Y ** 2 < 0.3 ** 2)
    for a in range(5):
        ang = a * 2 * math.pi / 5
        x, y = 0.1 + math.cos(ang) * 0.36, math.sin(ang) * 0.36
        g.box((x - 0.1, y - 0.1, cz + 0.3), (x + 0.1, y + 0.1, cz + 0.6), col(GOLD))
        g.box((x - 0.07, y - 0.07, cz + 0.6), (x + 0.07, y + 0.07, cz + 0.7), col(*GEM_RED))
    s = p.part('sparkle', anim='bob', parent='body', pivot=(0, 0, 3.3))
    for (x, y, z, ax) in ((-0.7, -0.2, 3.1, 'x'), (0.6, 0.1, 3.4, 'y'), (0.0, -0.4, 3.65, 'x')):
        coin(s, (x, y, z), 0.25, ax, 0.12)
    p.anchor = (0, 0, 0)


@prop('ShopShieldStand', 'shopdisplay', (-1.6, -1.0, 0), (1.6, 1.0, 3.4), budget=100, factors=(2,),
      note='Shield Refill: a round blue shield with a gold rim and an egg emblem on a little stand, '
           'a glowing halo behind it ("halo", pulse)')
def _shield(p):
    g = p.part('body')
    g.box((-0.6, -0.3, 0), (0.6, 0.6, 0.3), pick(WOOD_D, 570))
    g.box((-0.15, 0.1, 0.3), (0.15, 0.4, 1.2), pick(WOOD_D, 571))
    zc, r = 1.75, 1.15

    def disc(X, Y, Z, rr=r):
        return X ** 2 + (Z - zc) ** 2 <= rr * rr
    g.fill((-r, -0.2, zc - r), (r, 0.1, zc + r), disc, pick(SKY_BLUE, 572))
    g.paint((-r, -0.25, zc - r), (r, 0.15, zc + r), lambda X, Y, Z: X ** 2 + (Z - zc) ** 2 >= (r - 0.18) ** 2, col(GOLD))
    egg = lambda X, Y, Z: (X / 0.42) ** 2 + ((Z - zc + 0.05) / np.where(Z > zc, 0.6, 0.48)) ** 2 <= 1
    g.fill((-0.5, -0.3, zc - 0.6), (0.5, -0.2, zc + 0.7), egg, col(CREAM[0]))
    g.fill((-0.5, -0.32, zc - 0.6), (0.5, -0.28, zc + 0.7),
           lambda X, Y, Z: egg(X, Y, Z) & (np.abs(Z - zc) < 0.1), col(GOLD))
    h = p.part('halo', anim='pulse', parent='body', pivot=(0, 0.3, zc))
    h.fill((-1.6, 0.25, zc - 1.6), (1.6, 0.45, zc + 1.6),
           lambda X, Y, Z: np.abs(np.sqrt(X ** 2 + (Z - zc) ** 2) - 1.42) < 0.12, col(*HALO))
    p.anchor = (0, 0, 0)


@prop('ShopDoubleCoins', 'shopdisplay', (-1.4, -1.0, 0), (1.4, 1.0, 2.8), budget=110, factors=(2,),
      note='Double Coins: two big gold coins on a wooden cradle, stamped with an egg; each coin spins '
           '("coinA", "coinB", spin)')
def _double(p):
    g = p.part('body')
    g.box((-1.3, -0.5, 0), (1.3, 0.6, 0.3), pick(WOOD_D, 580))
    for x in (-0.6, 0.6):
        g.box((x - 0.35, -0.2, 0.3), (x + 0.35, 0.3, 0.55), pick(WOOD, 581))
    r = 0.95
    zc = 0.55 + r
    emblem = lambda X, Y, Z, cx: ((X - cx) / 0.36) ** 2 + ((Z - zc + 0.04) / np.where(Z > zc, 0.52, 0.42)) ** 2 <= 1
    # each coin is stamped with an egg on both faces (symmetric: the game
    # shows props mirrored left to right, so no letters or numbers)
    for name, cx, cy in (('coinA', -0.6, -0.1), ('coinB', 0.6, 0.2)):
        c = p.part(name, anim='spin', parent='body', pivot=(cx, cy, zc))
        coin(c, (cx, cy, zc), r, 'y', 0.24)
        for y0, y1 in ((cy - 0.24, cy - 0.12), (cy + 0.12, cy + 0.24)):
            c.fill((cx - 0.4, y0, zc - 0.5), (cx + 0.4, y1, zc + 0.6), lambda X, Y, Z, cx=cx: emblem(X, Y, Z, cx), col(GOLD_D))
    p.anchor = (0, 0, 0)


@prop('ShopIncubators', 'shopdisplay', (-1.5, -1.0, 0), (1.5, 1.0, 2.2), budget=110, factors=(2,),
      note='Extra Incubators: two little incubators with glass domes and warm-lit eggs inside')
def _incubators(p):
    g = p.part('body')
    g.box((-1.4, -0.75, 0), (1.4, 0.75, 0.25), pick(WOOD, 590))
    for x, k in ((-0.7, 'basic'), (0.7, 'meadow')):
        g.cyl(x, 0, 0.25, 0.65, 0.6, pick(['#E8E1D2', '#E1D9C8'], 591))
        g.cyl(x, 0, 0.55, 0.65, 0.62, col(BRASS))
        g.cyl(x, 0, 0.65, 0.75, 0.5, col(*LAMP))
        g.ell((x, 0, 0.75), (0.55, 0.55, 1.1), col(GLASS), cond=lambda X, Y, Z: Z >= 0.75)
        g.carve((x - 0.45, -0.45, 0.75), (x + 0.45, 0.45, 1.75),
                lambda X, Y, Z, x=x: ((X - x) / 0.45) ** 2 + (Y / 0.45) ** 2 + ((Z - 0.75) / 0.98) ** 2 <= 1)
        draw_egg(g, x, 0, 0.75, k, 0.48)
        g.box((x - 0.1, -0.1, 1.85), (x + 0.1, 0.1, 2.05), col(BRASS))
        g.box((x - 0.18, -0.65, 0.35), (x + 0.18, -0.55, 0.5), col('#9CFFB0', 2.0))
    p.anchor = (0, 0, 0)


@prop('ShopMagnet', 'shopdisplay', (-1.3, -0.9, 0), (1.3, 0.9, 3.4), budget=100, factors=(2,),
      note='Auto-Collect: a red horseshoe magnet with silver tips pulling coins toward it ("coins", bob)')
def _magnet(p):
    g = p.part('body')
    g.box((-0.9, -0.5, 0), (0.9, 0.5, 0.3), pick(WOOD_D, 600))
    zc, R, t = 1.15, 0.75, 0.28

    def horseshoe(X, Y, Z):
        rr = np.sqrt(X ** 2 + (Z - zc) ** 2)
        arc = (np.abs(rr - R) <= t) & (Z <= zc)
        legs = (np.abs(np.abs(X) - R) <= t) & (Z > zc) & (Z <= zc + 1.0)
        return (arc | legs) & (np.abs(Y) <= 0.3)
    g.fill((-R - t, -0.3, zc - R - t), (R + t, 0.3, zc + 1.0), horseshoe, pick([RED, '#DB5247'], 601))
    g.paint((-R - t, -0.35, zc + 0.62), (R + t, 0.35, zc + 1.0), None, col(SILVER))
    g.box((-0.2, -0.2, 0.3), (0.2, 0.2, zc - R + 0.1), pick(WOOD_D, 602))
    c = p.part('coins', anim='bob', parent='body', pivot=(0, 0, 2.8))
    for (x, z, ax) in ((-0.55, 2.55, 'x'), (0.35, 2.85, 'y'), (-0.05, 3.15, 'x')):
        coin(c, (x, 0, z), 0.24, ax, 0.12)
    for (x, z) in ((-0.95, 2.3), (0.85, 2.5), (0.6, 3.15)):
        c.box((x - 0.06, -0.06, z - 0.06), (x + 0.06, 0.06, z + 0.06), col(GOLD_L, 2.0))
    p.anchor = (0, 0, 0)


# ---------------------------------------------------------- lights and decor
@prop('ShopLantern', 'shop', (-0.5, -1.4, 0), (0.5, 0.1, 2.0), budget=30, factors=(2,),
      note='iron wall lantern on a bracket, warm glass ("lamp", flicker); anchor = where the bracket meets the wall')
def _lantern(p):
    g = p.part('body')
    z = 1.6  # the bracket's height above the lantern's foot
    g.box((-0.3, -0.1, z - 0.4), (0.3, 0.1, z + 0.3), col(IRON))
    g.box((-0.1, -1.0, z), (0.1, -0.1, z + 0.2), col(IRON))
    g.box((-0.45, -1.25, z - 0.3), (0.45, -0.35, z - 0.1), col(IRON))
    g.box((-0.45, -1.25, z - 1.4), (0.45, -0.35, z - 1.2), col(IRON))
    for sx in (-1, 1):
        for sy in (-1, 1):
            g.box((sx * 0.4 - 0.1, -0.8 + sy * 0.4 - 0.1, z - 1.4), (sx * 0.4 + 0.1, -0.8 + sy * 0.4 + 0.1, z - 0.1), col(IRON))
    g.box((-0.12, -0.92, z - 0.1), (0.12, -0.68, z + 0.05), col(IRON))
    lamp = p.part('lamp', anim='flicker', parent='body', pivot=(0, -0.8, z - 0.75))
    lamp.box((-0.3, -1.1, z - 1.2), (0.3, -0.5, z - 0.3), col(*LAMP))
    p.anchor = (0, 0, z)


@prop('ShopChandelier', 'shop', (-2.6, -2.6, 0), (2.6, 2.6, 2.5), budget=170, factors=(2,),
      note='wooden ring chandelier with six candles ("flames", flicker) on short iron chains; anchor = top, at the ceiling')
def _chandelier(p):
    g = p.part('body')
    rz = 0.2
    ring = lambda X, Y, Z, w: np.abs(np.sqrt(X ** 2 + Y ** 2) - 2.1) <= w
    g.fill((-2.4, -2.4, rz), (2.4, 2.4, rz + 0.35), lambda X, Y, Z: ring(X, Y, Z, 0.25), pick(WOOD_D, 610))
    g.fill((-2.4, -2.4, rz + 0.3), (2.4, 2.4, rz + 0.45), lambda X, Y, Z: ring(X, Y, Z, 0.3), col(GOLD_D))
    fl = p.part('flames', anim='flicker', parent='body', pivot=(0, 0, rz + 1.1))
    for a in range(6):
        ang = a * math.pi / 3
        x, y = math.cos(ang) * 2.1, math.sin(ang) * 2.1
        g.box((x - 0.15, y - 0.15, rz + 0.45), (x + 0.15, y + 0.15, rz + 0.95), col(CREAM[0]))
        fl.box((x - 0.1, y - 0.1, rz + 0.95), (x + 0.1, y + 0.1, rz + 1.25), col(*LAMP))
        if a % 2 == 0:
            g.seg((x * 0.95, y * 0.95, rz + 0.4), (0, 0, 2.3), 0.1, col(IRON))
    g.box((-0.25, -0.25, 2.1), (0.25, 0.25, 2.5), col(IRON))
    g.ell((0, 0, rz + 0.05), (0.35, 0.35, 0.3), col(GOLD))
    p.anchor = (0, 0, 2.5)


@prop('ShopRug', 'shop', (-4.2, -6.2, 0), (4.2, 6.2, 0.2), budget=130, factors=(2, 4),
      note='runner rug from the door to the counter: red with a cream border and gold diamonds')
def _rug(p):
    g = p.part('body')
    g.box((-4, -6, 0), (4, 6, 0.2), pick(['#C23B3B', '#B93636'], 620))
    g.paint((-4, -6, 0), (4, 6, 0.2), lambda X, Y, Z: (np.abs(X) > 3.4) | (np.abs(Y) > 5.4), pick(CREAM, 621))
    g.paint((-4, -6, 0), (4, 6, 0.2), lambda X, Y, Z: (np.abs(X) > 3.0) & (np.abs(X) <= 3.4) & (np.abs(Y) <= 5.4),
            col(GOLD_D))
    for yc in (-3.2, 0.0, 3.2):
        g.paint((-4, -6, 0), (4, 6, 0.2), lambda X, Y, Z, yc=yc: np.abs(X) + np.abs(Y - yc) * 0.8 <= 1.4, col(GOLD))
        g.paint((-4, -6, 0), (4, 6, 0.2), lambda X, Y, Z, yc=yc: np.abs(X) + np.abs(Y - yc) * 0.8 <= 0.6,
                col(CREAM[0]))
    p.anchor = (0, 0, 0)


@prop('ShopHeader', 'shop', (-5.4, -0.5, 0), (5.4, 0.1, 2.0), budget=40, factors=(2, 4),
      note='10 x 1.6 wooden header board over a row of displays (the game writes "Coins" or "Passes"); '
           'front is -Z, back against the wall')
def _header(p):
    g = p.part('body')
    g.box((-5.2, -0.3, 0), (5.2, 0, 1.8), pick(WOOD_D, 630))
    g.box((-4.9, -0.4, 0.25), (4.9, -0.25, 1.55), pick(CREAM, 631))
    for sx in (-1, 1):
        g.ell((sx * 5.2, -0.3, 0.9), (0.3, 0.2, 0.42), col(GOLD))
    p.anchor = (0, 0, 0)


HEADER_BOARD = dict(face_y=-0.42, x=0.0, z=0.9, w=9.6, h=1.2)


@prop('ShopPlant', 'shop', (-1.0, -1.0, 0), (1.0, 1.0, 3.2), budget=70, factors=(2, 4),
      note='a potted leafy plant in a terracotta pot, for the corners')
def _plant(p):
    g = p.part('body')
    g.cyl(0, 0, 0, 1.1, 0.6, pick(CLAY, 640), r1=0.75)
    g.cyl(0, 0, 1.0, 1.2, 0.8, col(CLAY[0]))
    for i, (x, y, z, r) in enumerate(((0, 0, 2.0, 0.85), (0.4, 0.3, 2.6, 0.55), (-0.4, -0.2, 2.5, 0.55), (0.1, -0.4, 1.6, 0.6))):
        g.blob((x, y, z), (r, r, r * 0.85), pick(LEAF, 641 + i), amp=0.25, f=4, seed=11 + i)
    p.anchor = (0, 0, 0)


# -------------------------------------------------------------------- layout
# Where the game puts each piece, in the building's art frame (studs; x
# right, y back, z up, origin = floor centre at ground level) with `turn` in
# degrees about the up axis, Roblox's sense (positive turns -Z toward -X,
# so a piece turned 90 faces -X and one turned -90 faces +X).
#
#   piece   a prop, solid or not
#   display a Robux item: `plinth` prop + `item` prop on its anchor, a price
#           card on the plinth front and a Buy prompt
#   light   a PointLight (studs)
#   text    a text board: `slot` names what the game writes there
#   keeper  a creature stand-in the client draws (CreatureLook)

def _displays():
    out = []
    # left wall, facing +X: the coin packs, smallest at the door
    for y, key, item in ((-6.6, 'CoinPackSmall', 'ShopCoinPouch'), (-1.9, 'CoinPackMedium', 'ShopCoinSack'),
                         (2.8, 'CoinPackBig', 'ShopCoinChest'), (7.5, 'CoinPackLarge', 'ShopCoinHoard')):
        out.append(dict(type='display', key=key, kind='product', plinth='ShopPlinth', item=item,
                        at=(X0 + T + 2.3, y, FLOOR), turn=-90))
    # right wall, facing -X: the passes, then the shield nearest the counter
    for y, key, kind, item in ((-6.6, 'AutoCollect', 'pass', 'ShopMagnet'), (-1.9, 'ExtraIncubators', 'pass', 'ShopIncubators'),
                               (2.8, 'DoubleCoins', 'pass', 'ShopDoubleCoins'), (7.5, 'ShieldRefill', 'product', 'ShopShieldStand')):
        out.append(dict(type='display', key=key, kind=kind, plinth='ShopPlinthVelvet', item=item,
                        at=(X1 - T - 2.3, y, FLOOR), turn=90))
    return out


LAYOUT = [
    dict(type='piece', prop='ShopFloor', at=(0, 0, 0), turn=0, collide=True),
    dict(type='piece', prop='ShopWallFront', at=(0, 0, 0), turn=0, collide=True),
    dict(type='piece', prop='ShopWallBack', at=(0, 0, 0), turn=0, collide=True),
    dict(type='piece', prop='ShopWallSide', at=(0, 0, 0), turn=0, collide=True),
    dict(type='piece', prop='ShopWallSide', at=(0, 0, 0), turn=180, collide=True),
    dict(type='piece', prop='ShopRoof', at=(0, 0, 0), turn=0, collide=True),
    dict(type='piece', prop='ShopGable', at=(0, 0, 0), turn=0, collide=True),
    dict(type='piece', prop='ShopCeiling', at=(0, 0, 0), turn=0, collide=False),
    dict(type='piece', prop='ShopAwning', at=(0, Y0, DOOR_H + 0.3), turn=0, collide=False),
    dict(type='piece', prop='ShopSign', at=(0, Y0, 12.1), turn=0, collide=False),
    dict(type='text', slot='title', prop='ShopSign', at=(0, Y0, 12.1), turn=0, board=SIGN_BOARD),
    dict(type='piece', prop='ShopLantern', at=(-5.0, Y0, 7.6), turn=0, collide=False),
    dict(type='piece', prop='ShopLantern', at=(5.0, Y0, 7.6), turn=0, collide=False),
    dict(type='light', at=(-5.0, Y0 - 0.8, 6.85), range=14, brightness=1.2),
    dict(type='light', at=(5.0, Y0 - 0.8, 6.85), range=14, brightness=1.2),
    dict(type='piece', prop='ShopRug', at=(0, -4.6, FLOOR), turn=0, collide=True),
    dict(type='piece', prop='ShopCounter', at=(0, 6.2, FLOOR), turn=0, collide=True),
    dict(type='piece', prop='ShopShelf', at=(0, Y1 - T - 1.25, FLOOR), turn=0, collide=True),
    dict(type='piece', prop='ShopStool', at=(-2.0, 8.4, FLOOR), turn=0, collide=True),
    dict(type='keeper', species='Hamster', at=(-2.0, 8.4, FLOOR + 2.4), turn=0, size=2.4),
    dict(type='piece', prop='ShopChandelier', at=(0, -1.0, WALL_H - 0.4), turn=0, collide=False),
    dict(type='light', at=(0, -1.0, WALL_H - 2.2), range=24, brightness=1.6),
    dict(type='piece', prop='ShopHeader', at=(X0 + T, 0.45, 8.0), turn=-90, collide=False),
    dict(type='text', slot='coins', prop='ShopHeader', at=(X0 + T, 0.45, 8.0), turn=-90, board=HEADER_BOARD),
    dict(type='piece', prop='ShopHeader', at=(X1 - T, 0.45, 8.0), turn=90, collide=False),
    dict(type='text', slot='passes', prop='ShopHeader', at=(X1 - T, 0.45, 8.0), turn=90, board=HEADER_BOARD),
    dict(type='piece', prop='ShopPlant', at=(X0 + T + 1.3, Y0 + T + 1.3, FLOOR), turn=0, collide=True),
    dict(type='piece', prop='ShopPlant', at=(X1 - T - 1.3, Y0 + T + 1.3, FLOOR), turn=0, collide=True),
] + _displays()

# wall lanterns inside, between the displays, and their lights
for _x, _turn in ((X0 + T, -90), (X1 - T, 90)):
    for _y in (-4.25, 0.45, 5.15):
        LAYOUT.append(dict(type='piece', prop='ShopLantern', at=(_x, _y, 7.2), turn=_turn, collide=False))
        _dx = 0.8 if _x < 0 else -0.8
        LAYOUT.append(dict(type='light', at=(_x + _dx, _y, 6.45), range=10, brightness=0.8))
# warm light on the counter and shelf
LAYOUT.append(dict(type='light', at=(0, 8.5, 7.0), range=14, brightness=0.9))

# the card on each plinth, in the plinth's art frame, and where its item stands
PLINTH_CARD = CARD
PLINTH_TOP = {'ShopPlinth': 2.4, 'ShopPlinthVelvet': 2.62}
