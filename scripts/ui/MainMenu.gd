# MainMenu.gd
# Placeholder main menu — Phase 1 stub.
extends Node2D

func _ready() -> void:
	print("[MainMenu] Ready — Phase 1 placeholder")
	$StartButton.pressed.connect(_on_start_pressed)
	$QuitButton.pressed.connect(_on_quit_pressed)
	# Auto-screenshot for Phase 1 documentation
	await get_tree().process_frame
	await ScreenshotTool.take_screenshot("phase1_mainmenu")

func _on_start_pressed() -> void:
	print("[MainMenu] Start pressed — scene flow not yet wired (Phase 10)")

func _on_quit_pressed() -> void:
	get_tree().quit()
