# OptionsMenu.gd — Phase 11 polish
extends Node2D

const BUS_MUSIC    := "Music"
const BUS_SFX      := "SFX"
const BUS_AMBIENCE := "Ambience"

var _back_btn: Button = null
var _sliders: Array = []

func _ready() -> void:
	_build_ui()
	AudioManager.play_music("res://new asets/Homescreen.ogg")
	print("[OptionsMenu] Ready")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()

func _build_ui() -> void:
	var font_big := load("res://assets/ui/fonts/alagard.ttf") as FontFile
	var font_sm  := load("res://assets/ui/fonts/Planes_ValMore.ttf") as FontFile

	# ── Animated background (GIF sprite sheet, 16 frames 770×370) ────────────
	const FRAME_W := 770
	const FRAME_H := 370
	const FRAME_COUNT := 16
	var bg_tex := load("res://assets/ui/backgrounds/optionsscreen_sheet.png") as Texture2D
	var sf := SpriteFrames.new()
	sf.add_animation("bg")
	sf.set_animation_loop("bg", true)
	sf.set_animation_speed("bg", 10.0)
	for i in FRAME_COUNT:
		var atlas := AtlasTexture.new()
		atlas.atlas = bg_tex
		atlas.region = Rect2(i * FRAME_W, 0, FRAME_W, FRAME_H)
		sf.add_frame("bg", atlas)
	var bg_anim := AnimatedSprite2D.new()
	bg_anim.sprite_frames = sf
	bg_anim.animation = "bg"
	bg_anim.play("bg")
	var bg_scale := maxf(1280.0 / FRAME_W, 720.0 / FRAME_H)
	bg_anim.scale = Vector2(bg_scale, bg_scale)
	bg_anim.position = Vector2(640.0, 360.0)
	bg_anim.z_index = -1
	add_child(bg_anim)

	# Semi-transparent dark overlay so UI remains readable
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(1280.0, 720.0)
	add_child(overlay)

	# ── Centred panel ─────────────────────────────────────────────────────────
	var panel := ColorRect.new()
	panel.color = Color(0.12, 0.09, 0.20, 0.15)
	panel.position = Vector2(240.0, 60.0)
	panel.size = Vector2(800.0, 600.0)
	add_child(panel)

	# Panel border
	var border := ColorRect.new()
	border.color = Color(0.55, 0.40, 0.85, 0.75)
	border.position = panel.position - Vector2(2.0, 2.0)
	border.size = panel.size + Vector2(4.0, 4.0)
	border.z_index = -1
	add_child(border)

	# ── Title ─────────────────────────────────────────────────────────────────
	var title := _make_label("OPTIONS", font_big, 52, Color(1.0, 0.85, 0.3))
	title.position = Vector2(240.0, 75.0)
	title.size = Vector2(800.0, 70.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	# ── Volume sliders ────────────────────────────────────────────────────────
	var slider_y: float = 190.0
	var sliders := [
		[BUS_MUSIC,    "MUSIC"],
		[BUS_SFX,      "SFX"],
		[BUS_AMBIENCE, "AMBIENCE"],
	]
	for entry in sliders:
		var bus_name: String = entry[0]
		var label_text: String = entry[1]
		slider_y = _add_slider_row(slider_y, bus_name, label_text, font_big, font_sm)
		slider_y += 20.0

	# ── Divider ───────────────────────────────────────────────────────────────
	var divider := ColorRect.new()
	divider.color = Color(0.55, 0.40, 0.85, 0.5)
	divider.position = Vector2(270.0, slider_y)
	divider.size = Vector2(740.0, 2.0)
	add_child(divider)
	slider_y += 20.0

	# ── Controls table ────────────────────────────────────────────────────────
	var map_title := _make_label("CONTROLS", font_big, 28, Color(1.0, 0.85, 0.3))
	map_title.position = Vector2(240.0, slider_y)
	map_title.size = Vector2(800.0, 40.0)
	map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(map_title)
	slider_y += 48.0

	# 4 equal columns across the 800px panel (x 240–1040), 10px left pad
	var col_x   := [290.0, 480.0, 670.0, 860.0]
	var col_w   := [185.0, 185.0, 185.0, 210.0]
	var row_h   := 28.0
	# Single punctuation chars that need bigger rendering to stay legible
	var punct   := ["/", ".", ",", "'", ";"]

	# [move, player 1, player 2, controller]
	var table: Array = [
		["Moves",        "Player 1",      "Player 2",   "Controller"],
		["Run",          "W / A / S / D", "Arrow Keys", "Left Stick / DPad"],
		["Jump",         "Space",         "/",          "A / Cross"],
		["Light Attack", "Z",             ".",          "Right Stick Left"],
		["Heavy Attack", "X",             ",",          "Right Stick Right"],
		["Special",      "C",             "'",          "Right Stick Up"],
		["Special Two",  "V",             ";",          "Right Stick Down"],
	]

	for row_idx in table.size():
		var cells: Array = table[row_idx]
		var is_header: bool = row_idx == 0
		for col_idx in 4:
			var txt: String = cells[col_idx]
			var is_punct: bool = txt in punct
			var fnt: FontFile  = font_big if is_header else font_sm
			var fsz: int       = 18 if is_header else (20 if is_punct else 14)
			var col: Color     = Color(1.0, 0.85, 0.3) if is_header else Color(0.9, 0.9, 1.0)
			var cell := _make_label(txt, fnt, fsz, col)
			cell.position = Vector2(col_x[col_idx], slider_y)
			cell.size     = Vector2(col_w[col_idx], row_h)
			add_child(cell)
		slider_y += row_h

	# ── Back button (top-left, matching CharacterSelect / StageSelect) ────────
	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.position = Vector2(30.0, 20.0)
	back_btn.size = Vector2(160.0, 44.0)
	_style_button(back_btn, font_big, 22)
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)
	_back_btn = back_btn

	# ── Wire focus chain for controller navigation ────────────────────────────
	# Order: Back → Music → SFX → Ambience → (wraps to Back)
	await get_tree().process_frame
	var focusables: Array = [_back_btn] + _sliders
	var n := focusables.size()
	for i in n:
		var cur: Control = focusables[i]
		var prv: Control = focusables[(i - 1 + n) % n]
		var nxt: Control = focusables[(i + 1) % n]
		cur.focus_neighbor_top    = cur.get_path_to(prv)
		cur.focus_neighbor_bottom = cur.get_path_to(nxt)
	_back_btn.grab_focus()

