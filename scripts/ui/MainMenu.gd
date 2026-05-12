# MainMenu.gd — Phase 10: wired scene flow
extends Node2D

const FRAME_COUNT  := 36
const FRAME_MS     := 130.0          # ms per GIF frame
const FRAME_DIR    := "res://assets/ui/homescreen/"

var _cursor: int = 0
var _buttons: Array = []

func _ready() -> void:
	_load_homescreen_anim()
	_apply_title_font()
	$StartButton.pressed.connect(_on_start_pressed)
	$OptionsButton.pressed.connect(_on_options_pressed)
	$CreditsButton.pressed.connect(_on_credits_pressed)
	$QuitButton.pressed.connect(_on_quit_pressed)
	_buttons = [$StartButton, $OptionsButton, $CreditsButton, $QuitButton]
	_update_highlight()
	AudioManager.play_music("res://new asets/Homescreen.ogg")
	print("[MainMenu] Ready")

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("p1_up") or Input.is_action_just_pressed("p2_up"):
		_cursor = (_cursor - 1 + _buttons.size()) % _buttons.size()
		_update_highlight()
	elif Input.is_action_just_pressed("p1_down") or Input.is_action_just_pressed("p2_down"):
		_cursor = (_cursor + 1) % _buttons.size()
		_update_highlight()
	elif Input.is_action_just_pressed("p1_jump") or Input.is_action_just_pressed("p2_jump") \
		or Input.is_action_just_pressed("p1_light_attack") or Input.is_action_just_pressed("p2_light_attack"):
		_buttons[_cursor].emit_signal("pressed")

func _update_highlight() -> void:
	for i in _buttons.size():
		var btn: Button = _buttons[i]
		if i == _cursor:
			btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.3))
		else:
			btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))

func _load_homescreen_anim() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 1000.0 / FRAME_MS)
	frames.set_animation_loop("idle", true)

	for i in FRAME_COUNT:
		var res_path := FRAME_DIR + "frame_%03d.png" % i
		var img := Image.new()
		img.load(ProjectSettings.globalize_path(res_path))
		frames.add_frame("idle", ImageTexture.create_from_image(img))

	var anim: AnimatedSprite2D = $HomescreenAnim
	anim.sprite_frames = frames
	anim.play("idle")

func _apply_title_font() -> void:
	var font := load("res://assets/ui/fonts/alagard.ttf") as FontFile
	if font == null:
		return
	var lbl: Label = $TitleLabel
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", 64)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

func _on_start_pressed() -> void:
	AudioManager.play_sfx("mainmenuselect")
	GameManager.go_to_character_select()

func _on_options_pressed() -> void:
	AudioManager.play_sfx("mainmenuselect")
	get_tree().change_scene_to_file("res://scenes/ui/OptionsMenu.tscn")

func _on_credits_pressed() -> void:
	AudioManager.play_sfx("mainmenuselect")
	get_tree().change_scene_to_file("res://scenes/ui/Credits.tscn")

func _on_quit_pressed() -> void:
	AudioManager.play_sfx("mainmenuselect")
	get_tree().quit()
