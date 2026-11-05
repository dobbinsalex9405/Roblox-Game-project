"""Extra accessories for roster entries (see variants.py), beside the ones in
kit.accessory:

- **ridge**: a row of spikes down the middle of the back, like a hedgehog's
  or a little dragon's (color; color2 tips the spikes).
- **third_eye**: a third eye in the middle of the forehead (color is its
  ring; it blinks with the other two).
- **butter**: a pat of butter on top of the head (color; color2 is the
  shine on top).
- **twin_tail**: the tail split into two that fork apart (color tints the
  tips; the tails keep their own colour).

Each is fn(c, H, color, color2, a) (variants.py's kit hook): colours are RGB
tuples, color2 may be None, `a` is the roster entry's accessory dict.
Same art frame as kit.py (x right, y back, front is -y, z up), k = H / 10."""
import math

from voxkit import hexc

INK, WHITE = hexc('#1B1B2F'), hexc('#FFFFFF')


def _rgb(col, default=None):
    if col is None:
        return default
    return hexc(col) if isinstance(col, str) else col


def _find(c, name):
    return next((p for p in c.parts if p.name == name), None)


def ridge(c, H, color, color2=None, a=None):
    """Spikes along the back's midline, from behind the head to the tail."""
    k = H / 10.0
    col = _rgb(color)
    tip = _rgb(color2, col)
    body = _find(c, 'body')
    head = _find(c, 'head')
    if body is None or not body.v:
        return
    sp = c.part('ridge', 'static')
    # from the crown of the head down the back to the tail: the top of the
    # head and body together, along the midline
    solid = set(body.v) | (set(head.v) if head is not None else set())
    if head is not None and head.v:
        hy = [p[1] for p in head.v]
        y_front = (min(hy) + max(hy)) / 2
    else:
        ys = [p[1] for p in body.v]
        y_front = min(ys) + (max(ys) - min(ys)) * 0.2
    step = max(2, round(0.7 * k))
    height = max(2, round(0.9 * k))
    tops = {}
    for (x, y, z) in solid:
        if x in (-1, 0) and y >= y_front:
            tops[(x, y)] = max(z, tops.get((x, y), z))
    for (x, y), z in sorted(tops.items()):
        if (y - math.ceil(y_front)) % step:
            continue
        # the spike leans back as it rises; it is two voxels wide at the root
        for i in range(height):
            if i == 0 or x == 0 or i < height - 1:
                sp.put((x, y + (i * 2 // height), z + 1 + i), tip if i == height - 1 else col)


def third_eye(c, H, color, color2=None, a=None):
    """A third eye on the forehead, above and between the other two."""
    k = H / 10.0
    ring = _rgb(color)
    head = _find(c, 'head')
    eyes = _find(c, 'eyes')
    if head is None or eyes is None or not eyes.v:
        return
    ez = max(p[2] for p in eyes.v)
    s = max(1, round(0.5 * k))
    z0 = ez + max(1, round(0.4 * k))
    # find the forehead: the highest row at the centre that still has face
    zs = [z for z in range(z0 + 3 * s, ez - 3 * s - 2, -1) if head.front(0, z) and head.front(-1, z)]
    if not zs:
        return
    zc = min(zs[0] - s, z0)  # under the top of the face, a little above the eyes if it fits
    for x in range(-s - 1, s + 1):
        for z in range(zc - 1, zc + max(2, s) + 1):
            f = head.front(x, z)
            if not f:
                continue
            inner = -s <= x < s and zc <= z < zc + max(2, s)
            if inner:
                del head.v[f]
                shine = z == zc + max(2, s) - 1 and x == -s
                eyes.put(f, WHITE if shine else INK)
            else:
                head.put(f, ring)


def butter(c, H, color, color2=None, a=None):
    """A flat square pat of butter sitting on the crown."""
    k = H / 10.0
    col = _rgb(color)
    top = _rgb(color2, tuple(min(255, round(v + (255 - v) * 0.45)) for v in col))
    head = _find(c, 'head') or _find(c, 'body')
    zt = max(p[2] for p in head.v)
    crown = [p for p in head.v if p[2] >= zt - 1]
    y = round(sum(p[1] for p in crown) / len(crown))
    pat = c.part('butter', 'static')
    w = max(1, round(0.8 * k))
    h = max(1, round(0.45 * k))
    for x in range(-w, w):
        for yy in range(y - w, y + w):
            for z in range(zt + 1, zt + 1 + h):
                pat.put((x, yy, z), top if z == zt + h else col)
    # a drip down one side
    for i in range(max(1, round(0.5 * k))):
        pat.put((w - 1, y - w, zt - i), col)


def twin_tail(c, H, color, color2=None, a=None):
    """Splits the tail into two that fork apart, left and right."""
    k = H / 10.0
    tip = _rgb(color)
    tail = _find(c, 'tail')
    if tail is None or not tail.v:
        return
    ys = [p[1] for p in tail.v]
    y0, y1 = min(ys), max(ys)
    span = max(1, y1 - y0)
    spread = max(1.0, 1.2 * k)
    out = {}
    for (x, y, z), v in tail.v.items():
        t = (y - y0) / span
        dx = round(spread * (0.4 + t))
        for sx in (-1, 1):
            xx = x + dx if sx > 0 else -(x + dx) - 1  # mirrored (cells are [x, x+1))
            col = (tip, False) if t > 0.8 else v
            out[(xx, y, z)] = col
    tail.v = out


ACCESSORIES = {'ridge': ridge, 'third_eye': third_eye, 'butter': butter, 'twin_tail': twin_tail}
