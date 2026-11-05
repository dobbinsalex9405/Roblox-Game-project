"""Builds Hatchery Heist's creatures in Blender: polished voxel meshes with
moving parts, idle and walk animations, .glb and .fbx files, a manifest, and
review renders (a hero shot, an 8-view turntable and animated previews).

    pip install --target=/opt/bpy bpy==5.1.2          # once, about 1 GB
    PYTHONPATH=/opt/bpy python3 tools/art/blender/build.py OUT [--tier Common] [--only Chick,Frog] [--no-render] [--fast]

The shapes come from tools/art (creatures.py, legends.py), the same source
as the in-game VoxelArt boxes, so a creature's parts, pivots, size and
colours always match. Each creature lands in OUT/<id>/:

    <id>.glb, <id>.fbx   every part as its own mesh, under one joint (an
                         empty) per part, with the idle and walk clips
    <id>_palette.png     the colour texture every mesh samples
    meta.json            what the game needs (see manifest.md)
    hero.png             a three-quarter portrait
    turntable.png        eight views around it in one sheet
    idle.gif, walk.gif   the animations, looping

and OUT/manifest.json lists them all.

Blender frame: the game frame (Y up, front -Z, studs) turned to Blender's
Z up, so Blender (x, y, z) = game (x, -z, y) and the creature faces +Y. The
glTF and FBX exporters turn it back, so files open in the game frame."""
import argparse
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

from describe import RANK, creatures, describe  # noqa: E402

FPS = 30

# How each tier moves, mirrored from games/hatchery-heist/src/shared/
# CreatureLooks.luau so the previews show what the game plays.
LOOKS = {
    'Common': dict(bob=0.04, bobSpeed=0.9, hover=0, head=False, ears=False, tail=False, wings=False, pulse=False),
    'Uncommon': dict(bob=0.04, bobSpeed=0.9, hover=0, head=True, ears=False, tail=True, wings=False, pulse=False),
    'Rare': dict(bob=0.04, bobSpeed=0.8, hover=0, head=True, ears=True, tail=True, wings=True, pulse=False),
    'Ultra Rare': dict(bob=0.04, bobSpeed=0.8, hover=0, head=True, ears=True, tail=True, wings=True, pulse=True),
    'Epic': dict(bob=0.035, bobSpeed=0.7, hover=0, head=True, ears=True, tail=True, wings=True, pulse=True),
    'Legendary': dict(bob=0.03, bobSpeed=0.5, hover=0.08, head=True, ears=True, tail=True, wings=True, pulse=True),
    'Godly': dict(bob=0.03, bobSpeed=0.45, hover=0.1, head=True, ears=True, tail=True, wings=True, pulse=True),
}
RING = {'Epic': (177, 92, 255), 'Legendary': (255, 194, 26), 'Godly': (255, 77, 94)}


def lin(c):
    return tuple(((x / 255 + 0.055) / 1.055) ** 2.4 if x / 255 > 0.04045 else x / 255 / 12.92 for x in c)


def b_of(g):
    """game (x, y, z) -> Blender (x, -z, y)"""
    return (g[0], -g[2], g[1])


def hexs(rgb):
    return '%02X%02X%02X' % rgb


# ------------------------------------------------------------------ scene

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.fps = FPS
    s.unit_settings.system = 'NONE'
    return s


def palette_image(p, name, path):
    w, h = p.size()
    img = bpy.data.images.new(name, w, h, alpha=False)
    rows = p.pixels()
    flat = []
    for row in reversed(rows):  # Blender stores the bottom row first
        for rgb in row:
            flat += [rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, 1.0]
    img.pixels = flat
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    return img


def solid_material(img):
    m = bpy.data.materials.new('Voxel')
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes['Principled BSDF']
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = img
    tex.interpolation = 'Closest'
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = 0.6
    return m


def glow_material(img, rgb):
    """Glowing voxels: lit by their own light like Roblox Neon. The emission
    strength is a driver target for the pulse in previews."""
    m = bpy.data.materials.new(f'Glow_{hexs(rgb)}')
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes['Principled BSDF']
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = img
    tex.interpolation = 'Closest'
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Emission Color'])
    bsdf.inputs['Emission Strength'].default_value = 2.2
    return m


