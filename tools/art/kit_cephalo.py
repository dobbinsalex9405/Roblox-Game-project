"""The last two Uncommons, a squid and a cuttlefish: plan `cephalopod`
(options.kind `squid` or `cuttlefish`). Owner: the Common A builder.

- **squid** stands on its arms like kit_wild's octopus, but its mantle is
  a tall bullet with a diamond fin at the top, its eyes are big and sit low
  on the mantle, its eight arms are short and the front pair are the two
  long feeding tentacles with paddle-shaped clubs. It walks (scuttle).

- **cuttlefish** swims level: a broad oval mantle with rippling colour
  bands across the back, a wavy fin skirt down both sides (finL/finR, which
  ripple as it swims), a pale belly, big pale-gold eyes with a dark W pupil
  standing out from the sides of the head and a bunch of eight pale pink
  arms pointing forward.

Colours: col (body), accent (the squid's freckles, the cuttlefish's bands)
and belly (undersides, suckers and the cuttlefish's fin edge).
No glow (Uncommon). Same frame as kit.py: x right, -y front, z up, feet at
z = 0, k = H / 10."""

import math

import kit
import kit_pond
import rig
from voxkit import hexc

_dark, _mix, face = kit_pond._dark, kit_pond._mix, kit_pond.face
WHITE = (255, 255, 255)


def _light(col, t=0.35):
    return _mix(col, WHITE, t)


def _leg(c, sx, i, n, hip):
    return rig.leg_part(c, 'L' if sx < 0 else 'R', i, n, hip)


def _mx(x):
    return -x - 1


def _mirror(part):
    """Copies the right half (x >= 0) onto the left, exactly."""
    for (x, y, z), v in [(p, v) for p, v in part.v.items() if p[0] >= 0]:
        part.v[(_mx(x), y, z)] = v


# ------------------------------------------------------------------- squid

