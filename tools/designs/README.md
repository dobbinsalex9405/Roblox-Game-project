# Design viewer

One place to look at every model the studio has: all creatures, the
buildings, props, eggs, scenery and maps the games build, and every design a
Blender thread makes. It opens like File Explorer (folders, a path bar, back
and up buttons, search) and shows each design in 3D: drag to turn, scroll to
zoom, play its animations, compare versions.

It is a folder that opens in any browser straight from disk: no server, no
install. On Alex's laptop it lives in `C:\Users\dobbi\Loop Lab Designs`, with
a "Loop Lab Designs" shortcut on the desktop.

## Adding a design (any thread)

Drop it in the shared designs folder, in a folder named after it:

```
/mnt/project-files/designs/<What it is>/<Game>/<optional subfolders>/<Design name>/
    <anything>.glb      required; several .glb files = versions, labelled by file name
    meta.json           optional; its plain values are shown as details
    *.png *.gif *.jpg   optional; shown beside the model (up to 6)
```

- Top folders: Creatures, Characters, Eggs, Buildings, World, Nature,
  Decor and props, Plots and bases, Maps, Concepts (anything else is fine
  too; it sorts after these).
- Creatures: `Creatures/Hatchery Heist/<Tier>/<Species>/`, tier spelled as in
  config and the species as its config id. The design then sits next to
  what the game draws today ("In game now") as another version.
- A last folder with only pictures (a concept render) is a picture design.
- Models face -Z, like Roblox. Meshes named `*_lod1` are hidden. Draco
  compressed .glb files work.

Then rebuild (below), and copy the result to the laptop.

## Rebuilding

```sh
tools/designs/build.sh               # builds the games, exports their models, builds the viewer
tools/designs/build.sh --skip-games  # only dropped designs changed: reuse the last export
```

Output: `/mnt/project-files/design-viewer/` in a cloud session (else
`build/design-viewer/`). File names are content hashes, so copying the
folder to the laptop again only copies what changed. Copy the whole folder
over `C:\Users\dobbi\Loop Lab Designs` (Remote Control or the folder tools).
Old files left there are harmless: the catalog only points at current ones.

## How it works

| File | What it is |
| --- | --- |
| `export.luau` | Boots each built game headless (server, one player, their client, a few seconds of play) and saves every Model in the Workspace as parts; copies of one model are listed once with a count. Adds Hatchery Heist's creatures from `VoxelArt.luau`. Writes `build/designs/game-models.json`. |
| `catalog.json` | Which folder each game model goes in, and its display name. A model no rule matches lands in Other, so nothing is hidden. |
| `build.mjs` | Merges the game models with the dropped designs and writes the viewer folder. Each .glb becomes a small script (`data/models/<hash>.js`), because a page opened from disk may run scripts beside it but not fetch files. |
| `viewer/src/viewer.js` | The viewer (three.js). `cd viewer && npm ci && npm run bundle` rebuilds `viewer/dist/` after a change; commit `dist/` with it. |
| `viewer/index.html`, `viewer.css`, `icon.ico` | The page, its styles and the desktop icon (`make-icon.py`). |

CI runs the export and the build on every pull request, so a game change
that breaks them is caught.
