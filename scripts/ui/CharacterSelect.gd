# CharacterSelect.gd — 4-player + CPU + editable stocks
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
]

const CELL_SIZE   := 80
const PORTRAIT_PX := 72
const GRID_TOP_Y  := 140
const IDLE_FPS    := 8.0

const PLAYER_COLORS := [
	Color(0.4, 0.7, 1.0),   # P1 blue
	Color(1.0, 0.5, 0.5),   # P2 red
	Color(0.4, 1.0, 0.5),   # P3 green
	Color(1.0, 0.85, 0.3),  # P4 gold
]

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
var _panel_w: int = 560

var _stock_count: int = 3
var _stock_lbl: Label = null

func _ready() -> void:
	_player_count = InputManager.get_active_player_count()
	GameManager.active_player_count = _player_count

	for i in _player_count:
		_cursors.append(Vector2i(i % 3, 0))
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

	_build_ui()
	for i in _player_count:
		_update_cursor(i)
	AudioManager.play_sfx("menu_open_1")
	print("[CharacterSelect] Ready — %d players" % _player_count)

func _build_ui() -> void:
	# ── Animated background ───────────────────────────────────────────────────
	const CS_FRAME_DIR := "res://assets/ui/backgrounds/charselect/"
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
	cs_bg.scale = Vector2(cs_scale, cs_scale)
	cs_bg.position = Vector2(640.0, 360.0)
	cs_bg.z_index = -1
	add_child(cs_bg)

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.45)
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(1280, 720)
	add_child(overlay)

	var font_big := load("res://assets/ui/fonts/alagard.ttf") as FontFile
	var font_sm  := load("res://assets/ui/fonts/Planes_ValMore.ttf") as FontFile

	# Back button
	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.position = Vector2(30.0, 20.0)
	back_btn.size = Vector2(160.0, 44.0)
	back_btn.add_theme_font_override("font", font_big)
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)

	# Title
	var title := Label.new()
	title.text = "SELECT YOUR CHARACTER"
	title.position = Vector2(0, 16)
	title.size = Vector2(1280, 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font_big)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(title)

	# Stock selector row
	var stock_row := Label.new()
	stock_row.text = "STOCKS:"
	stock_row.position = Vector2(480, 88)
	stock_row.size = Vector2(120, 30)
	stock_row.add_theme_font_override("font", font_big)
	stock_row.add_theme_font_size_override("font_size", 20)
	stock_row.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	add_child(stock_row)

	_stock_lbl = Label.new()
	_stock_lbl.text = str(_stock_count)
	_stock_lbl.position = Vector2(610, 88)
	_stock_lbl.size = Vector2(60, 30)
	_stock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stock_lbl.add_theme_font_override("font", font_big)
	_stock_lbl.add_theme_font_size_override("font_size", 22)
	_stock_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(_stock_lbl)

	var stock_hint := Label.new()
	stock_hint.text = "(P1 ← / → to change)"
	stock_hint.position = Vector2(680, 92)
	stock_hint.size = Vector2(220, 24)
	stock_hint.add_theme_font_override("font", font_sm)
	stock_hint.add_theme_font_size_override("font_size", 13)
	stock_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	add_child(stock_hint)

	# Compute panel layout
	const PANEL_GAP := 12
	const TOTAL_W := 1240
	_panel_w = int((TOTAL_W - ((_player_count - 1) * PANEL_GAP)) / float(_player_count))
	var start_x := 20
	for i in _player_count:
		_panel_xs.append(start_x + i * (_panel_w + PANEL_GAP))

	for i in _player_count:
		_build_panel(i)

	# Instructions
	var instr := Label.new()
	instr.text = "Move: WASD / Arrow Keys    Confirm: Space / [/]    Toggle CPU (P2): Tab"
	instr.position = Vector2(0, 693)
	instr.size = Vector2(1280, 24)
	instr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instr.add_theme_font_override("font", font_sm)
	instr.add_theme_font_size_override("font_size", 13)
	instr.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	add_child(instr)

