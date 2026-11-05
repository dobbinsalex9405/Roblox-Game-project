"""Uploads Hatchery Heist's creature meshes to Roblox through Open Cloud, as
one Model asset per creature, and records the asset ids in assets.json.

    python3 tools/art/blender/upload.py DIR [--only Chick,Frog] [--dry-run]

DIR is build.py's output (DIR/<id>/<id>.fbx). A creature already in
assets.json gets a new version of the same asset, so its id never changes;
a new creature gets a new asset. Afterwards run luau.py so the game knows
the ids.

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


def call(method, url, key=None, body=None, ctype=None, soft=False):
    """JSON from a Roblox API. soft: a 4xx raises LookupError instead of
    stopping, so the caller can try another way."""
    assert url.startswith('https://apis.roblox.com/') or (url.startswith('https://games.roblox.com/') and not key)
    req = urllib.request.Request(url, data=body, method=method)
    if key:
        req.add_header('x-api-key', key)
    if ctype:
        req.add_header('content-type', ctype)
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.loads(r.read() or b'{}')
        except urllib.error.HTTPError as e:
            text = e.read().decode('utf-8', 'replace')[:500]
            if e.code in (429, 500, 502, 503) and attempt < 4:
                time.sleep(2 ** attempt * 2)
                continue
            if soft and 400 <= e.code < 500:
                raise LookupError(f'HTTP {e.code}')
            raise SystemExit(f'{method} {url.split("?")[0]} failed: HTTP {e.code} {text}')


def multipart(request, path):
    b = uuid.uuid4().hex
    with open(path, 'rb') as f:
        data = f.read()
    parts = [
        f'--{b}\r\nContent-Disposition: form-data; name="request"\r\nContent-Type: application/json\r\n\r\n'.encode(),
        json.dumps(request).encode(), b'\r\n',
        (f'--{b}\r\nContent-Disposition: form-data; name="fileContent"; filename="{os.path.basename(path)}"\r\n'
         'Content-Type: model/fbx\r\n\r\n').encode(),
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('dir')
    ap.add_argument('--only')
    ap.add_argument('--dry-run', action='store_true')
    a = ap.parse_args()
    key = os.environ.get('ROBLOX_API_KEY', '')
    if not key and not a.dry_run:
        raise SystemExit('ROBLOX_API_KEY is not set')
    data = load()
    ids = sorted(d for d in os.listdir(a.dir) if os.path.isfile(os.path.join(a.dir, d, f'{d}.fbx')))
    if a.only:
        ids = [i for i in ids if i in set(a.only.split(','))]
    group = None if a.dry_run else owner_group(key)
    for sid in ids:
        fbx = os.path.join(a.dir, sid, f'{sid}.fbx')
        have = data['models'].get(sid)
        if a.dry_run:
            print(f'{sid}: would {"update " + str(have["assetId"]) if have else "create"} from {fbx}')
            continue
        if have:
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
        res = wait(op, key)
        asset = int(res.get('assetId') or have['assetId'])
        data['models'][sid] = {'assetId': asset, 'version': res.get('revisionId')}
        print(f'{sid}: asset {asset}', flush=True)
        with open(ASSETS, 'w') as f:  # after every upload, so a failure keeps the ids made so far
            json.dump(data, f, indent=1, sort_keys=True)
            f.write('\n')


if __name__ == '__main__':
    main()
