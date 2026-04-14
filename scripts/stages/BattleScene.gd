# BattleScene.gd — Phase 4 battle scene controller
# Spawns two Knight1 players at stage spawn points and wires kill zones.
extends Node2D

@onready var stage = $Stage
@onready var player1: Character = $Players/Player1
@onready var player2: Character = $Players/Player2

func _ready() -> void:
	# Position players at stage spawn points
	var sp1: Marker2D = stage.get_node("SpawnPoints/SpawnP1")
	var sp2: Marker2D = stage.get_node("SpawnPoints/SpawnP2")

	player1.global_position = sp1.global_position
	player1.respawn_position = sp1.global_position

	player2.global_position = sp2.global_position
	player2.respawn_position = sp2.global_position

	# Wire kill zones
	stage.body_entered_kill_zone.connect(_on_kill_zone_entered)

	GameManager.selected_stage = "Windrise"
	GameManager.start_match()

	print("[BattleScene] Phase 4 — Windrise | P1@%v  P2@%v" % [
		player1.global_position, player2.global_position
	])

	# Auto-screenshot for layout review
	await ScreenshotTool.take_screenshot("phase4_windrise_layout")

func _on_kill_zone_entered(body: Node) -> void:
	if not (body is Character):
		return
	var character := body as Character
	if character.state == Character.State.DEAD:
		return
	print("[BattleScene] P%d entered kill zone — triggering die()" % character.player_id)
	character.die()