# ── Helpers ───────────────────────────────────────────────────────────────────

func _add_slider_row(y: float, bus_name: String, label_text: String,
		font_big: FontFile, font_sm: FontFile) -> float:
	# Row label
	var lbl := _make_label(label_text, font_big, 28, Color(0.9, 0.9, 1.0))
	lbl.position = Vector2(270.0, y)
	lbl.size = Vector2(200.0, 40.0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(lbl)

	# Current dB → 0-100 value
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	var current_db: float = AudioServer.get_bus_volume_db(bus_idx) if bus_idx >= 0 else 0.0
	var initial_val: float = clampf(_db_to_pct(current_db), 0.0, 100.0)

	# Percentage label (updated on slide)
	var pct_lbl := _make_label("%d%%" % int(initial_val), font_sm, 18, Color(0.75, 0.75, 0.9))
	pct_lbl.position = Vector2(940.0, y)
	pct_lbl.size = Vector2(80.0, 40.0)
	pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(pct_lbl)

	# Slider
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = initial_val
	slider.position = Vector2(480.0, y + 6.0)
	slider.size = Vector2(450.0, 28.0)
	slider.value_changed.connect(func(val: float) -> void:
		AudioManager.set_volume(bus_name, _pct_to_db(val))
		pct_lbl.text = "%d%%" % int(val)
	)
	add_child(slider)
	_sliders.append(slider)
	return y + 50.0

func _db_to_pct(db: float) -> float:
	# -40 dB → 0%, 0 dB → 100%
	return clampf((db + 40.0) / 40.0 * 100.0, 0.0, 100.0)

func _pct_to_db(pct: float) -> float:
	# 0% → -40 dB, 100% → 0 dB
	return lerp(-40.0, 0.0, pct / 100.0)

func _make_label(text_str: String, font: FontFile, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text_str
	if font:
		lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _style_button(btn: Button, font: FontFile, size: int) -> void:
	if font:
		btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", size)

func _on_back_pressed() -> void:
	AudioManager.play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
