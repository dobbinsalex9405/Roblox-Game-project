# Store art: what to upload, and where

Every game has a store icon and two thumbnails, plus a cover for the Loop Lab
Games Community. The files are in this repo and in the project folder
`store/<game>/`. Upload them yourself in the Creator Dashboard (Roblox has no
API for icons or thumbnails). Each upload goes through Roblox moderation,
which usually takes a few minutes.

## Community

| What | File | Where |
|------|------|-------|
| Emblem (icon) | `branding/emblem-1024.png` | Configure Community → Information |
| Cover (banner) | `branding/community-banner-1440x456.png` | Configure Community → Information |
| Description | `branding/community-description.txt` | Configure Community → Information |

(Roblox renames these settings now and then. If a label differs, look for the
Community's settings page with the emblem and description on it.)

The banner is 1440 x 456 (the 60:19 shape Roblox uses for Community banners).
If it looks soft after upload, try `community-banner-2880x912.png`.

## Each game

Upload to the game's **Production** experience at launch. Staging can use
the same files, so playtest invites look right.

1. Open https://create.roblox.com/dashboard/creations and pick the game.
2. **Configurations → Places**, then the start place (the one with a star).
3. **Icon**: media type Image → Change → `games/<game>/store/icon.png` →
   Save Changes.
4. **Thumbnails**:
   - On the **Experience Details Page** tab, add `thumbnail-1.png`, then
     `thumbnail-2.png`.
   - On the **Home Page** tab, click **Edit active thumbnails**, turn on both,
     Save, then **Start**. With two or more active thumbnails, Roblox shows each
     player the one that works best. Leave both on; don't pick a winner early.
5. **Configurations → Basic Info**: paste the title and description from the
   game's store file (below) and save.

| Game | Images | Title and description |
|------|--------|-----------------------|
| Hatchery Heist | `games/hatchery-heist/store/` | `games/hatchery-heist/STORE.md` |
| Tidecatch Cove | `games/tidecatch-cove/store/` | project folder `store/tidecatch-cove/listing.md` |
| Street Food Empire | `games/street-food-empire/store/` | `games/street-food-empire/STORE.md` |
| Depthbound | `games/depthbound/store/` | project folder `store/depthbound/store.md` |

## Changing the art

Sources and the renderer are in `tools/store-art` (see its README). Claude
renders new art and opens a PR; you upload the new files the same way. Add
new thumbnails alongside the existing ones (up to 5 active) instead of
replacing them, so the personalization test keeps its history.