def mesh_object(md, p, mat, coll):
    me = bpy.data.meshes.new(md.name)
    me.from_pydata([b_of(v) for v in md.verts], [], md.tris)
    uv = me.uv_layers.new(name='UVMap')
    for poly, cell in zip(me.polygons, md.cells):
        u = p.uv(cell)
        for li in poly.loop_indices:
            uv.data[li].uv = u
    me.materials.append(mat)
    me.validate()
    me.update()
    ob = bpy.data.objects.new(md.name, me)
    coll.objects.link(ob)
    return ob


# ------------------------------------------------------------- the creature

def creature_scene(c, out_dir, coll):
    """Builds creature c in collection coll: one joint (an empty) per part at
    its pivot, parented like the game's motors, with that part's meshes
    under it. Returns (meta, root, joints, glow_mats)."""
    meta, p, parts = describe(c)
    img = palette_image(p, f'{c.species}_palette', os.path.join(out_dir, f'{c.species}_palette.png'))
    solid = solid_material(img)
    glow_mats = {}

    root = bpy.data.objects.new(c.species, None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.2
    coll.objects.link(root)

    joints, pivots = {}, {}
    for part, pivot, _ in parts:
        j = bpy.data.objects.new(part.name, None)
        j.empty_display_type = 'SPHERE'
        j.empty_display_size = 0.06
        coll.objects.link(j)
        joints[part.name], pivots[part.name] = j, Vector(b_of(pivot))
    for pm in meta['parts']:
        j, parent = joints[pm['name']], pm['parent']
        j.parent = joints[parent] if parent else root
        j.location = pivots[pm['name']] - (pivots[parent] if parent else Vector((0, 0, 0)))

    for part, pivot, meshes in parts:
        j = joints[part.name]
        for kind, rgb, md, name in meshes:
            if kind == 'glow':
                if rgb not in glow_mats:
                    glow_mats[rgb] = glow_material(img, rgb)
                mat = glow_mats[rgb]
            else:
                mat = solid
            ob = mesh_object(md, p, mat, coll)
            ob.name = ob.data.name = name
            lo_m, hi_m = md.bounds()
            # origin at the mesh's own centre, as Roblox places a MeshPart
            mid = Vector(b_of([(a + b) / 2 for a, b in zip(lo_m, hi_m)]))
            ob.data.transform(Matrix.Translation(-mid))
            ob.parent = j
            ob.location = mid - pivots[part.name]
    return meta, root, joints, glow_mats


# --------------------------------------------------------------- animation

def q(freq, seconds):
    """A frequency (cycles a second) rounded so a clip of `seconds` loops."""
    return max(1, round(freq * seconds)) / seconds


def rot(rx=0.0, ry=0.0, rz=0.0):
    """Rotation about the game's axes -> Blender euler (x, y, z)."""
    return (rx, -rz, ry)


def pose_fn(clip, look, height, seconds):
    """f(name, anim, t) -> (location offset (Blender), euler) or None. Same
    formulas as CreatureView.animate, with frequencies rounded to loop."""
    two_pi = math.pi * 2

    def idle(name, anim, t):
        if anim == 'body':
            bob = q(look['bobSpeed'], seconds)
            lift = height * (look['hover'] + look['bob'] * (0.5 + 0.5 * math.sin(t * bob * two_pi)))
            sway = math.sin(t * q(0.4 / two_pi, seconds) * two_pi) * 0.05 if look['head'] else 0
            return (0, 0, lift), rot(ry=sway)
        if anim == 'head' and look['head']:
            return (0, 0, 0), rot(rx=math.sin(t * q(1.1 / two_pi, seconds) * two_pi) * 0.07,
                                  ry=math.sin(t * q(0.5 / two_pi, seconds) * two_pi) * 0.2)
        if anim == 'ears' and look['ears']:
            k = t % (seconds / 1)
            k -= seconds * 0.55
            a = math.sin(k / 0.3 * math.pi) * 0.3 if 0 <= k < 0.3 else 0
            return (0, 0, 0), rot(rx=a)
        if anim == 'tail' and look['tail']:
            return (0, 0, 0), rot(ry=math.sin(t * q(6 / two_pi, seconds) * two_pi) * 0.35)
        if anim in ('wingL', 'wingR') and look['wings']:
            big = look['hover'] > 0
            f = q((2.6 if big else 4.5) / two_pi, seconds)
            a = math.sin(t * f * two_pi) * (0.45 if big else 0.25)
            return (0, 0, 0), rot(rz=a if anim == 'wingL' else -a)
        return None

    def walk(name, anim, t):
        # Two steps a second: a hop on each step, a side-to-side waddle, the
        # head steadying against it, the tail and wings swinging along.
        step = t * 2 * two_pi / 2  # radians, one hop per half second
        if anim == 'body':
            lift = height * (look['hover'] + 0.06 * abs(math.sin(step)))
            return (0, 0, lift), rot(rx=-0.06, rz=math.sin(step) * 0.10)
        if anim == 'head':
            return (0, 0, 0), rot(rx=0.04 + 0.04 * math.sin(step * 2), rz=-math.sin(step) * 0.07)
        if anim == 'tail':
            return (0, 0, 0), rot(ry=math.sin(step) * 0.4)
        if anim == 'ears':
            return (0, 0, 0), rot(rx=0.12 * math.sin(step * 2))
        if anim in ('wingL', 'wingR'):
            a = 0.18 + 0.12 * math.sin(step * 2)
            return (0, 0, 0), rot(rz=a if anim == 'wingL' else -a)
        return None

    return idle if clip == 'idle' else walk


def bake_clip(clip, c, meta, joints, height, glow_mats):
    look = LOOKS[c.rarity]
    seconds = meta['clips'][clip]['seconds']
    frames = int(seconds * FPS)
    fn = pose_fn(clip, look, height, seconds)
    rest = {n: Vector(j.location) for n, j in joints.items()}
    anims = {pm['name']: pm['anim'] for pm in meta['parts']}
    actions = {}
    for name, j in joints.items():
        j.animation_data_create()
        act = bpy.data.actions.new(f'{c.species}_{clip}_{name}')
        j.animation_data.action = act
        moved = False
        for f in range(frames + 1):
            t = f / FPS
            r = fn(name, anims[name], t)
            if r is None:
                loc, eul = (0, 0, 0), (0, 0, 0)
            else:
                loc, eul = r
                moved = True
            j.location = rest[name] + Vector(loc)
            j.rotation_euler = eul
            j.keyframe_insert('location', frame=f + 1)
            j.keyframe_insert('rotation_euler', frame=f + 1)
        j.location = rest[name]
        j.rotation_euler = (0, 0, 0)
        actions[name] = (act, moved)
    # blink: the eyes close for a few frames (the game hides them)
    if 'eyes' in joints:
        j = joints['eyes']
        act = actions['eyes'][0]
        for f, sc in ((int(1.5 * FPS), 1.0), (int(1.5 * FPS) + 2, 0.08), (int(1.5 * FPS) + 4, 1.0)):
            j.scale = (1, 1, sc)
            j.keyframe_insert('scale', frame=f + 1)
        j.scale = (1, 1, 1)
    # glow pulse (previews only: glTF and Roblox take no material keys)
    if look['pulse']:
        for rgb, m in glow_mats.items():
            bsdf = m.node_tree.nodes['Principled BSDF']
            inp = bsdf.inputs['Emission Strength']
            for f in range(0, frames + 1, 3):
                k = 0.5 + 0.5 * math.sin(f / FPS * q(2.2 / (2 * math.pi), seconds) * 2 * math.pi)
                inp.default_value = 1.6 + 2.4 * k
                inp.keyframe_insert('default_value', frame=f + 1)
    return frames


def clear_anim(joints, glow_mats):
    for j in joints.values():
        if j.animation_data:
            j.animation_data_clear()
    for m in glow_mats.values():
        if m.node_tree.animation_data:
            m.node_tree.animation_data_clear()


def push_nla(joints, clip):
    """Move each joint's current action into an NLA track named after the
    clip, so the exporters write every clip."""
    for j in joints.values():
        ad = j.animation_data
        if ad and ad.action:
            act = ad.action
            tr = ad.nla_tracks.new()
            tr.name = clip
            st = tr.strips.new(clip, 1, act)
            st.name = clip
            ad.action = None


# ------------------------------------------------------------------ export

def export_files(out_dir, c, coll, joints):
    for ob in bpy.context.scene.objects:
        ob.select_set(ob.name in coll.objects)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(out_dir, f'{c.species}.glb'),
        export_format='GLB',
        use_selection=True,
        export_animations=True,
        export_animation_mode='NLA_TRACKS',
        export_force_sampling=True,
        export_yup=True,
        export_apply=False,
        export_image_format='AUTO',
        export_extras=False,
    )
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(out_dir, f'{c.species}.fbx'),
        use_selection=True,
        object_types={'EMPTY', 'MESH'},
        apply_unit_scale=True,
        apply_scale_options='FBX_SCALE_UNITS',
        axis_forward='-Z',
        axis_up='Y',
        bake_anim=True,
        bake_anim_use_nla_strips=True,
        bake_anim_use_all_actions=False,
        path_mode='COPY',
        embed_textures=True,
    )


