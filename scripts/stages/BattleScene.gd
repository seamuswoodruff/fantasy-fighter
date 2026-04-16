# BattleScene.gd — Phase 6 battle scene controller (adds HUD wiring)
extends Node2D

@onready var stage = $Stage
@onready var player1: Character = $Players/Player1
@onready var player2: Character = $Players/Player2
@onready var hud = $HUD

func _ready() -> void:
	var sp1: Marker2D = stage.get_node("SpawnPoints/SpawnP1")
	var sp2: Marker2D = stage.get_node("SpawnPoints/SpawnP2")

	player1.global_position = sp1.global_position
	player1.respawn_position = sp1.global_position
	player2.global_position = sp2.global_position
	player2.respawn_position = sp2.global_position

	stage.body_entered_kill_zone.connect(_on_kill_zone_entered)
	GameManager.selected_stage = "Windrise"
	GameManager.start_match()

	# Wire HUD to both player characters so it can poll HP
	hud.set_characters(player1, player2)

	print("[BattleScene] Phase 6 — Windrise | P1@%v  P2@%v | HUD wired" % [player1.global_position, player2.global_position])

func _on_kill_zone_entered(body: Node) -> void:
	if not (body is Character):
		return
	var character := body as Character
	if character.state == Character.State.DEAD:
		return
	print("[BattleScene] P%d entered kill zone — triggering die()" % character.player_id)
	character.die()
