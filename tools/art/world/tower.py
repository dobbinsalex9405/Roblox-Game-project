"""The cozy apartment tower: one shell per floor, stacked ten high.

Layout (from the polish thread, base-local studs, art frame: x right, y =
Roblox Z, so the front of the tower, -y, faces the farm in the middle):

- footprint x -24..24, y -3..23; floor-to-floor height 12;
- elevator shaft in the back-left corner, 7 x 7 at x -24..-17, y 17..24
  (stop at -20.5, 20.5): the slab has a hole there and the walls stop at it;
- ladder outside the right wall at x 25.2, y 14.5: the right wall has a
  doorway at y 12.5..16.5;
- creature cells x -20..20, y 0..20 stay clear; walls on all four sides.
  The front wall (Alex, Nov 12: an open front read as a missing wall) has
  big windows whose glass is its own part, "pane", which the game draws
  see-through, and on floor 1 a door at x -4.5..4.5 (the way in).

Pieces per floor n (kind "tower", floor n):

    TowerFloor<n>   slab, top at the floor's walking height (z -0.6..0)
    TowerBack<n>    back wall with windows
    TowerLeft<n>    left wall with windows
    TowerRight<n>   right wall with the ladder doorway
    TowerFront<n>   front wall with four windows (floor 1: two windows, the
                    front door, planters and a striped awning)
    TowerRoof       caps the stack; place it as if it were floor 11

Every piece has the same anchor: the base centre (0, 0) at that floor's
walking height. The game puts the anchor at (base centre, floor height) and
every piece lands in place. Walls run 11.4 high, so the next slab (z -0.6
of the floor above) closes the gap exactly. Walls are 0.8 thick: the inside
faces are at y 22 (back) and x -23.2 / 23.2 (sides), the outside faces on
the footprint edge (the back one at y 22.8).

The outside climbs from brick (1 to 3) through pastel plaster with shutters
(4 to 7) to a garden terrace (8), a starry observatory (9) and a white and
gold penthouse (10). Inside, each floor has its own wallpaper, wainscot and
floor finish for its room theme.
"""
import math
import numpy as np

from vkit import Grid, VOX, col, hnoise
from styles import pick
from props import prop

W0, W1 = -24.0, 24.0  # footprint x
D0, D1 = -3.0, 23.0  # footprint y
H = 11.4  # wall height (floor to the next slab)
T = 0.8  # wall thickness: inside half wallpaper, outside half facade, so both survive 0.2 and 0.4 Parts voxels
IN_BACK, IN_LEFT, IN_RIGHT = 22.0, -23.2, 23.2  # inside faces of the walls, on the 0.4 grid
IN_FRONT = D0 + T  # inside face of the front wall (-2.2): the outside face is the footprint edge
SKIN = 0.4
SHAFT = (-24.0, -17.0, 17.0, 24.0)  # x0, x1, y0, y1
LADDER_DOOR = (12.5, 16.5, H)  # y0, y1, height: open floor to ceiling
LADDER_HOLE = (21.0, 24.0, 12.5, 16.5)  # x0, x1, y0, y1: deck opening on floors 2-10 (Geometry.LADDER_HOLE_MIN/MAX)
INNER, OUTER = -0.35, 1.3  # wall-local depth range: trims inside, sills and flower boxes outside

THEMES = ['Cozy studio', 'Book nook', 'Plant sunroom', 'Bakery kitchen', 'Games lounge', 'Winter cabin', 'Art studio',
          'Rooftop garden', 'Starlit observatory', 'Golden sky penthouse']


def fam(base, *others):
    """palette ids for base and others; others fold into base in the Parts export"""
    b = col(base) if isinstance(base, str) else base
    return [b] + [col(*o, of=b) if isinstance(o, tuple) else col(o, of=b) for o in others]


def C(x):
    return col(*x) if isinstance(x, tuple) else col(x)


# ----------------------------------------------------------- outside styles
def brick(base, dark, mortar='#E9DCC8'):
    b, d, m = fam(base, dark, mortar)

    def f(U, T_, Z):
        row = np.floor(Z / 0.4)
        off = np.where(np.mod(row, 2) == 0, 0.0, 0.6)
        mort = (np.mod(Z, 0.4) < VOX) | (np.mod(U + off, 1.2) < VOX)
        return np.where(mort, m, np.where(hnoise(np.floor((U + off) / 1.2), row, T_ * 0, 3) > 0.7, d, b))
    return f


def plaster(base, speck):
    return pick([base, speck], 7, scale=1.0)


def lattice(base, lath):
    b, l_ = fam(base, lath)

    def f(U, T_, Z):
        return np.where((np.mod(U + Z, 1.6) < 0.12) | (np.mod(U - Z, 1.6) < 0.12), l_, b)
    return f


def stars(base, dot, seed=11):
    b, s = fam(base, (dot, 2.5))

    def f(U, T_, Z):
        return np.where(hnoise(np.floor(U / 0.1), np.floor(Z / 0.1), T_ * 0, seed) > 0.985, s, b)
    return f


