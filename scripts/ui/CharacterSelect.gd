# CharacterSelect.gd — Phase 10
extends Node2D

const CHARACTERS := [
	{ "key": "knight_1",          "name": "KNIGHT I",       "idle": "res://assets/characters/warriors/knight_1/sprites/Idle.png" },
	{ "key": "knight_2",          "name": "KNIGHT II",      "idle": "res://assets/characters/warriors/knight_2/sprites/Idle.png" },
	{ "key": "knight_3",          "name": "KNIGHT III",     "idle": "res://assets/characters/warriors/knight_3/sprites/Idle.png" },
	{ "key": "samurai",           "name": "SAMURAI",        "idle": "res://assets/characters/samurai/samurai/sprites/Idle.png" },
	{ "key": "samurai_commander", "name": "COMMANDER",      "idle": "res://assets/characters/samurai/samurai_commander/sprites/Idle.png" },
	{ "key": "samurai_archer",    "name": "ARCHER",         "idle": "res://assets/characters/samurai/samurai_archer/sprites/Idle.png" },
	{ "key": "fire_wizard",       "name": "FIRE WIZARD",    "idle": "res://assets/characters/wizards/fire_wizard/sprites/Idle.png" },
	{ "key": "lightning_mage",    "name": "LT. MAGE",       "idle": "res://assets/characters/wizards/lightning_mage/sprites/Idle.png" },
	{ "key": "wanderer_magician", "name": "WANDERER",       "idle": "res://assets/characters/wizards/wanderer_magician/sprites/Idle.png" },
]

const CELL_SIZE   := 80
const PORTRAIT_PX := 72   # drawn size of the 128px source sprite
const GRID_TOP_Y  := 120
const P1_PANEL_X  := 40
const P2_PANEL_X  := 680
const PANEL_W     := 560  # each panel is 560px wide
const IDLE_FPS    := 8.0

# cursor position is (col, row) in the 3×3 grid
var _p1_cursor := Vector2i(0, 0)
var _p2_cursor := Vector2i(2, 0)
var _p1_locked := false
var _p2_locked := false

var _p1_cursor_rect: ColorRect
var _p2_cursor_rect: ColorRect
var _p1_name_lbl: Label
var _p2_name_lbl: Label
var _p1_lock_lbl: Label
var _p2_lock_lbl: Label
var _p1_preview: Sprite2D
var _p2_preview: Sprite2D
var _p1_preview_hframes: int = 1
var _p2_preview_hframes: int = 1
var _p1_anim_timer: float = 0.0
var _p2_anim_timer: float = 0.0
var _p1_anim_frame: int = 0
var _p2_anim_frame: int = 0

func _ready() -> void:
	_build_ui()
	_update_cursor(1)
	_update_cursor(2)
	AudioManager.play_sfx("menu_open_1")

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.10, 1)
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Center divider
	var div := ColorRect.new()
	div.color = Color(0.3, 0.3, 0.5, 0.6)
	div.position = Vector2(639, 0)
	div.size = Vector2(2, 720)
	add_child(div)

	var font_big := load("res://assets/ui/fonts/alagard.ttf") as FontFile

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

	_build_panel(1, P1_PANEL_X, Color(0.4, 0.7, 1.0))
	_build_panel(2, P2_PANEL_X, Color(1.0, 0.5, 0.5))

	# Bottom instructions
	var font_sm := load("res://assets/ui/fonts/Planes_ValMore.ttf") as FontFile
	var instr := Label.new()
	instr.text = "Move: WASD / Arrow Keys    Confirm: Space / [/]    Controller: D-Pad + A"
	instr.position = Vector2(0, 693)
	instr.size = Vector2(1280, 24)
	instr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instr.add_theme_font_override("font", font_sm)
	instr.add_theme_font_size_override("font_size", 13)
	instr.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	add_child(instr)

