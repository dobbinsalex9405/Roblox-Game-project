"""Paints Hatchery Heist's skybox: a storybook afternoon sky with blocky
voxel clouds, two rings of distant voxel mountains and little floating
islands, as the six square images a Roblox Sky takes.

    python3 tools/art/env/sky.py OUT [--size 1024]

OUT gets SkyboxBk/Dn/Ft/Lf/Rt/Up.png, a 6-face net (net.png) and a wide
panorama (panorama.png) for review.

Made to survive any face order: Roblox's docs do not say which way each
face points or how Up and Down are turned. So the top cap (everything above
33 degrees, where Up's picture lives) and the bottom are the same in every
direction, and near the four vertical seams the mountains and haze follow
one shared shape mirrored about the seam. Each face's middle has its own
clouds and islands. Whatever order or mirroring Roblox uses, the seams
still meet. Painted in plain numpy and Pillow; no Blender.
"""
import argparse
import math
import os

import numpy as np
from PIL import Image

BLOCK = 8          # a "voxel" of cloud, mountain and island is BLOCK x BLOCK pixels at 1024
CAP = 33.0         # degrees: above this the sky depends on elevation only
SEAM = 13.0        # degrees each side of a vertical seam that follow the shared shape

ZENITH = np.array([84, 148, 234])
HIGH = np.array([104, 168, 242])
LOW = np.array([170, 214, 252])
HORIZON = np.array([236, 244, 255])
GLOW = np.array([255, 236, 214])
BELOW = np.array([150, 196, 214])

# per face: (yaw of the face centre, seed, features)
FACES = {
    'Ft': dict(yaw=180, seed=3, island=(6.0, 21.0, 1.7, True)),
    'Rt': dict(yaw=90, seed=7, rocks=True),
    'Bk': dict(yaw=0, seed=11, island=(-12.0, 19.0, 1.25, False)),
    'Lf': dict(yaw=270, seed=17, island=(14.0, 24.5, 0.95, True)),
}


def lerp(a, b, t):
    t = np.clip(t, 0, 1)[..., None]
    return a * (1 - t) + b * t


