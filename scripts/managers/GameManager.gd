# GameManager.gd
# Autoload singleton — global game state, match tracking, scene flow.
extends Node

# Per-player arrays (index 0 = P1, 1 = P2, 2 = P3, 3 = P4)
var player_characters: Array[String] = ["", "", "", ""]
var player_is_cpu: Array[bool] = [false, false, false, false]
var player_stocks: Array[int] = [3, 3, 3, 3]
var active_player_count: int = 2
var stock_count: int = 3

# Computed aliases so WinScreen / StageSelect need no changes
var p1_character: String:
	get: return player_characters[0]
	set(v): player_characters[0] = v
var p2_character: String:
	get: return player_characters[1]
	set(v): player_characters[1] = v

var selected_stage: String = ""
var match_active: bool = false
var winner_id: int = 0

# Signals
signal stock_lost(player_id: int)
signal match_ended(winner_id: int)

func _ready() -> void:
	get_tree().debug_collisions_hint = false
	print("[GameManager] Ready")

func start_match() -> void:
	for i in active_player_count:
		player_stocks[i] = stock_count
	match_active = true
	print("[GameManager] Match started — %d players on %s" % [active_player_count, selected_stage])

func on_player_death(player_id: int) -> void:
	var idx := player_id - 1
	if idx < 0 or idx >= active_player_count:
		return
	player_stocks[idx] -= 1
	print("[GameManager] P%d lost a stock — %d remaining" % [player_id, player_stocks[idx]])
	emit_signal("stock_lost", player_id)
	if player_stocks[idx] <= 0:
		var alive := players_still_alive()
		if alive.size() == 1:
			end_match(alive[0])

func players_still_alive() -> Array:
	var alive: Array = []
	for i in active_player_count:
		if player_stocks[i] > 0:
			alive.append(i + 1)
	return alive

func end_match(winner_id_: int) -> void:
	match_active = false
	winner_id = winner_id_
	print("[GameManager] Match ended — Winner: P%d" % winner_id)
	emit_signal("match_ended", winner_id)
	AudioManager.stop_music()
	AudioManager.stop_ambience()
	get_tree().create_timer(1.5).timeout.connect(go_to_win_screen)

func reset_match_state() -> void:
	for i in 4:
		player_characters[i] = ""
		player_is_cpu[i] = false
		player_stocks[i] = stock_count
	winner_id = 0

func go_to_win_screen() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/WinScreen.tscn")

func go_to_main_menu() -> void:
	reset_match_state()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func go_to_character_select() -> void:
	reset_match_state()
	get_tree().change_scene_to_file("res://scenes/ui/CharacterSelect.tscn")

func go_to_stage_select() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/StageSelect.tscn")

func go_to_battle() -> void:
	get_tree().change_scene_to_file("res://scenes/stages/BattleScene.tscn")