func _build_panel(pid: int, panel_x: int, header_color: Color) -> void:
	var font_big := load("res://assets/ui/fonts/alagard.ttf") as FontFile
	var font_sm  := load("res://assets/ui/fonts/Planes_ValMore.ttf") as FontFile

	# Panel background
	var panel_bg := ColorRect.new()
	panel_bg.color = Color(0.08, 0.06, 0.15, 0.8)
	panel_bg.position = Vector2(panel_x, 88)
	panel_bg.size = Vector2(PANEL_W, 600)
	add_child(panel_bg)

	# Player header
	var header := Label.new()
	header.text = "PLAYER %d" % pid
	header.position = Vector2(panel_x, 92)
	header.size = Vector2(PANEL_W, 32)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_override("font", font_big)
	header.add_theme_font_size_override("font_size", 26)
	header.add_theme_color_override("font_color", header_color)
	add_child(header)

	# Grid is 3 columns × CELL_SIZE = 240px wide; center inside PANEL_W
	var grid_offset_x := int((PANEL_W - 3 * CELL_SIZE) / float(2))
	var grid_x := panel_x + grid_offset_x

	# Cursor highlight rect (rendered over cell backgrounds, behind portraits)
	var cursor := ColorRect.new()
	cursor.size = Vector2(CELL_SIZE, CELL_SIZE)
	cursor.color = header_color * Color(1, 1, 1, 0.35)
	cursor.z_index = 1
	add_child(cursor)
	if pid == 1:
		_p1_cursor_rect = cursor
	else:
		_p2_cursor_rect = cursor

	# 3×3 portrait grid
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

	# Character name label
	var name_lbl := Label.new()
	name_lbl.position = Vector2(panel_x, GRID_TOP_Y + 3 * CELL_SIZE + 6)
	name_lbl.size = Vector2(PANEL_W, 34)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", font_big)
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(name_lbl)
	if pid == 1:
		_p1_name_lbl = name_lbl
	else:
		_p2_name_lbl = name_lbl

	# Lock / ready label
	var lock_lbl := Label.new()
	lock_lbl.position = Vector2(panel_x, GRID_TOP_Y + 3 * CELL_SIZE + 44)
	lock_lbl.size = Vector2(PANEL_W, 30)
	lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_lbl.add_theme_font_override("font", font_sm)
	lock_lbl.add_theme_font_size_override("font_size", 16)
	lock_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	lock_lbl.text = "Press SPACE / [/] to confirm"
	add_child(lock_lbl)
	if pid == 1:
		_p1_lock_lbl = lock_lbl
	else:
		_p2_lock_lbl = lock_lbl

	# Preview sprite (idle animation, larger)
	var first_tex := load(CHARACTERS[0]["idle"]) as Texture2D
	var preview := Sprite2D.new()
	preview.texture = first_tex
	preview.hframes = int(first_tex.get_width() / float(128))
	preview.frame = 0
	preview.position = Vector2(panel_x + int(PANEL_W / float(2)), 575)
	preview.scale = Vector2(1.6, 1.6)
	preview.z_index = 3
	add_child(preview)
	if pid == 1:
		_p1_preview = preview
		_p1_preview_hframes = preview.hframes
	else:
		_p2_preview = preview
		_p2_preview_hframes = preview.hframes