def squid(c, H, col, accent, belly):
    k = H / 10.0
    body = c.part('body')
    # the skirt the arms hang from
    body.ell((0, 0.3 * k, 2.7 * k), (1.8 * k, 1.8 * k, 1.0 * k), col)
    # the mantle (it carries the face): a round base under a tall bullet
    # that leans back a little, built on the right and mirrored
    mantle = c.part('head', 'static', (0, 0.4 * k, 3.6 * k))
    mantle.ell((0, 0.4 * k, 4.4 * k), (2.0 * k, 1.9 * k, 1.6 * k), col, cond=lambda x, y, z: x >= 0)
    z0, z1 = 4.4 * k, 9.6 * k
    for z in range(math.floor(z0), math.ceil(z1)):
        t = min(0.999, max(0.0, (z + .5 - z0) / (z1 - z0)))
        r = 2.0 * k * (1 - t) ** 0.75 + 0.35 * k * (1 - t)
        cy = 0.4 * k + 0.35 * k * t
        if r < 0.6:
            continue
        mantle.ell((0, cy, z + .5), (r, r * 0.95, 0.5), col, cond=lambda x, y, zz: x >= 0)
    # the fin: a flat diamond each side of the top of the mantle, two
    # voxels thick, a shade darker at the edge
    fz0, fz1, fw = 6.6 * k, 9.9 * k, 2.2 * k
    edge = _dark(col, 0.12)
    for z in range(math.floor(fz0), math.ceil(fz1)):
        t = (z + .5 - fz0) / (fz1 - fz0)
        cy = 0.4 * k + 0.35 * k * min(1.0, (z + .5 - z0) / (z1 - z0))
        half = 2.0 * k * max(0.0, 1 - min(1.0, (z + .5 - z0) / (z1 - z0))) ** 0.75
        out = fw * (1 - abs(2 * t - 1.2)) if t < 0.6 else fw * (1 - (t - 0.6) / 0.4) * 0.8 + 0.2 * fw
        out = max(0.0, out)
        x1 = math.floor(half + out)
        for x in range(math.floor(half) - 1, x1 + 1):
            for y in (math.floor(cy), math.floor(cy) + 1):
                if x >= 0:
                    mantle.put((x, y, z), edge if x >= x1 - 1 else col)
    _mirror(mantle)
    # freckles: single accent dots scattered over the upper and back of the
    # mantle (never in rows across the face), never glowing
    def freckle(p, cc, g):
        x, y, z = p
        if cc != col or x < 0 or z < 5.4 * k or (y < 0.6 * k and z < 7.6 * k):
            return None
        return (accent, False) if kit._hash(x, y, z, 5) % 8 == 0 else None
    mantle.paint(freckle)
    _mirror(mantle)
    # big eyes low on the mantle
    face(c, mantle, k, 4.4, x_off=0.8, size=0.75, cheek_z=3.8, cheek_x=1.6)
    # eight arms, four a side: three short pairs that curl up at the tip,
    # and the front pair, the feeding tentacles, longer, ending in a club
    for i, (ang, reach, club) in enumerate(((22, 3.9, True), (62, 2.3, False), (110, 2.2, False), (152, 2.3, False))):
        a = math.radians(ang)
        ox, oy = math.sin(a), -math.cos(a)
        r0 = 1.3 * k
        pts = []
        n = 12
        for j in range(n + 1):
            t = j / n
            rr = r0 + reach * k * t
            z = 2.4 * k * (1 - t) ** 1.5 + 0.35 * k
            if not club and t > 0.75:
                rr -= (t - 0.75) * 1.6 * k
                z += (t - 0.75) * 3.2 * k
            w = (0.55 - 0.3 * t) * k
            if club and t > 0.78:
                w = 0.5 * k  # the paddle at the end of the tentacle
            pts.append((ox * rr, 0.3 * k + oy * rr, z, w))
        hip = (round(ox * r0) + .5, round(0.3 * k + oy * r0) + .5, round(2.4 * k) + 1)
        cells = {}
        for j, (x, y, z, w) in enumerate(pts):
            rr = max(w, .7)
            for xx in range(math.floor(x - rr), math.ceil(x + rr) + 1):
                for yy in range(math.floor(y - rr), math.ceil(y + rr) + 1):
                    for zz in range(math.floor(z - rr), math.ceil(z + rr) + 1):
                        if ((xx + .5 - x) ** 2 + (yy + .5 - y) ** 2 + (zz + .5 - z) ** 2) <= rr * rr and zz >= 0:
                            cells[(xx, yy, zz)] = j
        for sx in (1, -1):
            leg = _leg(c, sx, i, 4, hip if sx > 0 else (-hip[0], hip[1], hip[2]))
            for (x, y, z), j in cells.items():
                cc = col
                # pale suckers on the underside of the club and arm tips
                if z == min(q[2] for q, jj in cells.items() if jj == j) and j >= (9 if club else 6):
                    cc = belly
                leg.v[(x if sx > 0 else _mx(x), y, z)] = (cc, False)
    return c


# -------------------------------------------------------------- cuttlefish

