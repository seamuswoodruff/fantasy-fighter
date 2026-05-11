# 4-Player Session Notes — Multi-Player Support, Controller Assignment, HUD

## What Was Built

### 4-Player Character Select (CharacterSelect.gd rewrite)

Full rewrite to support 2–4 players with a dynamic panel layout.

**Key design decisions:**
- Default always starts at 2 players — P3/P4 panels are added by pressing `]` / `=` to increase count
- P3 and P4 can only be added when a controller is connected (or set to CPU); panels show a "⚠ Connect Controller" warning if no controller is available
- Stock count is adjustable with `[` / `]` buttons next to a stock count display
- Player count and stock changes call `InputManager.reassign_controllers()` immediately so controllers follow the new assignment
- Panel rebuild pattern: `_panel_node_refs: Array` tracks all procedurally-created nodes; `queue_free()` + rebuild on every count change preserves P1/P2 cursor and lock state

**Input bindings for count/stock adjustment:**
- `KEY_BRACKETRIGHT` / `KEY_EQUAL` → increase player count / stocks
- `KEY_BRACKETLEFT` / `KEY_MINUS` → decrease player count / stocks

### Controller Assignment (InputManager.gd rewrite)

Controllers assign to the **highest active player slot** that doesn't already have one:
- 2 players, 2 controllers → device 0 → P2, device 1 → P1
- 3 players, 2 controllers → device 0 → P3, device 1 → P2
- 4 players, 2 controllers → device 0 → P4, device 1 → P3

**Implementation:** `reassign_controllers()` clears joypad bindings from all 4 players via `InputMap.action_erase_event()`, then re-adds them top-down from the highest active slot. This is called on every `joy_connection_changed` signal and every time player count changes in CharacterSelect.

**Critical fix — missing p3_*/p4_* actions:** These actions don't exist in `project.godot` by default. Added `_ensure_player_actions(pid)` which calls `InputMap.add_action()` for any missing `p{n}_*` suffix before assigning joypad events. Without this, all P3/P4 bindings were silently skipped.

### CPU Toggle

Each player panel in CharacterSelect has a CPU toggle button. Setting a slot to CPU:
- Sets `GameManager.player_is_cpu[idx] = true`
- Marks the slot as filled (no controller warning suppressed)
- BattleScene injects a `CPUController` child node onto the spawned character

### 4-Player BattleScene Spawning

```gdscript
for i in GameManager.active_player_count:
    var char_node := _spawn_character(key, i + 1)
    char_node.stocks = GameManager.stock_count   # sync with selected stock count
    var sp_node := stage.get_node_or_null("SpawnPoints/SpawnP%d" % (i + 1))
    ...
    if GameManager.player_is_cpu[i]:
        char_node.is_cpu = true
        _add_cpu_controller(char_node)
    players.append(char_node)
```

SpawnP3 and SpawnP4 `Marker2D` nodes were appended to all three stage .tscn files (Windrise, Ruins, DesertTemple). `get_node_or_null` fallback handles stages that don't have them yet.

### Dynamic N-Player HUD (HUD.gd rewrite)

Old HUD.tscn had static P1Bar/P2Bar nodes hard-coded for 2 players. Full rewrite:

**Architecture:**
- `HUD.tscn` stripped to just the root CanvasLayer + script — zero static nodes
- `set_players(p_array: Array)` is the new public API; `set_characters(p1, p2)` is a shim
- N health bars at the top, fixed width (260px each), centered across the screen
- N stock panels directly below each bar: player name left-aligned, hearts centered

**Health bar implementation:**
- Replaced `TextureProgressBar` (caused nine-patch stretching issues with `texture_under`) with a plain `ColorRect` fill
- Border `ColorRect` → dark trough `ColorRect` → green fill `ColorRect`, all added in Z-order
- `_process()` sets `fill.size.x = _fill_max_w[i] * (current_hp / max_hp)` each frame
- Color swaps to red below 25% HP

---

## Bugs Fixed

### Double stock decrement (silent until 1-stock mode)
`Character.die()` decremented `Character.stocks` AND `GameManager.on_player_death()` decremented `player_stocks[idx]`. These are separate variables. With the default `Character.stocks = 3`, a player with 1 selected stock would still respawn twice before `Character.stocks` reached 0.

**Fix:** Set `char_node.stocks = GameManager.stock_count` in BattleScene spawn loop so both counters start at the same value.

### Eliminated players not permanently removed
When `Character.stocks` hit 0, the `if stocks > 0` guard in `die()` skipped the hide/disable timer — the character stayed in DEAD state at their current position, visible on screen.

**Fix:** Added `else` branch in `die()` that hides and disables the character after the death animation (0.7s), same as the respawn branch but without scheduling a respawn.

### Controller assignment ignored p3_*/p4_* actions
`InputManager._assign_joy_to_player(3, device)` iterated over suffixes and called `InputMap.has_action("p3_left")` etc. — all returned false since project.godot never defined those actions. Every binding was silently skipped.

**Fix:** `_ensure_player_actions(pid)` creates missing actions via `InputMap.add_action()` before assigning events.

---

## Spawn Point Coordinates

| Stage | SpawnP1 | SpawnP2 | SpawnP3 | SpawnP4 |
|-------|---------|---------|---------|---------|
| Windrise | (240, 400) | (1040, 400) | (380, 400) | (900, 400) |
| Ruins | (240, 400) | (1040, 400) | (380, 400) | (900, 400) |
| DesertTemple | (240, 400) | (1040, 400) | (380, 400) | (900, 400) |

---

## Files Changed

- `scripts/ui/CharacterSelect.gd` — full rewrite
- `scripts/managers/InputManager.gd` — full rewrite
- `scripts/managers/GameManager.gd` — `player_is_cpu`, `active_player_count`, `stock_count` arrays
- `scripts/stages/BattleScene.gd` — N-player spawn loop, CPU injection, `char_node.stocks` sync
- `scripts/characters/Character.gd` — `is_cpu` flag, stocks fix in `die()`
- `scripts/ui/HUD.gd` — full rewrite (N-player dynamic)
- `scenes/ui/HUD.tscn` — stripped to bare CanvasLayer
- `scenes/stages/Windrise.tscn` — SpawnP3, SpawnP4 added
- `scenes/stages/Ruins.tscn` — SpawnP3, SpawnP4 added
- `scenes/stages/DesertTemple.tscn` — SpawnP3, SpawnP4 added
