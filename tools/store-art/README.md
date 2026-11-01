# Store art

Source and renderer for every game's store images (icon and thumbnails) and
the Loop Lab Games Community banner. One shared style, taken from the studio
emblem (`branding/emblem.svg`): flat vector, thick dark outlines, the
emblem's orange-gold and cyan, and Lilita One / Fredoka type.

```
src/parts/            shared pieces: emblem mark, studio badge, coins, sparkles, the blocky avatar
src/<game>/           that game's parts and its icon.svg, thumbnail-N.svg
src/community-banner.svg
jobs.json             what to render, and where each output goes
render.mjs            inlines shared parts and fonts, writes the SVG and the PNG
fonts/                Lilita One, Fredoka (SIL Open Font License 1.1)
```

Outputs land next to the game: `games/<game>/store/icon.{svg,png}` (512 x 512)
and `thumbnail-N.{svg,png}` (1920 x 1080), and `branding/community-banner*`.
The committed SVGs are self-contained (fonts embedded), so they open anywhere.

## Render

Needs Node 18+ and Playwright with Chromium.

```sh
node tools/store-art/render.mjs              # everything
node tools/store-art/render.mjs depthbound   # jobs whose name contains "depthbound"
```

Depthbound's block grid is generated: after changing
`src/depthbound/make_strata.py`, run it with `python3`, then render.

## Rules for new art

- Show only what the game really has (mechanics, creature and ore names,
  HUD text). No brands, no Robux symbols, no "free" claims.
- Icons: one subject, no text, readable at 50 px. Check with a 150 px and a
  50 px downscale before shipping.
- Thumbnails: keep the headline in the top two thirds; Roblox can cover the
  bottom edge with player counts. At least 2 per game so thumbnail
  personalization can run.
- Every thumbnail carries the studio badge; every icon stays text-free.
