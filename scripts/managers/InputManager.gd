# InputManager.gd
# Autoload singleton — keyboard/controller abstraction per player.
extends Node

func _ready() -> void:
	print("[InputManager] Ready — connected joypads: %d" % Input.get_connected_joypads().size())
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		print("[InputManager] Controller connected: device %d (%s)" % [device, Input.get_joy_name(device)])
	else:
		print("[InputManager] Controller disconnected: device %d" % device)

# Returns the movement vector for a player (values -1, 0, 1 on each axis).
func get_move_vector(player_id: int) -> Vector2:
	var px := "p%d_" % player_id
	var x := Input.get_action_strength(px + "right") - Input.get_action_strength(px + "left")
	var y := Input.get_action_strength(px + "down") - Input.get_action_strength(px + "up")
	return Vector2(x, y)

func is_jump_pressed(player_id: int) -> bool:
	return Input.is_action_just_pressed("p%d_jump" % player_id)

func is_jump_held(player_id: int) -> bool:
	return Input.is_action_pressed("p%d_jump" % player_id)

func is_light_attack_pressed(player_id: int) -> bool:
	return Input.is_action_just_pressed("p%d_light_attack" % player_id)

func is_heavy_attack_pressed(player_id: int) -> bool:
	return Input.is_action_just_pressed("p%d_heavy_attack" % player_id)

func is_special_pressed(player_id: int) -> bool:
	return Input.is_action_just_pressed("p%d_special" % player_id)

func is_block_held(player_id: int) -> bool:
	return Input.is_action_pressed("p%d_block" % player_id)

func is_moving_left(player_id: int) -> bool:
	return Input.is_action_pressed("p%d_left" % player_id)

func is_moving_right(player_id: int) -> bool:
	return Input.is_action_pressed("p%d_right" % player_id)

func is_moving_down(player_id: int) -> bool:
	return Input.is_action_pressed("p%d_down" % player_id)