OUT = {
    1: dict(face=brick('#B5553C', '#A24A34'), plinth='#8F8A86', trim='#FFF4E0', box='#8B5A33', flowers=['#E8413C', '#FF6FA8']),
    2: dict(face=brick('#A84F3A', '#97452F'), trim='#FFF4E0', box='#3D5A80', flowers=['#FFD166', '#FFFFFF']),
    3: dict(face=brick('#BF6446', '#AE5A3E'), trim='#FFF4E0', box='#4FB3B0', flowers=['#C9A7FF', '#FF9EC7']),
    4: dict(face=plaster('#F7D88A', '#F2CF7C'), trim='#FFFFFF', shutter='#4FB3B0', box='#FFFFFF', flowers=['#E8413C', '#FFFFFF']),
    5: dict(face=plaster('#A9DCC0', '#9FD3B6'), trim='#FFFFFF', shutter='#F28FA8', box='#FFFFFF', flowers=['#FFD166', '#FF6FA8']),
    6: dict(face=plaster('#A8CBEB', '#9DC2E4'), trim='#FFFFFF', shutter='#3D5A80', box='#8B5A33', flowers=None, snow=True),
    7: dict(face=plaster('#F2B3B8', '#ECA8AE'), trim='#FFFFFF', shutter='#9C6ADE', box='#FFFFFF', flowers=['#8FD3FF', '#FFD166']),
    8: dict(face=lattice('#9CC59A', '#F4F1E6'), trim='#FFFFFF', box='#C98E52', flowers=['#FF6FA8', '#FFD166'], ivy=True),
    9: dict(face=stars('#2A3570', '#FFE58A'), trim='#F4C542', round=True),
    10: dict(face=plaster('#FFF8EC', '#F6EEDD'), trim='#F4C542', arch=True, pilaster=True),
}


# ------------------------------------------------------------ inside themes
def stripes(a, b, w=0.6):
    i, j = fam(a, b)
    return lambda U, T_, Z: np.where(np.mod(U, 2 * w) < w, i, j)


def dots(a, b, step=1.0, r=0.12, glow=0.0):
    i, j = fam(a, (b, glow))

    def f(U, T_, Z):
        row = np.floor(Z / step)
        uu = np.mod(U + np.where(np.mod(row, 2) == 0, 0, step / 2), step) - step / 2
        zz = np.mod(Z, step) - step / 2
        return np.where(uu * uu + zz * zz < r * r, j, i)
    return f


def logs(a, b, gap):
    i, j, k = fam(a, b, gap)
    return lambda U, T_, Z: np.where(np.mod(Z, 0.8) < VOX, k, np.where(np.mod(np.floor(Z / 0.8), 2) == 0, i, j))


def splats(base, cols, seed=21):
    ids = fam(base, *cols)

    def f(U, T_, Z):
        h = hnoise(np.floor(U / 0.3), np.floor(Z / 0.3), T_ * 0, seed)
        k = np.minimum(((h - 0.9) / 0.1 * len(cols)).astype(int), len(cols) - 1)
        return np.where(h > 0.9, np.array(ids[1:])[np.clip(k, 0, len(cols) - 1)], ids[0])
    return f


def marble(base, vein):
    i, j = fam(base, vein)
    return lambda U, T_, Z: np.where(np.abs(np.sin(U * 0.9 + Z * 0.6 + np.sin(Z * 1.7) * 1.2)) < 0.05, j, i)


def planks(a, b, seam, w=0.8):
    i, j, k = fam(a, b, seam)

    def f(X, Y, Z):
        row = np.floor(Y / w)
        joint = np.mod(X + np.mod(row * 2.3, 4.0), 4.0) < VOX
        return np.where((np.mod(Y, w) < VOX) | joint, k, np.where(hnoise(row, np.floor(X / 4), Z * 0, 5) > 0.6, j, i))
    return f


def tiles(a, grout, s=1.0):
    i, j = fam(a, grout)
    return lambda X, Y, Z: np.where((np.mod(X, s) < VOX) | (np.mod(Y, s) < VOX), j, i)


def checker(a, b, s=1.5):
    i, j = fam(a, b)
    return lambda X, Y, Z: np.where(np.mod(np.floor(X / s) + np.floor(Y / s), 2) == 0, i, j)


def speck(a, b, seed=4):
    return pick([a, b], seed)


