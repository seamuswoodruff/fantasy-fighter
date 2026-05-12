# WinScreen.gd — Phase 11
extends Node2D

const VICTORY_BG := {
	"knight":  "res://assets/ui/victory/knight_victory.png",
	"samurai": "res://assets/ui/victory/samurai_victory.png",
	"wizard":  "res://assets/ui/victory/wizard_victory.png",
	"ninja":   "res://assets/ui/victory/ninja_victory.png",
}

const CHAR_TYPE := {
	"knight_1": "knight", "knight_2": "knight", "knight_3": "knight",
	"samurai": "samurai", "samurai_commander": "samurai", "samurai_archer": "samurai",
	"fire_wizard": "wizard", "lightning_mage": "wizard", "wanderer_magician": "wizard",
	"kunoichi": "ninja", "ninja_monk": "ninja", "ninja_peasant": "ninja",
}

# Per-character Y adjustment from the base position Vector2(640, 310).
# Positive = move down, negative = move up.
const WINNER_OFFSETS := {
	"knight_1":          Vector2(50,  0),
	"knight_2":          Vector2(50,  0),
	"knight_3":          Vector2(50,  0),
	"samurai":           Vector2(40,  0),
	"samurai_commander": Vector2(0,   0),
	"samurai_archer":    Vector2(0,   0),
	"fire_wizard":       Vector2(20,  0),
	"lightning_mage":    Vector2(20,  0),
	"wanderer_magician": Vector2(20,  0),
	"kunoichi":          Vector2(0,   0),
	"ninja_monk":        Vector2(0,  25),
	"ninja_peasant":     Vector2(0,  20),
}

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
	"kunoichi":          "res://assets/characters/ninjas/kunoichi/sprites/Idle.png",
	"ninja_monk":        "res://assets/characters/ninjas/ninja_monk/sprites/Idle.png",
	"ninja_peasant":     "res://assets/characters/ninjas/ninja_peasant/sprites/Idle.png",
}

# Sequence of animations played after the first idle cycle before looping back to idle.
# Each entry is an Array of sprite sheet paths played in order.
const CHAR_VICTORY_SEQUENCES := {
	"knight_1":          ["res://assets/characters/warriors/knight_1/sprites/Attack 2.png",
	                      "res://assets/characters/warriors/knight_1/sprites/Attack 1.png"],
	"knight_2":          ["res://assets/characters/warriors/knight_2/sprites/Attack 2.png",
	                      "res://assets/characters/warriors/knight_2/sprites/Attack 1.png"],
	"knight_3":          ["res://assets/characters/warriors/knight_3/sprites/Attack 2.png",
	                      "res://assets/characters/warriors/knight_3/sprites/Attack 1.png"],
	"samurai":           ["res://assets/characters/samurai/samurai/sprites/Attack_1.png",
	                      "res://assets/characters/samurai/samurai/sprites/Attack_2.png"],
	"samurai_commander": ["res://assets/characters/samurai/samurai_commander/sprites/Attack_1.png",
	                      "res://assets/characters/samurai/samurai_commander/sprites/Attack_2.png"],
	"samurai_archer":    ["res://assets/characters/samurai/samurai_archer/sprites/Attack_1.png",
	                      "res://assets/characters/samurai/samurai_archer/sprites/Attack_2.png"],
	"fire_wizard":       ["res://assets/characters/wizards/fire_wizard/sprites/Flame_jet.png"],
	"lightning_mage":    ["res://assets/characters/wizards/lightning_mage/sprites/Attack_2.png",
	                      "res://assets/characters/wizards/lightning_mage/sprites/Attack_1.png"],
	"wanderer_magician": ["res://assets/characters/wizards/wanderer_magician/sprites/Attack_2.png",
	                      "res://assets/characters/wizards/wanderer_magician/sprites/Attack_1.png"],
	"kunoichi":          ["res://assets/characters/ninjas/kunoichi/sprites/light attack.png",
	                      "res://assets/characters/ninjas/kunoichi/sprites/heavy attack.png",
	                      "res://assets/characters/ninjas/kunoichi/sprites/Jump.png"],
	"ninja_monk":        ["res://assets/characters/ninjas/ninja_monk/sprites/light attack.png",
	                      "res://assets/characters/ninjas/ninja_monk/sprites/heavy attack.png"],
	"ninja_peasant":     [["res://assets/characters/ninjas/ninja_peasant/sprites/special 2.png", 20.0],
	                      ["res://assets/characters/ninjas/ninja_peasant/sprites/special 2.png", 20.0],
	                      ["res://assets/characters/ninjas/ninja_peasant/sprites/special 2.png", 20.0],
	                      ["res://assets/characters/ninjas/ninja_peasant/sprites/special 2.png", 20.0]],
}


