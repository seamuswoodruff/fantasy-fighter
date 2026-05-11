# CPUController.gd
# Attach as a child of any Character node with is_cpu = true.
# Drives character movement and attacks via the parent's cpu_* vars and
# direct method calls. The parent's handle_input() reads these each frame.
extends Node

@export var cpu_difficulty: int = 2   # 1 = Easy, 2 = Normal, 3 = Hard

# ── Difficulty-based constants ────────────────────────────────────────────────
# IDLE duration range [min, max] in seconds
const IDLE_RANGE := {
	1: [0.6, 1.2],
	2: [0.1, 0.45],
	3: [0.04, 0.18],
}
# Attack weights [light%, heavy%, special%] — must sum to 100
const ATTACK_WEIGHTS := {
	1: [90,  5,  5],
	2: [55, 25, 20],
	3: [40, 30, 30],
}

# ── State machine ─────────────────────────────────────────────────────────────
enum AIState { APPROACH, ATTACK, RETREAT, RECOVER, IDLE }
var _ai_state: AIState = AIState.IDLE
var _state_timer: float = 0.0

# ── Internal refs ─────────────────────────────────────────────────────────────
var _parent: Character = null
var _stage_center_x: float = 640.0   # default; updated on _ready if possible

# ── Approach jump timer ───────────────────────────────────────────────────────
var _jump_timer: float = 0.0
const JUMP_INTERVAL_MIN := 1.2
const JUMP_INTERVAL_MAX := 3.0

func _ready() -> void:
	_parent = get_parent() as Character
	if _parent == null:
		push_error("[CPUController] Parent is not a Character — disabling.")
		set_process(false)
		set_physics_process(false)
		return

	# Try to find stage center from the stage's spawn points
	var battle_scene := get_tree().get_first_node_in_group("battle_scene")
	if battle_scene != null and battle_scene.has_node("Stage/SpawnPoints"):
		var sp1 = battle_scene.get_node("Stage/SpawnPoints/SpawnP1")
		var sp2 = battle_scene.get_node("Stage/SpawnPoints/SpawnP2")
		if sp1 and sp2:
			_stage_center_x = (sp1.global_position.x + sp2.global_position.x) / 2.0

	# Randomise initial idle so multiple CPUs don't all act in sync
	_enter_state(AIState.IDLE, randf_range(0.2, 0.8))
	_jump_timer = randf_range(JUMP_INTERVAL_MIN, JUMP_INTERVAL_MAX)

func _physics_process(delta: float) -> void:
	if _parent == null or _parent.state == Character.State.DEAD:
		if _parent != null:
			_parent.cpu_move_x = 0.0
		return

	if not GameManager.match_active:
		_parent.cpu_move_x = 0.0
		return

	_state_timer -= delta
	_jump_timer  -= delta

	match _ai_state:
		AIState.IDLE:     _tick_idle(delta)
		AIState.APPROACH: _tick_approach(delta)
		AIState.ATTACK:   _tick_attack(delta)
		AIState.RETREAT:  _tick_retreat(delta)
		AIState.RECOVER:  _tick_recover(delta)

# ── State transitions ─────────────────────────────────────────────────────────
func _enter_state(new_state: AIState, duration: float = 0.0) -> void:
	_ai_state = new_state
	_state_timer = duration

func _idle_duration() -> float:
	var r: Array = IDLE_RANGE.get(cpu_difficulty, IDLE_RANGE[2])
	return randf_range(r[0], r[1])

# ── Tick functions ─────────────────────────────────────────────────────────────
func _tick_idle(_delta: float) -> void:
	_parent.cpu_move_x = 0.0
	if _state_timer <= 0.0:
		var target := _nearest_enemy()
		if target == null:
			_enter_state(AIState.IDLE, _idle_duration())
		elif _dist_to(target) < 110.0:
			_enter_state(AIState.ATTACK)
		else:
			_enter_state(AIState.APPROACH)

func _tick_approach(_delta: float) -> void:
	var target := _nearest_enemy()
	if target == null:
		_enter_state(AIState.IDLE, _idle_duration())
		return

	# Check if off-platform — prioritise recovery
	if _should_recover():
		_enter_state(AIState.RECOVER)
		return

	var dist := _dist_to(target)
	if dist < 110.0:
		_parent.cpu_move_x = 0.0
		_enter_state(AIState.ATTACK)
		return

	# Move toward target
	_parent.cpu_move_x = signf(target.global_position.x - _parent.global_position.x)

	# Occasionally jump while approaching to vary angle
	if _jump_timer <= 0.0 and _parent.is_on_floor():
		_parent.cpu_wants_jump = true
		_jump_timer = randf_range(JUMP_INTERVAL_MIN, JUMP_INTERVAL_MAX)

func _tick_attack(_delta: float) -> void:
	_parent.cpu_move_x = 0.0   # stop moving during attack decision
	if _parent.state == Character.State.HURT:
		# Got hit — retreat
		_enter_state(AIState.RETREAT, 0.4)
		return

	if _state_timer <= 0.0:
		var target := _nearest_enemy()
		if target == null or _dist_to(target) > 160.0:
			_enter_state(AIState.APPROACH)
			return
		# Face target
		_parent.cpu_move_x = signf(target.global_position.x - _parent.global_position.x)
		# Pick attack based on difficulty weights
		_execute_attack()
		_enter_state(AIState.IDLE, _idle_duration())

func _tick_retreat(_delta: float) -> void:
	var target := _nearest_enemy()
	if target != null:
		# Move away from target
		_parent.cpu_move_x = -signf(target.global_position.x - _parent.global_position.x)
	if _state_timer <= 0.0:
		_parent.cpu_move_x = 0.0
		_enter_state(AIState.APPROACH)

func _tick_recover(_delta: float) -> void:
	# Move toward stage center and jump to get back on platform
	var dir := signf(_stage_center_x - _parent.global_position.x)
	_parent.cpu_move_x = dir
	if _parent.is_on_floor():
		# Back on ground — return to approach
		_enter_state(AIState.APPROACH)
	elif _parent._jumps_remaining > 0:
		_parent.cpu_wants_jump = true

# ── Helpers ───────────────────────────────────────────────────────────────────
func _nearest_enemy() -> Character:
	var best: Character = null
	var best_dist := INF
	var all_chars := get_tree().get_nodes_in_group("characters")
	for node in all_chars:
		var ch := node as Character
		if ch == null or ch == _parent or ch.state == Character.State.DEAD:
			continue
		var d := _dist_to(ch)
		if d < best_dist:
			best_dist = d
			best = ch
	return best

func _dist_to(target: Character) -> float:
	return absf(target.global_position.x - _parent.global_position.x)

func _should_recover() -> bool:
	# If airborne and far from stage center, need to recover
	return not _parent.is_on_floor() and \
		   absf(_parent.global_position.x - _stage_center_x) > 420.0

func _execute_attack() -> void:
	var weights: Array = ATTACK_WEIGHTS.get(cpu_difficulty, ATTACK_WEIGHTS[2])
	var roll := randi() % 100
	if roll < weights[0]:
		_parent.attack_light()
	elif roll < weights[0] + weights[1]:
		_parent.attack_heavy()
	else:
		_parent.special_attack()
