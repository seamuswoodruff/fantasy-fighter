# BattleScene.gd — Phase 9: dynamic stage + character loading
extends Node2D

# ── Stage configuration ────────────────────────────────────────────────────────
# Phase 10 will use GameManager.selected_stage; for now Windrise is the default.
const DEFAULT_STAGE := "Windrise"

const STAGE_SCENES := {
	"Windrise":     "res://scenes/stages/Windrise.tscn",
	"Ruins":        "res://scenes/stages/Ruins.tscn",
	"DesertTemple": "res://scenes/stages/DesertTemple.tscn",
}

const STAGE_MUSIC := {
	"Windrise": [
		"res://assets/music/PerituneMaterial_Prairie3_loop.ogg",
		"res://assets/music/PerituneMaterial_Prairie4_loop.ogg",
		"res://assets/music/PerituneMaterial_Prairie5_loop.ogg",
		"res://assets/music/PerituneMaterial_BattleField_loop.ogg",
		"res://assets/music/PerituneMaterial_BattleField2_loop.ogg",
		"res://assets/music/PerituneMaterial_BattleField3_loop.ogg",
		"res://assets/music/PerituneMaterial_BattleField4_loop.ogg",
		"res://assets/music/PerituneMaterial_BattleField5_loop.ogg",
		"res://assets/music/PerituneMaterial_EpicBattle_loop.ogg",
	],
	"Ruins": [
		"res://assets/music/PerituneMaterial_Gothic_Dark_loop.ogg",
		"res://assets/music/PerituneMaterial_Demise_loop.ogg",
		"res://assets/music/PerituneMaterial_Havoc_loop.ogg",
		"res://assets/music/PerituneMaterial_Fight_loop.ogg",
		"res://assets/music/PerituneMaterial_Fight2_loop.ogg",
		"res://assets/music/PerituneMaterial_Fight3_loop.ogg",
		"res://assets/music/PerituneMaterial_Crisis_loop.ogg",
	],
	"DesertTemple": [
		"res://assets/music/PerituneMaterial_Raid_Ethnic_loop.ogg",
		"res://assets/music/PerituneMaterial_Raid_FolkMetal_loop.ogg",
		"res://assets/music/PerituneMaterial_Raid_FolkMetal2_loop.ogg",
		"res://assets/music/PerituneMaterial_Raid_loop.ogg",
		"res://assets/music/PerituneMaterial_Raid2_loop.ogg",
		"res://assets/music/PerituneMaterial_Raid3_loop.ogg",
		"res://assets/music/PerituneMaterial_Flap_loop.ogg",
		"res://assets/music/PerituneMaterial_Flap2_loop.ogg",
	],
}

const STAGE_AMBIENCE := {
	"Windrise":     "res://assets/sfx/ambience/Forest Day.ogg",
	"Ruins":        "res://assets/sfx/ambience/Cave.ogg",
	"DesertTemple": "res://assets/sfx/ambience/Forest Night.ogg",
}

# ── Character scenes ───────────────────────────────────────────────────────────
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

@onready var players_node: Node2D = $Players
@onready var hud = $HUD

var stage: Node2D
var player1: Character
var player2: Character

func _ready() -> void:
	_validate_all_characters()

	# Load stage — use GameManager selection if set, else default
	var stage_key := GameManager.selected_stage if GameManager.selected_stage != "" else DEFAULT_STAGE
	if not STAGE_SCENES.has(stage_key):
		push_error("[BattleScene] Unknown stage '%s', falling back to Windrise" % stage_key)
		stage_key = DEFAULT_STAGE
	GameManager.selected_stage = stage_key

	var stage_scene: PackedScene = load(STAGE_SCENES[stage_key])
	stage = stage_scene.instantiate() as Node2D
	stage.name = "Stage"
	add_child(stage)
	move_child(stage, 0)

	var p1_key := GameManager.p1_character if GameManager.p1_character != "" else "samurai_commander"
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
	GameManager.start_match()

	hud.set_characters(player1, player2)

	_play_stage_audio(stage_key)

	print("[BattleScene] Phase 9 — %s vs %s on %s" % [p1_key, p2_key, stage_key])

func _play_stage_audio(stage_key: String) -> void:
	var music_list: Array = STAGE_MUSIC.get(stage_key, STAGE_MUSIC["Windrise"])
	# Filter to existing files so a missing OGG doesn't crash
	var available: Array = music_list.filter(func(p): return ResourceLoader.exists(p))
	if available.is_empty():
		available = STAGE_MUSIC["Windrise"].filter(func(p): return ResourceLoader.exists(p))
	if not available.is_empty():
		AudioManager.play_music(available[randi() % available.size()])

	var amb_path: String = STAGE_AMBIENCE.get(stage_key, "")
	if amb_path != "" and ResourceLoader.exists(amb_path):
		AudioManager.play_ambience(amb_path)

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
