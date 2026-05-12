# Ninja Fixes Session Notes — Projectiles, Special 2, Damage Numbers, Sprite Sizing

## Overview

Four bug categories fixed across the three ninja characters after the initial
implementation session. All fixes were verified clean (no errors beyond known
stale UID warnings). Changes committed and pushed to master.

---

## Fix 1 — Ninja Projectiles Not Registering Hits

All three ninja projectiles (shuriken, staff, stone) were spawning visually but
not dealing damage. Three root causes found and fixed:

### Root cause A: No collision shape
`Projectile.tscn` has a `CollisionShape2D` node but no default shape resource
set on it. Every projectile spawner must create and assign a shape in code:
```gdscript
var shape_node: CollisionShape2D = proj.get_node("CollisionShape2D")
var rect := RectangleShape2D.new()
rect.size = Vector2(28.0, 16.0)   # dimensions vary per projectile
shape_node.shape = rect
```

### Root cause B: Direction baked into speed sign
Original code used negative `proj.speed` for left-facing throws. Projectile.gd
reads `velocity = direction * speed` where `direction` is expected to be ±1.0.
Setting `speed = -520.0` made `direction * speed` double-negative and produced
wrong velocity. Fix: always use positive speed and set direction separately:
```gdscript
proj.direction = 1.0 if facing_right else -1.0
proj.speed     = STONE_SPEED   # always positive
```

### Root cause C: `add_child` scene parent
Was using `get_tree().root.add_child(proj)` — projectile was parented to root
rather than the stage, so its `global_position` offset from character was wrong.
Fix: `get_parent().add_child(proj)` then set `proj.global_position` AFTER add.

### Root cause D: Missing `flip_h`
Projectile sprite wasn't flipping for left-facing throws. Fix:
```gdscript
spr.flip_h = not facing_right
```

**Pattern (matches WandererMagician):**
```gdscript
proj.direction = 1.0 if facing_right else -1.0
proj.speed     = SPEED_CONSTANT
get_parent().add_child(proj)
proj.global_position = global_position + Vector2(offset * proj.direction, -y)
```

---

## Fix 2 — Special 2 Mechanics Swapped

Original implementation had NinjaMonk with block/defend and NinjaPeasant with
blade slash. This was inverted — corrected to:

- **NinjaMonk Special 2**: blade slash (melee AOE, `hitbox_heavy`, 18 damage)
- **NinjaPeasant Special 2**: block/defend (hold to reduce damage 60%)

Both files were fully rewritten. See ninja_characters_session_notes.md for the
final implementations.

---

## Fix 3 — NinjaMonk Blade Slash Damage Numbers Not Showing

**Symptom:** NinjaMonk's Special 2 blade slash dealt damage (HP decreased) but
no floating damage numbers appeared and no hit VFX/SFX fired.

**Root cause:** The `_on_hitbox_heavy_area_entered` override called
`target.take_damage()` directly, bypassing `_apply_hit()`.

`_apply_hit()` in Character.gd is the single choke point that handles:
- `take_damage()` call
- Floating damage number spawn
- Screen freeze
- Recoil impulse
- VFX (`VFXManager.play_single`)
- SFX (`AudioManager.play_sfx`)

**Fix:**
```gdscript
# WRONG — bypasses the full hit pipeline
func _on_hitbox_heavy_area_entered(area: Area2D) -> void:
    if state == State.SPECIAL and _special2_active:
        var target := area.get_parent()
        target.take_damage(SPECIAL2_DAMAGE, global_position, true)

# CORRECT — routes through _apply_hit so everything fires
func _on_hitbox_heavy_area_entered(area: Area2D) -> void:
    if state == State.SPECIAL and _special2_active:
        _apply_hit(area, SPECIAL2_DAMAGE, true)
    else:
        super._on_hitbox_heavy_area_entered(area)
```

**Rule:** Any melee hit that should show damage numbers, VFX, and SFX must call
`_apply_hit(area, damage, is_heavy)` not `take_damage()` directly.

---

## Fix 4 — NinjaMonk/NinjaPeasant Too Big and Floating

**Symptom:** Both ninjas appeared larger than all other characters in-game and
in the CharacterSelect portrait grid. Both floated above the ground.

**Root cause — sprite art density:**
128px characters (knights, wizards, samurai) have art occupying only the **bottom
half** of their frame (~rows 64–127). The top 64px is empty padding. So effective
art height ≈ 64px.

96px ninja frames have much less padding — art fills ~71px (NinjaMonk) or ~68px
(NinjaPeasant) of the 96px frame. At scale 1.0, ninja art (71px) is visibly taller
than 128px character art (64px).

**Float cause:** Sprite `position.y` was 0, meaning the sprite center was at the
character origin instead of offset upward to align feet with the capsule bottom.

**Fixes applied:**

```gdscript
# NinjaMonk._ready():
sprite.scale    = Vector2(0.90, 0.90)  # 71px art * 0.90 ≈ 64px visual height
sprite.position = Vector2(0, -5)        # feet at: -5 + (48 * 0.90) = +38.2px ✓

# NinjaPeasant._ready():
sprite.scale    = Vector2(0.94, 0.94)  # 68px art * 0.94 ≈ 64px visual height
sprite.position = Vector2(0, -7)        # feet at: -7 + (48 * 0.94) = +38.1px ✓
```

Target feet position formula: `capsule_height/2 + ~6px margin = 32 + 6 = +38px`
(same as knight_1: position.y=-26, capsule half=32, feet at -26+64/2=+6 … actually
measured empirically — +38px from character origin is the right landing position).

**CharacterSelect portrait fix:**
Portrait scale was `PORTRAIT_PX / float(frame_px)` where `frame_px` was derived
from the texture height (96 for ninjas). Since 96 < 128, the division yielded a
LARGER scale for ninjas — making them bigger in the grid.

Fix: normalize all portraits to `PORTRAIT_PX / 128.0` regardless of frame size.
Portrait `hframes` still uses `tex.get_height()` as frame size (correct for both
96px and 128px sheets), but the display scale is always relative to 128px.

---

## Regression Check

After all fixes, BattleScene boot validation:
```
kunoichi      — HP:90  Spd:300  ✓
ninja_monk    — HP:105 Spd:275  ✓
ninja_peasant — HP:85  Spd:295  ✓
```
No errors. Only known stale UID warnings (non-fatal, pre-existing).