func _process(delta: float) -> void:
	if not _p1_locked:
		if Input.is_action_just_pressed("p1_left"):
			_move_cursor(1, Vector2i(-1, 0))
		elif Input.is_action_just_pressed("p1_right"):
			_move_cursor(1, Vector2i(1, 0))
		elif Input.is_action_just_pressed("p1_up"):
			_move_cursor(1, Vector2i(0, -1))
		elif Input.is_action_just_pressed("p1_down"):
			_move_cursor(1, Vector2i(0, 1))
		elif Input.is_action_just_pressed("p1_jump") or Input.is_action_just_pressed("p1_light_attack"):
			_lock_player(1)

	if not _p2_locked:
		if Input.is_action_just_pressed("p2_left"):
			_move_cursor(2, Vector2i(-1, 0))
		elif Input.is_action_just_pressed("p2_right"):
			_move_cursor(2, Vector2i(1, 0))
		elif Input.is_action_just_pressed("p2_up"):
			_move_cursor(2, Vector2i(0, -1))
		elif Input.is_action_just_pressed("p2_down"):
			_move_cursor(2, Vector2i(0, 1))
		elif Input.is_action_just_pressed("p2_jump") or Input.is_action_just_pressed("p2_light_attack"):
			_lock_player(2)

	# Animate previews independently
	_p1_anim_timer += delta
	if _p1_anim_timer >= 1.0 / IDLE_FPS:
		_p1_anim_timer = 0.0
		_p1_anim_frame = (_p1_anim_frame + 1) % _p1_preview_hframes
		_p1_preview.frame = _p1_anim_frame

	_p2_anim_timer += delta
	if _p2_anim_timer >= 1.0 / IDLE_FPS:
		_p2_anim_timer = 0.0
		_p2_anim_frame = (_p2_anim_frame + 1) % _p2_preview_hframes
		_p2_preview.frame = _p2_anim_frame

func _move_cursor(pid: int, delta: Vector2i) -> void:
	if pid == 1:
		_p1_cursor = Vector2i(
			(_p1_cursor.x + delta.x + 3) % 3,
			(_p1_cursor.y + delta.y + 3) % 3
		)
	else:
		_p2_cursor = Vector2i(
			(_p2_cursor.x + delta.x + 3) % 3,
			(_p2_cursor.y + delta.y + 3) % 3
		)
	_update_cursor(pid)
	AudioManager.play_sfx("select")

func _update_cursor(pid: int) -> void:
	var cur: Vector2i = _p1_cursor if pid == 1 else _p2_cursor
	var panel_x := P1_PANEL_X if pid == 1 else P2_PANEL_X
	var grid_offset_x := int((PANEL_W - 3 * CELL_SIZE) / float(2))
	var grid_x := panel_x + grid_offset_x
	var rect := _p1_cursor_rect if pid == 1 else _p2_cursor_rect
	rect.position = Vector2(grid_x + cur.x * CELL_SIZE, GRID_TOP_Y + cur.y * CELL_SIZE)

	var idx := cur.y * 3 + cur.x
	var char_data: Dictionary = CHARACTERS[idx]

	var name_lbl := _p1_name_lbl if pid == 1 else _p2_name_lbl
	if name_lbl != null:
		name_lbl.text = char_data["name"]

	# Update preview texture
	var tex := load(char_data["idle"]) as Texture2D
	var hf := int(tex.get_width() / float(128))
	if pid == 1:
		_p1_preview.texture = tex
		_p1_preview.hframes = hf
		_p1_preview.frame = 0
		_p1_preview_hframes = hf
		_p1_anim_frame = 0
	else:
		_p2_preview.texture = tex
		_p2_preview.hframes = hf
		_p2_preview.frame = 0
		_p2_preview_hframes = hf
		_p2_anim_frame = 0

func _lock_player(pid: int) -> void:
	var idx := (_p1_cursor.y * 3 + _p1_cursor.x) if pid == 1 else (_p2_cursor.y * 3 + _p2_cursor.x)
	var char_key: String = CHARACTERS[idx]["key"]

	if pid == 1:
		_p1_locked = true
		GameManager.p1_character = char_key
		_p1_lock_lbl.text = "READY!"
		_p1_lock_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	else:
		_p2_locked = true
		GameManager.p2_character = char_key
		_p2_lock_lbl.text = "READY!"
		_p2_lock_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))

	AudioManager.play_sfx("confirm_1")
	print("[CharacterSelect] P%d locked: %s" % [pid, char_key])

	if _p1_locked and _p2_locked:
		await get_tree().create_timer(0.5).timeout
		GameManager.go_to_stage_select()
