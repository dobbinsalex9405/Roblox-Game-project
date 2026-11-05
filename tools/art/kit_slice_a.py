"""Accessories for the Uncommon slice A creatures that the shared kits do
not cover. Owner: the Common A builder.

- **ape_arms**: takes off the cub's short arms and draws long ape arms in
  color, with hands in color2 (default a darker shade). `style`:
  `long` hangs them down to the knuckles near the floor (orangutan);
  `raised` swings them up and out over the head (gibbon). `r` scales the
  arm's thickness (default 1.0).

- **puffer**: turns kit_myth's goldfish into a pufferfish: the fancy veil
  tail and tall sail fin give way to a small fan tail and a low fin, in
  color (fins) and color2 (fin edges), so the round spiky ball reads.

The arms stay in the body part, like the kit's own, so they ride the
body's walk; the legs keep their own parts. Same frame as kit.py: x right,
-y front, z up, feet at z = 0, k = H / 10."""

import kit_myth as myth


def _find(c, name):
    for p in c.parts:
        if p.name == name:
            return p
    return None


def ape_arms(c, H, col, col2=None, a=None):
    a = a or {}
    k = H / 10.0
    body, head = _find(c, 'body'), _find(c, 'head')
    if body is None or head is None or not body.v:
        return
    # the cub's torso is an ellipse 1.6k wide at the waist; its arms are the
    # body voxels outside it
    half = 1.6 * k
    for p in [p for p in body.v if abs(p[0] + .5) > half + 0.6]:
        del body.v[p]
    hand = col2 if col2 is not None else myth.dark(col, 0.3)
    zs = [p[2] for p in body.v]
    zlo, zhi = min(zs), max(zs)
    shoulder = zlo + (zhi - zlo) * 0.8
    hz = max(p[2] for p in head.v)
    r = 0.5 * k * a.get('r', 1.0)
    for side in (1, -1):
        sx = side * (half + 0.2 * k)
        if a.get('style', 'long') == 'raised':
            # up and out, a little forward: a gibbon cheering
            elbow = (side * (half + 1.0 * k), -0.2 * k, shoulder + 1.2 * k)
            tip = (side * (half + 1.3 * k), -0.4 * k, hz + 0.9 * k)
        else:
            # down past the knees, knuckles just off the floor
            elbow = (side * (half + 0.9 * k), -0.2 * k, shoulder - 1.6 * k)
            tip = (side * (half + 1.0 * k), -0.6 * k, 0.7 * k)
        pts = myth.curve((sx, 0, shoulder), elbow, 6, (0, 0, 0)) + myth.curve(elbow, tip, 7, (0, 0, 0))[1:]
        for i, (x, y, z) in enumerate(pts):
            rr = r * (1.0 + 0.15 * (i / len(pts)))
            body.ell((x - (0.5 if side < 0 else 0), y, z), (rr, rr, rr), col)
        x, y, z = tip
        body.ell((x - (0.5 if side < 0 else 0), y, z), (r * 1.3, r * 1.3, r * 1.2), hand)


def puffer(c, H, col, col2=None, a=None):
    k = H / 10.0 * 1.4  # kit_myth draws fish 1.4x bigger
    tail = _find(c, 'tail')
    if tail is not None:
        root = tail.pivot
        c.parts.remove(tail)
        myth.fish_tail(c, k, root, 1.0, 0.8, col, col2, fork=0.25, veil=False)
    df = _find(c, 'dorsal')
    body = _find(c, 'body')
    if df is not None and body is not None and body.v:
        c.parts.remove(df)
        top = max(p[2] for p in body.v)
        ys = [p[1] for p in body.v if p[2] >= top - 1]
        myth.sail(c.part('dorsal', 'static'), 0, min(ys) + 0.2 * k, top, 1.2 * k, 0.7 * k, col,
                  edge=col2 or myth.light(col, 0.3), lean=0.6)


def eye_bridge(c, H, col, col2=None, a=None):
    """Splits two big eyes, or an eye mask, that meet over the nose into
    two (a tarsier's, a loris's, a kookaburra's): a strip `width` (in k,
    default 0.6) down the middle of the face, from below the eyes to above
    them, goes back to fur in `col`. Big dark eyes joined across the nose
    read as sunglasses at 2 studs."""
    a = a or {}
    k = H / 10.0 * (1.4 if c.rarity in ('Godly',) else 1.0)
    head = _find(c, 'head')
    e = _find(c, 'eyes')
    if not head or not head.v or not e or not e.v:
        return
    w = a.get('width', 0.6) * k
    zs = [p[2] for p in e.v]
    z0, z1 = min(zs) - 1, max(zs) + 1
    for p in [p for p in e.v if abs(p[0] + .5) < w]:
        del e.v[p]
        head.put(p, col)
    for x in {p[0] for p in head.v if abs(p[0] + .5) < w}:
        for z in range(z0, z1 + 1):
            f = head.front(x, z)
            if f:
                head.put(f, col)
    # an eye that lost its shine to the bridge gets it back, in its upper
    # inner corner
    WHITE = (255, 255, 255)
    for side in (-1, 1):
        ev = [p for p in e.v if (p[0] >= 0) == (side > 0)]
        if len(ev) >= 4 and not any(e.v[p][0] == WHITE for p in ev):
            zt = max(p[2] for p in ev)
            p = min((p for p in ev if p[2] >= zt - 1), key=lambda p: (abs(p[0] + .5), -p[2]))
            e.put(p, WHITE)


ACCESSORIES = {'ape_arms': ape_arms, 'puffer': puffer, 'eye_bridge': eye_bridge}
