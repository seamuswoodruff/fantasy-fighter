# TestStage.gd — Minimal test stage for character physics verification
extends Node2D

signal body_entered_kill_zone(body: Node)

func _ready() -> void:
	$KillZoneBottom.body_entered.connect(_on_kill_zone_entered)
	$KillZoneLeft.body_entered.connect(_on_kill_zone_entered)
	$KillZoneRight.body_entered.connect(_on_kill_zone_entered)
	print("[TestStage] Ready — 3 kill zones connected")

func _on_kill_zone_entered(body: Node) -> void:
	body_entered_kill_zone.emit(body)
