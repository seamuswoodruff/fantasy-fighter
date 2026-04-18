# BattleScene.gd — Phase 8: dynamic character loading, all 9 characters supported
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

const CHARACTER_SCENES := {
	"knight_1":           "res://scenes/characters/Knight1.tscn",
	"knight_2":           "res://scenes/characters/Knight2.tscn",
	"knight_3":           "res://scenes/characters/Knight3.tscn",
	"samurai":            "res://scenes/characters/Samurai.tscn",
	"samurai_commander":  "res://scenes/characters/SamuraiCommander.tscn",
	"samurai_archer":     "res://scenes/characters/SamuraiArcher.tscn",
	"fire_wizard":        "res://scenes/characters/FireWizard.tscn",
	"lightning_mage":     "res://scenes/characters/LightningMage.tscn",
	"wanderer_magician":  "res://scenes/characters/WandererMagician.tscn",
}

@onready var stage = $Stage
@onready var players_node: Node2D = $Players
@onready var hud = $HUD

var player1: Character
var player2: Character

func _ready() -> void:
	_validate_all_characters()

	var p1_key := GameManager.p1_character if GameManager.p1_character != "" else "fire_wizard"
	var p2_key := GameManager.p2_character if GameManager.p2_character != "" else "lightning_mage"

	player1 = _spawn_character(p1_key, 1)
	player2 = _spawn_character(p2_key, 2)

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

	hud.set_characters(player1, player2)

	AudioManager.play_music(WINDRISE_MUSIC[randi() % WINDRISE_MUSIC.size()])
	AudioManager.play_ambience("res://assets/sfx/ambience/Forest Day.ogg")

	print("[BattleScene] Phase 8 — %s vs %s on Windrise" % [p1_key, p2_key])

func _validate_all_characters() -> void:
	print("[BattleScene] Validating all 9 character scenes...")
	for key in CHARACTER_SCENES.keys():
		var node := _spawn_character(key, 99)
		if node == null:
			push_error("[BattleScene] FAILED to load: " + key)
		else:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			print("[BattleScene] OK: %s — HP:%.0f Spd:%.0f" % [key, node.max_hp, node.move_speed])
			node.queue_free()
	print("[BattleScene] All character validation complete.")

func _spawn_character(key: String, pid: int) -> Character:
	var scene_path: String = CHARACTER_SCENES.get(key, CHARACTER_SCENES["knight_1"])
	var scene: PackedScene = load(scene_path)
	var char_node := scene.instantiate() as Character
	if char_node == null:
		push_error("[BattleScene] Failed to load character: " + key)
		return null
	char_node.player_id = pid
	char_node.name = "Player%d" % pid
	players_node.add_child(char_node)
	return char_node

func _on_kill_zone_entered(body: Node) -> void:
	if not (body is Character):
		return
	var character := body as Character
	if character.state == Character.State.DEAD or character.is_invincible:
		return
	print("[BattleScene] P%d entered kill zone — triggering die()" % character.player_id)
	character.die()
