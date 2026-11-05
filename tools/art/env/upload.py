"""Uploads Hatchery Heist's outdoor nature to Roblox through Open Cloud: one
Model asset per nature model (its .fbx) and one image asset per skybox face
and for the grass tile. Records the ids in tools/art/env/assets.json; then
luau.py writes them into EnvArt.luau.

    python3 tools/art/env/upload.py MODELS_DIR IMAGES_DIR [--only PuffOakL,SkyboxFt] [--dry-run]

MODELS_DIR is build.py's output (MODELS_DIR/<id>/<id>.fbx); IMAGES_DIR holds
SkyboxBk.png ... SkyboxUp.png and Grass.png (sky.py and grass.py). Anything
whose content has not changed since its last upload is skipped. A model
already uploaded gets a new version of the same asset, so its id never
changes; a changed image becomes a new image (Roblox images have no
versions).

Same key, group and rules as the creature meshes (tools/art/blender/
upload.py, whose Open Cloud helpers this uses): ROBLOX_API_KEY is the Hatchery
Heist Staging key with Assets read and write; it is never printed; requests
only go to Roblox.
"""
import argparse
import hashlib
import json
import os
import sys
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'blender'))

import upload as cloud  # noqa: E402  (tools/art/blender/upload.py)

ASSETS = os.path.join(HERE, 'assets.json')
MANIFEST = os.path.join(HERE, 'env.json')
IMAGES = ['SkyboxBk', 'SkyboxDn', 'SkyboxFt', 'SkyboxLf', 'SkyboxRt', 'SkyboxUp', 'Grass']


def multipart(request, path, ctype):
    b = uuid.uuid4().hex
    with open(path, 'rb') as f:
        data = f.read()
    parts = [
        f'--{b}\r\nContent-Disposition: form-data; name="request"\r\nContent-Type: application/json\r\n\r\n'.encode(),
        json.dumps(request).encode(), b'\r\n',
        (f'--{b}\r\nContent-Disposition: form-data; name="fileContent"; filename="{os.path.basename(path)}"\r\n'
         f'Content-Type: {ctype}\r\n\r\n').encode(),
        data, f'\r\n--{b}--\r\n'.encode(),
    ]
    return b''.join(parts), f'multipart/form-data; boundary={b}'


def digest(obj=None, path=None):
    h = hashlib.sha256()
    if path:
        with open(path, 'rb') as f:
            h.update(f.read())
    else:
        h.update(json.dumps(obj, sort_keys=True).encode())
    return h.hexdigest()[:16]


def load():
    if os.path.exists(ASSETS):
        with open(ASSETS) as f:
            return json.load(f)
    return {'note': 'Roblox asset ids for the outdoor nature models and images (tools/art/env/upload.py).',
            'models': {}, 'images': {}}


def save(data):
    with open(ASSETS, 'w') as f:  # after every upload, so a failure keeps the ids made so far
        json.dump(data, f, indent=1, sort_keys=True)
        f.write('\n')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('models')
    ap.add_argument('images')
    ap.add_argument('--only')
    ap.add_argument('--dry-run', action='store_true')
    a = ap.parse_args()
    key = os.environ.get('ROBLOX_API_KEY', '')
    if not key and not a.dry_run:
        raise SystemExit('ROBLOX_API_KEY is not set')
    with open(MANIFEST) as f:
        manifest = json.load(f)
    want = set(a.only.split(',')) if a.only else None
    data = load()
    group = None if a.dry_run else cloud.owner_group(key)

    for mid in sorted(manifest):
        if want and mid not in want:
            continue
        fbx = os.path.join(a.models, mid, f'{mid}.fbx')
        if not os.path.isfile(fbx):
            raise SystemExit(f'{mid}: no {fbx}')
        h = digest(manifest[mid])
        have = data['models'].get(mid)
        if have and have.get('hash') == h:
            print(f'{mid}: unchanged ({have["assetId"]})')
            continue
        if a.dry_run:
            print(f'{mid}: would {"update " + str(have["assetId"]) if have else "create"} from {fbx}')
            continue
        if have:
            body, ctype = multipart({'assetId': str(have['assetId'])}, fbx, 'model/fbx')
            op = cloud.call('PATCH', f'{cloud.API}/assets/{have["assetId"]}', key, body, ctype)
        else:
            body, ctype = multipart({
                'assetType': 'Model',
                'displayName': f'HH nature {mid}',
                'description': f'Hatchery Heist outdoor nature {mid} (tools/art/env)',
                'creationContext': {'creator': {'groupId': group}},
            }, fbx, 'model/fbx')
            op = cloud.call('POST', f'{cloud.API}/assets', key, body, ctype)
        res = cloud.wait(op, key)
        asset = int(res.get('assetId') or have['assetId'])
        data['models'][mid] = {'assetId': asset, 'version': res.get('revisionId'), 'hash': h}
        print(f'{mid}: asset {asset}', flush=True)
        save(data)

    for name in IMAGES:
        if want and name not in want:
            continue
        png = os.path.join(a.images, f'{name}.png')
        if not os.path.isfile(png):
            raise SystemExit(f'{name}: no {png}')
        h = digest(path=png)
        have = data['images'].get(name)
        if have and have.get('hash') == h:
            print(f'{name}: unchanged ({have["assetId"]})')
            continue
        if a.dry_run:
            print(f'{name}: would upload {png}')
            continue
        body, ctype = multipart({
            'assetType': 'Decal',
            'displayName': f'HH {name}',
            'description': f'Hatchery Heist {name} (tools/art/env)',
            'creationContext': {'creator': {'groupId': group}},
        }, png, 'image/png')
        res = cloud.wait(cloud.call('POST', f'{cloud.API}/assets', key, body, ctype), key)
        data['images'][name] = {'assetId': int(res['assetId']), 'hash': h}
        print(f'{name}: asset {res["assetId"]}', flush=True)
        save(data)
    if not a.dry_run:
        save(data)


if __name__ == '__main__':
    main()
