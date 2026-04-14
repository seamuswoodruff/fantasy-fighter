# ScreenshotTool.gd
# Autoload singleton — active in every scene.
# Hotkeys:
#   F12  → screenshot named by current scene + timestamp
#   F11  → screenshot with a custom label (set via set_label() before pressing)
# Saved to: res://screenshots/
extends Node

const SCREENSHOT_DIR := "res://screenshots/"
const HOTKEY_CAPTURE := KEY_F12
const HOTKEY_LABELED := KEY_F11

var _pending_label: String = ""

func _ready() -> void:
	var abs_path := ProjectSettings.globalize_path(SCREENSHOT_DIR)
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_absolute(abs_path)
	print("[ScreenshotTool] Ready — screenshots → " + abs_path)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F12:
				take_screenshot()
			KEY_F11:
				take_screenshot(_pending_label if _pending_label != "" else "labeled")

func take_screenshot(label: String = "") -> String:
	var scene_name: String = "unknown"
	if get_tree().current_scene:
		scene_name = get_tree().current_scene.name.to_lower()

	var timestamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var label_part := (label + "_") if label != "" else ""
	var filename := "%s_%s%s.png" % [scene_name, label_part, timestamp]
	var full_path := ProjectSettings.globalize_path(SCREENSHOT_DIR + filename)

	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(full_path)

	print("[ScreenshotTool] Saved: " + full_path)
	_pending_label = ""
	return full_path

func set_label(label: String) -> void:
	_pending_label = label
