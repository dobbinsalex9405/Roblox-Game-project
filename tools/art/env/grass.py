"""Paints Hatchery Heist's ground: a seamless tile of storybook voxel grass
(soft patches of three greens, short blades, a few tiny flowers), laid over
the Baseplate and the hills with a Roblox Texture.

    python3 tools/art/env/grass.py OUT [--size 512]

OUT gets Grass.png (the tile) and grass-preview.png (3 x 3 tiles, to check
the seams and the repeat). Plain numpy; every pattern repeats exactly once
per tile, so the edges meet.
"""
import argparse
import math
import os

import numpy as np
from PIL import Image

BLOCK = 8  # one voxel of grass is 8 x 8 pixels (a quarter stud at 32 studs a tile)

BASE = np.array([93, 178, 74])
LIGHT = np.array([106, 190, 82])
DARK = np.array([82, 164, 67])
BLADE = np.array([136, 214, 102])
BLADE_DARK = np.array([66, 140, 56])
FLOWERS = [np.array(c) for c in ((255, 255, 255), (255, 222, 90), (255, 160, 200), (190, 170, 255))]


def periodic(n, seed, terms=6, top=5):
    """smooth noise on an n x n torus: sum of sines with whole-number
    frequencies, so it wraps exactly"""
    rng = np.random.default_rng(seed)
    y, x = np.meshgrid(np.arange(n), np.arange(n), indexing='ij')
    t = 2 * math.pi / n
    out = np.zeros((n, n))
    for _ in range(terms):
        fx, fy = rng.integers(-top, top + 1, 2)
        if fx == 0 and fy == 0:
            fx = 1
        out += rng.uniform(0.4, 1.0) * np.sin((fx * x + fy * y) * t + rng.uniform(0, 6.28))
    return out / terms


def tile(size):
    n = size // BLOCK
    rng = np.random.default_rng(5)
    patches = periodic(n, 1, 14) + 0.6 * periodic(n, 2, 24, 9)
    rgb = np.where((patches > 0.16)[..., None], LIGHT, np.where((patches < -0.16)[..., None], DARK, BASE)).astype(np.float64)
    # a little per-voxel variation so flat areas are not dead
    rgb *= (1 + rng.uniform(-0.025, 0.025, (n, n)))[..., None]
    # blades: two voxels tall, lighter tip over a darker root
    for _ in range(int(n * n * 0.022)):
        i, j = rng.integers(0, n, 2)
        rgb[i, j] = BLADE
        rgb[(i + 1) % n, j] = BLADE_DARK
    # a few tiny flowers
    for _ in range(int(n * n * 0.0025)):
        i, j = rng.integers(0, n, 2)
        rgb[i, j] = FLOWERS[rng.integers(0, len(FLOWERS))]
    big = np.repeat(np.repeat(rgb, BLOCK, 0), BLOCK, 1)
    # soft voxel edge: a lighter top row and darker bottom row where colours change
    q = rgb
    up = np.zeros((n, n), bool)
    dn = np.zeros((n, n), bool)
    up[:] = np.abs(q - np.roll(q, 1, 0)).sum(-1) > 30
    dn[:] = np.abs(q - np.roll(q, -1, 0)).sum(-1) > 30
    row = np.repeat((np.arange(size) % BLOCK)[:, None], size, 1)
    k = np.zeros((size, size))
    k[np.repeat(np.repeat(up, BLOCK, 0), BLOCK, 1) & (row < 1)] = 0.06
    k[np.repeat(np.repeat(dn, BLOCK, 0), BLOCK, 1) & (row >= BLOCK - 1)] = -0.07
    big = big * (1 + k[..., None])
    return np.clip(big, 0, 255).astype(np.uint8)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out')
    ap.add_argument('--size', type=int, default=1024)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    t = tile(a.size)
    Image.fromarray(t).save(os.path.join(a.out, 'Grass.png'), optimize=True)
    Image.fromarray(np.tile(t, (3, 3, 1))).resize((a.size * 3 // 4,) * 2, Image.NEAREST).save(
        os.path.join(a.out, 'grass-preview.png'), optimize=True)


if __name__ == '__main__':
    main()