def smooth(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


def sky_gradient(el):
    """el in degrees -> RGB; depends on elevation only"""
    e = np.asarray(el, np.float64)
    c = lerp(HORIZON, LOW, smooth(e / 9.0))
    c = lerp(c, HIGH, smooth((e - 9.0) / 26.0))
    c = lerp(c, ZENITH, smooth((e - 30.0) / 60.0))
    glow = np.exp(-np.maximum(e, 0) / 3.5) * 0.55
    c = lerp(c, GLOW, glow)
    below = smooth(-e / 6.0)
    return lerp(c, BELOW, below)


def ridge(x, seed, base, amp, freq):
    """blocky mountain heights (degrees) along face-local x (degrees)"""
    rng = np.random.default_rng(seed)
    ph = rng.uniform(0, 6.28, 4)
    h = np.zeros_like(x)
    for k, (f, a) in enumerate(((freq, 1.0), (freq * 2.3, 0.45), (freq * 5.1, 0.2), (freq * 9.7, 0.08))):
        h += a * np.sin(x * f + ph[k])
    return base + amp * h


def seam_shape(d, base, amp):
    """the shared shape near a seam; d = degrees from the seam (>= 0)"""
    return base + amp * (0.55 * np.cos(d * 0.21) + 0.25 * np.cos(d * 0.57 + 1.0))


def mountains(x, seed, base, amp, freq):
    d = 45.0 - np.abs(x)
    own = ridge(x, seed, base, amp, freq)
    shared = seam_shape(d, base, amp)
    w = smooth((d - 2.0) / (SEAM - 2.0))
    return shared * (1 - w) + own * w


def puffs_mask(x, y, puffs):
    """union of ellipses -> (inside, shade 0 bottom .. 1 top)"""
    inside = np.zeros(x.shape, bool)
    shade = np.zeros(x.shape)
    for cx, cy, rx, ry in puffs:
        d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
        m = d <= 1
        t = np.clip((y - (cy - ry)) / (2 * ry), 0, 1)
        shade = np.where(m & (~inside | (t > shade)), t, shade)
        inside |= m
    return inside, shade


def cloud(cx, cy, w, rng):
    """a cumulus: a flat bottom and a heap of round puffs on top"""
    puffs = [(cx, cy + w * 0.08, w * 0.5, w * 0.11)]
    n = rng.integers(4, 7)
    for i in range(n):
        t = (i + 0.5) / n - 0.5
        px = cx + t * w * 0.85 + rng.uniform(-0.05, 0.05) * w
        r = w * (0.2 + 0.16 * (1 - abs(t) * 2)) * rng.uniform(0.8, 1.15)
        puffs.append((px, cy + r * 0.55, r, r * 0.62))
    return puffs


def face_clouds(seed):
    rng = np.random.default_rng(seed)
    out = []
    # big ones low, smaller ones higher; all kept off the seams and below the cap
    for (lo, hi, wlo, whi, n) in ((10.0, 14.0, 24.0, 34.0, 1), (15.0, 21.0, 13.0, 20.0, 2), (23.0, 27.0, 7.0, 11.0, 2)):
        for _ in range(n):
            w = rng.uniform(wlo, whi)
            cx = rng.uniform(-39 + w * 0.55, 39 - w * 0.55)
            cy = min(rng.uniform(lo, hi), CAP - 2.0 - 0.36 * w)
            out.append(cloud(cx, cy, w, rng))
    return out


def island(x, y, cx, cy, s, falls):
    """a floating island: grass cap, rocky underside tapering to a point,
    a voxel tree or two and maybe a waterfall. -> RGB or None per pixel"""
    rgb = np.full(x.shape + (3,), -1.0)
    w = 7.0 * s
    top = cy
    # grass cap
    cap = (np.abs(x - cx) <= w) & (y <= top) & (y >= top - 1.1 * s)
    # underside: an upside-down rounded cone
    depth = 6.5 * s
    t = np.clip((top - 1.1 * s - y) / depth, 0, 1)
    half = w * (1 - t) ** 1.4 * (1 + 0.12 * np.sin(x * 3.1 / max(s, 0.3)))
    rock = (np.abs(x - cx) <= half) & (y < top - 1.1 * s) & (y >= top - 1.1 * s - depth)
    rock_c = lerp(np.array([158, 140, 170]), np.array([110, 98, 132]), t)
    rgb = np.where(rock[..., None], rock_c, rgb)
    grass_c = np.where(((y - (top - 1.1 * s)) > 0.55 * s)[..., None], np.array([132, 214, 104]), np.array([92, 178, 84]))
    rgb = np.where(cap[..., None], grass_c, rgb)
    # trees: round crowns on short trunks
    for k, (dx, hh, r) in enumerate(((-0.45, 2.2, 1.7), (0.35, 1.6, 1.3))):
        tx = cx + dx * w
        trunk = (np.abs(x - tx) <= 0.28 * s) & (y >= top) & (y <= top + hh * s)
        crown_d = ((x - tx) / (r * s)) ** 2 + ((y - (top + (hh + r * 0.6) * s)) / (r * s * 0.9)) ** 2
        crown = crown_d <= 1
        rgb = np.where(trunk[..., None], np.array([126, 86, 56]), rgb)
        cc = np.where(((y - (top + (hh + r * 0.6) * s)) > 0)[..., None], np.array([104, 200, 92]), np.array([70, 160, 76]))
        rgb = np.where(crown[..., None], cc, rgb)
    if falls:
        fx = cx + 0.62 * w
        fall = (np.abs(x - fx) <= 0.5 * s) & (y < top - 0.2 * s) & (y >= top - 1.1 * s - depth * 1.6)
        fade = np.clip((y - (top - 1.1 * s - depth * 1.6)) / (depth * 1.6), 0, 1)
        fc = lerp(np.array([220, 236, 255]), np.array([150, 206, 255]), fade)
        rgb = np.where(fall[..., None] & (fade > 0.12)[..., None], fc, rgb)
    return rgb


def rocks(x, y, seed):
    """a few tiny floating stones"""
    rng = np.random.default_rng(seed)
    rgb = np.full(x.shape + (3,), -1.0)
    for _ in range(5):
        cx, cy, s = rng.uniform(-28, 28), rng.uniform(13, 24), rng.uniform(0.6, 1.3)
        d = ((x - cx) / (1.6 * s)) ** 2 + ((y - cy) / (1.0 * s)) ** 2
        m = (d <= 1) | ((np.abs(x - cx) <= 1.6 * s * (1 - (cy - y) / (2.2 * s))) & (y < cy) & (y > cy - 2.2 * s))
        c = np.where((y > cy + 0.3 * s)[..., None], np.array([132, 214, 104]), np.array([150, 134, 166]))
        rgb = np.where(m[..., None], c, rgb)
    return rgb


def face_dirs(name, n):
    """unit directions for each pixel of a face. Roblox frame, Y up; the
    side faces look along their yaw (0 = +Z, 90 = +X)."""
    j, i = np.meshgrid(np.arange(n) + 0.5, np.arange(n) + 0.5)
    a = 2 * j / n - 1        # left -> right
    b = 1 - 2 * i / n        # top -> bottom
    if name in FACES:
        yaw = math.radians(FACES[name]['yaw'])
        f = np.array([math.sin(yaw), 0, math.cos(yaw)])
        r = np.array([math.cos(yaw), 0, -math.sin(yaw)]) * -1
        u = np.array([0, 1, 0])
    elif name == 'Up':
        f, r, u = np.array([0, 1, 0]), np.array([1, 0, 0]), np.array([0, 0, 1])
    else:
        f, r, u = np.array([0, -1, 0]), np.array([1, 0, 0]), np.array([0, 0, -1])
    d = f[None, None] + a[..., None] * r[None, None] + b[..., None] * u[None, None]
    return d / np.linalg.norm(d, axis=-1, keepdims=True)


def paint(dirs, name):
    """dirs (H, W, 3) -> RGB float"""
    x_, y_, z_ = dirs[..., 0], dirs[..., 1], dirs[..., 2]
    el = np.degrees(np.arcsin(np.clip(y_, -1, 1)))
    rgb = sky_gradient(el)
    if name not in FACES:
        return rgb
    face = FACES[name]
    az = np.degrees(np.arctan2(x_, z_))
    x = (az - face['yaw'] + 180) % 360 - 180  # face-local degrees, -45..45
    # clouds
    for k, puffs in enumerate(face_clouds(face['seed'])):
        inside, shade = puffs_mask(x, el, puffs)
        cc = lerp(np.array([196, 206, 238]), np.array([255, 255, 255]), smooth(shade * 1.6))
        rgb = np.where(inside[..., None], cc, rgb)
    # islands and stones float in front of the clouds, behind the mountains
    if 'island' in face:
        cx, cy, s, falls = face['island']
        isl = island(x, el, cx, cy, s, falls)
        haze = 0.25 / max(s, 0.5)
        rgb = np.where(isl[..., 0:1] >= 0, lerp(isl, LOW, np.full(el.shape, haze)), rgb)
    if face.get('rocks'):
        rk = rocks(x, el, face['seed'] + 1)
        rgb = np.where(rk[..., 0:1] >= 0, lerp(rk, LOW, np.full(el.shape, 0.3)), rgb)
    # far mountains (pale lavender), then near hills (soft teal-green)
    far = mountains(x, face['seed'] + 20, 10.5, 3.0, 0.07)
    m_far = el <= far
    c_far = lerp(np.array([170, 182, 228]), np.array([204, 212, 244]), smooth((el - 3) / 10))
    rgb = np.where(m_far[..., None], c_far, rgb)
    # snowy caps on the tallest far peaks
    snow = m_far & (el > far - 1.2) & (far > 12.2)
    rgb = np.where(snow[..., None], np.array([246, 248, 255]), rgb)
    near = mountains(x, face['seed'] + 40, 6.0, 2.2, 0.11)
    m_near = el <= near
    c_near = lerp(np.array([120, 182, 150]), np.array([156, 210, 176]), smooth((el - 1) / 7))
    rgb = np.where(m_near[..., None], c_near, rgb)
    return rgb


def render_face(name, n):
    """paint at block resolution (the voxel look), then a smooth sky under it"""
    nb = n // BLOCK
    coarse = paint(face_dirs(name, nb), name)
    fine = sky_gradient(np.degrees(np.arcsin(np.clip(face_dirs(name, n)[..., 1], -1, 1))))
    big = np.repeat(np.repeat(coarse, BLOCK, 0), BLOCK, 1)
    plain = np.repeat(np.repeat(sky_gradient(np.degrees(np.arcsin(np.clip(face_dirs(name, nb)[..., 1], -1, 1)))), BLOCK, 0), BLOCK, 1)
    feature = np.abs(big - plain).sum(-1) > 1.5
    out = np.where(feature[..., None], big, fine)
    # voxel edges: a light rim where a block's upper neighbour differs, a
    # darker one where the lower neighbour differs (no grid on flat areas)
    q = coarse.astype(np.float64)
    diff_up = np.zeros(q.shape[:2], bool)
    diff_dn = np.zeros(q.shape[:2], bool)
    diff_up[1:] = np.abs(q[1:] - q[:-1]).sum(-1) > 45
    diff_dn[:-1] = np.abs(q[:-1] - q[1:]).sum(-1) > 45
    up = np.repeat(np.repeat(diff_up, BLOCK, 0), BLOCK, 1)
    dn = np.repeat(np.repeat(diff_dn, BLOCK, 0), BLOCK, 1)
    i = np.arange(n) % BLOCK
    row = np.repeat(i[:, None], n, 1)
    k = np.zeros((n, n))
    k[up & (row < 2)] = 0.07
    k[dn & (row >= BLOCK - 2)] = -0.08
    out = np.where(feature[..., None], out * (1 + k[..., None]), out)
    return np.clip(out, 0, 255).astype(np.uint8)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out')
    ap.add_argument('--size', type=int, default=1024)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    n = a.size
    faces = {}
    for name in ('Ft', 'Rt', 'Bk', 'Lf', 'Up', 'Dn'):
        faces[name] = render_face(name, n)
        Image.fromarray(faces[name]).save(os.path.join(a.out, f'Skybox{name}.png'), optimize=True)
    # net:      Up
    #       Lf  Ft  Rt  Bk
    #           Dn
    q = n // 4
    net = Image.new('RGB', (q * 4, q * 3), (255, 255, 255))
    small = {k: Image.fromarray(v).resize((q, q)) for k, v in faces.items()}
    for k, (cx, cy) in {'Up': (1, 0), 'Lf': (0, 1), 'Ft': (1, 1), 'Rt': (2, 1), 'Bk': (3, 1), 'Dn': (1, 2)}.items():
        net.paste(small[k], (cx * q, cy * q))
    net.save(os.path.join(a.out, 'net.png'), optimize=True)
    # panorama: what a player turning round sees (elevation -10 .. 50)
    W, H = 2048, 680
    az = np.radians(np.linspace(-180, 180, W, endpoint=False))
    el = np.radians(np.linspace(50, -10, H))
    A, E = np.meshgrid(az, el)
    dirs = np.stack([np.sin(A) * np.cos(E), np.sin(E), np.cos(A) * np.cos(E)], -1)
    pano = np.zeros((H, W, 3), np.uint8)
    ax = np.abs(dirs)
    for name in ('Ft', 'Rt', 'Bk', 'Lf', 'Up', 'Dn'):
        if name == 'Up':
            sel = (ax[..., 1] >= ax[..., 0]) & (ax[..., 1] >= ax[..., 2]) & (dirs[..., 1] > 0)
        elif name == 'Dn':
            sel = (ax[..., 1] >= ax[..., 0]) & (ax[..., 1] >= ax[..., 2]) & (dirs[..., 1] < 0)
        else:
            yaw = math.radians(FACES[name]['yaw'])
            fx, fz = math.sin(yaw), math.cos(yaw)
            dot = dirs[..., 0] * fx + dirs[..., 2] * fz
            sel = (dot >= np.maximum(np.abs(dirs[..., 0] * fz - dirs[..., 2] * fx), ax[..., 1])) & (dot > 0)
        if sel.any():
            pano[sel] = np.clip(paint(dirs[sel][None], name)[0], 0, 255).astype(np.uint8)
    Image.fromarray(pano).save(os.path.join(a.out, 'panorama.png'), optimize=True)


if __name__ == '__main__':
    main()
