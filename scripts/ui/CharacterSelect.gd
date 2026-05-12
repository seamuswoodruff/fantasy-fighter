# CharacterSelect.gd — 4-player + CPU + editable stocks + dynamic player count
extends Node2D

const CHARACTERS := [
	{ "key": "knight_1",          "name": "KNIGHT I",    "idle": "res://assets/characters/warriors/knight_1/sprites/Idle.png" },
	{ "key": "knight_2",          "name": "KNIGHT II",   "idle": "res://assets/characters/warriors/knight_2/sprites/Idle.png" },
	{ "key": "knight_3",          "name": "KNIGHT III",  "idle": "res://assets/characters/warriors/knight_3/sprites/Idle.png" },
	{ "key": "samurai",           "name": "SAMURAI",     "idle": "res://assets/characters/samurai/samurai/sprites/Idle.png" },
	{ "key": "samurai_commander", "name": "COMMANDER",   "idle": "res://assets/characters/samurai/samurai_commander/sprites/Idle.png" },
	{ "key": "samurai_archer",    "name": "ARCHER",      "idle": "res://assets/characters/samurai/samurai_archer/sprites/Idle.png" },
	{ "key": "fire_wizard",       "name": "FIRE WIZARD", "idle": "res://assets/characters/wizards/fire_wizard/sprites/Idle.png" },
	{ "key": "lightning_mage",    "name": "LT. MAGE",    "idle": "res://assets/characters/wizards/lightning_mage/sprites/Idle.png" },
	{ "key": "wanderer_magician", "name": "WANDERER",    "idle": "res://assets/characters/wizards/wanderer_magician/sprites/Idle.png" },
	{ "key": "kunoichi",          "name": "KUNOICHI",    "idle": "res://assets/characters/ninjas/kunoichi/sprites/Idle.png" },
	{ "key": "ninja_monk",        "name": "NINJA MONK",  "idle": "res://assets/characters/ninjas/ninja_monk/sprites/Idle.png" },
	{ "key": "ninja_peasant",     "name": "NINJA",       "idle": "res://assets/characters/ninjas/ninja_peasant/sprites/Idle.png" },
]

const CELL_SIZE   := 80
const PORTRAIT_PX := 72
const GRID_TOP_Y  := 148
const IDLE_FPS    := 8.0

const PLAYER_COLORS := [
	Color(0.4, 0.7, 1.0),   # P1 blue
	Color(1.0, 0.5, 0.5),   # P2 red
	Color(0.4, 1.0, 0.5),   # P3 green
	Color(1.0, 0.85, 0.3),  # P4 gold
]

# ── Per-player state (size always == _player_count) ───────────────────────────
var _player_count: int = 2
var _cursors: Array[Vector2i] = []
var _locked: Array[bool] = []
var _is_cpu: Array[bool] = []
var _cursor_rects: Array = []
var _name_lbls: Array = []
var _lock_lbls: Array = []
var _status_lbls: Array = []
var _previews: Array = []
var _preview_hframes: Array[int] = []
var _anim_timers: Array[float] = []
var _anim_frames: Array[int] = []
var _panel_xs: Array[int] = []
var _panel_w: int = 600

# All nodes created by _build_panel() — freed when rebuilding
var _panel_node_refs: Array = []

# Stock + player-count UI refs (built once)
var _stock_lbl: Label = null
var _count_lbl: Label = null

func _ready() -> void:
	# Always start with 2 players regardless of connected controllers
	_player_count = 2
	GameManager.active_player_count = 2
	InputManager.reassign_controllers()

	_init_player_arrays(_player_count)
	_build_static_ui()
	_rebuild_panels()
	AudioManager.play_sfx("menu_open_1")
	print("[CharacterSelect] Ready — %d players" % _player_count)

# ── Array init ────────────────────────────────────────────────────────────────
func _init_player_arrays(count: int) -> void:
	_cursors           = []
	_locked            = []
	_is_cpu            = []
	_cursor_rects      = []
	_name_lbls         = []
	_lock_lbls         = []
	_status_lbls       = []
	_previews          = []
	_preview_hframes   = []
	_anim_timers       = []
	_anim_frames       = []
	_panel_xs          = []
	for i in count:
		_cursors.append(Vector2i(i % 4, 0))
		_locked.append(false)
		_is_cpu.append(false)
		_cursor_rects.append(null)
		_name_lbls.append(null)
		_lock_lbls.append(null)
		_status_lbls.append(null)
		_previews.append(null)
		_preview_hframes.append(1)
		_anim_timers.append(0.0)
		_anim_frames.append(0)

