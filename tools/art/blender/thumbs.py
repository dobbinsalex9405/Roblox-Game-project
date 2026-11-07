"""The Hatchery Book's creature pictures: how build.py --thumbs frames them,
and the fingerprint that says which art a picture was drawn from.

Plain Python (Pillow only for frame), so luau.py can tell, without Blender,
whether an uploaded picture still shows the creature as it is now. A
picture whose fingerprint no longer matches is left out of
CreatureThumbs.luau, and the Book draws that creature live instead (a
ViewportFrame) until a new picture is uploaded.

Bump STYLE whenever the look of the pictures changes (camera, light, size),
so every picture counts as out of date and is drawn again."""
import hashlib
import json

STYLE = 1
SIZE = 256  # the uploaded picture, square, in pixels
RENDER = 512  # rendered at this size, then cropped and scaled down to SIZE
SAMPLES = 32
YAW = 30  # degrees round from the face, as the hero shot
PITCH = 14
MARGIN = 0.06  # clear border on the long side, as a share of SIZE


def fingerprint(c):
    """A short hash of everything that changes how creature c looks: its
    meshes, its colours and the picture style."""
    from describe import describe

    meta, p, parts = describe(c)
    h = hashlib.sha1()
    h.update(f'style {STYLE} {SIZE} {RENDER} {SAMPLES} {YAW} {PITCH} {MARGIN}\n'.encode())
    h.update(json.dumps(meta, sort_keys=True).encode())
    h.update(json.dumps(p.cells).encode())
    for part, pivot, meshes in parts:
        h.update(f'{part.name} {[round(v, 4) for v in pivot]}\n'.encode())
        for kind, rgb, md, name in meshes:
            h.update(f'{kind} {rgb} {name} {len(md.verts)} {len(md.tris)}\n'.encode())
            h.update(json.dumps([[round(x, 4) for x in v] for v in md.verts]).encode())
            h.update(json.dumps(md.tris).encode())
    return h.hexdigest()[:16]


def frame(im):
    """Crops a clear-background render to the creature's outline and centres
    it in a SIZE square with a MARGIN border, so a mouse and a serpent fill
    their cards alike."""
    from PIL import Image

    box = im.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
    if box:
        im = im.crop(box)
    w, h = im.size
    inner = round(SIZE * (1 - 2 * MARGIN))
    k = inner / max(w, h)
    im = im.resize((max(1, round(w * k)), max(1, round(h * k))), Image.LANCZOS)
    out = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    out.paste(im, ((SIZE - im.size[0]) // 2, (SIZE - im.size[1]) // 2))
    return out
