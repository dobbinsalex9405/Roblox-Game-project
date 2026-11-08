"""Uploads Hatchery Heist's creature meshes to Roblox through Open Cloud, as
one Model asset per creature, and records the asset ids in assets.json.

    python3 tools/art/blender/upload.py DIR [--only Chick,Frog] [--textures-only] [--dry-run]
    python3 tools/art/blender/upload.py DIR --thumbs [--only Chick,Frog] [--dry-run]

DIR is build.py's output (DIR/<id>/<id>.fbx). A creature already in
assets.json gets a new version of the same asset, so its id never changes;
a new creature gets a new asset. Afterwards run luau.py so the game knows
the ids.

Each creature's colours are its palette PNG, uploaded as an **Image** asset
(never a Decal: MeshPart.TextureID needs an image id, and a decal id draws
the creature grey with "Asset type does not match requested type").
--textures-only re-uploads just the palettes of creatures that already have
a model asset.

--thumbs uploads the Hatchery Book pictures instead (build.py --thumbs:
DIR/<id>/<id>_thumb.png and thumb.json), each as an Image asset, and
records its id with the art fingerprint it was drawn from under "thumbs".
A picture is a new asset each time (an Image cannot take a new version).

The API key comes from ROBLOX_API_KEY (the Hatchery Heist Staging key, with
the Assets API "asset:read" and "asset:write" permissions). It is never
printed. The assets are created for the group that owns the Staging
experience (looked up from ops/environments.json), because a game can only
load assets its own owner made. Requests only ever go to Roblox."""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
ASSETS = os.path.join(HERE, 'assets.json')
API = 'https://apis.roblox.com/assets/v1'
CLOUD_UNIVERSE = 'https://apis.roblox.com/cloud/v2/universes'
GAMES = 'https://games.roblox.com/v1/games'
GAME = 'hatchery-heist'
TRIES = 5  # per request; waits 2, 4, 8, 16 s between them
RETRY_CODES = (429, 500, 502, 503, 504)


def call(method, url, key=None, body=None, ctype=None, soft=False):
    """JSON from a Roblox API. soft: a 4xx raises LookupError instead of
    stopping, so the caller can try another way."""
    assert url.startswith('https://apis.roblox.com/') or (url.startswith('https://games.roblox.com/') and not key)
    req = urllib.request.Request(url, data=body, method=method)
    if key:
        req.add_header('x-api-key', key)
    if ctype:
        req.add_header('content-type', ctype)
    for attempt in range(TRIES):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.loads(r.read() or b'{}')
        except urllib.error.HTTPError as e:
            text = e.read().decode('utf-8', 'replace')[:500]
            if e.code in RETRY_CODES and attempt < TRIES - 1:
                time.sleep(2 ** attempt * 2)
                continue
            if soft and 400 <= e.code < 500:
                raise LookupError(f'HTTP {e.code}')
            raise SystemExit(f'{method} {url.split("?")[0]} failed: HTTP {e.code} {text}')
        except (urllib.error.URLError, ConnectionError, TimeoutError) as e:
            # the network, not Roblox's answer: a refused or reset connection
            # or a timeout (run 42096155779 stopped on "Connection refused"
            # after 11 creatures). Retried like a 5xx; a retried create can at
            # worst leave one unused palette image behind.
            if attempt < TRIES - 1:
                print(f'{method} {url.split("?")[0]}: {e}; retrying', flush=True)
                time.sleep(2 ** attempt * 2)
                continue
            raise SystemExit(f'{method} {url.split("?")[0]} failed after {TRIES} tries: {e}')


def multipart(request, path, ctype='model/fbx'):
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


def owner_group(key):
    """The group that owns the Staging experience, which must also own the
    uploaded meshes. Asked of Open Cloud first (the key's own universe), then
    of the public games API (no key sent there). develop.roblox.com's
    universe lookup, used before, now answers 404."""
    if os.environ.get('ROBLOX_GROUP_ID', '').isdigit():
        return os.environ['ROBLOX_GROUP_ID']
    with open(os.path.join(ROOT, 'ops', 'environments.json')) as f:
        uni = json.load(f)[GAME]['staging']['universeId']
    try:
        info = call('GET', f'{CLOUD_UNIVERSE}/{uni}', key, soft=True)
        group = info.get('group', '')
        if group.startswith('groups/'):
            return group.split('/', 1)[1]
        if info.get('user'):
            raise SystemExit('the Staging experience is owned by a user, not a group; see ops/ASSETS.md')
    except LookupError as e:
        print(f'Open Cloud universe lookup unavailable ({e}); asking the games API')
    data = call('GET', f'{GAMES}?universeIds={uni}').get('data') or []
    creator = data[0].get('creator', {}) if data else {}
    if creator.get('type') != 'Group' or not creator.get('id'):
        raise SystemExit('could not find the group that owns the Staging experience; see ops/ASSETS.md')
    return str(creator['id'])


def wait(op, key):
    path = op.get('path') or f"operations/{op['operationId']}"
    for _ in range(60):
        if op.get('done'):
            return op['response']
        time.sleep(2)
        op = call('GET', f'{API}/{path}', key)
    raise SystemExit(f'upload did not finish: {path}')