# ── Static UI (built once) ────────────────────────────────────────────────────
func _build_static_ui() -> void:
	var font_big := load("res://assets/ui/fonts/alagard.ttf") as FontFile
	var font_sm  := load("res://assets/ui/fonts/Planes_ValMore.ttf") as FontFile

	# Animated background
	const CS_FRAME_DIR   := "res://assets/ui/backgrounds/charselect/"
	const CS_FRAME_COUNT := 20
	var cs_sf := SpriteFrames.new()
	cs_sf.add_animation("bg")
	cs_sf.set_animation_loop("bg", true)
	cs_sf.set_animation_speed("bg", 10.0)
	for i in CS_FRAME_COUNT:
		var img := Image.new()
		img.load(ProjectSettings.globalize_path(CS_FRAME_DIR + "frame_%02d.png" % i))
		cs_sf.add_frame("bg", ImageTexture.create_from_image(img))
	var cs_bg := AnimatedSprite2D.new()
	cs_bg.sprite_frames = cs_sf
	cs_bg.animation = "bg"
	cs_bg.play("bg")
	var cs_scale := maxf(1280.0 / 1580.0, 720.0 / 725.0)
	cs_bg.scale    = Vector2(cs_scale, cs_scale)
	cs_bg.position = Vector2(640.0, 360.0)
	cs_bg.z_index  = -1
	add_child(cs_bg)

	var overlay := ColorRect.new()
	overlay.color    = Color(0.0, 0.0, 0.0, 0.45)
	overlay.position = Vector2.ZERO
	overlay.size     = Vector2(1280, 720)
	add_child(overlay)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.position = Vector2(30.0, 20.0)
	back_btn.size     = Vector2(160.0, 44.0)
	back_btn.add_theme_font_override("font", font_big)
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)

	# Title
	var title := Label.new()
	title.text = "SELECT YOUR CHARACTER"
	title.position = Vector2(0, 16)
	title.size     = Vector2(1280, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font_big)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(title)

	# ── Player count row ──────────────────────────────────────────────────────
	var pc_lbl := Label.new()
	pc_lbl.text     = "PLAYERS:"
	pc_lbl.position = Vector2(380, 64)
	pc_lbl.size     = Vector2(130, 28)
	pc_lbl.add_theme_font_override("font", font_big)
	pc_lbl.add_theme_font_size_override("font_size", 19)
	pc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	add_child(pc_lbl)

	var pc_minus := Button.new()
	pc_minus.text     = "<"
	pc_minus.position = Vector2(512, 62)
	pc_minus.size     = Vector2(34, 30)
	pc_minus.add_theme_font_override("font", font_big)
	pc_minus.add_theme_font_size_override("font_size", 18)
	pc_minus.pressed.connect(func() -> void: _change_player_count(-1))
	add_child(pc_minus)

	_count_lbl = Label.new()
	_count_lbl.text     = str(_player_count)
	_count_lbl.position = Vector2(548, 64)
	_count_lbl.size     = Vector2(34, 28)
	_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_lbl.add_theme_font_override("font", font_big)
	_count_lbl.add_theme_font_size_override("font_size", 22)
	_count_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(_count_lbl)

	var pc_plus := Button.new()
	pc_plus.text     = ">"
	pc_plus.position = Vector2(584, 62)
	pc_plus.size     = Vector2(34, 30)
	pc_plus.add_theme_font_override("font", font_big)
	pc_plus.add_theme_font_size_override("font_size", 18)
	pc_plus.pressed.connect(func() -> void: _change_player_count(1))
	add_child(pc_plus)

	var pc_hint := Label.new()
	pc_hint.text     = "(– / + keys)"
	pc_hint.position = Vector2(622, 68)
	pc_hint.size     = Vector2(120, 22)
	pc_hint.add_theme_font_override("font", font_sm)
	pc_hint.add_theme_font_size_override("font_size", 12)
	pc_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	add_child(pc_hint)

	# ── Stock selector row ────────────────────────────────────────────────────
	var stock_lbl := Label.new()
	stock_lbl.text     = "STOCKS:"
	stock_lbl.position = Vector2(380, 96)
	stock_lbl.size     = Vector2(130, 26)
	stock_lbl.add_theme_font_override("font", font_big)
	stock_lbl.add_theme_font_size_override("font_size", 19)
	stock_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	add_child(stock_lbl)

	var st_minus := Button.new()
	st_minus.text     = "<"
	st_minus.position = Vector2(512, 94)
	st_minus.size     = Vector2(34, 30)
	st_minus.add_theme_font_override("font", font_big)
	st_minus.add_theme_font_size_override("font_size", 18)
	st_minus.pressed.connect(func() -> void: _change_stocks(-1))
	add_child(st_minus)

	_stock_lbl = Label.new()
	_stock_lbl.text     = str(GameManager.stock_count)
	_stock_lbl.position = Vector2(548, 96)
	_stock_lbl.size     = Vector2(34, 26)
	_stock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stock_lbl.add_theme_font_override("font", font_big)
	_stock_lbl.add_theme_font_size_override("font_size", 20)
	_stock_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(_stock_lbl)

	var st_plus := Button.new()
	st_plus.text     = ">"
	st_plus.position = Vector2(584, 94)
	st_plus.size     = Vector2(34, 30)
	st_plus.add_theme_font_override("font", font_big)
	st_plus.add_theme_font_size_override("font_size", 18)
	st_plus.pressed.connect(func() -> void: _change_stocks(1))
	add_child(st_plus)

	var stock_hint := Label.new()
	stock_hint.text     = "([ ] keys)"
	stock_hint.position = Vector2(622, 100)
	stock_hint.size     = Vector2(100, 20)
	stock_hint.add_theme_font_override("font", font_sm)
	stock_hint.add_theme_font_size_override("font_size", 12)
	stock_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	add_child(stock_hint)

	# Instructions at bottom
	var instr := Label.new()
	instr.text = "Move: WASD / Arrows / Stick    Confirm: Space / [/] / A    CPU (P2): Tab    Players: – / +"
	instr.position = Vector2(0, 694)
	instr.size     = Vector2(1280, 22)
	instr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instr.add_theme_font_override("font", font_sm)
	instr.add_theme_font_size_override("font_size", 12)
	instr.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	add_child(instr)

