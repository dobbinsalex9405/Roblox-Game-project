"""Draws app/icon.ico: three voxel cubes, the viewer's desktop icon.

Run once after changing it:  python3 tools/designs/viewer/make-icon.py
Needs Pillow."""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
S = 512


def cube(d, cx, cy, r, top, left, right):
    # Isometric cube centred at (cx, cy) with "radius" r.
    h = r * 0.5
    t = [(cx, cy - r), (cx + r * 0.866, cy - h), (cx, cy), (cx - r * 0.866, cy - h)]
    l = [(cx - r * 0.866, cy - h), (cx, cy), (cx, cy + r), (cx - r * 0.866, cy + h)]
    g = [(cx + r * 0.866, cy - h), (cx + r * 0.866, cy + h), (cx, cy + r), (cx, cy)]
    for poly, col in ((t, top), (l, left), (g, right)):
        d.polygon(poly, fill=col, outline=(20, 24, 40, 255), width=int(r * 0.07))


img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.rounded_rectangle((16, 16, S - 16, S - 16), radius=96, fill=(31, 37, 58, 255))
cube(d, 256, 300, 120, (255, 214, 92, 255), (240, 140, 0, 255), (196, 104, 0, 255))
cube(d, 152, 196, 84, (140, 160, 255, 255), (79, 108, 247, 255), (52, 76, 196, 255))
cube(d, 362, 190, 76, (120, 230, 150, 255), (47, 168, 79, 255), (30, 120, 56, 255))
img.save(os.path.join(HERE, "icon.ico"), sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
img.resize((128, 128), Image.LANCZOS).save(os.path.join(HERE, "icon-preview.png"))