def cuttlefish(c, H, col, accent, belly):
    # a cuttlefish is long and low, so (like kit_myth's manta) it is drawn
    # at a larger scale than its height alone would give
    k = H / 10.0 * 1.25
    cz = 2.3 * k
    body = c.part('body')
    # a broad oval mantle, longest front to back, a little domed on top
    body.ell((0, 0.6 * k, cz), (1.9 * k, 3.0 * k, 1.45 * k), col)
    # rippling colour bands across the back: each band wavers side to side
    def band(p, cc, g):
        x, y, z = p
        if z + .5 < cz - 0.25 * k:
            return (belly, False)
        ax = abs(x + .5)
        wob = 0.45 * k * math.sin(ax / (1.3 * k) * math.pi)
        return (accent, False) if math.floor((y + .5 + wob) / (0.7 * k)) % 2 == 0 and y + .5 > -0.7 * k else None
    body.paint(band)
    # the head at the front, as tall as the mantle, its eyes high up
    head = c.part('head', 'head', (0, -2.0 * k, cz))
    head.ell((0, -2.4 * k, cz + 0.05 * k), (1.6 * k, 1.3 * k, 1.3 * k), col)
    head.paint(lambda p, cc, g: (belly, False) if p[2] + .5 < cz - 0.3 * k else None)
    # big pale-gold eyes on the sides of the head, 3 long and 2 tall, one
    # voxel proud of the surface, with a dark W-shaped pupil (dark low at
    # both ends and high in the middle), so each eye is a light shape on
    # the brown and needs no ring; they blink
    eyes = c.part('eyes', 'blink', head.pivot)
    gold, ink = hexc('#F4D77A'), hexc('#1B1B2F')
    ez = math.floor(cz + 0.35 * k)
    ey = math.floor(-2.7 * k)
    for (dy, dz), cc in (((0, 1), gold), ((1, 1), ink), ((2, 1), gold),
                         ((0, 0), ink), ((1, 0), gold), ((2, 0), ink)):
        y, z = ey + dy, ez + dz
        xs = [q[0] for q in head.v if q[1] == y and q[2] == z and q[0] >= 0]
        if not xs:
            continue
        x = max(xs) + 1
        eyes.put((x, y, z), cc)
        eyes.put((_mx(x), y, z), cc)
    # eight short arms bunched forward under the eyes, three a side and two
    # in the middle, the tips drooping and drawn together, paler at the end
    arms = c.part('arms', 'static', (0, -3.4 * k, cz - 0.3 * k))
    pink, tip = hexc('#F0BFC2'), hexc('#FBE3E4')
    for ax, ln in ((0.3, 1.0), (0.85, 0.9), (1.3, 0.75)):
        for j in range(10):
            t = j / 9
            x = ax * k * (1 - 0.35 * t)
            y = -3.4 * k - 2.6 * k * ln * t
            z = cz - 0.2 * k - 0.9 * k * t * t
            r = (0.34 - 0.1 * t) * k
            arms.ell((x, y, z), (max(r, .6), max(r, .6), max(r, .6)), tip if t > 0.7 else pink, cond=lambda xx, yy, zz: xx >= 0)
    _mirror(arms)
    # the fin skirt: a wavy frill down each side of the mantle, two voxels
    # deep, in two parts (finL/finR) that ripple as it swims; pale at the edge
    for sx, name in ((1, 'finR'), (-1, 'finL')):
        fin = c.part(name, name, (sx * 1.7 * k, 0.6 * k, cz - 0.2 * k))
        for y in range(math.floor(-1.9 * k), math.ceil(3.3 * k)):
            u = (y + .5 - 0.6 * k) / (3.0 * k)
            if abs(u) >= 0.97:
                continue
            half = 1.9 * k * math.sqrt(1 - u * u)  # the mantle's edge here
            width = 0.8 * k * (1 - abs(u) ** 4)
            wave = round(0.2 * k * math.sin((y + .5) / (0.8 * k) * math.pi))
            z = math.floor(cz - 0.3 * k) + wave
            x0 = math.floor(half) - 1
            x1 = math.floor(half + width)
            for x in range(x0, x1 + 1):
                cc = belly if x >= x1 else _light(col, 0.2)
                for dz in (0, 1):
                    fin.put((x if sx > 0 else _mx(x), y, z + dz), cc)
    return c


PLANS = {'cephalopod': ({'col', 'accent', 'belly'}, {'kind': {'squid', 'cuttlefish'}})}


def _build(c, H, cols, opts):
    col = cols['col']
    accent = cols.get('accent') or _dark(col, 0.3)
    belly = cols.get('belly') or _light(col, 0.4)
    if opts.get('kind') == 'cuttlefish':
        return cuttlefish(c, H, col, accent, belly)
    return squid(c, H, col, accent, belly)


BUILDERS = {'cephalopod': _build}