# ── Panel rebuild ─────────────────────────────────────────────────────────────
func _rebuild_panels() -> void:
	# Free all previously created panel nodes
	for node in _panel_node_refs:
		if is_instance_valid(node):
			node.queue_free()
	_panel_node_refs.clear()

	# Recompute layout
	_panel_xs.clear()
	const PANEL_GAP := 12
	const TOTAL_W   := 1240
	_panel_w = int((TOTAL_W - (_player_count - 1) * PANEL_GAP) / float(_player_count))
	var start_x := 20
	for i in _player_count:
		_panel_xs.append(start_x + i * (_panel_w + PANEL_GAP))

	for i in _player_count:
		_build_panel(i)

	# Restore cursor visuals
	for i in _player_count:
		_update_cursor(i)

func _build_panel(pid_idx: int) -> void:
	var panel_x: int = _panel_xs[pid_idx]
	var color: Color = PLAYER_COLORS[pid_idx]
	var font_big := load("res://assets/ui/fonts/alagard.ttf") as FontFile
	var font_sm  := load("res://assets/ui/fonts/Planes_ValMore.ttf") as FontFile
	var has_ctrl := _player_has_controller(pid_idx)

	var panel_bg := ColorRect.new()
	panel_bg.color    = Color(0.08, 0.06, 0.15, 0.8)
	panel_bg.position = Vector2(panel_x, 128)
	panel_bg.size     = Vector2(_panel_w, 562)
	add_child(panel_bg)
	_panel_node_refs.append(panel_bg)

	var header := Label.new()
	header.text = "PLAYER %d" % (pid_idx + 1)
	header.position = Vector2(panel_x, 132)
	header.size     = Vector2(_panel_w, 28)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_override("font", font_big)
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", color)
	add_child(header)
	_panel_node_refs.append(header)
	_status_lbls[pid_idx] = header

	# "No Controller" warning for P3/P4 without a controller
	if pid_idx >= 2 and not has_ctrl:
		var warn := Label.new()
		warn.text     = "⚠  Connect Controller"
		warn.position = Vector2(panel_x, 160)
		warn.size     = Vector2(_panel_w, 22)
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warn.add_theme_font_override("font", font_sm)
		warn.add_theme_font_size_override("font_size", 13)
		warn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		add_child(warn)
		_panel_node_refs.append(warn)

	# Grid (4×3), centered in panel
	var grid_offset_x := int((_panel_w - 4 * CELL_SIZE) / float(2))
	var grid_x        := panel_x + grid_offset_x

	var cursor := ColorRect.new()
	cursor.size    = Vector2(CELL_SIZE, CELL_SIZE)
	cursor.color   = color * Color(1, 1, 1, 0.35)
	cursor.z_index = 1
	add_child(cursor)
	_panel_node_refs.append(cursor)
	_cursor_rects[pid_idx] = cursor

	for row in 3:
		for col in 4:
			var idx: int = row * 4 + col
			var cell_pos := Vector2(grid_x + col * CELL_SIZE, GRID_TOP_Y + row * CELL_SIZE)
			var cell_bg := ColorRect.new()
			cell_bg.color    = Color(0.15, 0.12, 0.22, 1)
			cell_bg.position = cell_pos
			cell_bg.size     = Vector2(CELL_SIZE, CELL_SIZE)
			cell_bg.z_index  = 0
			add_child(cell_bg)
			_panel_node_refs.append(cell_bg)
			var tex := _load_portrait_tex(CHARACTERS[idx]["idle"])
			var portrait := Sprite2D.new()
			portrait.texture  = tex
			# Frame size = sheet height (all idle sheets are square-per-frame)
			var frame_px: int = tex.get_height() if tex != null else 128
			portrait.hframes  = int(tex.get_width() / float(frame_px)) if tex != null else 1
			portrait.frame    = 0
			portrait.position = cell_pos + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
			portrait.scale    = Vector2(PORTRAIT_PX / 128.0, PORTRAIT_PX / 128.0)
			portrait.z_index  = 2
			add_child(portrait)
			_panel_node_refs.append(portrait)

	var name_lbl := Label.new()
	name_lbl.position = Vector2(panel_x, GRID_TOP_Y + 3 * CELL_SIZE + 6)
	name_lbl.size     = Vector2(_panel_w, 28)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", font_big)
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(name_lbl)
	_panel_node_refs.append(name_lbl)
	_name_lbls[pid_idx] = name_lbl

	# Confirm hint text
	var confirm_hint: String
	if pid_idx == 0:
		confirm_hint = "Space to confirm"
	elif pid_idx == 1:
		confirm_hint = "[/] to confirm"
	else:
		confirm_hint = "A (controller) to confirm"

	var lock_lbl := Label.new()
	lock_lbl.position = Vector2(panel_x, GRID_TOP_Y + 3 * CELL_SIZE + 38)
	lock_lbl.size     = Vector2(_panel_w, 26)
	lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_lbl.add_theme_font_override("font", font_sm)
	lock_lbl.add_theme_font_size_override("font_size", 14)
	lock_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	lock_lbl.text = confirm_hint
	add_child(lock_lbl)
	_panel_node_refs.append(lock_lbl)
	_lock_lbls[pid_idx] = lock_lbl

	# Preview sprite
	var first_tex := _load_portrait_tex(CHARACTERS[_cursors[pid_idx].y * 4 + _cursors[pid_idx].x]["idle"])
	var preview := Sprite2D.new()
	preview.texture  = first_tex
	var _fpx: int = first_tex.get_height() if first_tex != null else 128
	preview.hframes  = int(first_tex.get_width() / float(_fpx)) if first_tex != null else 1
	preview.frame    = 0
	preview.position = Vector2(panel_x + int(_panel_w / float(2)), 618)
	preview.scale    = Vector2(1.3, 1.3)
	preview.z_index  = 3
	add_child(preview)
	_panel_node_refs.append(preview)
	_previews[pid_idx]         = preview
	_preview_hframes[pid_idx]  = preview.hframes

	# If already locked (e.g. after player count change restores state), show READY
	if _locked[pid_idx]:
		_lock_lbls[pid_idx].text = "READY!"

