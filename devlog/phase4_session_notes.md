# Phase 4 Session Notes — Windrise + Combat Debugging

## What Was Built
- Windrise stage with parallax background, TileMap visuals, StaticBody2D collision platforms, kill zones, spawn points
- Two Knight1 players spawning and fighting in BattleScene
- Full combat loop: attacks, hitbox/hurtbox detection, damage, knockback, hitstun, stocks, respawn

---

## Issues Fixed This Session

### 1. Character Visual Jumps When Changing Direction
**Symptom:** When a character turned left or right, the sprite appeared to "snap" horizontally by ~12–16px.

**Root Cause:** The knight_1 sprite art body is not centered in the 128×128 frame — the torso sits roughly 16px left of the frame center. `AnimatedSprite2D.flip_h` mirrors the art around the sprite node's local origin. With `sprite.position.x = 0`, the offset was zero so `_set_facing()`'s mirroring logic (`sprite.position.x = absf(x) * sign_x`) had nothing to compensate with.

**Fix:** Set `AnimatedSprite2D position.x = 16` in `Knight1.tscn`. The `_set_facing()` code then correctly mirrors it to `-16` when facing left, keeping the visual body centered over the physics capsule in both directions.

**Key insight:** The facing code assumes positive x when facing right, negative when facing left. For art where the body is LEFT of frame center, you need a positive initial x offset equal to `64 - body_center_pixel`.

---

### 2. Combat Hits Not Registering At All
**Symptom:** Characters could attack with no effect — no knockback, no damage, no reaction.

**Root Cause:** The `HitboxLightShape` and `HitboxHeavyShape` collision shapes in `Knight1.tscn` were positioned at `y = -50`. The physics capsule center is at y=0, and the enemy's hurtbox capsule (height=68) only extends up to `y = -34`. The hitboxes were sitting **16px above the top of any reachable hurtbox** — they could never overlap.

These incorrect y positions were set during a previous session's sprite offset debugging and never corrected.

**Fix:** Changed both hitbox shape positions from `y = -50` to `y = -10`, placing them at torso level (within the hurtbox capsule range).

**How we diagnosed it:** Checked `get_debug_output` during gameplay — no "[Character] P took X dmg" print statements ever appeared, confirming zero hits registered despite attacks firing.

---

### 3. Knockback Too Severe
**Symptom:** A single hit launched characters off the screen entirely.

**Root Cause:** Knockback constants were `400` (light) and `700` (heavy) — approximately 2× the intended values from the design spec.

**Fix:** Reduced to `200` (light) and `350` (heavy) in `Character.gd`:
```gdscript
var kb_base := 350.0 if is_heavy else 200.0
```

---

### 4. Character Frozen After Heavy Hit
**Symptom:** After receiving a heavy attack, the character would lock into the hurt pose permanently and stop responding to input.

**Root Cause:** A race condition between the hurt animation duration and the hitstun timer:
- Hurt animation: 2 frames at 10fps = **0.20 seconds**
- Heavy hitstun: **0.18 seconds**

`_on_sprite_animation_finished()` fires at 0.20s and checks `if _hitstun_timer <= 0.0` before exiting HURT state. But at 0.20s the timer still had ~0.01s left — the check failed, the transition never happened, and nothing else could trigger it because `_is_locked()` blocks `_update_state()` for the HURT state.

**Fix:** Added an exit check directly in `_tick_timers()` so the hitstun expiry itself forces the transition, regardless of animation timing:
```gdscript
func _tick_timers(delta: float) -> void:
    if _hitstun_timer > 0.0:
        _hitstun_timer -= delta
        if _hitstun_timer <= 0.0 and state == State.HURT:
            change_state(State.IDLE)  # ← always exits HURT when timer runs out
```

---

## Key Architecture Notes for Future Sessions

### Collision Layer Map
| Layer | Purpose |
|-------|---------|
| 1 | CharacterBody2D (world collision) |
| 2 | Hurtboxes (Area2D, `collision_layer = 2`) |
| 4 | Hitboxes (Area2D, `collision_layer = 4`, `collision_mask = 2`) |
| 8 | Kill zones |

### Knight1 Sprite Offsets (current working values)
- `AnimatedSprite2D position = Vector2(16, -16)` — 16px right compensates for left-biased art; -16 aligns feet to capsule bottom
- `HitboxLightShape position = Vector2(42, -10)` — torso level, extends forward
- `HitboxHeavyShape position = Vector2(48, -10)` — torso level, slightly wider reach

### CapsuleShape2D Height Convention
In Godot 4, `CapsuleShape2D.height` is **total height** including both hemisphere caps. A capsule with `height = 64` has its bottom at `center_y + 32` (not +48). This is easy to get wrong — always divide by 2 for the half-extent.

### Hitbox Activation (frame-accurate)
Hitboxes activate via `_on_sprite_frame_changed()` and only while in the attack state. If a character gets stuck in an attack state and the animation can't finish (e.g., wrong animation name), the hitbox either never activates or never deactivates. Always verify animation names in the SpriteFrames resource match exactly what `_try_play()` passes.

### Windrise Platform Setup
- TileMap is **visual only** — no physics layers set on it
- All collision is via `StaticBody2D` nodes with `RectangleShape2D` sub-resources
- Wall barriers at x=0 and x=1280 prevent characters walking off screen edges
- Kill zones at bottom (y=850), left (x=-250), right (x=1530), top (y=-300)
