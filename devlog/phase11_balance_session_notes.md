# Phase 11 Session Notes — Balance Changes

## Overview

Six targeted balance changes applied from `BALANCE_CHANGES.md`. Each change was
tested individually — project run + debug output checked for errors before moving
to the next. All six passed clean.

---

## Change 1 — Character.gd: Hitstun Reduction

**File:** `scripts/characters/Character.gd`  
**Location:** `take_damage()`, hitstun assignment line

**Before:**
```gdscript
var hitstun := 1.2 if is_heavy else 0.5
```

**After:**
```gdscript
var hitstun := 0.35 if is_heavy else 0.18
```

**Why:** 1.2s heavy hitstun (72 frames at 60fps) guaranteed a free follow-up combo
on every heavy hit. 0.35s (21 frames) is rewarding without being a guaranteed combo
extender. Light hitstun drops from 0.5s to 0.18s (~11 frames) — confirms the hit
without enabling free loops.

**Note on block reduction:** `BALANCE_CHANGES.md` suggested verifying `* 0.4`
(60% reduction) but the project already had `* 0.2` (80% reduction) per an earlier
explicit request. The 80% value was kept unchanged.

---

## Change 2 — LightningMage.gd: Extra Hitstun Reduction

**File:** `scripts/characters/LightningMage.gd`  
**Location:** Constants block, line 17

**Before:**
```gdscript
const EXTRA_HITSTUN: float = 1.0
```

**After:**
```gdscript
const EXTRA_HITSTUN: float = 0.25
```

**Why:** `EXTRA_HITSTUN` stacks on top of the base heavy hitstun. Even after Change 1
(base = 0.35s), a 1.0s bonus would bring the total to 1.35s — still completely
oppressive. At 0.25s the total is 0.6s, the longest hitstun in the game, meaningfully
rewarding without locking out for over a second.

---

## Change 3 — FireWizard.gd: Flame Jet Cooldown

**File:** `scripts/characters/FireWizard.gd`

**What changed:**

Added constant and timer variable:
```gdscript
const FLAMEJET_COOLDOWN: float = 3.5
var _flamejet_cooldown_timer: float = 0.0
```

Guarded `special2_attack()`:
```gdscript
if _is_locked() or _flamejet_active or _flamejet_cooldown_timer > 0.0:
    return
```

`_end_flamejet()` now starts the cooldown:
```gdscript
func _end_flamejet() -> void:
    _flamejet_active = false
    _flamejet_cooldown_timer = FLAMEJET_COOLDOWN
    hitbox_light.monitoring = false
    is_attacking = false
    change_state(State.IDLE)
```

`_physics_process()` ticks the cooldown (outside the `if _flamejet_active:` block):
```gdscript
if _flamejet_cooldown_timer > 0.0:
    _flamejet_cooldown_timer -= delta
```

**Why:** Flame Jet deals up to 40 damage over 1 second with no downtime. A wizard
has 100 HP — two immediate uses would be a near-certain kill. The 3.5s cooldown
(3.5× the jet duration) keeps it a powerful niche tool rather than a spammable nuke.

---

## Change 4 — Knight.gd: Heavy Attack Slowdown + Attack 3 Startup

**File:** `scripts/characters/Knight.gd`

### 4a. Heavy Attack FPS

**Before:**
```gdscript
_add_anim(sf, "attack_heavy", load(p + "Attack 2.png"), 128, 128, 0, 4, 16.0, false)
```

**After:**
```gdscript
_add_anim(sf, "attack_heavy", load(p + "Attack 2.png"), 128, 128, 0, 4, 10.0, false)
```

4-frame heavy now takes 400ms total (was 250ms). Light attack is 5 frames at 16fps
= 312ms. Heavy now visibly slower than light, which is correct — heavy attacks
should feel weightier and riskier.

### 4b. Attack 3 Startup Frame

**Before:**
```gdscript
if _is_attack_3:
    hitbox_heavy.monitoring = (f >= 0 and f <= 2)
```

**After:**
```gdscript
if _is_attack_3:
    hitbox_heavy.monitoring = (f >= 1 and f <= 2)
```

`f >= 0` meant the hitbox was live on the very first frame — literally unreactable.
One frame of startup (~100ms at 10fps after the animation change above) gives
opponents a theoretical window to react. Still very fast and dangerous.

---

## Change 5 — Samurai.gd: Recovery Timers

**File:** `scripts/characters/Samurai.gd`

**What changed:**

Added constants and variable:
```gdscript
const LIGHT_RECOVERY: float = 0.10
const SPECIAL_RECOVERY: float = 0.12
var _recovery_timer: float = 0.0
```

Added `_is_locked()` override:
```gdscript
func _is_locked() -> bool:
    return super._is_locked() or _recovery_timer > 0.0
```

Added timer tick at the top of `_physics_process()` (before `if _is_special_active:`):
```gdscript
if _recovery_timer > 0.0:
    _recovery_timer -= delta
```

Updated `_on_sprite_animation_finished()` — added recovery timer starts and a new
`State.ATTACK_LIGHT` branch (previously handled by the base class):
```gdscript
State.SPECIAL:
    hitbox_light.monitoring = false
    _is_special_active = false
    is_attacking = false
    _recovery_timer = SPECIAL_RECOVERY
    change_state(State.IDLE)
State.ATTACK_LIGHT:
    hitbox_light.monitoring = false
    is_attacking = false
    _recovery_timer = LIGHT_RECOVERY
    change_state(State.IDLE)
```

**Why:** 0 recovery on both moves meant a Samurai player could throw them out freely
with no risk. 100ms (~6 frames) and 120ms (~7 frames) are short enough to be
invisible in normal play but create a real punish window when whiffed close to an
opponent.

---

## Change 6 — SamuraiArcher.gd: Arrow Damage Increase

**File:** `scripts/characters/SamuraiArcher.gd`  
**Location:** Constants block

**Before:**
```gdscript
const ARROW_DAMAGE: float = 14.0
```

**After:**
```gdscript
const ARROW_DAMAGE: float = 16.0
```

Header comment updated to reflect new value.

**Why:** The Archer has no block and the lowest HP (110). The arrow requires
committing to a full cast animation before firing. At 14 damage, the arrow did less
than the Heavy melee (also 16). 16 damage makes the projectile worth the commitment
without outpacing melee-range options.

---

## Final State

All 6 changes applied and verified error-free. Game boots and validates all 9
characters clean. Hitstun values are now:

| Hit type | Old | New |
|----------|-----|-----|
| Light | 0.5s | 0.18s |
| Heavy | 1.2s | 0.35s |
| Light Charge (Lightning Mage) | 2.2s (1.2 + 1.0) | 0.60s (0.35 + 0.25) |
