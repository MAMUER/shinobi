# Sengoku Pixel Pack — Original Sheets

The raw generated sheets behind the *Sengoku Pixel Pack*: 109 images.
**Never cut, never scaled, never background-removed.**

You do not need this download to use the asset pack. Get it if you want to
re-cut the art yourself.

```
fx/           51 files  effects, ambient particle sheets, fog strips,
                        transformations, interactive props
backgrounds/  15 files  far / mid / near / ground-clutter sheets
weapons/      24 files  base, tiered (tier1–3) and evolution (evo) sheets
terrain/      13 files  one sheet per terrain material
ui/            6 files  panels, buttons, bars, misc, item and status icons
```

Filenames match the main pack: `fx/jp_raikiri` there came out of
`fx/jp_raikiri.jpeg` here.

## What to expect

They come exactly as the model produced them:

- **Effects, backgrounds, terrain, props and UI are on magenta `#FF00FF`**,
  not transparent. Magenta because many subjects glow or contain near-white
  pixels, and a white key would eat them.
- **Weapons are on white**, drawn at an angle (roughly 25°–60°, tip up and
  to the right). The main pack has them measured and rotated flat.
- **Evolution sheets** (`wp_sengoku_evo_*`) are 2 × 2: sealed, awakened,
  unleashed, ultimate. The four quadrants share one scale and position.
- Grids vary: 6 × 2, 6 × 3, 5 × 3, 4 × 3, 3 × 4 (horizontal weapons), and
  some UI sheets are not grids at all. **Do not divide the width by six.**
- Grid lines appear on some sheets and not others, in black, in dark
  magenta, or not at all.
- Terrain sheets show **one chunk of ground and one floating platform**, not
  tiles. The main pack cuts them into left / middle / right pieces, makes the
  middles seamless, and builds slopes from them.
- Ambient particle sheets (`*_parts`) are single petals, leaves and
  snowflakes; the looping animations in the main pack were composited from
  them in code. Fog strips (`*_strips`) were cropped at a matching point to
  loop.
- JPEG, so every edge has a thin fringe of blended background. On the
  greyscale effect sheets that fringe is exactly recoverable:
  `alpha = 1 − (R−G)/255` and the true grey is `G / alpha`. For coloured
  sheets, quantise to the sheet's own palette and the fringe snaps away.

Every one of these quirks is already handled in the finished art in the main
pack. This download is the unprocessed input, not a cleaner version.

## What these are for

The sheets are 1024–1376 px wide — more detail than the finished sprites.
Enough to re-cut larger, keep frames that were dropped, or do a cleaner
cutout. Starting from these beats upscaling the finished art.

## License

**CC0 1.0 Universal** — public domain dedication. See `LICENSE.txt`.
Use commercially, modify, ship, resell what you make. No credit required.

## AI disclosure

**Every image here was generated with Google Gemini from written text
prompts.** No existing artwork was used as an input, reference or img2img
source at any point.
