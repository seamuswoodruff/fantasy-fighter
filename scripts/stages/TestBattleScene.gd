# TestBattleScene.gd — Minimal battle scene for physics verification
extends Node2D

@onready var stage = $TestStage
@onready var player1: Character = $Players/Player1
@onready var player2: Character = $Players/Player2

func _ready() -> void:
	var sp1: Marker2D = stage.get_node("SpawnPoints/SpawnP1")
	var sp2: Marker2D = stage.get_node("SpawnPoints/SpawnP2")

	player1.global_position = sp1.global_position
	player1.respawn_position = sp1.global_position
	player2.global_position = sp2.global_position
	player2.respawn_position = sp2.global_position

	stage.body_entered_kill_zone.connect(_on_kill_zone_entered)
	GameManager.selected_stage = "Test"
	GameManager.start_match()

	print("[TestBattle] P1 spawn: %v  P2 spawn: %v" % [player1.global_position, player2.global_position])

	# Test 1: both land on ground from spawn
	get_tree().create_timer(2.0).timeout.connect(_test_float)

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var ts := Time.get_datetime_string_from_system() \
		.replace(":", "").replace("-", "").replace("T", "_")
	var path := ProjectSettings.globalize_path("res://screenshots/" + label + "_" + ts + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("[TestBattle] Screenshot: %s | P1 pos=%v floor=%s | P2 pos=%v floor=%s" % [
		label,
		player1.global_position, player1.is_on_floor(),
		player2.global_position, player2.is_on_floor()
	])

func _test_float() -> void:
	# Screenshot current ground landing
	await _capture("test_ground")
	# Teleport P2 above the float platform (surface y=360, spawn above at y=200)
	player2.global_position = Vector2(640, 200)
	player2.velocity = Vector2.ZERO
	await get_tree().create_timer(1.5).timeout
	await _capture("test_float")

func _on_kill_zone_entered(body: Node) -> void:
	if not (body is Character):
		return
	var character := body as Character
	if character.state == Character.State.DEAD:
		return
	print("[TestBattle] P%d entered kill zone" % character.player_id)
	character.die()
