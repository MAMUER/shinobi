# Sengoku Pixel Pack

Pixel art for a side-scrolling action game set in feudal Japan: spell and
weapon effects, parallax scenery, a town kit, a full terrain kit (outdoor and
indoor), 120 weapons with tiers and evolutions, a matching UI kit with skill
and crafting icons, and animated characters — yokai, heroes, bosses and
dialogue portraits.

Every folder stands on its own — take only the terrain, or only the UI.
They were made together so they also work as one set.

## Contents

| Folder | What | Count |
|---|---|---|
| `fx/` | Attack & spell effects, frame by frame | **36 effects, 470 frames** |
| `fx/` | Ambient loops — sakura, maple leaves, snow, rain, fireflies | **5 loops**, tileable |
| `fx/` | Fog & cloud-sea strips, seamless left↔right | **10 strips** |
| `fx/` | Animated scenery, interactive props, projectiles, pickup | **16 animations** |
| `backgrounds/` | Parallax scenery props (far / mid / near), town buildings, ground clutter, title decor | **107 pieces** |
| `terrain/` | Terrain sets: ground, platforms, slopes, back walls — outdoor and indoor, with Tiled & Godot tilesets | **17 materials, 985 tiles** |
| `weapons/` | Weapons: 36 base, 36 tiered, 12 evolution lines × 4 stages | **120** |
| `weapon_fx/` | Looping elemental glow that sits on top of a weapon | **49 overlays** |
| `icons/` | 32 × 32 weapon icons | **120** |
| `ui/` | Panels, buttons, bars, cursors, dividers; item, status, skill & crafting-material icons | **39 elements + 48 icons** |
| `characters/` | Animated heroes (8 famous warlords), enemy soldiers, yokai, bosses, dialogue portraits | **13 heroes, 6 soldiers, 17 yokai, 5 bosses (6 sheets), 20 portraits, 10 colour variants** |

---

## Effects

### Monochrome on purpose

The attack effects are drawn in white → dark grey only. That lets you tint
one effect into fire, ice, poison or holy light at runtime with a single
colour multiply. (Ambient loops, props and weapon glow are in full colour.)

### Anchors — read this before you place them

`pack.json` gives each effect an `anchor`:

| `anchor` | Align the cell's… | Effects |
|---|---|---|
| `center` | centre to the caster's body | most of them (17) |
| `bottom` | **bottom edge to the ground line** | arrow rain, flame wall, icicle fall, mire trap, purify light, quake, raikiri, rock spikes, seal circle, smoke escape, spectral hands, tatsumaki, tidal wave, ward barrier, water ripple |
| `left` | **left edge to the attacking hand**, flip with facing | afterimage dash, blood bloom, frost breath, iai slash |

`bottom` means *where it lands*, not where it comes from — raikiri falls
from the sky but is anchored at the ground it strikes.

### Cells and frames

Attack effects are horizontal strips of **256 × 256** cells, plus the same
frames already cut in `<name>_frames/`. Frame *n* sits at `x = n * 256`.
Frame counts run 10–18; `pack.json` has the exact number. The peak is early
(frames 2–3) so they read as impacts.

### Ambient loops and fog strips

`jp_amb_*` loops (sakura, momiji, snow, rain, firefly) are 48 frames of
256 × 256 that **tile in both directions** — lay the same tile across the
whole screen. Frame 48 returns exactly to frame 0. They are greyscale;
`pack.json` suggests a tint for each.

Fog and cloud-sea strips (`jp_amb_fog_*`, `jp_amb_unkai_*`,
`jp_amb_valley_mist_*`) tile **left↔right**; scroll them slowly behind or in
front of a layer. `pack.json` suggests an alpha (fog ≈ 0.55).

---

## Backgrounds — separate props, not a wide image

There is no seamless backdrop here, deliberately: a tiling picture has a
seam you would fight forever. You get **individual objects** to scatter
along each depth layer.

| Layer | Suggested parallax | Look | Pieces |
|---|---|---|---|
| `far` | **0.06** | pale, washed out | 13 |
| `mid` | **0.18** | full colour — castles, shrines, famous sights | 43 |
| `near` | **1.00** | near-black silhouettes that frame the screen | 17 |
| `ground` | **1.00** | grass, flowers, rocks, bamboo shoots, leaves — sit on the terrain | 7 |
| `town` | **1.00** | machiya, shop (blank noren), teahouse, storehouse, row house, smithy, well, shrines, inn, rice shop, watchtower, stall, stone lantern — **same scale as the characters**, sit on the terrain | 15 |
| `deco` | — | golden / grey *suyari-gasumi* cloud bands, **for title screens and menus** | 12 |

`deco` clouds are opaque, outlined bands. In a playable scene they read like
platforms you can stand on, so keep them to title screens, menus and cutscenes.