IN = {
    1: dict(paper=stripes('#F7D6B5', '#F2C9A3'), wains='#C98E52', rail='#FFF4E0', floor=planks('#C98E52', '#BF8549', '#A8743F')),
    2: dict(paper=dots('#5E8C6A', '#E8C66A', 1.2, 0.1), wains='#7A4D2B', rail='#E8C66A', floor=planks('#8B5A33', '#7E5130', '#6A4226', 0.6)),
    3: dict(paper=dots('#DDF0D8', '#B9DDB2', 1.0, 0.18), wains='#FFFFFF', rail='#FFFFFF', floor=tiles('#D98B5F', '#E8C3A6', 1.2)),
    4: dict(paper=stripes('#FFE7B3', '#FFF1D1', 0.4), wains=('tile', '#FFFFFF', '#E3E3E3'), rail='#D9534F',
            floor=checker('#D9534F', '#FFF4E0', 1.5)),
    5: dict(paper=dots('#6E56B8', '#8F79D6', 1.4, 0.2), wains='#2E3A6B', rail='#4FB3B0',
            floor=lambda X, Y, Z: np.where(hnoise(np.floor(X / 0.3), np.floor(Y / 0.3), Z * 0, 9) > 0.93,
                                           fam('#3D5A80', '#FFD166')[1], fam('#3D5A80', '#FFD166')[0])),
    6: dict(paper=logs('#A0673A', '#94603A', '#6E4527'), wains=None, rail='#6E4527', floor=planks('#B07A42', '#A6703C', '#8B5A33')),
    7: dict(paper=splats('#FAFAF5', ['#FF6FA8', '#4FB3B0', '#FFD166', '#9C6ADE']), wains='#E8E4DC', rail='#9C6ADE',
            floor=lambda X, Y, Z: splats('#BDBDBD', ['#FF6FA8', '#4FB3B0', '#FFD166'], 23)(X, Z, Y)),
    8: dict(paper=lattice('#BFE3B4', '#FFFFFF'), wains='#C98E52', rail='#FFFFFF', floor=speck('#6CC04A', '#62B543')),
    9: dict(paper=stars('#1E2A5A', '#FFF1B0', 13), wains='#141C40', rail='#F4C542',
            floor=lambda X, Y, Z: stars('#232F66', '#FFF1B0', 17)(X, Z, Y)),
    10: dict(paper=marble('#FFF8EC', '#EADFC8'), wains='#F4C542', rail='#FFF8EC',
             floor=checker('#FFF8EC', '#F2D98A', 2.0)),
}


# ------------------------------------------------------------- wall builder
class WallGrid(Grid):
    """a wall modelled in its own frame: u along the wall, t through it (0 =
    inside face, T = outside face), z up"""


def win_shape(o, cu, z0, z1, w):
    if o.get('round'):
        r, zc = w / 2, (z0 + z1) / 2
        return lambda U, Z: (U - cu) ** 2 + (Z - zc) ** 2 < r * r
    if o.get('arch'):
        r = w / 2
        return lambda U, Z: (np.abs(U - cu) < r) & ((Z < z1 - r) | ((U - cu) ** 2 + (Z - (z1 - r)) ** 2 < r * r))
    return lambda U, Z: np.abs(U - cu) < w / 2


def window(g, n, cu, w=4.0, z0=3.6, z1=8.6, outside=True, pane=None):
    o, i = OUT[n], IN[n]
    if o.get('round'):
        z0, z1 = 6.0 - w / 2, 6.0 + w / 2
    trim, glass = C(o['trim']), col('#BEE6FF')
    inside = win_shape(o, cu, z0, z1, w)
    frame = win_shape(o, cu, z0 - 0.3, z1 + 0.3, w + 0.6)
    lo, hi = (cu - w / 2 - 2, INNER, z0 - 1.5), (cu + w / 2 + 2, OUTER, z1 + 1)
    g.fill((lo[0], -0.12, z0 - 0.3), (hi[0], T + 0.15, z1 + 0.3), lambda U, T_, Z: frame(U, Z) & ~inside(U, Z), trim)
    g.carve((lo[0], INNER, z0), (hi[0], OUTER, z1), lambda U, T_, Z: inside(U, Z))
    (pane if pane is not None else g).fill((lo[0], 0.2, z0), (hi[0], 0.6, z1), lambda U, T_, Z: inside(U, Z), glass)
    # mullions: one upright and one cross bar
    zc = (z0 + z1) / 2 + (0.6 if not o.get('round') else 0)
    g.fill((cu - 0.1, 0.1, z0), (cu + 0.1, 0.7, z1), lambda U, T_, Z: inside(U, Z), trim)
    g.fill((lo[0], 0.1, zc - 0.1), (hi[0], 0.7, zc + 0.1), lambda U, T_, Z: inside(U, Z), trim)
    # sills
    g.box((cu - w / 2 - 0.3, -0.3, z0 - 0.3), (cu + w / 2 + 0.3, 0, z0), C(i['rail']))
    curtains(g, n, cu, w, z0, z1)
    if not outside:
        return
    g.box((cu - w / 2 - 0.4, T, z0 - 0.35), (cu + w / 2 + 0.4, T + 0.35, z0), trim)
    if o.get('snow'):
        g.box((cu - w / 2 - 0.4, T, z0), (cu + w / 2 + 0.4, T + 0.35, z0 + 0.12), col('#FFFFFF'))
    if o.get('shutter'):
        s, sl = fam(o['shutter'], '#2F3A4A' if o['shutter'] != '#3D5A80' else '#2A3F5C')
        for a, b in ((cu - w / 2 - 1.5, cu - w / 2 - 0.3), (cu + w / 2 + 0.3, cu + w / 2 + 1.5)):
            g.fill((a, T, z0), (b, T + 0.18, z1), None, lambda U, T_, Z: np.where(np.mod(Z, 0.5) < VOX, sl, s))
    if o.get('flowers'):
        bx = C(o['box'])
        g.box((cu - w / 2, T, z0 - 1.25), (cu + w / 2, T + 0.7, z0 - 0.35), bx)
        g.box((cu - w / 2 - 0.05, T + 0.6, z0 - 1.1), (cu + w / 2 + 0.05, T + 0.75, z0 - 0.95), C(o['trim']))
        leaf = pick(['#3E9A3A', '#55B947'], 31)
        g.fill((cu - w / 2 + 0.1, T + 0.05, z0 - 0.4), (cu + w / 2 - 0.1, T + 0.65, z0 + 0.25),
               lambda U, T_, Z: Z < z0 - 0.35 + 0.35 * (0.5 + 0.5 * np.sin(U * 5.1) * np.sin(T_ * 7.3)), leaf)
        fl = [col(c) for c in o['flowers']]
        for k in range(int(w / 0.6)):
            u = cu - w / 2 + 0.3 + k * 0.6
            tt = T + 0.2 + 0.25 * (k % 2)
            g.ell((u, tt, z0 - 0.05 + 0.08 * (k % 3)), (0.17, 0.17, 0.13), fl[k % len(fl)])
    if o.get('snow') and not o.get('flowers'):
        g.box((cu - w / 2, T, z0 - 1.0), (cu + w / 2, T + 0.6, z0 - 0.35), C(o['box']))
        g.box((cu - w / 2, T, z0 - 0.35), (cu + w / 2, T + 0.6, z0 - 0.2), col('#FFFFFF'))
        g.ell((cu - 0.6, T + 0.3, z0 - 0.15), (0.35, 0.3, 0.25), col('#FFFFFF'))


