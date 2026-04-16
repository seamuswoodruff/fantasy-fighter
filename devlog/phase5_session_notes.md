# Phase 5 Session Notes — Combat System

## What Was Built
- HP-based combat fully wired: hitbox → hurtbox → `take_damage()` → knockback → hitstun → death → stock decrement → respawn
- Kill zones connected via `Windrise.gd` signal chain through `BattleScene.gd`
- `GameManager` stock tracking and `match_ended` signal
- 0.1s `Engine.time_scale` screen freeze on heavy hits
- Confirmed both knight_1 instances can fight, deplete HP, lose stocks, and respawn

---

## Architecture Decisions

### HP-Based Combat (Not Smash-Style)
Damage is flat subtraction: `current_hp -= amount`. No percentage accumulator, no knockback scaling formula. Knockback is a fixed impulse per attack type:
- Light: `Vector2(direction * 200, -120)`
- Heavy: `Vector2(direction * 350, -200)`

Direction is computed in `take_damage()` from attacker position: `signf(target.global_position.x - attacker_pos.x)`. The attacker passes `global_position` — not a pre-computed direction vector — so the target owns the knockback math.

### Hitstun Timer vs. Animation Finished
Hitstun is tracked with `_hitstun_timer` (light: 0.5s, heavy: 1.2s) and exits HURT state in `_tick_timers()`, not in `_on_sprite_animation_finished()`. This prevents a freeze bug where the animation ends slightly before the timer, leaving the state machine stuck in HURT with nothing to trigger the exit.

### Screen Freeze
`_trigger_screen_freeze(0.1)` is called from `_apply_hit()` on heavy hits only. It sets `Engine.time_scale = 0.0` and restores it via a timer created with `ignore_time_scale = true` so it fires even while time is frozen. The timer is connected with a lambda — no `await` needed, which avoids coroutine lifetime issues inside signal callbacks.

---

## Issues Fixed This Session

### 1. Death Animation Not Playing
**Symptom:** Character disappeared instantly on death with no animation visible.

**Root Cause:** `die()` called `process_mode = PROCESS_MODE_DISABLED` and `hide()` synchronously, on the same frame as `change_state(State.DEAD)`. This stopped the `AnimatedSprite2D` from advancing before a single frame of the death animation rendered.

**Fix:** Delayed the hide/disable with a 0.7s timer (enough for the death animation to play). The respawn fires at 1.5s from the original `die()` call — unchanged. The guard `if state == State.DEAD` in the 0.7s callback prevents hiding a character that somehow exited DEAD early.

```gdscript
get_tree().create_timer(0.7, true).timeout.connect(func() -> void:
    if state == State.DEAD:
        process_mode = Node.PROCESS_MODE_DISABLED
        hide()
)
get_tree().create_timer(1.5, true).timeout.connect(respawn)
```

---

## Key Values (current working)

| Mechanic | Value |
|----------|-------|
| Light knockback | `Vector2(±200, -120)` |
| Heavy knockback | `Vector2(±350, -200)` |
| Light hitstun | 0.5s |
| Heavy hitstun | 1.2s |
| Screen freeze duration | 0.1s |
| Death → hide delay | 0.7s |
| Death → respawn delay | 1.5s |
| Respawn invincibility | 2.0s |
| Block damage reduction | 60% |

## What's Not Yet Wired (deferred to Phase 7)
- VFX on hit, death, and landing
- Audio: swing, impact, and footstep SFX
- Match-end screen transition (GameManager emits `match_ended` but nothing handles it yet)