# ------------------------------------------------------------------ render

def stage(s, meta, fast):
    """Sky, sun, a soft green ground and a camera, sized to the creature."""
    w = bpy.data.worlds.new('Sky')
    s.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes['Background']
    bg.inputs['Color'].default_value = (0.42, 0.62, 1.0, 1)
    bg.inputs['Strength'].default_value = 0.85
    sun = bpy.data.lights.new('Sun', 'SUN')
    sun.energy = 3.2
    sun.angle = math.radians(8)
    so = bpy.data.objects.new('Sun', sun)
    so.rotation_euler = (math.radians(48), 0, math.radians(150))
    s.collection.objects.link(so)
    fill = bpy.data.lights.new('Fill', 'SUN')
    fill.energy = 0.6
    fo = bpy.data.objects.new('Fill', fill)
    fo.rotation_euler = (math.radians(65), 0, math.radians(-40))
    s.collection.objects.link(fo)

    size = meta['sizeStuds']
    big = max(size)
    bpy.ops.mesh.primitive_plane_add(size=big * 40, location=(0, 0, 0))
    ground = bpy.context.object
    gm = bpy.data.materials.new('Ground')
    gm.use_nodes = True
    gb = gm.node_tree.nodes['Principled BSDF']
    gb.inputs['Base Color'].default_value = (*lin((112, 190, 98)), 1)
    gb.inputs['Roughness'].default_value = 0.9
    ground.data.materials.append(gm)
    if meta['rarity'] in RING:
        bpy.ops.mesh.primitive_cylinder_add(radius=max(size[0], size[2]) * 0.48, depth=0.04, location=(0, 0, 0.02))
        rm = bpy.data.materials.new('Ring')
        rm.use_nodes = True
        rb = rm.node_tree.nodes['Principled BSDF']
        rb.inputs['Base Color'].default_value = (*lin(RING[meta['rarity']]), 1)
        rb.inputs['Emission Color'].default_value = (*lin(RING[meta['rarity']]), 1)
        rb.inputs['Emission Strength'].default_value = 1.2
        bpy.context.object.data.materials.append(rm)

    cam = bpy.data.cameras.new('Cam')
    cam.lens = 60
    co = bpy.data.objects.new('Cam', cam)
    s.collection.objects.link(co)
    s.camera = co

    s.render.engine = 'CYCLES'
    s.cycles.device = 'CPU'
    s.cycles.samples = 12 if fast else 48
    s.cycles.use_denoising = True
    s.cycles.max_bounces = 4
    s.view_settings.view_transform = 'Standard'
    s.view_settings.exposure = -0.15
    s.render.film_transparent = False
    return co


