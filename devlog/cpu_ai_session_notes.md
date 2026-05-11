# CPU AI Session Notes — Full State Machine Controller

## Overview

Replaced the simple stub CPUController (direct velocity manipulation, single attack
type, no state logic) with a full state-machine AI driven through the character's
virtual input vars. The new system works for any character archetype — melee, ranged,
or wizard — because it calls the same `attack_light()`, `attack_heavy()`, `special_attack()`
methods that a human player would trigger.

---

## Architecture

### Virtual Input Interface (Character.gd changes)

Added two vars to the Character runtime state block:
```gdscript
var cpu_move_x: float = 0.0      # horizontal direction (-1, 0, 1)
var cpu_wants_jump: bool = false  # consumed once per frame
```

Added CPU guard at the very top of `handle_input()`:
```gdscript
func handle_input() -> void:
    if is_cpu:
        if cpu_wants_jump:
            _try_jump()
            cpu_wants_jump = false
        if cpu_move_x != 0.0:
            velocity.x = move_toward(velocity.x, cpu_move_x * move_speed,
                                     ACCELERATION * get_process_delta_time())
        else:
            velocity.x = move_toward(velocity.x, 0.0,
                                     FRICTION * get_process_delta_time())
        return
    # ... real input handling below
```

This means CPU characters go through the same physics (acceleration, friction, coyote
time, double jump) as human players — only the input source is different.

### Group Registration

- `Character._ready()` calls `add_to_group("characters")` — CPUController uses
  `get_tree().get_nodes_in_group("characters")` to find enemies
- `BattleScene._ready()` calls `add_to_group("battle_scene")` — CPUController uses
  `get_tree().get_first_node_in_group("battle_scene")` to locate spawn points and
  calculate stage center X

---

## CPUController State Machine

```
IDLE ──────► APPROACH ──────► ATTACK
  ▲               │               │
  │         (off-stage)      (took hit)
  │               ▼               ▼
  └──────── RECOVER          RETREAT ──► APPROACH
```

### States

| State | Behaviour |
|-------|-----------|
| **IDLE** | Stop moving. Wait for `_state_timer`. Then transition to APPROACH or ATTACK based on distance. |
| **APPROACH** | Move toward nearest enemy. Occasional jump to vary approach angle. Switch to RECOVER if off-stage. Switch to ATTACK when within 110px. |
| **ATTACK** | Stop moving. If `_state_timer` expired, pick and execute an attack, then go IDLE. If hit during attack, go RETREAT. If target moves out of 160px range, go APPROACH. |
| **RETREAT** | Move away from target for `_state_timer` seconds, then go APPROACH. |
| **RECOVER** | Move toward stage center X and use remaining jumps to return to platform. Once grounded, go APPROACH. |

### Difficulty Levels

| Difficulty | IDLE duration | Attack mix |
|------------|--------------|------------|
| 1 (Easy) | 0.6–1.2s | 90% light, 5% heavy, 5% special |
| 2 (Normal) | 0.1–0.45s | 55% light, 25% heavy, 20% special |
| 3 (Hard) | 0.04–0.18s | 40% light, 30% heavy, 30% special |

Default is **Normal (2)**. Multiple CPUs randomise their initial idle offset so they
don't all attack simultaneously.

### Stage Center Detection

On `_ready()`, CPUController finds BattleScene via group, then reads SpawnP1 and SpawnP2
positions to compute the midpoint:
```gdscript
_stage_center_x = (sp1.global_position.x + sp2.global_position.x) / 2.0
```
This is used by `_should_recover()` — if the CPU is airborne and more than 420px from
stage center, it enters RECOVER state.

---

## Tuning Notes

- **Attack range:** 110px to enter ATTACK, 160px to exit back to APPROACH
- **Jump interval:** 1.2–3.0s random while approaching
- **Retreat duration:** 0.4s fixed on taking a hit
- **Recovery threshold:** 420px from stage center while airborne

To make CPU more aggressive: lower `IDLE_RANGE` values and increase `ATTACK_WEIGHTS[2]`
heavy/special percentages.

To prevent edge-walking: increase the 420.0 recovery threshold in `_should_recover()`.

---

## Files Changed

- `scripts/characters/CPUController.gd` — full rewrite (state machine AI)
- `scripts/characters/Character.gd` — `cpu_move_x`, `cpu_wants_jump` vars; CPU guard in `handle_input()`; `add_to_group("characters")` in `_ready()`
- `scripts/stages/BattleScene.gd` — `add_to_group("battle_scene")` in `_ready()`
