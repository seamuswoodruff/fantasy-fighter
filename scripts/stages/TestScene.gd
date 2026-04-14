# TestScene.gd — Phase 3 combat test
# Two Knight1 warriors on a flat platform.
# P1: WASD + Space(jump) + Z(light) + X(heavy) + C(special/shield) + LShift(block)
# P2: Arrows + Num0(jump) + Num1(light) + Num2(heavy) + Num3(special) + RShift(block)
extends Node2D

func _ready() -> void:
	print("[TestScene] Phase 3 — knight_1 combat test loaded")
	print("[TestScene] P1: WASD + Space | Z=light X=heavy C=shield LShift=block")
	print("[TestScene] P2: Arrows + Num0 | Num1=light Num2=heavy Num3=shield RShift=block")
	await ScreenshotTool.take_screenshot("phase3_knight1_idle")
