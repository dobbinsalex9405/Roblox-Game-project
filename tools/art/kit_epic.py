"""Plans for the Epic batch built by the Rare builder (see variants.py for how
kit modules plug in). Epics stand at 3 studs on a pad and may glow; each
carries one clear glowing feature of its own.

- **epicbiped**: a chibi figure that stands on two legs like a person
  (`legL`/`legR`, waddle; the sprites hover). Kinds: gnome (mushroom-cap
  hat, beard), troll (moss hair, big nose), imp (horns, flame tail), ent
  (bark body, leaf crown, branch arms), yeti (shaggy white, blue face,
  snowball), golem (gingerbread, icing trim, gumdrop buttons), frost (ice
  fairy, crystal wings), petal (flower fairy, petal skirt and wings).
  Colours: col (body), skin (head), belly, accent, feet, glow.
- **epicdrake**: a four-legged drake hatchling that trots. Kinds: rime
  (frost-white, icicle spines, small wings), bonsai (a bonsai tree on its
  back). Colours: col, belly, accent, glow.

Same art frame and scale as every kit: x right, y back (front is -y), z up,
k = H / 10. Everything is drawn on the right (x >= 0) or centred, and
mirrored exactly onto the left."""
import math

from voxkit import hexc
import kit_pond
import rig

INK, WHITE = hexc('#1B1B2F'), hexc('#FFFFFF')
_dark, _mix, line, face = kit_pond._dark, kit_pond._mix, kit_pond.line, kit_pond.face


def _light(col, t=0.35):
    return _mix(col, WHITE, t)


def _mx(x):
    return -x - 1


def _mirror(part, pred=None):
    """Copies the right half (x >= 0) onto the left exactly."""
    right = {p: v for p, v in part.v.items() if p[0] >= 0 and (pred is None or pred(p))}
    for (x, y, z), v in right.items():
        part.v[(_mx(x), y, z)] = v


def _sym_put(part, p, col, glow=False):
    part.put(p, col, glow)
    part.put((_mx(p[0]), p[1], p[2]), col, glow)


def _fine(c):
    return getattr(c, 'fine', False)


# ------------------------------------------------------------------ biped

def _biped(c, H, col, skin, belly=None, feet=None, *, hip=1.8, body_r=(1.85, 1.5, 1.75), body_z=3.5,
           head_r=(2.3, 2.0, 2.0), head_z=6.7, leg_w=0.5, leg_x=0.85, arm=True, eye_z=6.5, eye_x=0.7,
           eye_size=0.85, cheeks=True):
    """The shared figure: body, two legs (own parts), a big head with its
    face, and two short arms (static, riding the body). Returns the parts
    (body, head, arms)."""
    k = H / 10.0
    feet = feet or _dark(col, 0.25)
    body = c.part('body')
    body.ell((0, 0, body_z * k), (body_r[0] * k, body_r[1] * k, body_r[2] * k), col)
    if belly:
        body.paint(lambda p, cc, g: (belly, False) if p[1] < -0.55 * body_r[1] * k and abs(p[0] + .5) < 1.05 * k
                   and p[2] < (body_z + 1.0) * k else None)
    for side, sx in (('L', -1), ('R', 1)):
        leg = rig.leg_part(c, side, 0, 1, (sx * leg_x * k, 0, hip * k))
        right = c.part('_legtmp')
        right.ell((leg_x * k, 0, hip * k * 0.55), (leg_w * k + .3, leg_w * k + .3, hip * k * 0.6), col)
        right.ell((leg_x * k, -0.3 * k, 0.35 * k), (leg_w * k + .5, (leg_w + 0.45) * k, 0.45 * k), feet,
                  cond=lambda x, y, z: z >= 0)
        for (x, y, z), v in right.v.items():
            leg.v[(x if sx > 0 else _mx(x), y, z)] = v
        c.parts.remove(right)
    head = c.part('head', 'head', (0, 0, (body_z + body_r[2] * 0.8) * k))
    head.ell((0, -0.25 * k, head_z * k), (head_r[0] * k, head_r[1] * k, head_r[2] * k), skin)
    arms = None
    if arm:
        arms = c.part('arms', 'static')
        arms.ell((1.75 * k, -0.2 * k, (body_z + 0.3) * k), (0.55 * k, 0.55 * k, 0.95 * k), col)
        arms.ell((1.95 * k, -0.35 * k, (body_z - 0.65) * k), (0.6 * k, 0.6 * k, 0.55 * k), skin)
        _mirror(arms)
    face(c, head, k, eye_z, x_off=eye_x, size=eye_size, cheeks=cheeks)
    return body, head, arms