# inside dressing per theme: curtain fabric (main, fold shade) and the
# colours of the little pictures between the windows (sky, ground)
DRESS = {
    1: dict(curtain=('#F28FA8', '#E27E98'), art=('#8FD3FF', '#7AC35E')),
    2: dict(curtain=('#9E3B4A', '#8A3241'), art=('#FFD166', '#3D5A80')),
    3: dict(curtain=('#FFFFFF', '#EDEDED'), art=('#BFE9FF', '#55B947')),
    4: dict(curtain=('#D9534F', '#C94743'), art=('#FFE7B3', '#C98E52')),
    5: dict(curtain=('#4FB3B0', '#44A3A0'), art=('#FF6FA8', '#6E56B8')),
    6: dict(curtain=('#3D5A80', '#34507A'), art=('#DDEFFF', '#FFFFFF')),
    7: dict(curtain=('#FFD166', '#F0C058'), art=('#FF6FA8', '#4FB3B0')),
    8: dict(curtain=('#FFFFFF', '#EDEDED'), art=('#8FD3FF', '#FF9EC7')),
    9: dict(curtain=('#5B3E96', '#4E3484'), art=('#1E2A5A', '#FFE58A')),
    10: dict(curtain=('#B5202E', '#A11C29'), art=('#FFF1B0', '#F4C542')),
}


def curtains(g, n, cu, w, z0, z1):
    """two drapes and a valance on the inside of a window"""
    main, fold = fam(*DRESS[n]['curtain'])
    tie = C(IN[n]['rail'])
    shade = lambda U, T_, Z: np.where(np.sin(U * 7.0) > 0.3, fold, main)  # noqa: E731
    for a, b in ((cu - w / 2 - 0.9, cu - w / 2 + 0.35), (cu + w / 2 - 0.35, cu + w / 2 + 0.9)):
        g.fill((a, -0.34, z0 - 0.7), (b, -0.02, z1 + 0.5),
               lambda U, T_, Z: T_ > -0.32 + 0.14 * (0.5 + 0.5 * np.sin(U * 7.0)), shade)
        g.box((a, -0.36, z0 + 1.2), (b, -0.02, z0 + 1.45), tie)
    g.fill((cu - w / 2 - 1.0, -0.36, z1 + 0.35), (cu + w / 2 + 1.0, -0.02, z1 + 1.05),
           lambda U, T_, Z: Z > z1 + 0.35 + 0.18 * (0.5 + 0.5 * np.cos(U * 3.1)), shade)


def picture(g, n, cu, z=5.0):
    """a small framed picture on the inside: sky, a hill and a sun"""
    sky, hill = col(DRESS[n]['art'][0]), col(DRESS[n]['art'][1])
    frame = C(IN[n]['rail'])
    g.box((cu - 0.9, -0.16, z), (cu + 0.9, 0, z + 1.4), frame)
    g.box((cu - 0.72, -0.2, z + 0.18), (cu + 0.72, -0.1, z + 1.22), sky)
    g.fill((cu - 0.72, -0.24, z + 0.18), (cu + 0.72, -0.12, z + 0.8),
           lambda U, T_, Z: Z < z + 0.45 + 0.3 * np.cos((U - cu) * 2.0), hill)
    g.ell((cu + 0.35, -0.2, z + 0.95), (0.16, 0.06, 0.16), col('#FFD166'))


def door(g, n, u0, u1, h):
    """the ladder opening: open from the floor to the ceiling, so players
    climbing the outside ladder step straight through (the slab above has
    its hole beside it, LADDER_HOLE); trim posts only on either side"""
    o = OUT[n]
    g.carve((u0, INNER, 0), (u1, OUTER, H + 0.3))
    trim = C(o['trim'])
    g.box((u0 - 0.35, -0.15, 0), (u0, T + 0.2, H), trim)
    g.box((u1, -0.15, 0), (u1 + 0.35, T + 0.2, H), trim)


CORNER = 0.4  # how far a side wall's outside trims reach past the front corner


