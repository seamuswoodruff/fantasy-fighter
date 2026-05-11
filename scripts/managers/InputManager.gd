# InputManager.gd
# Autoload singleton — keyboard/controller abstraction per player.
# Controllers assign to the HIGHEST active player slot that has no controller,
# so with 4 players and 2 controllers: P4 gets device 0, P3 gets device 1.
extends Node

func _ready() -> void:
	print("[InputManager] Ready — connected joypads: %d" % Input.get_connected_joypads().size())
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	# Initial assignment (usually 0 controllers at startup, but handle hot-plug)
	reassign_controllers()

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		print("[InputManager] Controller connected: device %d (%s)" % [device, Input.get_joy_name(device)])
	else:
		print("[InputManager] Controller disconnected: device %d" % device)
	reassign_controllers()

# ── Player count helpers ───────────────────────────────────────────────────────

func get_active_player_count() -> int:
	return GameManager.active_player_count

func get_max_player_count() -> int:
	# P1+P2 always available via keyboard; each controller unlocks one more slot
	return mini(2 + Input.get_connected_joypads().size(), 4)

# ── Controller assignment ──────────────────────────────────────────────────────
# Clears all joypad bindings from p3_* and p4_* actions, then re-adds them
# so the first joypad goes to the highest active player, etc.

func reassign_controllers() -> void:
	var joypads: Array = Input.get_connected_joypads()
	var active: int = GameManager.active_player_count

	# Always clear p3 and p4 joypad bindings first
	_clear_joy_bindings(3)
	_clear_joy_bindings(4)

	if joypads.is_empty():
		return

	# Assign controllers from highest active slot downward (only to P3/P4)
	# Slot numbering: slot 3 = P4, slot 2 = P3 (P1/P2 always keyboard)
	var slot := active  # 1-based, start from highest
	for device in joypads:
		if slot < 3:
			break  # reached P2 — P1/P2 keep keyboard only for now
		_assign_joy_to_player(slot, device)
		slot -= 1

	print("[InputManager] reassigned — active:%d joypads:%d" % [active, joypads.size()])

func _clear_joy_bindings(pid: int) -> void:
	var pfx := "p%d_" % pid
	for suffix in ["left", "right", "up", "down", "jump",
				   "light_attack", "heavy_attack", "special", "special2"]:
		var action: String = pfx + suffix
		if not InputMap.has_action(action):
			continue
		for evt in InputMap.action_get_events(action).duplicate():
			if evt is InputEventJoypadButton or evt is InputEventJoypadMotion:
				InputMap.action_erase_event(action, evt)

func _assign_joy_to_player(pid: int, device: int) -> void:
	var bindings: Dictionary = {
		"left":         [_joy_axis(JOY_AXIS_LEFT_X, -1.0, device),
						 _joy_btn(JOY_BUTTON_DPAD_LEFT, device)],
		"right":        [_joy_axis(JOY_AXIS_LEFT_X,  1.0, device),
						 _joy_btn(JOY_BUTTON_DPAD_RIGHT, device)],
		"up":           [_joy_axis(JOY_AXIS_LEFT_Y, -1.0, device),
						 _joy_btn(JOY_BUTTON_DPAD_UP, device)],
		"down":         [_joy_axis(JOY_AXIS_LEFT_Y,  1.0, device),
						 _joy_btn(JOY_BUTTON_DPAD_DOWN, device)],
		"jump":         [_joy_btn(JOY_BUTTON_A, device)],
		"light_attack": [_joy_axis(JOY_AXIS_RIGHT_X,  1.0, device)],
		"heavy_attack": [_joy_axis(JOY_AXIS_RIGHT_X, -1.0, device)],
		"special":      [_joy_axis(JOY_AXIS_RIGHT_Y, -1.0, device)],
		"special2":     [_joy_axis(JOY_AXIS_RIGHT_Y,  1.0, device)],
	}
	for suffix in bindings:
		var action := "p%d_%s" % [pid, suffix]
		if not InputMap.has_action(action):
			continue
		for evt: InputEvent in bindings[suffix]:
			InputMap.action_add_event(action, evt)
	print("[InputManager] P%d → joypad device %d" % [pid, device])

func _joy_btn(button: JoyButton, device: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device       = device
	e.button_index = button
	e.pressed      = true
	return e

func _joy_axis(axis: JoyAxis, value: float, device: int) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device     = device
	e.axis       = axis
	e.axis_value = value
	return e

# ── Per-player input queries ───────────────────────────────────────────────────

func get_move_vector(player_id: int) -> Vector2:
	var px := "p%d_" % player_id
	var x := Input.get_action_strength(px + "right") - Input.get_action_strength(px + "left")
	var y := Input.get_action_strength(px + "down")  - Input.get_action_strength(px + "up")
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

func is_special_held(player_id: int) -> bool:
	return Input.is_action_pressed("p%d_special" % player_id)

func is_special2_pressed(player_id: int) -> bool:
	return Input.is_action_just_pressed("p%d_special2" % player_id)

func is_special2_held(player_id: int) -> bool:
	return Input.is_action_pressed("p%d_special2" % player_id)

func is_block_held(player_id: int) -> bool:
	return Input.is_action_pressed("p%d_block" % player_id)

func is_moving_left(player_id: int) -> bool:
	return Input.is_action_pressed("p%d_left" % player_id)

func is_moving_right(player_id: int) -> bool:
	return Input.is_action_pressed("p%d_right" % player_id)

func is_moving_down(player_id: int) -> bool:
	return Input.is_action_pressed("p%d_down" % player_id)
