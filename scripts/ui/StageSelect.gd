# StageSelect.gd — Phase 10
extends Node2D

const STAGES := [
	{ "key": "Windrise",     "name": "WINDRISE",      "bg": "res://assets/stages/windrise/background/windrise-background.png" },
	{ "key": "Ruins",        "name": "RUINS",         "bg": "res://assets/stages/ruins/background/ruins_background.png" },
	{ "key": "DesertTemple", "name": "DESERT TEMPLE", "bg": "res://assets/stages/desert_temple/background/desert_background.png" },
]

const CARD_W     := 330
const CARD_H     := 200
const CARD_GAP   := 35
const CARDS_TOP  := 200

var _selected: int = 0
var _highlight: ColorRect
var _card_rects: Array = []

func _ready() -> void:
	_build_ui()
	_update_selection()
	AudioManager.play_music("res://japanese music by hitslab.ogg")
	var names: Array = []
	for i in GameManager.active_player_count:
		names.append("P%d: %s" % [i + 1, GameManager.player_characters[i]])
	print("[StageSelect] %s" % "  |  ".join(names))

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.09, 1)
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.position = Vector2(30.0, 20.0)
	back_btn.size = Vector2(160.0, 44.0)
	var font_back := load("res://assets/ui/fonts/alagard.ttf") as FontFile
	if font_back:
		back_btn.add_theme_font_override("font", font_back)
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)

	var font_big := load("res://assets/ui/fonts/alagard.ttf") as FontFile
	var font_sm  := load("res://assets/ui/fonts/Planes_ValMore.ttf") as FontFile

	# Title
	var title := Label.new()
	title.text = "SELECT A STAGE"
	title.position = Vector2(0, 60)
	title.size = Vector2(1280, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font_big)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(title)

	# Characters chosen banner — supports 2–4 players
	var banner_parts: Array = []
	for i in GameManager.active_player_count:
		banner_parts.append(GameManager.player_characters[i].replace("_", " ").to_upper())
	var banner := Label.new()
	banner.text = "  vs  ".join(banner_parts)
	banner.position = Vector2(0, 150)
	banner.size = Vector2(1280, 36)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_override("font", font_sm)
	banner.add_theme_font_size_override("font_size", 18)
	banner.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	add_child(banner)

	# Total width of all cards + gaps
	var total_w := STAGES.size() * CARD_W + (STAGES.size() - 1) * CARD_GAP
	var start_x := int((1280 - total_w) / float(2))

	# Cursor highlight (behind cards)
	_highlight = ColorRect.new()
	_highlight.color = Color(1.0, 0.85, 0.3, 0.25)
	_highlight.size = Vector2(CARD_W + 12, CARD_H + 12)
	_highlight.z_index = 0
	add_child(_highlight)

	# Build stage cards
	for i in STAGES.size():
		var card_x := start_x + i * (CARD_W + CARD_GAP)
		var card_pos := Vector2(card_x, CARDS_TOP)
		_card_rects.append(card_pos)

		# Card background
		var card_bg := ColorRect.new()
		card_bg.position = card_pos
		card_bg.size = Vector2(CARD_W, CARD_H)
		card_bg.color = Color(0.1, 0.08, 0.18, 1)
		card_bg.z_index = 1
		add_child(card_bg)

		# Stage thumbnail (background image scaled to fit card)
		var tex := load(STAGES[i]["bg"]) as Texture2D
		if tex:
			var thumb := Sprite2D.new()
			thumb.texture = tex
			var sx := CARD_W / float(tex.get_width())
			var sy := CARD_H / float(tex.get_height())
			thumb.scale = Vector2(sx, sy)
			thumb.position = card_pos + Vector2(CARD_W / float(2), CARD_H / float(2))
			thumb.z_index = 2
			add_child(thumb)

		# Dark overlay so name is readable
		var overlay := ColorRect.new()
		overlay.position = card_pos + Vector2(0, CARD_H - 50)
		overlay.size = Vector2(CARD_W, 50)
		overlay.color = Color(0, 0, 0, 0.65)
		overlay.z_index = 3
		add_child(overlay)

		# Stage name label
		var name_lbl := Label.new()
		name_lbl.text = STAGES[i]["name"]
		name_lbl.position = card_pos + Vector2(0, CARD_H - 44)
		name_lbl.size = Vector2(CARD_W, 40)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_override("font", font_big)
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		name_lbl.z_index = 4
		add_child(name_lbl)

	# Instructions
	var instr := Label.new()
	instr.text = "Left / Right to browse    Space / [/] to confirm    (Player 1 chooses)"
	instr.position = Vector2(0, 693)
	instr.size = Vector2(1280, 24)
	instr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instr.add_theme_font_override("font", font_sm)
	instr.add_theme_font_size_override("font_size", 13)
	instr.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	add_child(instr)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_on_back_pressed()
		return

	if Input.is_action_just_pressed("p1_left"):
		_selected = max(0, _selected - 1)
		_update_selection()
		AudioManager.play_sfx("click")
	elif Input.is_action_just_pressed("p1_right"):
		_selected = min(STAGES.size() - 1, _selected + 1)
		_update_selection()
		AudioManager.play_sfx("click")
	elif Input.is_action_just_pressed("p1_jump") or Input.is_action_just_pressed("p1_light_attack"):
		_confirm()

func _update_selection() -> void:
	if _card_rects.is_empty():
		return
	var card_pos: Vector2 = _card_rects[_selected]
	_highlight.position = card_pos - Vector2(6, 6)

func _confirm() -> void:
	AudioManager.play_sfx("click")
	GameManager.selected_stage = STAGES[_selected]["key"]
	print("[StageSelect] Stage selected: %s" % GameManager.selected_stage)
	GameManager.go_to_battle()

func _on_back_pressed() -> void:
	AudioManager.play_sfx("click")
	GameManager.go_to_character_select()