def wall(n, u0, u1, wins, doorway=None, pane=None, corner=False):
    """voxel array of one wall of floor n in the (u, t, z) frame; with `pane`
    (another WallGrid of the same bounds) the window glass goes there.
    `corner`: u0 is the tower's front corner, where this wall's end shows
    beside the front wall, so the end is all facade (the inside dressing
    starts behind the front wall) and the outside trims wrap the corner"""
    o, i = OUT[n], IN[n]
    g = WallGrid((u0 - (CORNER if corner else 0), INNER, 0), (u1, OUTER, H + 0.3))
    uo = u0 - CORNER if corner else u0  # outside trims
    g.box((u0, 0, 0), (u1, T, H), o['face'])
    if o.get('plinth'):
        g.box((u0, 0.3, 0), (u1, T + 0.1, 1.2), pick([o['plinth'], '#857F7B'], 9))
    # outside: base band and the cornice at the top of the floor
    g.box((uo, T, 0), (u1, T + 0.15, 0.35), C(o['trim']))
    g.box((uo, T, H - 0.5), (u1, T + 0.3, H), C(o['trim']))
    g.box((uo, T, H - 0.75), (u1, T + 0.15, H - 0.5), C(o['trim']))
    if corner:
        u0 = u0 + T  # inside dressing starts behind the front wall
    if o.get('pilaster'):
        for k in range(int((u1 - u0) / 6) + 1):
            u = u0 + 1 + k * 6
            if u + 0.6 <= u1 - 0.5:
                g.box((u, T, 0.35), (u + 0.6, T + 0.25, H - 0.75), C(o['trim']))
    # inside: wallpaper, wainscot, chair rail, baseboard, crown
    g.box((u0, 0, 0), (u1, SKIN, H), i['paper'])
    wn = i['wains']
    if wn is not None:
        if isinstance(wn, tuple) and wn[0] == 'tile':
            c = tiles(wn[1], wn[2], 0.5)
            g.box((u0, -0.08, 0), (u1, SKIN, 3.0), lambda U, T_, Z: c(U, Z, T_))
        else:
            g.box((u0, -0.08, 0), (u1, SKIN, 3.0), C(wn))
        g.box((u0, -0.18, 2.95), (u1, SKIN, 3.2), C(i['rail']))
    g.box((u0, -0.16, 0), (u1, SKIN, 0.45), C(i['rail']))
    g.box((u0, -0.25, H - 0.35), (u1, SKIN, H), C(i['rail']))
    for cu, w in wins:
        window(g, n, cu, w, pane=pane)
    for (ca, wa), (cb, wb) in zip(wins, wins[1:]):
        if cb - ca - (wa + wb) / 2 >= 5.0:
            picture(g, n, (ca + cb) / 2)
    if doorway:
        door(g, n, *doorway)
    if o.get('ivy'):
        leaf = pick(['#3E9A3A', '#37903A', '#55B947'], 33)
        for cu, w in wins:
            for side in (-1, 1):
                u = cu + side * (w / 2 + 0.9)
                g.fill((u - 0.8, T, 0.2), (u + 0.8, T + 0.35, 8.5),
                       lambda U, T_, Z, u=u: np.abs(U - u - 0.35 * np.sin(Z * 1.3)) < 0.3 + 0.2 * np.sin(Z * 3.1) ** 2, leaf)
    return g


def put(p, wg, side, part='body'):
    """copy a wall grid into one of the prop's part grids, turned to its side"""
    dst = p.part(part)
    c, o = wg.c, wg.o
    if side == 'front':  # x = u, y = -2.2 - t (the outside faces -y)
        arr, org = c[:, ::-1, :], (o[0], int(round(IN_FRONT / VOX)) - (o[1] + c.shape[1]), o[2])
    elif side == 'back':  # x = u, y = 22.4 + t
        arr, org = c, (o[0], o[1] + int(round(IN_BACK / VOX)), o[2])
    elif side == 'right':  # x = 23.4 + t, y = u
        arr, org = c.transpose(1, 0, 2), (o[1] + int(round(IN_RIGHT / VOX)), o[0], o[2])
    else:  # left: x = -23.4 - t, y = u
        arr = c.transpose(1, 0, 2)[::-1]
        org = (int(round(IN_LEFT / VOX)) - (o[1] + c.shape[1]), o[0], o[2])
    a = [org[k] - dst.o[k] for k in range(3)]
    sl = tuple(slice(a[k], a[k] + arr.shape[k]) for k in range(3))
    sub = dst.c[sl]
    m = arr > 0
    sub[m] = arr[m]


def wall_bounds(side, u0, u1):
    if side in ('left', 'right') and u0 == D0:
        u0 -= CORNER  # the outside trims wrap the front corner (wall(corner=True))
    if side == 'back':
        return (u0, IN_BACK + INNER, 0), (u1, IN_BACK + OUTER, H + 0.3)
    if side == 'right':
        return (IN_RIGHT + INNER, u0, 0), (IN_RIGHT + OUTER, u1, H + 0.3)
    return (IN_LEFT - OUTER, u0, 0), (IN_LEFT - INNER, u1, H + 0.3)