func _player_has_controller(pid_idx: int) -> bool:
	# P1 and P2 have keyboard; P3 needs ≥1 controller, P4 needs ≥2
	if pid_idx < 2:
		return true
	var required := pid_idx - 1  # P3 needs 1, P4 needs 2
	return Input.get_connected_joypads().size() >= required

# ── Player count change ───────────────────────────────────────────────────────
func _change_player_count(delta: int) -> void:
	var max_count: int = InputManager.get_max_player_count()
	var new_count: int = clampi(_player_count + delta, 2, max_count)
	if new_count == _player_count:
		# Flash the count label to indicate limit
		if _count_lbl:
			_count_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			await get_tree().create_timer(0.25).timeout
			_count_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		return

	# Save state for players that exist in both old and new counts
	var save_cursors := _cursors.duplicate()
	var save_locked  := _locked.duplicate()
	var save_is_cpu  := _is_cpu.duplicate()

	_player_count = new_count
	GameManager.active_player_count = new_count
	InputManager.reassign_controllers()

	# Reinitialise arrays for new count, restoring existing player state
	_init_player_arrays(new_count)
	for i in mini(save_cursors.size(), new_count):
		_cursors[i]  = save_cursors[i]
		_locked[i]   = save_locked[i]
		_is_cpu[i]   = save_is_cpu[i]
		GameManager.player_is_cpu[i] = _is_cpu[i]

	# Clear GameManager slots for removed players
	for i in range(new_count, 4):
		GameManager.player_characters[i] = ""
		GameManager.player_is_cpu[i]     = false

	_rebuild_panels()

	if _count_lbl:
		_count_lbl.text = str(_player_count)

	AudioManager.play_sfx("select")
	print("[CharacterSelect] Player count → %d (max:%d)" % [_player_count, max_count])