func _build_panel(pid_idx: int) -> void:
	var panel_x := _panel_xs[pid_idx]
	var color: Color = PLAYER_COLORS[pid_idx]
	var font_big := load("res://assets/ui/fonts/alagard.ttf") as FontFile
	var font_sm  := load("res://assets/ui/fonts/Planes_ValMore.ttf") as FontFile

	var panel_bg := ColorRect.new()
	panel_bg.color = Color(0.08, 0.06, 0.15, 0.8)
	panel_bg.position = Vector2(panel_x, 120)
	panel_bg.size = Vector2(_panel_w, 570)
	add_child(panel_bg)

	var header := Label.new()
	header.text = "PLAYER %d" % (pid_idx + 1)
	header.position = Vector2(panel_x, 124)
	header.size = Vector2(_panel_w, 30)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_override("font", font_big)
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", color)
	add_child(header)
	_status_lbls[pid_idx] = header

	# Grid (3×3), centered in panel
	var grid_offset_x := int((_panel_w - 3 * CELL_SIZE) / float(2))
	var grid_x := panel_x + grid_offset_x

	var cursor := ColorRect.new()
	cursor.size = Vector2(CELL_SIZE, CELL_SIZE)
	cursor.color = color * Color(1, 1, 1, 0.35)
	cursor.z_index = 1
	add_child(cursor)
	_cursor_rects[pid_idx] = cursor

	for row in 3:
		for col in 3:
			var idx := row * 3 + col
			var cell_pos := Vector2(grid_x + col * CELL_SIZE, GRID_TOP_Y + row * CELL_SIZE)
			var cell_bg := ColorRect.new()
			cell_bg.color = Color(0.15, 0.12, 0.22, 1)
			cell_bg.position = cell_pos
			cell_bg.size = Vector2(CELL_SIZE, CELL_SIZE)
			cell_bg.z_index = 0
			add_child(cell_bg)
			var tex := load(CHARACTERS[idx]["idle"]) as Texture2D
			var portrait := Sprite2D.new()
			portrait.texture = tex
			portrait.hframes = int(tex.get_width() / float(128))
			portrait.frame = 0
			portrait.position = cell_pos + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
			portrait.scale = Vector2(PORTRAIT_PX / 128.0, PORTRAIT_PX / 128.0)
			portrait.z_index = 2
			add_child(portrait)

	var name_lbl := Label.new()
	name_lbl.position = Vector2(panel_x, GRID_TOP_Y + 3 * CELL_SIZE + 6)
	name_lbl.size = Vector2(_panel_w, 28)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", font_big)
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(name_lbl)
	_name_lbls[pid_idx] = name_lbl

	var lock_lbl := Label.new()
	lock_lbl.position = Vector2(panel_x, GRID_TOP_Y + 3 * CELL_SIZE + 38)
	lock_lbl.size = Vector2(_panel_w, 26)
	lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_lbl.add_theme_font_override("font", font_sm)
	lock_lbl.add_theme_font_size_override("font_size", 14)
	lock_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	lock_lbl.text = "Press Space to confirm" if pid_idx == 0 else "Press [/] to confirm"
	add_child(lock_lbl)
	_lock_lbls[pid_idx] = lock_lbl

	# Preview sprite
	var first_tex := load(CHARACTERS[0]["idle"]) as Texture2D
	var preview := Sprite2D.new()
	preview.texture = first_tex
	preview.hframes = int(first_tex.get_width() / float(128))
	preview.frame = 0
	preview.position = Vector2(panel_x + int(_panel_w / float(2)), 610)
	preview.scale = Vector2(1.4, 1.4)
	preview.z_index = 3
	add_child(preview)
	_previews[pid_idx] = preview
	_preview_hframes[pid_idx] = preview.hframes

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_on_back_pressed()
		return

	# P1 stock selector (only when P1 not locked)
	if not _locked[0]:
		if Input.is_action_just_pressed("p1_left"):
			_change_stocks(-1)
		elif Input.is_action_just_pressed("p1_right"):
			_change_stocks(1)

	# P2 CPU toggle (Tab)
	if _player_count >= 2:
		if not _locked[1]:
			if Input.is_action_just_pressed("ui_focus_next"):
				_toggle_cpu(1)
		elif _is_cpu[1]:
			if Input.is_action_just_pressed("ui_focus_next"):
				_toggle_cpu(1)

	# Per-player cursor/confirm input
	for i in _player_count:
		if _is_cpu[i]:
			continue
		if _locked[i]:
			continue
		var pfx := "p%d_" % (i + 1)
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
				_previews[i].frame = _anim_frames[i]