WALLS = {
    # side: (u0, u1, windows [(centre, width)], doorway)
    'Back': ('back', SHAFT[1], IN_RIGHT, [(-9.0, 4.0), (3.0, 4.0), (15.0, 4.0)], None),
    'Left': ('left', D0, SHAFT[2], [(1.5, 4.0), (10.0, 4.0)], None),
    'Right': ('right', D0, IN_BACK, [(3.5, 4.0), (20.0, 3.0)], (LADDER_DOOR[0], LADDER_DOOR[1], LADDER_DOOR[2])),
}
NOTES = {
    'Back': 'back wall, {} outside, {} inside; three windows; stops at the elevator shaft (x -17)',
    'Left': 'left wall, {} outside, {} inside; two windows; stops at the elevator shaft (base z 17)',
    'Right': 'right wall, {} outside, {} inside; open floor to ceiling at base z 12.5..16.5 where the outside ladder comes in',
}
LOOK = {1: 'red brick', 2: 'red brick', 3: 'red brick', 4: 'butter-yellow plaster with teal shutters',
        5: 'mint plaster with pink shutters', 6: 'sky-blue plaster with navy shutters and snowy sills',
        7: 'rose plaster with purple shutters', 8: 'sage trellis with ivy', 9: 'starry navy with gold portholes',
        10: 'white and gold with arched windows'}


def _wall_prop(n, name):
    side, u0, u1, wins, doorway = WALLS[name]
    if n == 9:
        wins = [(c, 3.6) for c, _ in wins]
    lo, hi = wall_bounds(side, u0, u1)

    def fn(p):
        g = wall(n, u0, u1, wins, doorway, corner=side in ('left', 'right') and u0 == D0)
        put(p, g, side)
        p.anchor = (0, 0, 0)
    note = NOTES[name].format(LOOK[n], THEMES[n - 1].lower()) + '. Anchor: base centre at this floor\'s walking height.'
    prop(f'Tower{name}{n}', 'tower', lo, hi, budget=190 if name == 'Back' else 140, floor=n, note=note, factors=(2, 4, 5, 6, 8))(fn)


# ------------------------------------------------------------------- slabs
def slab(p, n, z0=-0.6, top=None):
    g = p.part('body')
    o, i = OUT[n], IN[n]
    edge = C(o['trim'])
    g.box((W0, D0, z0), (W1, D1, 0), edge)
    g.box((W0 + 0.3, D0 + 0.3, z0 + 0.15), (W1, D1, 0), pick(['#D8D2C8', '#CFC8BD'], 61))
    g.box((W0 + 0.3, D0 + 0.3, -0.2), (W1 - 0.3, D1 - 0.3, 0), top or i['floor'])
    g.carve((SHAFT[0], SHAFT[2], z0 - 1), (SHAFT[1], SHAFT[3] + 1, 1))
    if n >= 2:
        g.carve((LADDER_HOLE[0] - 0.1, LADDER_HOLE[2] - 0.1, z0 - 1), (LADDER_HOLE[1] + 1, LADDER_HOLE[3] + 0.1, 1))
    # front lip under the balcony rail
    g.box((W0, D0 - 0.25, z0), (W1, D0 + 0.05, z0 + 0.25), edge)
    p.anchor = (0, 0, 0)


def _floor_prop(n):
    def fn(p):
        slab(p, n)
    prop(f'TowerFloor{n}', 'tower', (W0, D0 - 0.25, -0.6), (W1, D1, 0), budget=60, floor=n,
         note=f'floor slab, {THEMES[n - 1].lower()} floor finish; hole for the elevator shaft in the back-left corner'
              + (' and the ladder opening at x 21..24, base z 12.5..16.5. ' if n >= 2 else '. ') +
              'Top face is the walking height. Anchor: base centre at this floor\'s walking height.')(fn)


# ------------------------------------------------------------------ fronts
# The front wall runs the full width, x -24..24, outside face on the
# footprint edge (y -3) like the other walls; the side walls own the two
# corners (export.py resolves the overlap, so no face is drawn twice).
FRONT_WINDOWS = [(-16.0, 5.0), (-5.5, 5.0), (5.5, 5.0), (16.0, 5.0)]
DOOR = (-4.5, 4.5, 8.0)  # x0, x1, height: the way in on floor 1 (the planter gap before)
FRONT_WINDOWS_1 = [(-15.0, 6.0), (15.0, 6.0)]


def entrance(g, n, u0, u1, top):
    """the front door on floor 1: open from the floor to `top`, with trim
    posts and a lintel round it (wall frame: inside t < 0, outside t > T)"""
    o = OUT[n]
    trim = C(o['trim'])
    g.carve((u0, INNER, 0), (u1, OUTER, top))
    g.box((u0 - 0.4, -0.15, 0), (u0, T + 0.2, top + 0.4), trim)
    g.box((u1, -0.15, 0), (u1 + 0.4, T + 0.2, top + 0.4), trim)
    g.box((u0 - 0.4, -0.15, top), (u1 + 0.4, T + 0.2, top + 0.4), trim)


