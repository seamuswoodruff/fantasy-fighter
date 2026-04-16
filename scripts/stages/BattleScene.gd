# BattleScene.gd — Phase 7: adds stage music and ambience
extends Node2D

const WINDRISE_MUSIC := [
	"res://assets/music/PerituneMaterial_Prairie3_loop.ogg",
	"res://assets/music/PerituneMaterial_Prairie4_loop.ogg",
	"res://assets/music/PerituneMaterial_Prairie5_loop.ogg",
	"res://assets/music/PerituneMaterial_BattleField_loop.ogg",
	"res://assets/music/PerituneMaterial_BattleField2_loop.ogg",
	"res://assets/music/PerituneMaterial_BattleField3_loop.ogg",
	"res://assets/music/PerituneMaterial_BattleField4_loop.ogg",
	"res://assets/music/PerituneMaterial_BattleField5_loop.ogg",
	"res://assets/music/PerituneMaterial_EpicBattle_loop.ogg",
]

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

	player2.spawn_facing_right = false
	player2._set_facing(false)

	stage.body_entered_kill_zone.connect(_on_kill_zone_entered)
	GameManager.selected_stage = "Windrise"
	GameManager.start_match()

	# Wire HUD to both player characters so it can poll HP
	hud.set_characters(player1, player2)

	# Stage audio
	AudioManager.play_music(WINDRISE_MUSIC[randi() % WINDRISE_MUSIC.size()])
	AudioManager.play_ambience("res://assets/sfx/ambience/Forest Day.ogg")

	print("[BattleScene] Phase 7 — Windrise | P1@%v  P2@%v | HUD + audio wired" % [player1.global_position, player2.global_position])

func _on_kill_zone_entered(body: Node) -> void:
	if not (body is Character):
		return
	var character := body as Character
	# is_invincible covers both the post-respawn i-frame window and the case where
	# physics re-fires body_entered after process_mode is re-enabled in respawn()
	if character.state == Character.State.DEAD or character.is_invincible:
		return
	print("[BattleScene] P%d entered kill zone — triggering die()" % character.player_id)
	character.die()
