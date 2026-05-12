# Phase 9 Session Notes — All 3 Stages

## Overview

Ruins and DesertTemple stages built and integrated. All three stages now load with
correct parallax backgrounds, platform layouts, spawn points, kill zones, and
stage-appropriate music/ambience. StageSelect wired to all three.

---

## Ruins Stage

**Scene:** `scenes/stages/Ruins.tscn`
**Script:** `scripts/stages/Ruins.gd`

### Visual Layers
- Background: `ruins_background.png` — lush green valley with floating castles
- Platforms: built from `Ruins_tilemap.png` tileset

### Platform Layout
Two main ground sections with a gap in the center, three floating platforms above
the gap. Ground sections use the Ground & Cliff tile category. Floating platforms
use the Floating Island tile category from the tileset.

### Music / Ambience
Randomly picks from: Gothic_Dark, Demise, Havoc, Fight_1–3, Crisis.
Ambience: `cave` or `interior` OGG.

### Kill Zones
- Bottom Y > 750
- Left X < -150
- Right X > 1430
- Top Y < -200

---

## DesertTemple Stage

**Scene:** `scenes/stages/DesertTemple.tscn`
**Script:** `scripts/stages/DesertTemple.gd`

### Visual Layers
- Background: `desert_background.png` — desert scene with oasis and dunes
- Platforms: sliced from `AssetSheet_Yellow.png` and `DesertTemple_platforms.png`

### Platform Layout
Two ground sections (left and right) with a center gap. One large center floating
island above the gap, flanked by two smaller floating islands. Ground sections
decorated with pillar props.

### Music / Ambience
Randomly picks from: Raid_Ethnic, Raid_FolkMetal_1–2, Raid_1–3, Flap_1–2.
Ambience: `water` or `forest_night` OGG.

### Kill Zones
Same dimensions as Ruins.

---

## GameManager Integration

`GameManager.go_to_battle()` reads `selected_stage` and instantiates the correct
scene. `BattleScene` boots the correct stage by key. All three keys verified:
`"Windrise"`, `"Ruins"`, `"DesertTemple"`.

---

## Platform Building Protocol Applied

- Measured each tileset before use — logged pixel dimensions
- Never scaled platform sprites — tile count determines width
- Built and screenshotted one section at a time before placing the full layout
- StaticBody2D collision separate from visual TileMap nodes
