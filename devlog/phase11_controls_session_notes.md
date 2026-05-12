# Phase 11 Session Notes — Controls Overhaul & Combat Fixes

## Overview

Major rework of the input system, moveset standardization across all 9 characters,
and several combat feel fixes (block damage, shield break, health bar accuracy,
turning-while-blocking). Also created `BALANCING.md` as a permanent reference doc.

---

## Input System Changes

### Right Stick Attack Bindings
All four attacks are now bound exclusively to the right analog stick. Face buttons
were removed from all attack actions.

| Direction | Action |
|-----------|--------|
| Right | Light attack |
| Left | Heavy attack |
| Up | Special |
| Down | Special 2 |

Both P1 and P2 use `InputEventJoypadMotion` axis entries (axis 2/3, threshold ±1.0)
in `project.godot`. Face button entries (button_index 1, 2, 3, 10) were removed from
all four attack actions for both players.

### Block Bindings Removed
`p1_block` and `p2_block` were cleared to empty event arrays. All characters with a
block mechanic (Knight, Samurai, samurai_commander) now use `p{n}_special2` (right
stick down / V / semicolon) as their block input. This integrates block into the
standardized four-move scheme.

Back/cancel navigation in menus was moved off `p1_block` to `ui_cancel` (Escape).
Updated in `CharacterSelect.gd` and `StageSelect.gd`.

### Controller Menu Navigation
`MainMenu.gd` gained a cursor system (`_cursor: int`, `_buttons: Array`) that reads
`p1_up/p2_up/p1_down/p2_down` for navigation and `p1_jump/p2_jump/p1_light_attack/
p2_light_attack` for confirm. `_update_highlight()` tints the selected button gold
and all others white.

---

## Moveset Standardization — All 9 Characters

Every character now maps to the same four-input scheme. Characters without a given
move leave that input as a no-op.

| Character | Light | Heavy | Special | Special 2 |
|-----------|-------|-------|---------|-----------|
| Knight (×3) | Attack 1 | Attack 2 | Attack 3 (standalone) | Block (Defend) |
| Samurai (×2) | Attack_1 | Attack_2 | Attack_3 (dash) | Block |
| Samurai Archer | Attack_1 | Attack_2 | Shot/Arrow (projectile) | Attack_3 (melee) |
| Fire Wizard | Attack_1 | Attack_2 | Fireball (projectile) | Flame Jet (AOE) |
| Lightning Mage | Attack_1 | Attack_2 | Light Ball (projectile) | Light Charge (melee AOE) |
| Wanderer Magician | Attack_1 | Attack_2 | Magic Arrow (projectile) | Magic Sphere (projectile) |

### Knight Changes
- Attack 3 moved from heavy-combo-follow-up to its own `special_attack()`. It fires
  any time the player is not locked, regardless of previous attack state.
- Block moved to `special2_attack()` slot. `_read_block_input()` virtual method
  override returns `InputManager.is_special2_held(player_id)`.
- Removed `_combo_buffered` variable — combo chain logic simplified.

### Samurai Changes
- Added `_read_block_input()` override returning `InputManager.is_special2_held(player_id)`.
- Block now activates on right stick down / V / semicolon, not on a separate bind.

### Samurai Archer Changes
- Added `special2` animation entry (`Attack_3.png`) to sprite frames.
- Implemented `special2_attack()` using `hitbox_heavy` with frame-gated activation
  (`f >= 1 and f <= total - 2`).
- `_on_sprite_animation_finished()` handles both `special` (fires arrow) and
  `special2` (resets hitbox, returns to idle).

### Block Architecture — Virtual Method Pattern
Rather than changing the global block input in `Character.gd`, a virtual method
`_read_block_input()` was introduced. The base implementation reads
`InputManager.is_block_held(player_id)` (no-op since that action is now empty).
Knight and Samurai override it to read `is_special2_held()` instead.

This approach avoids breaking:
- Wizard characters (their `special2` is an attack, not a block)
- Menu back navigation (previously on `p1_block`)
- Characters with no block at all

`InputManager.is_special2_held(player_id)` was added to support the override.

---

## Combat Fixes

### Block Damage Reduction — 80%
`take_damage()` in `Character.gd` now applies `* 0.2` on blocked hits (80% reduction,
down from the earlier `* 0.4`). Knockback on block is also scaled to `0.25×`.
No hitstun is applied while successfully blocking.

### Turning Around While Blocking
**Bug:** When a blocking Knight received knockback, the sprite flipped to face the
attacker because `_update_facing()` read the knockback velocity direction.

**Fix:** `_update_facing()` now returns early if `is_blocking` is true:
```gdscript
func _update_facing() -> void:
    if _is_locked() or is_blocking:
        return
    ...
```

### Shield Break Mechanic
A cumulative `_shield_damage: float` tracker was added to `Character.gd`. It
accumulates raw (pre-reduction) incoming damage while the character is blocking.
When it reaches 100, the shield breaks:
- `is_blocking` set to false
- `_hitstun_timer = 0.3` (0.3s of stun)
- State transitions to HURT
- `_shield_damage` resets to 0

The tracker resets to 0 on voluntary block release (player releases the input).
This means the 100-point threshold is per block instance — taking your shield down
and putting it back up resets the counter.

### Health Bar Accuracy
**Bug:** The `TextureProgressBar` health bar emptied before characters died because
its implicit `max_value = 100` was never overridden, while characters have 110–150 HP.

**Fix:** `HUD.set_characters()` now explicitly sets:
```gdscript
bar.min_value = 0
bar.max_value = ch.max_hp
bar.value = ch.max_hp
```
`_refresh()` uses `bar.value = ch.current_hp` directly rather than a ratio.

The 25% HP red color-swap was also removed — bars stay green at all HP values.

---

## New File — `BALANCING.md`

Created at project root. Contains:
- Shared physics constants (gravity, friction, jump)
- Knockback values by hit type
- Hitstun durations by hit type
- Block system properties (damage reduction, knockback reduction, shield health)
- Frame data for all 6 character archetypes (startup / active / recovery / total)
- Comparative stats table across all 9 characters
- Per-character and per-move tuning reference

Used as the source of truth for `BALANCE_CHANGES.md` and future tuning sessions.

---

## Key Architecture Notes

### `_read_block_input()` Pattern
Any future character that needs a non-standard block trigger should override this
method rather than touching `handle_input()`. The base no-op means characters
without the override simply never block.

### `is_special2_held()` vs `is_special2_pressed()`
- `is_special2_held()` — `Input.is_action_pressed()` — used for held block
- `is_special2_pressed()` — `Input.is_action_just_pressed()` — used for one-shot
  special2 attack activation in `handle_input()`
Both live in `InputManager.gd`.
