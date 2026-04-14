# TestScene.gd — Phase 2 movement test
# Spawns two placeholder characters on a flat platform.
# Auto-screenshots after the first rendered frame for review.
extends Node2D

func _ready() -> void:
	print("[TestScene] Phase 2 movement test loaded")
	print("[TestScene] P1: WASD + Space (double jump) | P2: Arrow keys + Numpad 0")
	print("[TestScene] Both characters support coyote time (6 frames) and double jump")
	await ScreenshotTool.take_screenshot("phase2_base_character")