Animated versions of five props are in `fx/` (`jp_bgan_*`): a war banner and
camp curtain that ripple, two lanterns that flicker, the Nachi waterfall.
They are pixel-for-pixel the same art as the still prop, so you can swap one
for the other.

### Day, dusk and night from the same art

No separate night sprites are needed. Multiply each layer by one colour
(Godot: `modulate` on the `ParallaxLayer` / `TileMapLayer`; Unity: sprite
`color`) and swap the sky gradient:

| | Sky top → bottom | far | mid | ground / terrain | near |
|---|---|---|---|---|---|
| dusk | `#3A285C` → `#F69668` | `#FAAA96` | `#ECAA8C` | `#DCA088` | `#966060` |
| night | `#080C22` → `#283460` | `#606EAA` | `#6E78B0` | `#6870A0` | `#282840` |

---

## Terrain

Each material is a **set**: ground, floating platform and slopes that join
without seams.

| Piece | Tiles |
|---|---|
| Ground surface / body | left end, middle (×3 variants), right end, single-width |
| Ground bottom edge, single-row ground | same five |
| Floating platform top / underside | same five |
| Slopes | 26°, 45°, 63° up and down; 26° and 45° platform slopes |
| Back wall | darkened body tile for caves and interiors |

Outdoor: castle stone, temple flagstones, mossy rock, bamboo grove, snow,
timber, spring grass, autumn leaves, shrine steps, wooden bridge, beach,
volcanic rock, roof tiles.

Indoor: tatami, polished wood floor over a stone footing, and two **walls** —
shoji screens and white plaster with dark posts. Paint the walls with their
back-wall tiles behind the play area to build castle rooms and dojos.

**Mix the three middle variants at random** — that is what keeps stone walls
from looking stamped.

### Tilesets with autotiling

`terrain/tilesets/` has, for every material, one tilesheet PNG plus:

- **Tiled** `.tsx` — terrain brush set up (Wang set, edges)
- **Godot 4** `.tres` — `TileSet` with terrain set *Match Sides*

Paint with the terrain brush and the ends, middles and single pillars pick
themselves. Slopes and back walls are placed by hand.

### Placement guide

`terrain/guide/` has a labelled example level per material and an
`example_level_*.json` listing every cell, so you can rebuild it in any engine.

---

## Weapons

Horizontal, tip to the right, grip at the left edge, 80–244 px along the
long edge. `pack.json` has size and grouping for each.

- **Base** (36) — katana, spears, bows, matchlocks, ritual objects, tools.
- **Tiered** (36) — 12 weapons × 3 tiers: *ashigaru* (rough iron), *samurai*
  (polished steel, lacquer), *master-forged* (gold fittings, elemental glow).
  `tier`, `tier_group` and `slot` in `pack.json`; the three tiers of one
  weapon are the same length.
- **Evolution** (48) — 12 weapons × 4 stages: sealed → awakened → unleashed →
  ultimate. **All four stages share one canvas and the grip is on the same
  pixel** (`grip` in `pack.json`), so swapping stages in-game never jumps.
- **Transformations** (in `fx/`, `wp_sengoku_morph_*`) — war fan opening into
  a shield, shakujō growing a spear head, nodachi splitting into twin blades.
- **Icons** (`icons/`) — every weapon as a 32 × 32 icon with an outline.
- **Projectiles** (in `fx/`, `jp_proj_*`) — spinning shuriken, kunai and
  hōroku bomb.

### Weapon glow overlays

`weapon_fx/` holds a looping glow for every elemental weapon (flame,
lightning, sakura, wind, water): 16 frames, hard-edged. The weapon stays a
still image — **draw the glow on top at the weapon's position plus
`offset`** from its JSON:

```
draw(weapon, p)
draw(glow[frame], p + offset)
```

---

## UI kit

| Part | Notes |
|---|---|
| Panels (4) | washi, scroll, wooden board, lacquer dialog — **9-slice**; margins in `ui.json`, Godot `StyleBoxTexture` `.tres` included |
| Buttons (4 styles) | normal / hover / pressed, pixel-aligned; pressed sinks 2 px |
| Bars | empty frame + HP, MP, stamina fills. Godot `TextureProgressBar` scenes included |
| Cursors | katana and fan — hotspot in `ui.json` |
| Checkbox, slider, dividers, corner | dividers repeat their middle (rope and bamboo would smear if stretched) |
| Item icons (13) | onigiri, sake, scroll, talisman, medicine, key, koban, rice bag, tea bowl, smoke bomb, rope, two lanterns |
| Status icons (8) | poison, burn, freeze, paralyze, blessing, bleed, silence, haste |
| Skill icons (12) | slash, thrust, cast, block, dash, shuriken, talisman, barrier, whirlwind, fire, heal, stealth — one shared frame |
| Crafting materials (15) | iron ore, tamahagane steel, charcoal, silk, hemp cloth, leather, wood plank, bamboo, herbs, mushroom, bone, black feather, spirit crystal, washi, lacquer bowl |

