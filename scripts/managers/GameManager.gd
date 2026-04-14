# GameManager.gd
# Autoload singleton — global game state, match tracking, scene flow.
extends Node

# Selected characters and stage
var p1_character: String = ""
var p2_character: String = ""
var selected_stage: String = ""

# Match state
var p1_stocks: int = 3
var p2_stocks: int = 3
var match_active: bool = false

# Signals
signal stock_lost(player_id: int)
signal match_ended(winner_id: int)

func _ready() -> void:
	print("[GameManager] Ready")

func start_match() -> void:
	p1_stocks = 3
	p2_stocks = 3
	match_active = true
	print("[GameManager] Match started — P1: %s vs P2: %s on %s" % [p1_character, p2_character, selected_stage])

func on_player_death(player_id: int) -> void:
	if player_id == 1:
		p1_stocks -= 1
		print("[GameManager] P1 lost a stock — stocks remaining: %d" % p1_stocks)
		emit_signal("stock_lost", 1)
		if p1_stocks <= 0:
			end_match(2)
	else:
		p2_stocks -= 1
		print("[GameManager] P2 lost a stock — stocks remaining: %d" % p2_stocks)
		emit_signal("stock_lost", 2)
		if p2_stocks <= 0:
			end_match(1)

func end_match(winner_id: int) -> void:
	match_active = false
	print("[GameManager] Match ended — Winner: P%d" % winner_id)
	emit_signal("match_ended", winner_id)

func go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func go_to_character_select() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/CharacterSelect.tscn")

func go_to_stage_select() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/StageSelect.tscn")

func go_to_battle() -> void:
	get_tree().change_scene_to_file("res://scenes/stages/BattleScene.tscn")
