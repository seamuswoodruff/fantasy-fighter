# PauseMenu.gd
extends CanvasLayer

signal resume_pressed
signal quit_pressed

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_menu() -> void:
	show()

func hide_menu() -> void:
	hide()

func _on_resume_button_pressed() -> void:
	emit_signal("resume_pressed")

func _on_quit_button_pressed() -> void:
	emit_signal("quit_pressed")
