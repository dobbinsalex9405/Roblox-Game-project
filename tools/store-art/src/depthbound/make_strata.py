"""Writes src/depthbound/strata-*.svg: the block grid used by the Depthbound
thumbnails (deterministic, so re-running gives the same picture).

    python3 tools/store-art/src/depthbound/make_strata.py
"""
import random
from pathlib import Path

HERE = Path(__file__).parent
TILE = 120

# Colours from games/depthbound/config/blocks.luau (rock) and the store brief.
LAYERS = [  # (rows, rock colour, [(ore colour, highlight, weight)], plain-rock weight)
    (2, "#9A7352", [("#2A2A30", "#8A8A98", 4), ("#E8834A", "#FFD2B0", 3), ("#EDEDF5", "#FFFFFF", 1)], 6),
    (2, "#5D626D", [("#A08C82", "#E0D0C8", 3), ("#C8CDD8", "#FFFFFF", 3), ("#41C27A", "#BFFFD8", 2)], 6),
    (4, "#3A2D2E", [("#F0C83C", "#FFF2B0", 3), ("#3C5AD8", "#B8C8FF", 3), ("#2840C8", "#A0B4FF", 1), ("#FF5A1E", "#FFE0B8", 2)], 5),
]


def grid(width, top, holes, seed):
    rnd = random.Random(seed)
    out = []
    row = 0
    for rows, rock, ores, plain in LAYERS:
        for _ in range(rows):
            y = top + row * TILE
            for col in range((width + TILE - 1) // TILE):
                if (col, row) in holes:
                    continue
                x = col * TILE
                cx, cy = x + TILE / 2, y + TILE / 2
                pick = rnd.choices(range(len(ores) + 1), weights=[w for *_, w in ores] + [plain])[0]
                out.append(f'<rect x="{x+3}" y="{y+3}" width="{TILE-6}" height="{TILE-6}" rx="12" fill="{rock}" stroke="#120C1E" stroke-width="6"/>')
                out.append(f'<path d="M{x+16} {y+16} H{x+TILE-30}" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round" opacity="0.15"/>')
                if pick < len(ores):
                    gem, hi, _ = ores[pick]
                    r = rnd.uniform(-20, 20)
                    out.append(f'<use href="#gem" transform="translate({cx-12:.0f} {cy-8:.0f}) rotate({r:.0f}) scale(0.95)" style="--gem:{gem};--gemHi:{hi}"/>')
                    out.append(f'<use href="#gem" transform="translate({cx+26:.0f} {cy+26:.0f}) rotate({-r:.0f}) scale(0.55)" style="--gem:{gem};--gemHi:{hi}"/>')
            row += 1
    return "\n".join(out)


# Thumbnail 1: shaft in column 11 down to a pocket in row 5, columns 9-12.
holes1 = {(11, r) for r in range(0, 6)} | {(c, 5) for c in (9, 10, 12)} | {(12, 4)}
(HERE / "strata-1.svg").write_text(grid(1920, 260, holes1, 7) + "\n")
# Thumbnail 2: shaft in column 7 down to row 6, pocket at row 6 columns 6-9.
holes2 = {(7, r) for r in range(0, 7)} | {(c, 6) for c in (6, 8, 9)}
(HERE / "strata-2.svg").write_text(grid(1920, 140, holes2, 11) + "\n")
print("ok")