def _gnome(c, H, cols):
    k = H / 10.0
    skin = cols.get('skin', hexc('#F6C9A8'))
    beard = cols.get('belly', hexc('#F4F1EA'))
    cap = cols.get('accent', hexc('#E0402F'))
    glow = cols.get('glow', hexc('#FFF6D8'))
    body, head, arms = _biped(c, H, cols['col'], skin, None, cols.get('feet', hexc('#6B4A2E')),
                              head_r=(2.0, 1.8, 1.8), head_z=6.3, eye_z=6.3, eye_size=0.75)
    # a round nose
    head.ell((0, -2.0 * k, 5.9 * k), (0.55 * k, 0.5 * k, 0.5 * k), _mix(skin, hexc('#FF8A7A'), 0.4))
    # a big beard over the chest and the lower face
    beardp = c.part('beard', 'static')
    beardp.ell((0, -1.25 * k, 4.7 * k), (1.7 * k, 1.0 * k, 1.5 * k), beard,
               cond=lambda x, y, z: z <= round(5.6 * k))
    beardp.ell((0, -1.4 * k, 3.4 * k), (1.0 * k, 0.8 * k, 0.9 * k), beard)
    if _fine(c):  # texture on the mesh build only (in-game box budget)
        beardp.paint(lambda p, cc, g: (_dark(beard, 0.08), False) if (p[0] + p[2]) % 3 == 0 else None)
    # a belt
    if _fine(c):
        body.paint(lambda p, cc, g: (hexc('#4A3220'), False) if round(2.5 * k) <= p[2] <= round(2.5 * k) + max(0, round(0.2 * k)) else None)
    # the mushroom-cap hat: a broad red dome over a pale band, white spots
    # that glow softly
    hat = c.part('hat', 'static')
    band_z = 7.65 * k
    if _fine(c):
        hat.ell((0, -0.2 * k, band_z), (1.75 * k, 1.6 * k, 0.6 * k), hexc('#F2E8D5'))
    hat.ell((0, -0.2 * k, band_z + 0.5 * k), (2.9 * k, 2.6 * k, 2.0 * k), cap, cond=lambda x, y, z: z >= round(band_z + 0.3 * k))
    if _fine(c):
        hat.paint(lambda p, cc, g: (_dark(cap, 0.25), False) if cc == cap and p[2] <= round(band_z + 0.5 * k) else None)
    # round white spots that glow softly, placed by direction from the
    # dome's centre so they stay round on the curve
    cen = (0, -0.2 * k, band_z + 0.5 * k)
    spots = [(270, 35), (215, 30), (325, 30), (180, 55), (0, 55), (90, 40), (130, 20), (50, 20), (270, 75)]
    if not _fine(c):
        spots = [(270, 40), (90, 55)]  # fewer, for the in-game boxes
    dirs = []
    for az, el in spots:
        a, e = math.radians(az), math.radians(el)
        dirs.append((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e)))

    def spot(p, cc, g):
        if cc != cap:
            return None
        v = (p[0] + .5 - cen[0], p[1] + .5 - cen[1], (p[2] + .5 - cen[2]) * 1.15)
        n = math.sqrt(sum(t * t for t in v)) or 1
        for d in dirs:
            for dd in (d, (-d[0], d[1], d[2])):
                if sum(a * b for a, b in zip(v, dd)) / n > 0.982:
                    return (glow, True)
        return None
    hat.paint(spot)
    return c