const IDLE_FPS    := 8.0
const VICTORY_FPS := 12.0

enum VictoryState { IDLE_ONCE, VICTORY, IDLE_LOOP }

var _winner_sprite: AnimatedSprite2D = null
var _victory_state: VictoryState = VictoryState.IDLE_ONCE
var _victory_idx: int = 0
var _cursor: int = 0
var _btn_nodes: Array = []

func _ready() -> void:
	_build_ui()
	AudioManager.play_music("res://assets/music/PerituneMaterial_EpicBattle_loop.ogg")

func _build_ui() -> void:
	var winner: int      = GameManager.winner_id
	var char_key: String = GameManager.player_characters[clamp(winner - 1, 0, 3)]
	var win_color: Color = Color(0.72, 0.48, 0.88)

	# Background — character-type victory image, fallback to dark fill
	var char_type: String = CHAR_TYPE.get(char_key, "")
	var bg_path: String   = VICTORY_BG.get(char_type, "")
	if bg_path != "":
		var bg_tex := _load_tex_safe(bg_path)
		if bg_tex != null:
			var bg := Sprite2D.new()
			bg.texture  = bg_tex
			bg.position = Vector2(640.0, 360.0)
			var sx := 1280.0 / bg_tex.get_width()
			var sy := 720.0  / bg_tex.get_height()
			bg.scale    = Vector2(maxf(sx, sy), maxf(sx, sy))
			bg.z_index  = -1
			add_child(bg)
		else:
			_add_fallback_bg()
	else:
		_add_fallback_bg()

	var font_big := load("res://assets/ui/fonts/alagard.ttf") as FontFile

	# "PLAYER X WINS!"
	var win_lbl := Label.new()
	win_lbl.text = "%s WINS!" % GameManager.CHAR_DISPLAY_NAMES.get(char_key, char_key.replace("_", " ").to_upper())
	win_lbl.position = Vector2(0, 60)
	win_lbl.size = Vector2(1280, 130)
	win_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_lbl.add_theme_font_override("font", font_big)
	win_lbl.add_theme_font_size_override("font_size", 80)
	win_lbl.add_theme_color_override("font_color", win_color)
	win_lbl.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0))
	win_lbl.add_theme_constant_override("outline_size", 3)
	add_child(win_lbl)

	# Winner animated sprite: idle once → victory anim → idle loop
	if char_key != "" and CHAR_IDLE_PATHS.has(char_key):
		var idle_tex := _load_tex_safe(CHAR_IDLE_PATHS[char_key])
		if idle_tex:
			var sf := SpriteFrames.new()
			var fs: int = idle_tex.get_height()

			# "idle" animation — loop disabled initially (plays once)
			sf.add_animation("idle")
			sf.set_animation_speed("idle", IDLE_FPS)
			sf.set_animation_loop("idle", false)
			var idle_count := int(idle_tex.get_width() / float(fs))
			for i in idle_count:
				var at := AtlasTexture.new()
				at.atlas  = idle_tex
				at.region = Rect2(i * fs, 0, fs, fs)
				sf.add_frame("idle", at)

			# "victory_N" animations — one per entry in the sequence, all non-looping.
			# Each entry is either a String path or [path, fps].
			var vic_sequence: Array = CHAR_VICTORY_SEQUENCES.get(char_key, [])
			for seq_idx in vic_sequence.size():
				var entry = vic_sequence[seq_idx]
				var vic_path: String = entry[0] if entry is Array else entry
				var vic_fps: float   = entry[1]  if entry is Array else VICTORY_FPS
				var vic_tex := _load_tex_safe(vic_path)
				if vic_tex:
					var vfs: int = vic_tex.get_height()
					var anim_name := "victory_%d" % seq_idx
					sf.add_animation(anim_name)
					sf.set_animation_speed(anim_name, vic_fps)
					sf.set_animation_loop(anim_name, false)
					var vic_count := int(vic_tex.get_width() / float(vfs))
					for i in vic_count:
						var at := AtlasTexture.new()
						at.atlas  = vic_tex
						at.region = Rect2(i * vfs, 0, vfs, vfs)
						sf.add_frame(anim_name, at)

			_winner_sprite = AnimatedSprite2D.new()
			_winner_sprite.sprite_frames = sf
			var offset: Vector2 = WINNER_OFFSETS.get(char_key, Vector2.ZERO)
			_winner_sprite.position = Vector2(640, 310) + offset
			_winner_sprite.scale    = Vector2(1.8, 1.8)
			_winner_sprite.animation_finished.connect(_on_winner_anim_finished)
			add_child(_winner_sprite)
			_victory_state = VictoryState.IDLE_ONCE
			_victory_idx = 0
			_winner_sprite.play("idle")

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

	_btn_nodes = [rematch_btn, menu_btn]
	_update_win_highlight()


