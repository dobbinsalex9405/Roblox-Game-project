"""The per-creature palette texture: one small PNG, a grid of flat colour
cells. Every face of a creature's mesh samples the centre of one cell, so the
texture never blurs between colours, at any mip level.

Each colour of the creature gets TONES face tones (a few percent lighter or
darker, for the hand-placed look) and one darker rim tone (the grooves).
Glowing colours get the same so the preview matches; in game a glow mesh is
Neon and takes its colour from the manifest."""
from voxmesh import TONES

CELL = 4  # pixels per cell side
COLS = 16  # cells per row
FACE_TONE = (0.94, 0.98, 1.0, 1.04)  # one per tone variant
RIM_TONE = 0.90
GLOW_FACE_TONE = (0.97, 1.0, 1.0, 1.02)
GLOW_RIM_TONE = 0.95

assert len(FACE_TONE) == TONES and len(GLOW_FACE_TONE) == TONES


def shade(rgb, k):
    return tuple(max(0, min(255, round(c * k))) for c in rgb)


class Palette:
    def __init__(self):
        self.cells = []  # rgb per cell
        self.index = {}

    def cell_of(self, rgb, glow, kind, tone):
        key = (rgb, glow, kind, tone if kind == 'face' else 0)
        i = self.index.get(key)
        if i is None:
            if kind == 'face':
                k = (GLOW_FACE_TONE if glow else FACE_TONE)[tone]
            else:
                k = GLOW_RIM_TONE if glow else RIM_TONE
            i = len(self.cells)
            self.cells.append(shade(rgb, k))
            self.index[key] = i
        return i

    def size(self):
        rows = max(1, -(-len(self.cells) // COLS))
        h = 1
        while h < rows * CELL:
            h *= 2
        return COLS * CELL, max(h, CELL)

    def uv(self, i):
        """UV of cell i's centre (origin bottom left, as Blender and glTF
        after their flips expect: v counts up from the bottom row)."""
        w, h = self.size()
        cx, cy = i % COLS, i // COLS
        return ((cx + 0.5) * CELL / w, 1 - (cy + 0.5) * CELL / h)

    def pixels(self):
        """Rows of rgb tuples, top row first."""
        w, h = self.size()
        rows = [[(255, 255, 255)] * w for _ in range(h)]
        for i, rgb in enumerate(self.cells):
            cx, cy = i % COLS, i // COLS
            for yy in range(cy * CELL, cy * CELL + CELL):
                for xx in range(cx * CELL, cx * CELL + CELL):
                    rows[yy][xx] = rgb
        return rows