func _change_stocks(delta: int) -> void:
	_stock_count = clampi(_stock_count + delta, 1, 3)
	GameManager.stock_count = _stock_count
	_stock_lbl.text = str(_stock_count)
	AudioManager.play_sfx("select")

func _toggle_cpu(pid_idx: int) -> void:
	_is_cpu[pid_idx] = not _is_cpu[pid_idx]
	GameManager.player_is_cpu[pid_idx] = _is_cpu[pid_idx]
	if _is_cpu[pid_idx]:
		var random_idx := randi() % CHARACTERS.size()
		GameManager.player_characters[pid_idx] = CHARACTERS[random_idx]["key"]
		_status_lbls[pid_idx].text = "CPU"
		_lock_lbls[pid_idx].text = "Random character selected"
		_lock_lbls[pid_idx].add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		var tex := load(CHARACTERS[random_idx]["idle"]) as Texture2D
		_previews[pid_idx].texture = tex
		_previews[pid_idx].hframes = int(tex.get_width() / float(128))
		_previews[pid_idx].frame = 0
		_preview_hframes[pid_idx] = _previews[pid_idx].hframes
		AudioManager.play_sfx("confirm_1")
		_locked[pid_idx] = true
		_check_all_locked()
	else:
		GameManager.player_characters[pid_idx] = ""
		GameManager.player_is_cpu[pid_idx] = false
		_status_lbls[pid_idx].text = "PLAYER %d" % (pid_idx + 1)
		_lock_lbls[pid_idx].text = "Press [/] to confirm"
		_lock_lbls[pid_idx].add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		_locked[pid_idx] = false
		AudioManager.play_sfx("back_1")

func _move_cursor(pid_idx: int, delta: Vector2i) -> void:
	_cursors[pid_idx] = Vector2i(
		(_cursors[pid_idx].x + delta.x + 3) % 3,
		(_cursors[pid_idx].y + delta.y + 3) % 3
	)
	_update_cursor(pid_idx)
	AudioManager.play_sfx("select")

func _update_cursor(pid_idx: int) -> void:
	var cur := _cursors[pid_idx]
	var grid_offset_x := int((_panel_w - 3 * CELL_SIZE) / float(2))
	var grid_x := _panel_xs[pid_idx] + grid_offset_x
	_cursor_rects[pid_idx].position = Vector2(
		grid_x + cur.x * CELL_SIZE, GRID_TOP_Y + cur.y * CELL_SIZE)
	var idx := cur.y * 3 + cur.x
	_name_lbls[pid_idx].text = CHARACTERS[idx]["name"]
	var tex := load(CHARACTERS[idx]["idle"]) as Texture2D
	var hf := int(tex.get_width() / float(128))
	_previews[pid_idx].texture = tex
	_previews[pid_idx].hframes = hf
	_previews[pid_idx].frame = 0
	_preview_hframes[pid_idx] = hf
	_anim_frames[pid_idx] = 0

func _lock_player(pid_idx: int) -> void:
	var idx := _cursors[pid_idx].y * 3 + _cursors[pid_idx].x
	GameManager.player_characters[pid_idx] = CHARACTERS[idx]["key"]
	_locked[pid_idx] = true
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
