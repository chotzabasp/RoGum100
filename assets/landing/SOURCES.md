# Landing page asset sources

Retrieved 2026-09-26 for the user-requested local Gum100 landing page.

- Reference: https://db.morroc.in.th/worldmap
- `midgard.jpg`: https://db.morroc.in.th/api/worldmap/region-image/worldmap.jpg (1280 × 1024).
- Monster PNGs: `https://db.morroc.in.th/api/simulator/monster-icon/{id}`, except Angeling and Ghostring.
- `ghostring.png`: first frame of `https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Ghostring.gif`, also referenced by the existing Gum100 miniboss migration.
- `angeling.png`: first frame of `https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Angeling.gif`, the existing Gum100 asset referenced in migration `20260922000400_add_miniboss_round.sql`. The reference site's Angeling icon returned the same image as Poring; the existing Gum100 artwork retains its wings and halo. A still frame lets the page's pause control and reduced-motion preference stop all character motion.
- Map coordinates: `https://db.morroc.in.th/api/worldmap/regions`, Midgard region, center of each map's `rect` divided by 1280 × 1024. Artwork and pins always share one coordinate system.
- The current nine monster/map pairings are explicitly selected by the user. Reference monster IDs were checked using `https://db.morroc.in.th/api/worldmap/map/{map}/monsters`. Dungeon coordinates mark the dungeon's position on the world map, not an internal floor map.

| Local file | Monster ID | Map | Classification |
| --- | --- | --- | --- |
| ghostring.png | Existing Gum100 GIF | pay_fild04 | Mini boss |
| angeling.png | 1096 | mjolnir_10 | Mini boss |
| maya.png | 1147 | anthell02 | MVP |
| eddga.png | 1115 | pay_fild10 | MVP |
| orc_hero.png | 1087 | gef_fild14 | MVP |
| seal.png | 1317 | cmd_fild02 | Monster |
| skeleton_worker.png | 1169 | mjo_dun03 | Monster |
| raydric.png | 1163 | gl_cas02 | Monster |
| grand_peco.png | 1369 | yuno_fild02 | Monster |

These are user-selected pairings, not universal spawn claims or live boss status. The page labels that distinction in its footer. All media are served locally; no runtime dependency on the reference APIs. Existing Gum100 logo and feature illustrations are reused from the repository. Earlier prototype sprites remain in the asset directory; only the nine entries above are map pins. Poring is still used as decorative artwork in the closing section.

Source attribution does not transfer copyright or establish a license. These are third-party Ragnarok assets, not original Gum100 artwork. No license statement was verified from the reference site in this task; confirm reuse rights before public redistribution.

- boss-timers-preview.png: user-supplied screenshot of the live Gum100 boss timer interface (2026-09-26), using the replacement image with Admin labels. Displayed unchanged at responsive size; full-size image linked from the preview.
