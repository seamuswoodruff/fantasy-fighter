# MainMenu.gd — Phase 10: wired scene flow
extends Node2D

func _ready() -> void:
	_apply_title_font()
	$StartButton.pressed.connect(_on_start_pressed)
	$QuitButton.pressed.connect(_on_quit_pressed)
	AudioManager.play_sfx("menu_open_1")
	print("[MainMenu] Ready")

func _apply_title_font() -> void:
	var font := load("res://assets/ui/fonts/alagard.ttf") as FontFile
	if font == null:
		return
	var lbl: Label = $TitleLabel
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", 64)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

func _on_start_pressed() -> void:
	AudioManager.play_sfx("confirm_1")
	GameManager.go_to_character_select()

func _on_quit_pressed() -> void:
	AudioManager.play_sfx("back_1")
	get_tree().quit()