def front_one(p):
    """floor 1: brick front with two big windows, the front door (x -4.5..4.5),
    lanterns either side, planters along the foot and a striped awning"""
    n = 1
    o = OUT[1]
    pane = WallGrid((W0, INNER, 0), (W1, OUTER, H + 0.3))
    g = wall(n, W0, W1, FRONT_WINDOWS_1, pane=pane)
    entrance(g, n, DOOR[0], DOOR[1], DOOR[2])
    # lanterns on the wall either side of the door
    for x in (DOOR[0] - 1.4, DOOR[1] + 1.4):
        g.box((x - 0.4, T, 5.6), (x + 0.4, T + 0.4, 5.9), col('#2F3A4A'))
        g.box((x - 0.3, T + 0.2, 5.9), (x + 0.3, T + 0.8, 6.7), col('#FFD89A', 3.0))
        g.box((x - 0.4, T + 0.1, 6.7), (x + 0.4, T + 0.9, 6.9), col('#2F3A4A'))
    put(p, g, 'front')
    put(p, pane, 'front', part='pane')
    # planters along the foot of the wall, outside, either side of the door
    body = p.part('body')
    yo = D0 - 0.4  # the wall's outside face lands on the 0.4 grid at -3.2
    for x0, x1 in ((W0 + 1.2, DOOR[0] - 2.4), (DOOR[1] + 2.4, W1 - 1.2)):
        body.box((x0, yo - 1.0, 0), (x1, yo, 1.2), brick('#B5553C', '#A24A34'))
        body.box((x0 - 0.05, yo - 1.08, 1.2), (x1 + 0.05, yo, 1.4), C(o['trim']))
        leaf = pick(['#3E9A3A', '#55B947', '#4DB043'], 74)
        body.fill((x0 + 0.1, yo - 0.9, 1.4), (x1 - 0.1, yo - 0.1, 2.3),
                  lambda X, Y, Z: Z < 1.55 + 0.6 * (0.5 + 0.5 * np.sin(X * 2.3) * np.sin(Y * 6.1 + X)), leaf)
        fl = [col(h) for h in ('#E8413C', '#FF6FA8', '#FFD166')]
        for k in range(int((x1 - x0) / 0.9)):
            body.ell((x0 + 0.45 + k * 0.9, yo - 0.7 + 0.35 * (k % 2), 2.0 + 0.1 * (k % 3)), (0.18, 0.18, 0.14), fl[k % 3])
    # striped awning over the door, clear of the wall's outside face
    a = p.part('awning', anim='sway', parent='body', pivot=(0, yo, H - 0.2))
    red, cream = fam('#D9534F', '#FFF4E0')
    a.fill((-6, yo - 2.6, H - 2.2), (6, yo, H), lambda X, Y, Z: Z > H - 0.2 + (Y - yo) * 0.62,
           lambda X, Y, Z: np.where(np.mod(X + 6, 2.0) < 1.0, red, cream))
    a.carve((-6, yo - 2.6, H - 2.2), (6, yo, H), lambda X, Y, Z: Z > H + (Y - yo) * 0.62)
    a.fill((-6, yo - 2.7, H - 2.6), (6, yo - 2.4, H - 1.6),
           lambda X, Y, Z: Z > H - 2.6 + 0.35 * (np.mod(X + 6, 1.0) < 0.5), lambda X, Y, Z: np.where(np.mod(X + 6, 2.0) < 1.0, red, cream))
    for x in (-5.8, 5.6):
        a.box((x, yo - 2.55, H - 1.8), (x + 0.2, yo, H - 1.6), col('#2F3A4A'))
    p.anchor = (0, 0, 0)


def front_wall(p, n):
    """floors 2-10: the front wall with four big windows"""
    wins = FRONT_WINDOWS
    if n == 9:
        wins = [(c, 4.4) for c, _ in wins]
    pane = WallGrid((W0, INNER, 0), (W1, OUTER, H + 0.3))
    g = wall(n, W0, W1, wins, pane=pane)
    put(p, g, 'front')
    put(p, pane, 'front', part='pane')
    p.anchor = (0, 0, 0)


def _front_prop(n):
    def fn(p):
        if n == 1:
            return front_one(p)
        front_wall(p, n)
    lo = (W0 - 0.4, IN_FRONT - OUTER - (3.2 if n == 1 else 0.0), 0)
    hi = (W1 + 0.4, IN_FRONT - INNER, H + 0.3)
    what = (f'{LOOK[n]} outside, {THEMES[n - 1].lower()} inside; two big windows, the front door (x -4.5..4.5), '
            'lanterns, planters and a striped awning (part "awning")') if n == 1 else \
        f'{LOOK[n]} outside, {THEMES[n - 1].lower()} inside; four big windows'
    prop(f'TowerFront{n}', 'tower', lo, hi, budget=260, floor=n, factors=(4,),
         note=f'front wall of floor {n}: {what}; window glass is part "pane" (drawn see-through). '
              'Anchor: base centre at this floor\'s walking height.')(fn)


for _n in range(1, 11):
    _floor_prop(_n)
    for _w in ('Back', 'Left', 'Right'):
        _wall_prop(_n, _w)
    _front_prop(_n)


# -------------------------------------------------------------------- roof
@prop('TowerRoof', 'tower', (W0 - 0.4, D0 - 0.4, -0.6), (W1 + 0.4, D1 + 0.4, 14.0), budget=260,
      note='roof over floor 10: gold-trimmed parapet, slate mansard, a golden dome with a glowing star and two corner turrets. '
           'Place it like a floor 11 (anchor at base centre, 10 floors above floor 1).')