# ── Input ─────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	match ke.keycode:
		KEY_MINUS, KEY_KP_SUBTRACT:
			_change_player_count(-1)
		KEY_EQUAL, KEY_KP_ADD:
			_change_player_count(1)
		KEY_BRACKETLEFT:
			_change_stocks(-1)
		KEY_BRACKETRIGHT:
			_change_stocks(1)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_on_back_pressed()
		return

	# (player count ± and stock [ ] changes handled in _input())

	# P2 CPU toggle (Tab)
	if _player_count >= 2:
		if not _locked[1] or _is_cpu[1]:
			if Input.is_action_just_pressed("ui_focus_next"):
				_toggle_cpu(1)

	# Per-player cursor / confirm
	for i in _player_count:
		if _is_cpu[i]:
			continue
		if _locked[i]:
			continue
		var pfx: String = "p%d_" % (i + 1)
		if Input.is_action_just_pressed(pfx + "left"):
			_move_cursor(i, Vector2i(-1, 0))
		elif Input.is_action_just_pressed(pfx + "right"):
			_move_cursor(i, Vector2i(1, 0))
		elif Input.is_action_just_pressed(pfx + "up"):
			_move_cursor(i, Vector2i(0, -1))
		elif Input.is_action_just_pressed(pfx + "down"):
			_move_cursor(i, Vector2i(0, 1))
		elif Input.is_action_just_pressed(pfx + "jump") or \
			 Input.is_action_just_pressed(pfx + "light_attack"):
			_lock_player(i)

	# Animate previews
	for i in _player_count:
		if _is_cpu[i]:
			continue
		_anim_timers[i] += delta
		if _anim_timers[i] >= 1.0 / IDLE_FPS:
			_anim_timers[i] = 0.0
			_anim_frames[i] = (_anim_frames[i] + 1) % _preview_hframes[i]
			if _previews[i] != null:
				(_previews[i] as Sprite2D).frame = _anim_frames[i]

# ── Game actions ──────────────────────────────────────────────────────────────
func _change_stocks(delta: int) -> void:
	var new_val := clampi(GameManager.stock_count + delta, 1, 5)
	if new_val == GameManager.stock_count:
		return
	GameManager.stock_count = new_val
	_stock_lbl.text = str(GameManager.stock_count)
	AudioManager.play_sfx("select")

