# Phase 11 Session Notes — Polish, Ninjas, CPU AI, 4-Player

## Overview

Phase 11 covered four major areas: three new ninja characters, a full CPU AI state
machine, 4-player support, and a broad polish pass (HUD rework, screen shake,
respawn fade, match countdown, stun fixes). Balance and controls overhaul documented
separately in `phase11_balance_session_notes.md` and `phase11_controls_session_notes.md`.

---

## Ninja Characters

Three new characters added, each with a distinct playstyle:

### Kunoichi (`scripts/characters/Kunoichi.gd`)
**Scene:** `scenes/characters/Kunoichi.tscn`
- Fastest character in the roster (HP: 90, Speed: 350, Jump: -680)
- Light: fast dual-slash combo. Heavy: overhead slam.
- Special: Shuriken projectile (500px/s, 8 damage, 4 per burst).
- Special 2: Smoke dash — brief invincibility + teleport dash forward.
- Animations: `Idle`, `Walk`, `Run`, `Jump`, `Attack_1`, `Attack_2`, `Throw`,
  `Shuriken`, `Smoke_bomb`, `Hurt`, `Dead`

### NinjaMonk (`scripts/characters/NinjaMonk.gd`)
**Scene:** `scenes/characters/NinjaMonk.tscn`
- Balanced staff fighter (HP: 110, Speed: 290, Jump: -620)
- Light: quick staff strike. Heavy: wide sweep.
- Special: Staff throw projectile (450px/s, 12 damage).
- Special 2: Blade slash — close-range heavy burst (20 damage).
- Animations: `Idle`, `Walk`, `Run`, `Jump`, `Attack_1`, `Attack_2`, `Throw`,
  `Staff`, `Blade`, `Hurt`, `Dead`

### NinjaPeasant (`scripts/characters/NinjaPeasant.gd`)
**Scene:** `scenes/characters/NinjaPeasant.tscn`
- Glass cannon (HP: 100, Speed: 300, Jump: -650)
- Light: scythe swipe. Heavy: charged overhead.
- Special: Kunai burst (three kunai in spread, 7 damage each).
- Special 2: Ground slam — AOE attack via hitbox_heavy (22 damage).
- Animations: `Idle`, `Walk`, `Run`, `Jump`, `Attack_1`, `Attack_2`, `Throw`,
  `Kunai`, `Ground_slam`, `Hurt`, `Dead`

### CharacterSelect Grid Expansion
Grid expanded from 3×3 to 4-column layout to accommodate 12 characters.
All 12 characters listed in `CHARACTERS` constant with correct idle PNG paths.
`PREVIEW_OFFSETS` and `PREVIEW_TINTS` entries added for all three ninjas.

---

## CPU AI State Machine

**Script:** `scripts/characters/CPUController.gd`

Attached to a character when `GameManager.player_is_cpu[i]` is true.
`BattleScene._ready()` calls `_attach_cpu(character, player_id)` after spawning.

### States
```
IDLE → APPROACH → ATTACK → RETREAT → JUMP_APPROACH
```

| State | Behavior |
|-------|----------|
| IDLE | Short pause before deciding. Transitions to APPROACH. |
| APPROACH | Moves toward the nearest opponent. Transitions to ATTACK within range. |
| ATTACK | Fires light, heavy, or special randomly weighted. Retreats after. |
| RETREAT | Steps back briefly. Transitions to IDLE or JUMP_APPROACH. |
| JUMP_APPROACH | Jumps toward opponent. Used when opponent is above or blocked. |

### Key Design Notes
- CPU reads the same `InputManager` interface as human players via simulated
  `_inject_input()` calls rather than calling character methods directly.
  This ensures identical physics and hitbox activation paths.
- Attack selection weighted: 60% light, 30% heavy, 10% special.
- Reaction delay: 0.05–0.15s randomized per decision cycle to feel less robotic.
- Avoidance: CPU detects edge proximity (`position.x < 200` or `> 1080`) and
  moves toward center rather than off the stage.

---

## 4-Player Support

### GameManager
`active_player_count` extended to support 2–4 players. `player_characters`,
`player_is_cpu`, and `player_stocks` are 4-element arrays.

### CharacterSelect
`_player_count` can be 2–4. Each player gets their own panel column.
Players 3 and 4 use `p3_` / `p4_` input prefix bindings.

### BattleScene
Spawns up to 4 characters at 4 spawn points. `_on_kill_zone_entered()` and
stock/win logic generalized to work with any active player count.
Win condition: last player with stocks > 0 wins.

### HUD
Generalized to show 1–4 player panels. P1/P2 panels bottom-left/right as before.
P3/P4 panels top-left/top-right. Each panel: health bar + stock hearts.

---

## Polish — Screen Shake

`BattleScene._start_screen_shake(intensity, duration)` added. Creates a tween that
offsets `$Camera2D.offset` by a random Vector2 within ±intensity, then returns to
zero over duration seconds.

Triggered on:
- Heavy hit landing: intensity 8, duration 0.15s
- KO / stock loss: intensity 15, duration 0.3s

---

## Polish — Respawn Fade

Characters respawn with `modulate.a = 0.0` and tween to 1.0 over 0.5 seconds
(falling in from above simultaneously). The `is_invincible` flag covers the entire
fade-in duration to prevent hits during the animation.

---

## Polish — Match Countdown

`BattleScene._run_countdown()` builds a full-screen CanvasLayer (layer 20) overlay.
Beats: "3", "2", "1", "FIGHT!" — each pops in with a scale tween (0.3→1.15→1.0
over 200ms), holds for 500ms (650ms for FIGHT!), then fades out. Players are
movement-locked during the countdown via `process_mode = PROCESS_MODE_DISABLED`.

---

## Polish — Stunlock Fixes

Documented in `STUNLOCK_FIXES.md`. Key fixes:
- HURT state exit now driven by `_hitstun_timer` reaching 0, not `animation_finished`.
  Prevents permanent HURT lock when hitstun timer expires before animation ends.
- `die()` state guard (`if state == State.DEAD: return`) now on the very first line.
  Prevents double-stock-decrement from simultaneous kill zone callbacks.
- `is_invincible` checked in kill zone callback to block re-trigger during i-frames.
