# Phase 10 Session Notes — Full Menu Flow

## Overview

Complete menu flow implemented: MainMenu → CharacterSelect → StageSelect →
BattleScene → WinScreen → loop. All scenes built procedurally in GDScript using
the alagard/Planes_ValMore font pair. Full keyboard and controller navigation.

---

## MainMenu

**Scene:** `scenes/ui/MainMenu.tscn`
**Script:** `scripts/ui/MainMenu.gd`

Four buttons: Start Game, Options, Credits, Quit.
- Background: animated GIF converted to sprite sheet (`homescreen_sheet.png`),
  played as AnimatedSprite2D at 10fps.
- Controller cursor: `_cursor` int + `_buttons` Array, navigated with p1_up/down,
  confirmed with p1_jump or p1_light_attack. Selected button tints gold.
- Connects to: CharacterSelect, OptionsMenu, Credits, `get_tree().quit()`.

---

## CharacterSelect

**Scene:** `scenes/ui/CharacterSelect.tscn`
**Script:** `scripts/ui/CharacterSelect.gd`

### Layout
4-column × 3-row grid showing all 12 characters (9 original + 3 ninjas).
Each cell: 80×80px portrait with character name below.

### Per-Player State
- Each player has an independent cursor (`Vector2i`), locked status, and preview panel.
- P1: WASD + Space to confirm. P2: Arrow keys + `/` to confirm.
- Controller: left stick/DPad to move cursor, A/Cross to lock in.

### CPU Toggle
Each player panel has a CPU button. Toggling CPU assigns a random character,
locks the slot, and sets `GameManager.player_is_cpu[i] = true`. The BattleScene
uses this to attach `CPUController.gd` instead of reading player input.

### Stock Count
+/- buttons on the shared header adjust `GameManager.stock_count` (1–5 stocks).
Default 3.

### Preview Animation
Locked-in character's idle sprite animates in their panel at 8fps.
`PREVIEW_OFFSETS` and `PREVIEW_TINTS` dictionaries fine-tune per-character
sprite positioning and color tinting for the preview display.

### Proceeding
Both non-CPU players must lock in before the "FIGHT" button activates.
Calls `GameManager.go_to_stage_select()`.

---

## StageSelect

**Scene:** `scenes/ui/StageSelect.tscn`
**Script:** `scripts/ui/StageSelect.gd`

Three stage cards (330×200px thumbnails) with the stage background image scaled
to fit. Highlight rect tracks the selected card. P1 navigates with left/right,
confirms with Space or Z. Calls `GameManager.go_to_battle()`.

---

## WinScreen

**Scene:** `scenes/ui/WinScreen.tscn`
**Script:** `scripts/ui/WinScreen.gd`

### Victory Display
- `CHAR_DISPLAY_NAMES` maps character keys to readable names.
- `CHAR_VICTORY_SEQUENCES` maps each character to their idle animation PNG for
  the victory pose display.
- Winner's sprite animates in a large centered preview alongside "PLAYER X WINS".
- Victory state machine (`VictoryState` enum): ENTER → HOLD → REMATCH.

### Buttons
Rematch: reloads BattleScene with same characters and stage.
Menu: clears `GameManager.p1_character` / `p2_character` and goes to MainMenu.

---

## OptionsMenu

**Scene:** `scenes/ui/OptionsMenu.tscn`
**Script:** `scripts/ui/OptionsMenu.gd`

- Background: animated dark forest sprite sheet (`optionsscreen_sheet.png`).
- Three HSlider rows: Music, SFX, Ambience — each mapped to an AudioServer bus.
- Value range 0–100% mapped to −40dB–0dB via linear interpolation.
- Percentage label updates live as slider moves.
- Controls reference table showing all keyboard and controller bindings.
- Focus chain wired for full controller navigation (Back → Music → SFX → Ambience).

---

## Credits

**Scene:** `scenes/ui/Credits.tscn`
**Script:** `scripts/ui/Credits.gd`

- Background: animated GIF sprite sheet (`credits_bg_sheet.png`, 71 frames, 8×9 grid).
- RichTextLabel inside a ScrollContainer auto-scrolls using a state machine:
  PAUSE_TOP (1s) → SCROLLING → PAUSE_BOTTOM (1s) → reset.
- BBCode for headers, colors, and centered alignment.

---

## PauseMenu

**Scene:** `scenes/ui/PauseMenu.tscn`
**Script:** `scripts/ui/PauseMenu.gd`

In-battle pause overlay on Escape/Start. Options: Resume, Options, Quit to Menu.
Uses a separate CanvasLayer (layer 30) and `PROCESS_MODE_ALWAYS` so it stays
active while the game tree is paused.

---

## GameManager Updates

Added for Phase 10:
- `active_player_count: int` — 2 to 4 (CharacterSelect sets this)
- `player_characters: Array` — per-player character key array
- `player_is_cpu: Array` — per-player CPU flag
- `player_stocks: Array` — per-player stock tracking
- `stock_count: int` — match stock setting (default 3)
- Computed property aliases `p1_character` / `p2_character` for backward compatibility

---

## Full Scene Flow

```
MainMenu → CharacterSelect → StageSelect → BattleScene → WinScreen
                                                              ↓
                                                     Rematch → BattleScene
                                                     Menu    → MainMenu
```