No text is drawn on anything — every banner, plaque and seal is blank for
your own lettering.

---

## Characters

| Kind | Who | Animations |
|---|---|---|
| Warlords (72 px body) | Oda Nobunaga, Sanada Yukimura, Date Masamune, Honda Tadakatsu, Uesugi Kenshin, Miyamoto Musashi, Hattori Hanzō, Tomoe Gozen | idle, walk, attack, jump, fall, hurt, death + **cast, block, dash**, and a 3-expression portrait each |
| Heroes (72 px body) | samurai, ninja, shrine maiden, kunoichi, onmyōji | same set; kunoichi and onmyōji have portraits too |
| Soldiers (80 px) | ashigaru spearman, matchlock ashigaru, bandit, enemy ninja, warrior monk, rōnin | idle, move, attack, hurt, death |
| Yokai (80 px) | kappa, crow tengu, red oni, lantern ghost, ittan-momen, skeleton warrior, kitsune, yuki-onna, kasa-obake, jorogumo, bakeneko, kamaitachi, rokurokubi, hitotsume-kozō, umibōzu, gaki; nurikabe at 120 px | idle, move, attack, hurt, death |
| Bosses (150 px) | Great Tengu, Shuten-dōji, Yamata no Orochi, Tamamo-no-Mae in two forms (court lady with nine tails, and the nine-tailed fox — use them as phase 1 and 2), Kiyohime (serpent woman) | idle, move, two attacks, an ultimate, hurt, death |
| Portraits (128 px) | teahouse girl, merchant, shrine priest, swordsmith, daimyo, farmer, geisha, temple monk, fisherman, ninja master | 3 expressions each |
| Colour variants | blue and green oni, blue-lacquer and silver samurai, black and green ninja, blue and purple lantern ghost, silver kitsune, blue kappa | same frames as the original |

The warlords' looks follow their historical armour, helmets and crests
(Masamune's crescent, Yukimura's six coins, Tadakatsu's antlers and beads,
Kenshin's white hood); they are not based on any game's character designs.
Crests are drawn as shapes, never as text.

- Yokai and bosses face **left**, heroes face **right** — flip for the other side.
- Every frame of one animation shares one canvas, feet on the bottom edge
  (`anchor: bottom`), so frames swap without jitter.
- Heroes: `foot_y` / `body_x` in `pack.json` are the ground row and head column
  of each animation. Line these up when switching animations (skills come from
  a separate sheet with its own canvas; jump/fall frames reach lower).
- Hurt is a white-silhouette flash; death ends in a dither fade to nothing.
- Portraits of one person are pixel-aligned — only the face changes.
- No text anywhere: talismans, banners, fans and plaques are blank.

---

## Interactive props

In `fx/`: a lacquer treasure chest opening, a shoji door sliding open, a
barrel and a clay jar breaking. The base stays on the same pixel in every
frame; each ends on a still final frame.

## `pack.json`

One file describing everything: frame counts and anchors for effects, layer
and parallax factor for scenery, tiers/stages/grip for weapons, offsets for
glow overlays, 9-slice margins for UI.

## The original sheets are a separate download

*Sengoku Pixel Pack — Original Sheets* holds the raw generated sheets every
piece was cut from. You do not need it; get it if you want to re-cut.
Same page, free, same CC0 license.

## Importing

Use **nearest-neighbour** filtering everywhere.

**Godot** — set *Filter* to *Nearest*; use the included `.tres` / `.tscn`
for tilesets and UI. Effects: `Sprite2D` + `hframes`, or drag the cut frames
onto an `AnimatedSprite2D`.

**Unity** — *Filter Mode: Point*, *Compression: None*; Sprite Editor → Slice
→ *Grid By Cell Size* for strips. Panels: set the Border from `ui.json`.

**Tiled** — add the `.tsx` from `terrain/tilesets/`, use the Terrain brush.

## License

**CC0 1.0 Universal** — public domain dedication. See `LICENSE.txt`.
Use it commercially, modify it, ship it. No credit required.

## AI disclosure

**Every image in this pack was generated with Google Gemini from written
text prompts, then cut, cleaned, aligned and assembled with scripts and by
hand.** Animations such as ambient loops, slopes, fog strips and glow
overlays were composited in code from those generated pieces. Each character
pose was edited from one generated base image of that character; hurt
flashes, death fades and small position shifts were done in code.

No existing artwork was used as an input, reference or img2img source.