def _roof(p):
    g = p.part('body')
    gold, gold_d = col('#F4C542'), col('#D9A92E')
    white = pick(['#FFF8EC', '#F6EEDD'], 81)
    slate = pick(['#4A5A8A', '#43527F', '#52639A'], 82)
    g.box((W0, D0, -0.6), (W1, D1, 0), white)
    g.box((W0 - 0.3, D0 - 0.3, -0.6), (W1 + 0.3, D1 + 0.3, -0.3), gold)
    # mansard roof: slopes in from the edge, flat deck on top
    inset, rh = 4.0, 3.2

    def mans(X, Y, Z):
        d = np.minimum(np.minimum(X - W0, W1 - X), np.minimum(Y - D0, D1 - Y))
        return Z < d / inset * rh
    g.fill((W0, D0, 0), (W1, D1, rh), mans, slate)
    g.paint((W0, D0, 0), (W1, D1, rh), lambda X, Y, Z: np.mod(Z, 0.8) < VOX, col('#3A4870', of=col('#4A5A8A')))
    g.box((W0 + inset, D0 + inset, rh - 0.3), (W1 - inset, D1 - inset, rh), white)
    # dormers with round windows along the front
    for x in (-14.0, 0.0, 14.0):
        g.box((x - 1.6, D0 + 0.4, 0), (x + 1.6, D0 + 3.0, 2.6), white)
        g.fill((x - 1.9, D0 + 0.2, 2.6), (x + 1.9, D0 + 3.2, 4.0), lambda X, Y, Z, x=x: Z - 2.6 < 1.4 - np.abs(X - x) * 0.74, slate)
        g.fill((x - 0.8, D0 + 0.25, 0.6), (x + 0.8, D0 + 0.5, 2.2), lambda X, Y, Z, x=x: (X - x) ** 2 + (Z - 1.4) ** 2 < 0.72 ** 2, gold)
        g.fill((x - 0.8, D0 + 0.2, 0.6), (x + 0.8, D0 + 0.6, 2.2), lambda X, Y, Z, x=x: (X - x) ** 2 + (Z - 1.4) ** 2 < 0.5 ** 2,
               col('#FFD89A', 2.0))
    # parapet posts with gold caps
    for x in np.arange(W0, W1 + 0.01, 6.0):
        for y in (D0, D1):
            g.box((x - 0.35, y - 0.35, 0), (x + 0.35, y + 0.35, 1.2), white)
            g.ell((x, y, 1.35), (0.3, 0.3, 0.3), gold)
    # golden dome with a glowing star on a spire
    cx, cy, zb = 0.0, 10.0, rh
    g.cyl(cx, cy, zb, zb + 1.2, 4.6, white)
    g.cyl(cx, cy, zb + 1.0, zb + 1.3, 4.8, gold)
    g.ell((cx, cy, zb + 1.3), (4.4, 4.4, 4.8), pick(['#F4C542', '#FFD45E', '#E8B838'], 83), cond=lambda X, Y, Z: Z >= zb + 1.3)
    for k in range(8):
        a = k * math.pi / 4
        g.seg((cx + math.cos(a) * 4.4, cy + math.sin(a) * 4.4, zb + 1.3), (cx + math.cos(a) * 0.4, cy + math.sin(a) * 0.4, zb + 6.1),
              0.12, gold_d)
    g.cyl(cx, cy, zb + 6.0, zb + 7.4, 0.2, gold_d)
    st = p.part('star', anim='spin', parent='body', pivot=(cx, cy, zb + 8.1))

    def star(X, Y, Z):
        a = np.arctan2(Z - (zb + 8.1), X - cx)
        r = np.hypot(X - cx, Z - (zb + 8.1))
        return (r < 0.45 + 0.45 * np.abs(np.cos(2.5 * a)) ** 3) & (np.abs(Y - cy) < 0.2)
    st.fill((cx - 1, cy - 0.3, zb + 7.1), (cx + 1, cy + 0.3, zb + 9.1), star, col('#FFE58A', 3.5))
    # two little turrets at the front corners
    for x in (W0 + 2.2, W1 - 2.2):
        y = D0 + 2.2
        g.cyl(x, y, 0, 5.0, 1.6, white)
        g.cyl(x, y, 4.6, 5.0, 1.8, gold)
        g.cyl(x, y, 5.0, 8.4, 1.8, slate, r1=0.1)
        for k in range(4):
            a = k * math.pi / 2 + math.pi / 4
            g.fill((x + math.cos(a) * 1.7 - 0.4, y + math.sin(a) * 1.7 - 0.4, 2.4), (x + math.cos(a) * 1.7 + 0.4, y + math.sin(a) * 1.7 + 0.4, 3.6),
                   None, col('#FFD89A', 2.0))
        g.ell((x, y, 8.6), (0.3, 0.3, 0.3), gold)
    # chimney at the back
    g.box((14.0, 18.0, 0), (16.0, 20.0, 5.6), brick('#B5553C', '#A24A34'))
    g.box((13.8, 17.8, 5.6), (16.2, 20.2, 6.0), white)
    p.anchor = (0, 0, 0)