func _toggle_cpu(pid_idx: int) -> void:
	_is_cpu[pid_idx]                   = not _is_cpu[pid_idx]
	GameManager.player_is_cpu[pid_idx] = _is_cpu[pid_idx]
	if _is_cpu[pid_idx]:
		var random_idx := randi() % CHARACTERS.size()
		GameManager.player_characters[pid_idx] = CHARACTERS[random_idx]["key"]
		_status_lbls[pid_idx].text = "CPU"
		_lock_lbls[pid_idx].text   = "Random character selected"
		_lock_lbls[pid_idx].add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		var tex := _load_portrait_tex(CHARACTERS[random_idx]["idle"])
		var fpx := tex.get_height() if tex != null else 128
		_previews[pid_idx].texture  = tex
		_previews[pid_idx].hframes  = int(tex.get_width() / float(fpx)) if tex != null else 1
		_previews[pid_idx].frame    = 0
		_preview_hframes[pid_idx]   = _previews[pid_idx].hframes
		AudioManager.play_sfx("confirm_1")
		_locked[pid_idx] = true
		_check_all_locked()
	else:
		GameManager.player_characters[pid_idx] = ""
		GameManager.player_is_cpu[pid_idx]     = false
		_status_lbls[pid_idx].text = "PLAYER %d" % (pid_idx + 1)
		var hint := "Space to confirm" if pid_idx == 0 else (
			"[/] to confirm" if pid_idx == 1 else "A (controller) to confirm")
		_lock_lbls[pid_idx].text = hint
		_lock_lbls[pid_idx].add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		_locked[pid_idx] = false
		AudioManager.play_sfx("back_1")

func _move_cursor(pid_idx: int, delta: Vector2i) -> void:
	_cursors[pid_idx] = Vector2i(
		(_cursors[pid_idx].x + delta.x + 4) % 4,
		(_cursors[pid_idx].y + delta.y + 3) % 3
	)
	_update_cursor(pid_idx)
	AudioManager.play_sfx("select")

func _update_cursor(pid_idx: int) -> void:
	if _cursor_rects[pid_idx] == null or not is_instance_valid(_cursor_rects[pid_idx]):
		return
	var cur := _cursors[pid_idx]
	var grid_offset_x := int((_panel_w - 4 * CELL_SIZE) / float(2))
	var grid_x: int   = _panel_xs[pid_idx] + grid_offset_x
	_cursor_rects[pid_idx].position = Vector2(
		grid_x + cur.x * CELL_SIZE, GRID_TOP_Y + cur.y * CELL_SIZE)
	var idx: int = cur.y * 4 + cur.x
	if _name_lbls[pid_idx] != null:
		_name_lbls[pid_idx].text = CHARACTERS[idx]["name"]
	if _previews[pid_idx] != null:
		var tex := _load_portrait_tex(CHARACTERS[idx]["idle"])
		var fpx := tex.get_height() if tex != null else 128
		var hf  := int(tex.get_width() / float(fpx)) if tex != null else 1
		_previews[pid_idx].texture = tex
		_previews[pid_idx].hframes = hf
		_previews[pid_idx].frame   = 0
		_preview_hframes[pid_idx]  = hf
		_anim_frames[pid_idx]      = 0

func _lock_player(pid_idx: int) -> void:
	var idx: int = _cursors[pid_idx].y * 4 + _cursors[pid_idx].x
	GameManager.player_characters[pid_idx] = CHARACTERS[idx]["key"]
	_locked[pid_idx]         = true
	_lock_lbls[pid_idx].text = "READY!"
	_lock_lbls[pid_idx].add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	AudioManager.play_sfx("confirm_1")
	print("[CharacterSelect] P%d locked: %s" % [pid_idx + 1, CHARACTERS[idx]["key"]])
	_check_all_locked()

func _check_all_locked() -> void:
	for i in _player_count:
		if not _locked[i]:
			return
	await get_tree().create_timer(0.5).timeout
	GameManager.go_to_stage_select()

func _on_back_pressed() -> void:
	AudioManager.play_sfx("back_1")
	GameManager.go_to_main_menu()

# Loads a PNG that may not have a .import sidecar (e.g. ninja sprites).
# Falls back to raw Image load if load() fails.
func _load_portrait_tex(res_path: String) -> Texture2D:
	# Use ResourceLoader.exists() to avoid engine-level error logs for un-imported PNGs
	if ResourceLoader.exists(res_path):
		return load(res_path) as Texture2D
	var img := Image.new()
	var err := img.load(ProjectSettings.globalize_path(res_path))
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)
