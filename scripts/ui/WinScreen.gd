# WinScreen.gd — Phase 10
extends Node2D

const CHAR_IDLE_PATHS := {
	"knight_1":          "res://assets/characters/warriors/knight_1/sprites/Idle.png",
	"knight_2":          "res://assets/characters/warriors/knight_2/sprites/Idle.png",
	"knight_3":          "res://assets/characters/warriors/knight_3/sprites/Idle.png",
	"samurai":           "res://assets/characters/samurai/samurai/sprites/Idle.png",
	"samurai_commander": "res://assets/characters/samurai/samurai_commander/sprites/Idle.png",
	"samurai_archer":    "res://assets/characters/samurai/samurai_archer/sprites/Idle.png",
	"fire_wizard":       "res://assets/characters/wizards/fire_wizard/sprites/Idle.png",
	"lightning_mage":    "res://assets/characters/wizards/lightning_mage/sprites/Idle.png",
	"wanderer_magician": "res://assets/characters/wizards/wanderer_magician/sprites/Idle.png",
}

const IDLE_FPS := 8.0

var _winner_sprite: Sprite2D = null
var _anim_hframes: int = 1
var _anim_timer: float = 0.0
var _anim_frame: int = 0

func _ready() -> void:
	_build_ui()
	AudioManager.play_sfx("confirm_2")
	AudioManager.play_music("res://assets/music/PerituneMaterial_EpicBattle_loop.ogg")

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.08, 1)
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var winner: int = GameManager.winner_id
	var char_key: String = GameManager.player_characters[clamp(winner - 1, 0, 3)]
	var win_color: Color = Color(0.4, 0.7, 1.0) if winner == 1 else Color(1.0, 0.45, 0.45)

	var font_big := load("res://assets/ui/fonts/alagard.ttf") as FontFile
	var font_sm  := load("res://assets/ui/fonts/Planes_ValMore.ttf") as FontFile

	# "PLAYER X WINS!"
	var win_lbl := Label.new()
	win_lbl.text = "PLAYER %d WINS!" % winner
	win_lbl.position = Vector2(0, 60)
	win_lbl.size = Vector2(1280, 130)
	win_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_lbl.add_theme_font_override("font", font_big)
	win_lbl.add_theme_font_size_override("font_size", 80)
	win_lbl.add_theme_color_override("font_color", win_color)
	add_child(win_lbl)

	# Character name subtitle
	if char_key != "":
		var char_lbl := Label.new()
		char_lbl.text = char_key.replace("_", " ").to_upper()
		char_lbl.position = Vector2(0, 185)
		char_lbl.size = Vector2(1280, 40)
		char_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		char_lbl.add_theme_font_override("font", font_sm)
		char_lbl.add_theme_font_size_override("font_size", 22)
		char_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		add_child(char_lbl)

	# Winner idle animation
	if char_key != "" and CHAR_IDLE_PATHS.has(char_key):
		var tex := load(CHAR_IDLE_PATHS[char_key]) as Texture2D
		if tex:
			_winner_sprite = Sprite2D.new()
			_winner_sprite.texture = tex
			_winner_sprite.hframes = int(tex.get_width() / float(128))
			_winner_sprite.frame = 0
			_winner_sprite.position = Vector2(640, 390)
			_winner_sprite.scale = Vector2(3.0, 3.0)
			_anim_hframes = _winner_sprite.hframes
			add_child(_winner_sprite)

	# REMATCH button
	var rematch_btn := Button.new()
	rematch_btn.text = "REMATCH"
	rematch_btn.position = Vector2(400, 590)
	rematch_btn.size = Vector2(200, 52)
	rematch_btn.pressed.connect(_on_rematch)
	add_child(rematch_btn)

	# MAIN MENU button
	var menu_btn := Button.new()
	menu_btn.text = "MAIN MENU"
	menu_btn.position = Vector2(680, 590)
	menu_btn.size = Vector2(200, 52)
	menu_btn.pressed.connect(_on_menu)
	add_child(menu_btn)

	# Stage label
	var stage_lbl := Label.new()
	stage_lbl.text = "Stage: %s" % GameManager.selected_stage
	stage_lbl.position = Vector2(0, 660)
	stage_lbl.size = Vector2(1280, 24)
	stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_lbl.add_theme_font_override("font", font_sm)
	stage_lbl.add_theme_font_size_override("font_size", 14)
	stage_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	add_child(stage_lbl)

func _process(delta: float) -> void:
	if _winner_sprite == null:
		return
	_anim_timer += delta
	if _anim_timer >= 1.0 / IDLE_FPS:
		_anim_timer = 0.0
		_anim_frame = (_anim_frame + 1) % _anim_hframes
		_winner_sprite.frame = _anim_frame

func _on_rematch() -> void:
	AudioManager.play_sfx("confirm_1")
	# characters and stage are still set in GameManager — go straight to battle
	GameManager.go_to_battle()

func _on_menu() -> void:
	AudioManager.play_sfx("back_1")
	GameManager.p1_character = ""
	GameManager.p2_character = ""
	GameManager.selected_stage = ""
	GameManager.winner_id = 0
	GameManager.go_to_main_menu()