def aim(co, meta, yaw, dist_k=1.0, pitch=18):
    """Camera on a circle around the creature at `yaw` degrees (0 = straight
    at its face), framing its whole height."""
    sx, sy, sz = meta['sizeStuds']
    lift = meta['sizeStuds'][1] * LOOKS[meta['rarity']]['hover']
    h = sy + lift
    r = max(h, sx, sz) * 2.4 * dist_k
    a = math.radians(yaw)
    pt = math.radians(pitch)
    target = Vector((0, 0, lift + h * 0.46))
    eye = target + Vector((math.sin(a) * math.cos(pt), math.cos(a) * math.cos(pt), math.sin(pt))) * r
    co.location = eye
    co.rotation_euler = (target - eye).to_track_quat('-Z', 'Y').to_euler()


def render_still(s, path, res):
    s.render.resolution_x = s.render.resolution_y = res
    s.render.filepath = path
    bpy.ops.render.render(write_still=True)


def sheet(paths, cols, out):
    from PIL import Image
    ims = [Image.open(p) for p in paths]
    w, h = ims[0].size
    rows = -(-len(ims) // cols)
    sh = Image.new('RGB', (w * cols, h * rows), (255, 255, 255))
    for i, im in enumerate(ims):
        sh.paste(im, ((i % cols) * w, (i // cols) * h))
    sh.save(out, optimize=True)


def gif(frames_dir, out, fps):
    subprocess.run([
        'ffmpeg', '-loglevel', 'error', '-y', '-framerate', str(fps), '-i', os.path.join(frames_dir, '%04d.png'),
        '-vf', 'split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4',
        '-loop', '0', out,
    ], check=True)


def renders(s, co, c, meta, joints, glow_mats, out_dir, fast, root):
    tmp = tempfile.mkdtemp(prefix='hhren-')
    try:
        s.frame_set(1)
        aim(co, meta, 30)
        render_still(s, os.path.join(out_dir, 'hero.png'), 480 if fast else 900)
        views = []
        for i in range(8):
            root.rotation_euler = (0, 0, math.radians(-45 * i))
            aim(co, meta, 0, pitch=14)
            pth = os.path.join(tmp, f'turn{i}.png')
            render_still(s, pth, 200 if fast else 320)
            views.append(pth)
        root.rotation_euler = (0, 0, 0)
        sheet(views, 4, os.path.join(out_dir, 'turntable.png'))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def render_clip(s, co, meta, clip, frames, out_dir, fast):
    tmp = tempfile.mkdtemp(prefix='hhclip-')
    try:
        aim(co, meta, 30)
        step = 3  # 10 frames a second in the gif
        s.render.resolution_x = s.render.resolution_y = 200 if fast else 280
        s.cycles.samples = 8 if fast else 16
        n = 0
        for f in range(1, frames + 1, step):
            s.frame_set(f)
            s.render.filepath = os.path.join(tmp, '%04d.png' % n)
            bpy.ops.render.render(write_still=True)
            n += 1
        gif(tmp, os.path.join(out_dir, f'{clip}.gif'), FPS // step)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


# -------------------------------------------------------------------- main

def build_one(c, out_root, do_render, fast):
    out_dir = os.path.join(out_root, c.species)
    os.makedirs(out_dir, exist_ok=True)
    s = reset()
    coll = bpy.data.collections.new(c.species)
    s.collection.children.link(coll)
    meta, root, joints, glow_mats = creature_scene(c, out_dir, coll)
    height = meta['heightStuds']

    frames = {}
    for clip in ('idle', 'walk'):
        frames[clip] = bake_clip(clip, c, meta, joints, height, glow_mats)
        push_nla(joints, clip)
        for m in glow_mats.values():
            if m.node_tree.animation_data:
                m.node_tree.animation_data_clear()
    export_files(out_dir, c, coll, joints)

    if do_render:
        co = stage(s, meta, fast)
        # stills at rest pose, with glow at its middle strength
        for j in joints.values():
            j.animation_data_clear()
        renders(s, co, c, meta, joints, glow_mats, out_dir, fast, root)
        for clip in ('idle', 'walk'):
            clear_anim(joints, glow_mats)
            bake_clip(clip, c, meta, joints, height, glow_mats)
            s.frame_start, s.frame_end = 1, frames[clip]
            render_clip(s, co, meta, clip, frames[clip], out_dir, fast)

    with open(os.path.join(out_dir, 'meta.json'), 'w') as f:
        json.dump(meta, f, indent=1)
    return meta


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out')
    ap.add_argument('--tier', action='append')
    ap.add_argument('--only')
    ap.add_argument('--no-render', action='store_true')
    ap.add_argument('--fast', action='store_true')
    a = ap.parse_args()
    out = os.path.abspath(a.out)
    os.makedirs(out, exist_ok=True)
    cs = creatures(a.tier, set(a.only.split(',')) if a.only else None)
    metas = []
    for c in cs:
        m = build_one(c, out, not a.no_render, a.fast)
        print(f"{c.species:16s} {c.rarity:10s} {m['tris']:6d} tris  {len(m['parts'])} parts", flush=True)
        metas.append(m)
    path = os.path.join(out, 'manifest.json')
    old = {}
    if os.path.exists(path):
        with open(path) as f:
            old = {m['id']: m for m in json.load(f)['creatures']}
    for m in metas:
        old[m['id']] = m
    allm = sorted(old.values(), key=lambda m: (RANK.index(m['rarity']), m['id']))
    with open(path, 'w') as f:
        json.dump({'version': 1, 'creatures': allm}, f, indent=1)


if __name__ == '__main__':
    main()