def load():
    if os.path.exists(ASSETS):
        with open(ASSETS) as f:
            return json.load(f)
    return {'note': 'Roblox Model asset ids for each creature\'s meshes (tools/art/blender/upload.py).', 'models': {}}


def save(data):
    with open(ASSETS, 'w') as f:  # after every upload, so a failure keeps the ids made so far
        json.dump(data, f, indent=1, sort_keys=True)
        f.write('\n')


def upload_thumbs(a, key, data):
    ids = sorted(d for d in os.listdir(a.dir) if os.path.isfile(os.path.join(a.dir, d, f'{d}_thumb.png')))
    if a.only:
        ids = [i for i in ids if i in set(a.only.split(','))]
    if not ids:
        raise SystemExit(f'no pictures in {a.dir} (run build.py --thumbs first)')
    group = None if a.dry_run else owner_group(key)
    pics = data.setdefault('thumbs', {})
    for sid in ids:
        png = os.path.join(a.dir, sid, f'{sid}_thumb.png')
        with open(os.path.join(a.dir, sid, 'thumb.json')) as f:
            source = json.load(f)['source']
        if a.dry_run:
            print(f'{sid}: would upload {png} as an Image (art {source})')
            continue
        body, ctype = multipart({
            'assetType': 'Image',
            'displayName': f'HH {sid} book',
            'description': f'Hatchery Heist creature {sid}, Hatchery Book picture (tools/art/blender)',
            'creationContext': {'creator': {'groupId': group}},
        }, png, 'image/png')
        img = wait(call('POST', f'{API}/assets', key, body, ctype), key)
        kind = str(img.get('assetType', ''))
        if 'IMAGE' not in kind.upper():
            raise SystemExit(f'{sid}: picture came back as {kind or "an unknown type"}, not an Image')
        pics[sid] = {'imageId': int(img['assetId']), 'source': source}
        print(f'{sid}: picture {img["assetId"]}', flush=True)
        save(data)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('dir')
    ap.add_argument('--only')
    ap.add_argument('--textures-only', action='store_true')
    ap.add_argument('--thumbs', action='store_true', help='the Hatchery Book pictures (see the top)')
    ap.add_argument('--dry-run', action='store_true')
    a = ap.parse_args()
    key = os.environ.get('ROBLOX_API_KEY', '')
    if not key and not a.dry_run:
        raise SystemExit('ROBLOX_API_KEY is not set')
    data = load()
    if a.thumbs:
        upload_thumbs(a, key, data)
        return
    ids = sorted(d for d in os.listdir(a.dir) if os.path.isfile(os.path.join(a.dir, d, f'{d}.fbx')))
    if a.only:
        ids = [i for i in ids if i in set(a.only.split(','))]
    group = None if a.dry_run else owner_group(key)
    for sid in ids:
        fbx = os.path.join(a.dir, sid, f'{sid}.fbx')
        if not os.path.isfile(os.path.join(a.dir, sid, f'{sid}_palette.png')):
            raise SystemExit(f'{sid}: no {sid}_palette.png next to the fbx')
        have = data['models'].get(sid)
        if a.dry_run:
            what = 'keep' if a.textures_only and have else ('update ' + str(have['assetId'])) if have else 'create'
            print(f'{sid}: would {what} model from {fbx} and upload its palette as an Image')
            continue
        if a.textures_only and have:
            res = {'assetId': have['assetId'], 'revisionId': have.get('version')}
        elif have:
            body, ctype = multipart({'assetId': str(have['assetId'])}, fbx)
            op = call('PATCH', f'{API}/assets/{have["assetId"]}', key, body, ctype)
        else:
            body, ctype = multipart({
                'assetType': 'Model',
                'displayName': f'HH {sid}',
                'description': f'Hatchery Heist creature {sid} (tools/art/blender)',
                'creationContext': {'creator': {'groupId': group}},
            }, fbx)
            op = call('POST', f'{API}/assets', key, body, ctype)
        if not (a.textures_only and have):
            res = wait(op, key)
        asset = int(res.get('assetId') or have['assetId'])
        # the colours: the palette image as its own asset, set as each
        # MeshPart's TextureID by the game (the FBX carries no texture)
        png = os.path.join(a.dir, sid, f'{sid}_palette.png')
        body, ctype = multipart({
            'assetType': 'Image',
            'displayName': f'HH {sid} palette',
            'description': f'Hatchery Heist creature {sid} colours (tools/art/blender)',
            'creationContext': {'creator': {'groupId': group}},
        }, png, 'image/png')
        tex = wait(call('POST', f'{API}/assets', key, body, ctype), key)
        kind = str(tex.get('assetType', ''))
        if 'IMAGE' not in kind.upper():
            raise SystemExit(f'{sid}: palette came back as {kind or "an unknown type"}, not an Image')
        data['models'][sid] = {'assetId': asset, 'version': res.get('revisionId'),
                               'textureId': int(tex['assetId']), 'textureType': 'Image'}
        print(f'{sid}: asset {asset}, texture {tex["assetId"]}', flush=True)
        save(data)


if __name__ == '__main__':
    main()
