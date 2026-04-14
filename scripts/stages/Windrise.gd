# Windrise.gd — Phase 4 Windrise stage
# Connects all KillZone Area2D children and re-emits body_entered as a single signal.
extends Node2D

signal body_entered_kill_zone(body: Node)

func _ready() -> void:
	for kz in $KillZones.get_children():
		kz.body_entered.connect(_on_kill_zone_body_entered)
	print("[Windrise] Stage ready — %d kill zones connected" % $KillZones.get_child_count())

func _on_kill_zone_body_entered(body: Node) -> void:
	body_entered_kill_zone.emit(body)
