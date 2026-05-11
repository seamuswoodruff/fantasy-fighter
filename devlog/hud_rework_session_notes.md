# HUD Rework Session Notes — Health Bar Visual Fix

## Problem

After the 4-player HUD rewrite, health bars were visually broken in two separate ways:

### Issue 1 — Old static nodes still rendering
`HUD.tscn` contained `P1Bar` and `P2Bar` as static `TextureProgressBar` nodes with
anchor-based sizing, hard-coded for 2 players. The new script also added bars dynamically,
causing both sets to render simultaneously — old bars in the corners, new stretched bars
overlapping them.

**Fix:** Stripped `HUD.tscn` down to just the root `CanvasLayer` node. All HUD elements
are now built entirely in code.

### Issue 2 — TextureProgressBar stretching the sprite sheet
`texture_under = load("res://assets/ui/hud/HealthBar DARK.png")` was used to replicate
the original bar style. `HealthBar DARK.png` is a sprite sheet (multiple rows of assets),
not a single-frame texture. Setting it as `texture_under` rendered the entire sheet as
the background, producing a stack of icons and bars behind the green fill.

`nine_patch_stretch = true` made this worse — it attempted to stretch a multi-row sheet
as a nine-patch, producing garbled visuals.

**Fix:** Dropped `TextureProgressBar` entirely. Replaced with three plain `ColorRect` nodes
stacked in Z-order:
1. Outer border (dark red, 2px wider/taller than trough)
2. Dark trough background
3. Green fill — resized every frame via `fill.size.x = max_w * (hp / max_hp)`

This is bulletproof and produces identical visuals to the original.

---

## Final HUD Layout

```
[+] [===GREEN FILL========] [trough---]   ← top bar (y = 12)
[P1]  ♥ ♥ ♥                              ← info row (y = 44, label left, hearts centered)
```

- Bar width: **260px fixed** (shrinks proportionally if >4 players don't fit)
- Bar height: 28px
- `+` label: font size 22, left edge of bar
- Info row: 4px below bar bottom
  - Player name: left-aligned at bar x, font size 13
  - Hearts: centered under bar, 20×20px each
- Low HP threshold: 25% → fill color switches from green to red
- No bottom panel — stocks/name live inline under each bar

---

## Color Reference

| Element | Color |
|---------|-------|
| Outer border | `Color(0.55, 0.08, 0.14)` — dark crimson |
| Trough | `Color(0.22, 0.04, 0.08)` — very dark maroon |
| Fill (healthy) | `Color(0.18, 0.78, 0.22)` — green |
| Fill (low HP) | `Color(0.85, 0.14, 0.18)` — red |
| Stock panel bg | `Color(0.05, 0.04, 0.10, 0.85)` — near-black |
| Player label | `Color(0.7, 0.7, 0.9)` — soft blue-white |

---

## Files Changed

- `scripts/ui/HUD.gd` — health bar approach switched from TextureProgressBar to ColorRect
- `scenes/ui/HUD.tscn` — stripped to bare CanvasLayer (removed P1Bar, P2Bar, P1Heart*, P2Heart*, troughs, borders)