def _troll(c, H, cols):
    k = H / 10.0
    skin = cols.get('skin', cols['col'])
    moss = cols.get('accent', hexc('#3F7D3A'))
    glow = cols.get('glow', hexc('#C8FF7A'))
    body, head, arms = _biped(c, H, cols['col'], skin, cols.get('belly'), cols.get('feet'),
                              body_r=(2.0, 1.6, 1.8), head_r=(2.35, 1.9, 1.85), head_z=6.5, eye_z=6.6, eye_x=0.9,
                              eye_size=0.7)
    # a big round nose and two small tusks
    head.ell((0, -2.0 * k, 5.9 * k), (0.8 * k, 0.75 * k, 0.75 * k), _dark(skin, 0.08))
    for x in range(max(1, round(0.45 * k)), max(1, round(0.45 * k)) + max(1, round(0.3 * k))):
        for z in range(round(5.0 * k), round(5.0 * k) + max(2, round(0.45 * k))):
            f = head.front(x, z)
            if f:
                _sym_put(head, f, hexc('#FFF6E0'))
    # pointed ears sticking out sideways
    ears = c.part('ears', 'ears', (0, 0, 6.6 * k))
    for i in range(round(1.2 * k)):
        r = max(0.5, 0.55 * k - i * 0.35)
        ears.ell((2.2 * k + i, 0, 6.6 * k + i * 0.25), (0.5, r, r), skin)
    _mirror(ears)
    # moss hair: a lumpy cap of dark and light tufts, with two glowing
    # sprouts in it
    hair = c.part('hair', 'static')
    for ang in range(0, 360, 36):
        a = math.radians(ang)
        for ring, (rr, zz) in enumerate(((1.6, 8.0), (0.7, 8.5))):
            hair.ell((math.cos(a) * rr * k, math.sin(a) * rr * k + 0.15 * k, zz * k), (0.75 * k, 0.75 * k, 0.6 * k),
                     moss if (ang // 36 + ring) % 2 else _light(moss, 0.25))
    hair.ell((0, 0.4 * k, 7.6 * k), (2.1 * k, 1.8 * k, 0.8 * k), moss, cond=lambda x, y, z: y > -1.2 * k)
    _mirror(hair)
    sprout = c.part('sprouts', 'glow')
    for sx_, sy_ in ((0.9, -0.4),):
        x = round(sx_ * k)
        base = max((p[2] for p in hair.v if p[0] == x and p[1] == round(sy_ * k)), default=round(9 * k))
        for i in range(max(2, round(0.5 * k))):
            _sym_put(sprout, (x, round(sy_ * k), base + 1 + i), hexc('#6CBF4A'))
        cap_z = base + 1 + max(2, round(0.5 * k))
        sprout.ell((x + .5, sy_ * k + .5, cap_z), (0.36 * k + .2, 0.36 * k + .2, 0.34 * k + .3), glow, True)
        sprout.ell((_mx(x) + .5, sy_ * k + .5, cap_z), (0.36 * k + .2, 0.36 * k + .2, 0.34 * k + .3), glow, True)
    # a leaf loincloth
    body.paint(lambda p, cc, g: (hexc('#7A5A34'), False) if round(1.9 * k) <= p[2] <= round(2.5 * k) else None)
    return c


def _imp(c, H, cols):
    k = H / 10.0
    col = cols['col']
    glow = cols.get('glow', hexc('#FFB020'))
    body, head, arms = _biped(c, H, col, col, cols.get('belly', _light(col, 0.4)), cols.get('feet', _dark(col, 0.35)),
                              body_r=(1.6, 1.35, 1.6), body_z=3.3, head_r=(2.25, 1.95, 1.9), head_z=6.4, eye_z=6.4)
    # a little grin with two fangs
    for x in range(-max(1, round(0.5 * k)), max(1, round(0.5 * k))):
        f = head.front(x, round(5.4 * k))
        if f:
            head.put(f, INK)
    for x in (max(1, round(0.3 * k)) - 1,):
        f = head.front(x, round(5.4 * k) - 1)
        if f:
            _sym_put(head, f, WHITE)
    # curved horns
    horns = c.part('horns', 'static')
    for i in range(round(1.8 * k)):
        t = i / max(1, round(1.8 * k) - 1)
        r = max(0.5, (0.45 - 0.3 * t) * k)
        horns.ell((1.2 * k + t * 0.9 * k, -0.4 * k + t * 0.6 * k, 7.9 * k + t * 1.3 * k), (r, r, r), _dark(col, 0.65))
    _mirror(horns)
    # pointed ears
    ears = c.part('ears', 'ears', (0, 0, 6.6 * k))
    for i in range(round(1.0 * k)):
        r = max(0.5, 0.5 * k - i * 0.4)
        ears.ell((2.2 * k + i, 0.1 * k, 6.7 * k + i * 0.3), (0.5, r, r), col)
    _mirror(ears)
    # small bat wings on the back
    for side, sx in (('L', -1), ('R', 1)):
        w = c.part('wing' + side, 'wing' + side, (sx * 0.9 * k, 1.2 * k, 4.4 * k))
        tmp = c.part('_w')
        for i in range(round(1.8 * k)):
            top = 4.8 * k + i * 0.35
            bot = 3.6 * k + i * 0.55 + (0.5 * k if i % max(1, round(0.6 * k)) == 0 else 0)
            for z in range(round(bot), round(top) + 1):
                tmp.put((round(0.9 * k) + i, round(1.3 * k), z), _dark(col, 0.45))
        for (x, y, z), v in tmp.v.items():
            w.v[(x if sx > 0 else _mx(x), y, z)] = v
        c.parts.remove(tmp)
    # the flame tail: a thin tail curling up behind, ending in a flame
    tail = c.part('tail', 'tail', (0, 1.3 * k, 2.6 * k))
    pts = []
    for i in range(24):
        t = i / 23
        pts.append((t * t * 1.6 * k, 1.3 * k + t * 1.8 * k, 2.6 * k - math.sin(t * math.pi) * 0.4 * k + max(0, t - 0.4) * 5.0 * k))
    for x, y, z in pts:
        tail.ell((x, y, z), (0.25 * k + .3, 0.25 * k + .3, 0.25 * k + .3), col)
    fx, fy, fz = pts[-1]
    # a teardrop flame: orange outside, gold, a pale core
    for i, (r, cc) in enumerate(((0.95, glow), (0.62, hexc('#FFE070')), (0.34, hexc('#FFF6C8')))):
        tail.ell((fx, fy, fz + 0.5 * k), (r * k + .3, r * k + .3, r * 1.2 * k + .3), cc, True)
    tail.ell((fx, fy, fz + 1.7 * k), (0.45 * k + .3, 0.45 * k + .3, 0.75 * k + .3), glow, True)
    return c


def _ent(c, H, cols):
    k = H / 10.0
    bark = cols['col']
    leaf = cols.get('accent', hexc('#5DBB4A'))
    glow = cols.get('glow', hexc('#FFE27A'))
    body, head, arms = _biped(c, H, bark, bark, None, _dark(bark, 0.2), body_r=(1.7, 1.45, 2.0), body_z=3.6,
                              head_r=(1.95, 1.75, 1.9), head_z=6.5, arm=False, eye_z=6.4, eye_x=0.6, eye_size=0.75,
                              cheeks=False)
    # the bark: darker vertical grooves on the trunk
    for p_ in (body, head):
        if _fine(c):  # texture on the mesh build only (in-game box budget)
            p_.paint(lambda p, cc, g: (_dark(bark, 0.22), False) if cc == bark and (p[0] * 3 + (p[2] // max(1, round(1.4 * k)))) % 5 == 0 else None)
    # rosy knot cheeks
    for z in (round(5.7 * k),):
        x = round(1.3 * k)
        f = head.front(x, z)
        if f:
            _sym_put(head, f, hexc('#C97B5A'))
    # branch arms reaching out and up, with leaf tufts at the tips
    arm = c.part('arms', 'static')
    line(arm, (1.4 * k, -0.1 * k, 4.2 * k), (2.6 * k, -0.4 * k, 3.6 * k), bark, r=0.4 * k)
    line(arm, (2.6 * k, -0.4 * k, 3.6 * k), (3.2 * k, -0.5 * k, 4.6 * k), bark, r=0.32 * k)
    arm.ell((3.3 * k, -0.5 * k, 5.0 * k), (0.7 * k, 0.6 * k, 0.6 * k), leaf)
    _mirror(arm)
    # the leaf crown: a cloud of leafy clumps over the head, two shades,
    # with small glowing blossoms
    crown = c.part('crown', 'static')
    clumps = [(0, 0, 8.6, 1.9), (1.5, -0.4, 8.2, 1.2), (1.0, 1.0, 9.2, 1.2), (0.0, -1.2, 9.4, 1.1), (1.9, 0.6, 7.7, 0.9),
              (0.6, 0.3, 10.1, 0.9)]
    if not _fine(c):
        clumps = [(0, 0, 8.6, 1.9), (1.5, -0.4, 8.2, 1.2), (0.0, -1.2, 9.4, 1.1)]
    for i, (x, y, z, r) in enumerate(clumps):
        crown.ell((x * k, y * k, z * k), (r * k, r * k, r * 0.8 * k), leaf if i % 2 == 0 else _light(leaf, 0.25))
    if _fine(c):  # texture on the mesh build only (in-game box budget)
        crown.paint(lambda p, cc, g: (_dark(leaf, 0.2), False) if (p[0] + p[1] * 2 + p[2]) % 4 == 0 else None)
    _mirror(crown)
    # small glowing blossoms dotted over the crown's outside
    def blossom(p, cc, g):
        x, y, z = p
        if (x, y - 1, z) in crown.v and (x, y, z + 1) in crown.v:
            return None  # buried
        h = (abs(x * 7 + 3) * 13 + y * 5 + z * 11) % 17
        return (glow, True) if h == 0 and z > round(7.6 * k) and (_fine(c) or (x + z) % 2 == 0) else None
    crown.paint(lambda p, cc, g: blossom(p, cc, g) if p[0] >= 0 else None)
    _mirror(crown)
    return c


def _yeti(c, H, cols):
    k = H / 10.0
    fur = cols['col']
    face_col = cols.get('skin', hexc('#6FA8DC'))
    glow = cols.get('glow', hexc('#9EE7FF'))
    body, head, arms = _biped(c, H, fur, fur, None, cols.get('feet', hexc('#5E8FC4')), body_r=(2.05, 1.65, 1.85),
                              head_r=(2.4, 2.05, 2.0), head_z=6.6, eye_z=6.6, eye_x=0.75, eye_size=0.75, arm=False)
    # the blue face: a flat oval plate on the front of the head, under the
    # eyes, with the eyes and mouth on it
    for (x, y, z) in list(head.v):
        fy = head.front(x, z)
        if fy and fy[1] == y and ((x + .5) / (1.7 * k)) ** 2 + ((z + .5 - 6.3 * k) / (1.5 * k)) ** 2 <= 1:
            head.put((x, y, z), face_col)
            if _fine(c) and y + 1 <= max(p[1] for p in head.v):
                head.put((x, y + 1, z), face_col)
    for x in range(-max(1, round(0.4 * k)), max(1, round(0.4 * k))):
        f = head.front(x, round(5.4 * k))
        if f:
            head.put(f, _dark(face_col, 0.55))
    # shaggy fur: jagged tufts round the body, head and shoulders
    shag = c.part('shag', 'static')
    for ang in range(0, 360, 40) if _fine(c) else ():
        a = math.radians(ang)
        for zz in (3.4,):
            r = 1.9 * k if zz != 2.6 else 1.6 * k
            shag.ell((math.cos(a) * r, math.sin(a) * r * 0.85, zz * k + (ang % 80) * 0.01 * k), (0.55 * k, 0.55 * k, 0.8 * k),
                     fur if ang % 80 or not _fine(c) else _dark(fur, 0.06), cond=lambda x, y, z: z > 0)
    for ang in (range(0, 360, 60) if _fine(c) else ()):
        a = math.radians(ang)
        if math.sin(a) < 0.1:
            continue  # leave the face clear
        shag.ell((math.cos(a) * 2.2 * k, math.sin(a) * 1.9 * k - 0.2 * k, 7.0 * k), (0.55 * k, 0.55 * k, 0.6 * k), fur)
    shag.ell((0, 0, 8.6 * k), (1.1 * k, 1.0 * k, 0.7 * k), fur)
    shag.ell((0.4 * k, -0.6 * k, 9.1 * k), (0.4 * k, 0.4 * k, 0.6 * k), fur)
    for p in [p for p in shag.v if p[0] < 0]:  # the ring is lopsided: keep the
        del shag.v[p]                          # right half, mirror it exactly
    _mirror(shag)
    # two small horns
    horns = c.part('horns', 'static')
    for i in range(round(1.1 * k)):
        r = max(0.5, (0.4 - 0.25 * i / max(1, round(1.1 * k))) * k)
        horns.ell((1.6 * k + i * 0.35, 0, 8.1 * k + i * 0.8), (r, r, r), hexc('#E8E2D6'))
    _mirror(horns)
    # arms: shaggy, both reaching forward to hug a glowing snowball against
    # the tummy (kept symmetric so the model and its legs stay centred)
    arm = c.part('arms', 'static')
    arm.ell((1.95 * k, -0.3 * k, 3.7 * k), (0.65 * k, 0.65 * k, 0.95 * k), fur)
    line(arm, (1.85 * k, -0.6 * k, 3.4 * k), (1.5 * k, -2.0 * k, 3.0 * k), fur, r=0.55 * k)
    arm.ell((1.35 * k, -2.55 * k, 2.95 * k), (0.5 * k, 0.5 * k, 0.5 * k), face_col)
    _mirror(arm)
    ball = c.part('snowball', 'static')
    bc = (0, -2.75 * k, 3.25 * k)
    ball.ell(bc, (1.1 * k, 1.05 * k, 1.1 * k), hexc('#A8DBFF'))
    if not _fine(c):
        ball.paint(lambda p, cc, g: (glow, True))  # one glowing ball in game
    ball.paint(lambda p, cc, g: None if not _fine(c) else (glow, True) if (p[0] * 3 + p[1] * 5 + p[2] * 7) % 5 == 0 else
               ((hexc('#7FC0EE'), False) if p[2] + .5 < bc[2] - 0.2 * k else None))
    return c


def _golem(c, H, cols):
    k = H / 10.0
    dough = cols['col']
    icing = cols.get('belly', hexc('#FFFDF6'))
    drops = [cols.get('accent', hexc('#FF4A6A')), hexc('#4AD96A'), hexc('#FFD23A')]
    body, head, arms = _biped(c, H, dough, dough, None, dough, body_r=(2.05, 1.35, 1.95), body_z=3.6,
                              head_r=(2.2, 1.6, 1.95), head_z=6.8, leg_w=0.6, eye_z=6.8, eye_x=0.75, eye_size=0.75,
                              arm=False)
    # gingerbread-man arms held out and down
    arm = c.part('arms', 'static')
    line(arm, (1.7 * k, 0, 4.5 * k), (2.9 * k, -0.1 * k, 3.3 * k), dough, r=0.62 * k)
    _mirror(arm)
    # icing: a dashed ring round the face, a smile, cuffs on the wrists and
    # ankles
    front = {}
    for (x, y, z) in head.v:
        if (x, z) not in front or y < front[(x, z)]:
            front[(x, z)] = y
    for (x, z), y in front.items():
        d = math.hypot((x + .5) / (2.2 * k), (z + .5 - 6.8 * k) / (1.95 * k))
        if 0.8 < d < 0.95 and (x + z) % 3 != 0:
            head.put((x, y, z), icing)
    r = max(2, round(0.6 * k))
    for x in range(-r, r):
        z = round(5.75 * k + 0.4 * k * ((x + .5) / r) ** 2)
        f = head.front(x, z)
        if f:
            head.put(f, icing)
    arm.paint(lambda p, cc, g: (icing, False) if abs(p[0] + .5) >= 2.5 * k and abs(abs(p[0] + .5) - 2.55 * k) < 0.22 * k + .3 else None)
    for p_ in c.parts:
        if p_.name in rig.LEG_NAMES:
            p_.paint(lambda p, cc, g: (icing, False) if cc == dough and p[2] == round(0.95 * k) else None)
    # gumdrop buttons down the chest, glowing
    btn = c.part('buttons', 'glow')
    for i, zz in enumerate((4.8, 3.6, 2.4)):
        f = body.front(0, round(zz * k))
        if not f:
            continue
        cc = drops[i % 3]
        btn.ell((0, f[1] + 0.1 * k, zz * k), (0.42 * k, 0.32 * k, 0.32 * k), cc, True)
    return c


def _sprite(c, H, cols, kind):
    k = H / 10.0
    col = cols['col']
    skin = cols.get('skin', _light(col, 0.5))
    glow = cols.get('glow', hexc('#BFF4FF'))
    acc = cols.get('accent', _light(col, 0.4))
    body, head, arms = _biped(c, H, col, skin, None, cols.get('feet', _dark(col, 0.15)), hip=2.0,
                              body_r=(1.35, 1.15, 1.5), body_z=3.4, head_r=(2.15, 1.9, 1.95), head_z=6.3, leg_w=0.4,
                              leg_x=0.6, eye_z=6.3, eye_x=0.7, eye_size=0.8)
    if kind == 'frost':
        # icy spiked hair: a cap with points sticking up and out
        hair = c.part('hair', 'static')
        hair.ell((0, 0.3 * k, 7.3 * k), (2.25 * k, 1.95 * k, 1.3 * k), acc, cond=lambda x, y, z: z >= round(7.0 * k) or y > 0.6 * k)
        for ang, tilt, ln in ((90, 0.0, 1.6), (50, 0.45, 1.3), (15, 0.8, 1.1), (125, -0.3, 1.2)):
            a = math.radians(ang)
            base = (math.cos(a) * 1.0 * k, -math.sin(a) * 0.2 * k + 0.4 * k, 8.1 * k)
            for i in range(round(ln * k)):
                t = i / max(1, round(ln * k))
                r = max(0.5, (0.45 - 0.35 * t) * k)
                hair.ell((base[0] + tilt * i, base[1] + 0.2 * i, base[2] + i), (r, r, r), _light(acc, 0.3 * t))
        _mirror(hair)
        # a frost dress: a flared skirt of icy points
        skirt = c.part('skirt', 'static')
        for ang in range(0, 360, 30):
            a = math.radians(ang)
            skirt.ell((math.cos(a) * 1.3 * k, math.sin(a) * 1.1 * k, 2.3 * k), (0.55 * k, 0.55 * k, 0.6 * k),
                      acc if ang % 60 or not _fine(c) else _light(acc, 0.35), cond=lambda x, y, z: z >= round(1.8 * k))
        _mirror(skirt)
        wing_col, edge = hexc('#D8F6FF'), glow
    else:
        # a flower on the head: pink petals round a glowing heart, a leaf
        hair = c.part('hair', 'static')
        hair.ell((0, 0.3 * k, 7.2 * k), (2.2 * k, 1.95 * k, 1.35 * k), cols.get('hair', hexc('#FFB3CC')),
                 cond=lambda x, y, z: z >= round(6.9 * k) or y > 0.7 * k)
        fl = c.part('flower', 'static')
        fc = (1.1 * k, -0.6 * k, 8.4 * k)
        for ang in range(0, 360, 60):
            a = math.radians(ang)
            fl.ell((fc[0] + math.cos(a) * 0.6 * k, fc[1] - 0.2 * k, fc[2] + math.sin(a) * 0.6 * k),
                   (0.45 * k, 0.3 * k, 0.45 * k), acc)
        fl.ell((fc[0], fc[1] - 0.4 * k, fc[2]), (0.3 * k + .3, 0.3 * k, 0.3 * k + .3), glow, True)
        fl.ell((-0.6 * k, 0.4 * k, 8.4 * k), (0.8 * k, 0.4 * k, 0.3 * k), hexc('#6CC24A'))
        # the petal skirt: a ring of pointed petals, pale at the tips
        skirt = c.part('skirt', 'static')
        for ang in range(0, 360, 36):
            a = math.radians(ang)
            for i in range(round(1.0 * k)):
                t = i / max(1, round(1.0 * k))
                skirt.ell((math.cos(a) * (1.0 + 0.7 * t) * k, math.sin(a) * (0.9 + 0.6 * t) * k, 2.6 * k - t * 0.9 * k),
                          (0.45 * k * (1 - 0.4 * t) + .3, 0.45 * k * (1 - 0.4 * t) + .3, 0.4 * k),
                          (_light(acc, 0.5 * t) if _fine(c) else acc) if ang % 72 else _mix(acc, hexc('#FF7AA8'), 0.4))
        _mirror(skirt)
        wing_col, edge = _light(acc, 0.35), glow
    # wings: thin panels on the back, two lobes each, glowing edges
    for side, sx in (('L', -1), ('R', 1)):
        w = c.part('wing' + side, 'wing' + side, (sx * 0.5 * k, 1.1 * k, 4.4 * k))
        tmp = {}
        for lobe, (cz, rx, rz, tilt) in enumerate(((5.6, 1.9, 1.5, 0.3), (3.6, 1.3, 1.0, -0.2))):
            for x in range(0, round((0.6 + 2 * rx) * k) + 1):
                for z in range(round((cz - rz) * k), round((cz + rz) * k) + 1):
                    ex = (x + .5 - (0.6 + rx) * k) / (rx * k)
                    ez = (z + .5 - cz * k - tilt * (x - rx * k)) / (rz * k)
                    d = ex * ex + ez * ez
                    if d <= 1.0 and x >= round(0.4 * k):
                        tmp[(x, round(1.3 * k), z)] = (edge, True) if d > 0.62 or not _fine(c) else (
                            (wing_col, False) if kind != 'frost' or (x + z) % 3 or not _fine(c) else (_light(wing_col, 0.5), True))
        for (x, y, z), v in tmp.items():
            w.v[(x if sx > 0 else _mx(x), y, z)] = v
    return c


BIPEDS = {'gnome': _gnome, 'troll': _troll, 'imp': _imp, 'ent': _ent, 'yeti': _yeti, 'golem': _golem,
          'frost': lambda c, H, cols: _sprite(c, H, cols, 'frost'),
          'petal': lambda c, H, cols: _sprite(c, H, cols, 'petal')}


def epicbiped(c, H, cols, opts):
    return BIPEDS[opts.get('kind', 'gnome')](c, H, cols)



# ------------------------------------------------------------------ drake

def _drake_base(c, H, col, belly, horn, ear_col=None):
    import creatures as cr
    k = H / 10.0
    cr.quadruped(c, H, col, belly=belly, snout=col, ears='pointy', ear_col=ear_col or horn, tail='long', tail_col=col)
    # two swept-back horns
    hp = c.part('horns', 'static')
    for i in range(max(3, round(1.6 * k))):
        t = i / max(1, round(1.6 * k) - 1)
        r = max(0.5, (0.42 - 0.25 * t) * k)
        hp.ell((0.95 * k + t * 0.3 * k, -1.4 * k + t * 1.4 * k, 7.6 * k + t * 0.9 * k), (r, r, r), horn)
    _mirror(hp)
    # a dragon's muzzle: a rounded snout over the mouth, two nostrils and a
    # small smile under it
    head = c.part('head')
    head.paint(lambda p, cc, g: (col, False) if cc == INK else None)  # the puppy mouth goes
    zc = 5.2 * k
    ymin = min((p[1] for p in head.v if p[2] == round(zc)), default=round(-4.6 * k))
    snout = _light(col, 0.12)
    head.ell((0, ymin - 0.05 * k, zc), (1.05 * k, 0.55 * k, 0.48 * k), snout)
    nz = round(zc + 0.2 * k)
    for x in (max(0, round(0.3 * k)),):
        f = head.front(x, nz)
        if f:
            _sym_put(head, f, _dark(col, 0.5))
    for x in range(0, max(1, round(0.35 * k))):
        f = head.front(x, round(zc - 0.55 * k))
        if f:
            _sym_put(head, f, _dark(col, 0.6))
    # a tapered dragon tail curling up behind
    tail = c.part('tail')
    tail.v.clear()
    pts = []
    for i in range(20):
        t = i / 19
        pts.append((0.0, 3.6 * k + t * 3.0 * k, 3.0 * k + t * t * 2.2 * k, (0.62 - 0.42 * t) * k))
    for x, y, z, r in pts:
        tail.ell((x, y, z), (r + .3, r + .3, r + .3), col)
    c.tail_pts = pts
    return k


def _rime(c, H, cols):
    col = cols['col']
    ice = cols.get('accent', hexc('#9EDCFF'))
    glow = cols.get('glow', hexc('#BFF4FF'))
    k = _drake_base(c, H, col, cols.get('belly', hexc('#E6F4FF')), ice, ear_col=_dark(col, 0.06))
    # frosted paws: the lower legs fade to ice blue
    # (the legs are still part of the body here; split_legs cuts them later)
    for p_ in c.parts:
        if p_.name == 'body' or p_.name in rig.LEG_NAMES:
            p_.paint(lambda p, cc, g: (_mix(col, ice, 0.85), False) if p[2] <= round(0.9 * k) else None)
    import creatures as cr
    cr.add_wings(c, k, _light(ice, 0.45), (0, 0.6 * k, 4.6 * k), span=2.6, glow_edge=glow)
    pts = c.tail_pts
    # icicle spines: pointed ice shards down the neck, back and tail, pale
    # blue at the root and glowing at the tip
    body = c.part('body')
    sp = c.part('spines', 'static')

    def shard(y, top, n):
        for i in range(n):
            w = max(0, round((n - 1 - i) * 0.3))
            tip = i >= n - max(1, n // 3)
            for x in range(-w - 1, w + 1):
                sp.put((x, y, top + 1 + i), glow if tip else ice, tip)
    for y in range(round(0.2 * k), round(3.6 * k), max(2, round(0.8 * k))):
        top = max((p[2] for p in body.v if p[1] == y and p[0] in (0, -1)), default=None)
        if top is not None:
            shard(y, top, max(3, round((1.5 - 0.15 * y / k) * k)))
    for x, y, z, r in (pts[2::4] if _fine(c) else []):
        shard(round(y), round(z + r), max(2, round(0.8 * k)))
    # an icicle crest on the crown, the tallest in the middle
    head = c.part('head')
    for y, n in (((-2.0 * k, 1.2), (-1.2 * k, 1.8), (-0.4 * k, 1.5), (0.4 * k, 1.1)) if _fine(c) else ((-1.2 * k, 1.8), (0.0, 1.4))):
        yy = round(y)
        top = max((p[2] for p in head.v if p[1] == yy and p[0] in (0, -1)), default=None)
        if top is not None:
            shard(yy, top, max(3, round(n * k)))
    return c


def _bonsai(c, H, cols):
    col = cols['col']
    k = _drake_base(c, H, col, cols.get('belly', hexc('#E8F2C8')), cols.get('accent', hexc('#C9A66B')))
    glow = cols.get('glow', hexc('#FFB3D1'))
    leaf = cols.get('leaf', hexc('#3E8F4A'))
    bark = hexc('#7A5232')
    body = c.part('body')
    # a mossy saddle the tree grows from, behind the head
    yb = 1.6 * k
    top = max((p[2] for p in body.v if p[1] == round(yb) and p[0] in (0, -1)), default=round(4.5 * k))
    tree = c.part('tree', 'static')
    tree.ell((0, yb, top), (1.2 * k, 1.2 * k, 0.45 * k), hexc('#6FAE4A'), cond=lambda x, y, z: (x, y, z) not in body.v)
    # a crooked trunk that leans out to the right of the head, one branch
    # back to the left, and flat cloud pads of leaves on top
    base = (0, yb, top + 0.2 * k)
    bend = (1.5 * k, yb + 0.2 * k, top + 2.2 * k)
    crown = (1.0 * k, yb, top + 4.4 * k)
    branch = (-1.3 * k, yb + 0.4 * k, top + 3.6 * k)
    line(tree, base, bend, bark, r=0.42 * k)
    line(tree, bend, crown, bark, r=0.34 * k)
    line(tree, (0.9 * k, yb + 0.2 * k, top + 3.0 * k), branch, bark, r=0.24 * k)
    pads = [(crown[0], crown[1], crown[2] + 0.3 * k, 1.5), (branch[0], branch[1], branch[2] + 0.2 * k, 1.05),
            (crown[0] + 1.5 * k, crown[1] + 0.2 * k, crown[2] - 1.0 * k, 0.9)]
    for (x, y, z, r) in (pads if _fine(c) else pads[:2]):
        tree.ell((x, y, z), (r * k, r * 0.85 * k, r * 0.38 * k + .4), leaf)
        if _fine(c):
            tree.paint(lambda p, cc, g, z=z: (_light(leaf, 0.22), False) if cc == leaf and p[2] >= round(z + 0.1 * k) else None)
    # glowing pink blossoms dotted over the top of the leaf pads
    light = _light(leaf, 0.22) if _fine(c) else leaf
    for (x, y, z), (cc, g) in list(tree.v.items()):
        if cc == light and (x, y, z + 1) not in tree.v and (x * 7 + y * 11 + z * 3) % (13 if _fine(c) else 19) == 0:
            tree.v[(x, y, z)] = (glow, True)
            tree.put((x, y, z + 1), glow, True)
    return c


DRAKES = {'rime': _rime, 'bonsai': _bonsai}


def epicdrake(c, H, cols, opts):
    return DRAKES[opts.get('kind', 'bonsai')](c, H, cols)


PLANS = {
    'epicbiped': ({'col', 'skin', 'belly', 'accent', 'feet', 'glow', 'hair'},
                  {'kind': set(BIPEDS)}),
    'epicdrake': ({'col', 'belly', 'accent', 'glow', 'leaf'}, {'kind': set(DRAKES)}),
}
BUILDERS = {
    'epicbiped': epicbiped,
    'epicdrake': epicdrake,
}
