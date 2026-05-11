# CPUController.gd
# Simple AI controller — attached as a child node to a CPU Character.
# Moves toward the nearest live opponent and attacks when in melee range.
extends Node

const ATTACK_RANGE    := 100.0   # pixels — start attacking when this close
const JUMP_CHANCE     := 0.015   # probability per frame of jumping
const SPECIAL_CHANCE  := 0.004   # probability per frame of using special

var _char: Character = null
var _action_timer: float = 0.0

func _ready() -> void:
	_char = get_parent() as Character

func _physics_process(delta: float) -> void:
	if _char == null:
		return
	if _char.state == Character.State.DEAD:
		return
	if not GameManager.match_active:
		return

	_action_timer += delta

	# Find nearest live opponent
	var target := _find_nearest_opponent()
	if target == null:
		return

	var dx := target.global_position.x - _char.global_position.x
	var dist := absf(dx)
	var dir := signf(dx)

	# Move toward target unless in attack range
	if dist > ATTACK_RANGE:
		# Simulate directional input by directly influencing the character's velocity
		_char.velocity.x = dir * _char.move_speed
	else:
		# In range — slow down, try to attack
		_char.velocity.x = move_toward(_char.velocity.x, 0.0, _char.move_speed * 0.5)

		# Light attack when in range (cooldown guard via action_timer)
		if _action_timer >= 0.35:
			_action_timer = 0.0
			if _char.state in [Character.State.IDLE, Character.State.RUN]:
				_char.attack_light()

	# Occasional jump (helps get to elevated platforms or over opponent)
	if randf() < JUMP_CHANCE and _char.is_on_floor():
		_char.velocity.y = _char.jump_force

	# Occasional special
	if randf() < SPECIAL_CHANCE:
		if _char.state in [Character.State.IDLE, Character.State.RUN]:
			_char.special_attack()

func _find_nearest_opponent() -> Character:
	var best: Character = null
	var best_dist := INF
	# Characters live under BattleScene/Players — walk up two levels from self
	var players_node := _char.get_parent()
	if players_node == null:
		return null
	for node in players_node.get_children():
		if not (node is Character):
			continue
		var c := node as Character
		if c == _char:
			continue
		if c.state == Character.State.DEAD:
			continue
		var d := _char.global_position.distance_to(c.global_position)
		if d < best_dist:
			best_dist = d
			best = c
	return best