func _on_winner_anim_finished() -> void:
	if _winner_sprite == null:
		return
	match _victory_state:
		VictoryState.IDLE_ONCE:
			if _winner_sprite.sprite_frames.has_animation("victory_0"):
				_victory_state = VictoryState.VICTORY
				_victory_idx = 0
				_winner_sprite.play("victory_0")
			else:
				_victory_state = VictoryState.IDLE_LOOP
				_winner_sprite.sprite_frames.set_animation_loop("idle", true)
				_winner_sprite.play("idle")
		VictoryState.VICTORY:
			var next := "victory_%d" % (_victory_idx + 1)
			if _winner_sprite.sprite_frames.has_animation(next):
				_victory_idx += 1
				_winner_sprite.play(next)
			else:
				_victory_state = VictoryState.IDLE_LOOP
				_winner_sprite.sprite_frames.set_animation_loop("idle", true)
				_winner_sprite.play("idle")

func _update_win_highlight() -> void:
	for i in _btn_nodes.size():
		var btn := _btn_nodes[i] as Button
		if i == _cursor:
			btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		else:
			btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))

func _process(_delta: float) -> void:
	# Controller navigation
	if Input.is_action_just_pressed("p1_left") or Input.is_action_just_pressed("p2_left") \
		or Input.is_action_just_pressed("p1_up") or Input.is_action_just_pressed("p2_up"):
		_cursor = (_cursor - 1 + _btn_nodes.size()) % _btn_nodes.size()
		_update_win_highlight()
		AudioManager.play_sfx("click")
	elif Input.is_action_just_pressed("p1_right") or Input.is_action_just_pressed("p2_right") \
		or Input.is_action_just_pressed("p1_down") or Input.is_action_just_pressed("p2_down"):
		_cursor = (_cursor + 1) % _btn_nodes.size()
		_update_win_highlight()
		AudioManager.play_sfx("click")
	elif Input.is_action_just_pressed("p1_jump") or Input.is_action_just_pressed("p2_jump") \
		or Input.is_action_just_pressed("p1_light_attack") or Input.is_action_just_pressed("p2_light_attack"):
		(_btn_nodes[_cursor] as Button).emit_signal("pressed")

func _on_rematch() -> void:
	AudioManager.play_sfx("click")
	GameManager.go_to_battle()

func _on_menu() -> void:
	AudioManager.play_sfx("click")
	GameManager.p1_character = ""
	GameManager.p2_character = ""
	GameManager.selected_stage = ""
	GameManager.winner_id = 0
	GameManager.go_to_main_menu()

func _add_fallback_bg() -> void:
	var bg := ColorRect.new()
	bg.color    = Color(0.03, 0.02, 0.08, 1)
	bg.position = Vector2.ZERO
	bg.size     = Vector2(1280, 720)
	bg.z_index  = -1
	add_child(bg)

func _load_tex_safe(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		return load(res_path) as Texture2D
	var img := Image.new()
	var err := img.load(ProjectSettings.globalize_path(res_path))
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)
