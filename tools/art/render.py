"""Render creatures with Blender (bpy) for review: the same boxes the game
builds, lit like a sunny yard.

    pip install --target=<dir> bpy==5.1.2      # once; about 1 GB
    PYTHONPATH=<dir> python3 tools/art/render.py out.png Phoenix GoldenGoose
    PYTHONPATH=<dir> python3 tools/art/render.py out.png --all

One species renders as a close portrait; several stand in a row, smallest
first, at their in-game sizes (VOXEL studs per voxel)."""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402

from creatures import VOXEL, build_all  # noqa: E402
from voxkit import greedy_boxes, merged_boxes  # noqa: E402

RANK = ['Common', 'Uncommon', 'Rare', 'Ultra Rare', 'Epic', 'Legendary', 'Godly']
RING = {'Epic': (177, 92, 255), 'Legendary': (255, 194, 26), 'Godly': (255, 77, 94)}


def lin(c):
    return tuple(((x / 255 + 0.055) / 1.055) ** 2.4 if x / 255 > 0.04045 else x / 255 / 12.92 for x in c)


def material(name, glow):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    a = nt.nodes.new("ShaderNodeAttribute")
    a.attribute_name = "Col"
    nt.links.new(a.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.55
    if glow:
        nt.links.new(a.outputs["Color"], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = 3.0
    return m


FACES = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]


def add_creature(bm, col, c, ox):
    """Adds the creature's boxes, its feet centred at x = ox. Returns its
    width and height in studs."""
    lo, hi = c.bounds()
    cx, cy = (lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2
    for p in c.parts:
        a, b = greedy_boxes(p.v), merged_boxes(p.v)
        for (x, y, z, sx, sy, sz, (rgb, glow)) in (b if len(b) <= len(a) else a):
            vs = []
            for dx in (0, sx):
                for dy in (0, sy):
                    for dz in (0, sz):
                        vs.append(bm.verts.new(((x + dx - cx) * VOXEL + ox, (y + dy - cy) * VOXEL, (z + dz - lo[2]) * VOXEL)))
            for f in FACES:
                face = bm.faces.new([vs[i] for i in f])
                face.material_index = 1 if glow else 0
                for loop in face.loops:
                    loop[col] = (*lin(rgb), 1)
    return (hi[0] - lo[0]) * VOXEL, (hi[2] - lo[2]) * VOXEL


def main():
    out = os.path.abspath(sys.argv[1])
    names = sys.argv[2:]
    creatures = build_all()
    if names != ['--all']:
        creatures = [c for c in creatures if c.species in names]
    creatures.sort(key=lambda c: RANK.index(c.rarity))

    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    bm = bmesh.new()
    col = bm.loops.layers.color.new("Col")
    x = 0.0
    spots = []
    for c in creatures:
        lo, hi = c.bounds()
        w = (hi[0] - lo[0]) * VOXEL
        x += w / 2
        _, h = add_creature(bm, col, c, x)
        spots.append((c, x, w, h))
        x += w / 2 + 0.8
    mesh = bpy.data.meshes.new("Creatures")
    bm.to_mesh(mesh)
    ob = bpy.data.objects.new("Creatures", mesh)
    ob.data.materials.append(material("Solid", False))
    ob.data.materials.append(material("Glow", True))
    s.collection.objects.link(ob)

    # rarity rings and the ground
    for c, cx, w, h in spots:
        if c.rarity in RING:
            bpy.ops.mesh.primitive_cylinder_add(radius=w * 0.48, depth=0.05, location=(cx, 0, 0.03))
            rm = bpy.data.materials.new(f"Ring{c.species}")
            rm.use_nodes = True
            bsdf = rm.node_tree.nodes["Principled BSDF"]
            bsdf.inputs["Base Color"].default_value = (*lin(RING[c.rarity]), 1)
            bsdf.inputs["Emission Color"].default_value = (*lin(RING[c.rarity]), 1)
            bsdf.inputs["Emission Strength"].default_value = 1.2
            bpy.context.object.data.materials.append(rm)
    bpy.ops.mesh.primitive_plane_add(size=400, location=(x / 2, 0, 0))
    gm = bpy.data.materials.new("Ground")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*lin((108, 184, 92)), 1)
    bpy.context.object.data.materials.append(gm)

    w = bpy.data.worlds.new("Sky")
    s.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.35, 0.6, 1.0, 1)
    bg.inputs["Strength"].default_value = 0.9
    sun = bpy.data.lights.new("Sun", 'SUN')
    sun.energy = 3.4
    sun.angle = math.radians(6)
    so = bpy.data.objects.new("Sun", sun)
    so.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    s.collection.objects.link(so)

    cam = bpy.data.cameras.new("Cam")
    co = bpy.data.objects.new("Cam", cam)
    s.collection.objects.link(co)
    s.camera = co
    tallest = max(h for _, _, _, h in spots)
    if len(spots) == 1:
        _, cx, wd, h = spots[0]
        cam.lens = 50
        size = max(wd, h)
        eye = Vector((cx - size * 0.55, -size * 2.3, h * 0.75))
        target = Vector((cx, 0, h * 0.45))
        s.render.resolution_x = s.render.resolution_y = 1000
    else:
        cam.type = 'ORTHO'
        cam.ortho_scale = x + 2
        eye = Vector((x / 2, -60, tallest * 0.5 + 14))
        target = Vector((x / 2, 0, tallest * 0.42))
        s.render.resolution_x = 2000
        s.render.resolution_y = max(400, int(2000 * (tallest * 1.25 + 1) / (x + 2)))
    co.location = eye
    co.rotation_euler = (target - eye).to_track_quat('-Z', 'Y').to_euler()

    s.render.engine = 'CYCLES'
    s.cycles.device = 'CPU'
    s.cycles.samples = 64
    s.cycles.use_denoising = True
    s.view_settings.view_transform = 'Standard'
    s.view_settings.exposure = -0.2
    s.render.filepath = out
    bpy.ops.render.render(write_still=True)


if __name__ == '__main__':
    main()
