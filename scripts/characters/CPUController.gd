# CPUController.gd — character-aware AI controller (V5 — full mobility)
# Attach as a child of any Character node with is_cpu = true.
extends Node

@export var cpu_difficulty: int = 2   # 1 = Easy, 2 = Normal, 3 = Hard

# ── Difficulty timing ─────────────────────────────────────────────────────────
const IDLE_RANGE := {
	1: [0.4, 0.8],
	2: [0.05, 0.20],
	3: [0.02, 0.08],
}

# ── Attack ranges ─────────────────────────────────────────────────────────────
const MELEE_ATTACK_RANGE  := 120.0
const RANGED_PREFER_RANGE := 280.0
const RANGED_MIN_RANGE    := 90.0

# ── Aerial pursuit ────────────────────────────────────────────────────────────
# Jump to chase when target is this many px above us (Godot Y increases downward)
const AERIAL_CHASE_Y := 80.0

# ── Heal threshold (Kunoichi) ─────────────────────────────────────────────────
const HEAL_HP_THRESHOLD := 0.45

# ── Jump intervals ────────────────────────────────────────────────────────────
const JUMP_INTERVAL_MIN := 0.25
const JUMP_INTERVAL_MAX := 0.7

# ── State machine ─────────────────────────────────────────────────────────────
enum AIState { APPROACH, ATTACK, RETREAT, RECOVER, IDLE }
var _ai_state: AIState = AIState.IDLE
var _state_timer: float = 0.0

# ── Internal refs ─────────────────────────────────────────────────────────────
var _parent: Character = null
var _stage_center_x: float = 640.0
var _jump_timer: float = 0.0

# Cached from parent on _ready — never read per-frame
var _archetype: String = "melee"
var _jump_count: int = 2
var _jump_freq_mult: float = 1.0   # scales jump interval: more jumps → jumps more often

func _ready() -> void:
	_parent = get_parent() as Character
	if _parent == null:
		push_error("[CPUController] Parent is not a Character — disabling.")
		set_process(false)
		set_physics_process(false)
		return

	_archetype  = _parent.cpu_archetype
	_jump_count = _parent.jump_count

	# jump_count=2 → mult 1.0 (standard); 5 → mult 0.4 (very jumpy)
	_jump_freq_mult = clampf(2.0 / float(_jump_count), 0.3, 1.0)

	var battle_scene := get_tree().get_first_node_in_group("battle_scene")
	if battle_scene != null and battle_scene.has_node("Stage/SpawnPoints"):
		var sp1 = battle_scene.get_node("Stage/SpawnPoints/SpawnP1")
		var sp2 = battle_scene.get_node("Stage/SpawnPoints/SpawnP2")
		if sp1 and sp2:
			_stage_center_x = (sp1.global_position.x + sp2.global_position.x) / 2.0

	_enter_state(AIState.IDLE, randf_range(0.2, 0.8))
	_jump_timer = randf_range(JUMP_INTERVAL_MIN, JUMP_INTERVAL_MAX) * _jump_freq_mult

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

	# Healer: opportunistically heal when HP is low
	if _archetype == "healer" and not _parent._is_locked() \
			and _parent.current_hp / _parent.max_hp < HEAL_HP_THRESHOLD \
			and _ai_state != AIState.RECOVER:
		_parent.special2_attack()

	# Global aerial pursuit — active in every state except RECOVER and RETREAT.
	# Jumps to chase opponents onto platforms. High-jump chars do this much more.
	if _ai_state != AIState.RECOVER and _ai_state != AIState.RETREAT:
		_try_aerial_pursuit()

	match _ai_state:
		AIState.IDLE:     _tick_idle(delta)
		AIState.APPROACH: _tick_approach(delta)
		AIState.ATTACK:   _tick_attack(delta)
		AIState.RETREAT:  _tick_retreat(delta)
		AIState.RECOVER:  _tick_recover(delta)

# ── Aerial pursuit ────────────────────────────────────────────────────────────
# Called every frame from _physics_process. Jumps (using any remaining jump)
# whenever the target is significantly above — lets Kunoichi/ninjas chain
# multiple jumps to chase opponents who try to escape upward.
func _try_aerial_pursuit() -> void:
	if _jump_timer > 0.0 or _parent._jumps_remaining == 0:
		return
	if _parent._is_locked():
		return
	# Only jump when grounded or on the way UP — never while falling.
	# velocity.y > 0 means falling in Godot (Y increases downward).
	# This stops high-jump chars burning all their jumps in mid-air spam.
	if not _parent.is_on_floor() and _parent.velocity.y > 0.0:
		return
	var target := _nearest_enemy()
	if target == null:
		return
	# Positive dy means target is higher up (lower Y value)
	var dy := _parent.global_position.y - target.global_position.y
	if dy > AERIAL_CHASE_Y:
		_parent.cpu_wants_jump = true
		_jump_timer = randf_range(JUMP_INTERVAL_MIN, JUMP_INTERVAL_MAX) * _jump_freq_mult

# ── State transitions ─────────────────────────────────────────────────────────
func _enter_state(new_state: AIState, duration: float = 0.0) -> void:
	_ai_state = new_state
	_state_timer = duration

func _idle_duration() -> float:
	var r: Array = IDLE_RANGE.get(cpu_difficulty, IDLE_RANGE[2])
	return randf_range(r[0], r[1])

# ── Tick: IDLE ────────────────────────────────────────────────────────────────
func _tick_idle(_delta: float) -> void:
	_parent.cpu_move_x = 0.0
	if _state_timer <= 0.0:
		var target := _nearest_enemy()
		if target == null:
			_enter_state(AIState.IDLE, _idle_duration())
			return
		var dist := _dist_to(target)
		if dist < _attack_range():
			_enter_state(AIState.ATTACK)
		else:
			_enter_state(AIState.APPROACH)

# ── Tick: APPROACH ────────────────────────────────────────────────────────────
func _tick_approach(_delta: float) -> void:
	var target := _nearest_enemy()
	if target == null:
		_enter_state(AIState.IDLE, _idle_duration())
		return
	if _should_recover():
		_enter_state(AIState.RECOVER)
		return

	var dist         := _dist_to(target)
	var attack_range := _attack_range()

	if dist < attack_range:
		_parent.cpu_move_x = 0.0
		_enter_state(AIState.ATTACK)
		return

	var toward_target := signf(target.global_position.x - _parent.global_position.x)

	# Ranged: stop at preferred range and fire instead of rushing in
	if (_archetype == "ranged" or _archetype == "healer") \
			and dist <= RANGED_PREFER_RANGE and dist > RANGED_MIN_RANGE:
		_parent.cpu_move_x = 0.0
		_enter_state(AIState.ATTACK)
		return

	# Ground-ahead check: jump over gap while still moving
	if _parent.is_on_floor() and not _has_ground_ahead(toward_target, 120.0):
		if _parent._jumps_remaining > 0:
			_parent.cpu_wants_jump = true
	_parent.cpu_move_x = toward_target

	# Periodic mobility jump during approach (separate from aerial pursuit above)
	if _jump_timer <= 0.0 and _parent.is_on_floor() and not _parent._is_locked():
		_parent.cpu_wants_jump = true
		_jump_timer = randf_range(JUMP_INTERVAL_MIN, JUMP_INTERVAL_MAX) * _jump_freq_mult

# ── Tick: ATTACK ──────────────────────────────────────────────────────────────
# Stays in ATTACK state rather than bouncing through IDLE — repeatedly attacks
# as long as the target is within range. Tracks target and jumps for mobility.
func _tick_attack(_delta: float) -> void:
	if _parent.state == Character.State.HURT:
		# Blocker: try to block when being pressured (difficulty 2+)
		if (_archetype == "blocker") and cpu_difficulty >= 2:
			_parent.special2_attack()
		_enter_state(AIState.RETREAT, 0.4)
		return

	var target := _nearest_enemy()
	if target == null:
		_parent.cpu_move_x = 0.0
		_enter_state(AIState.APPROACH)
		return

	var dist         := _dist_to(target)
	var attack_range := _attack_range()

	if dist > attack_range * 1.4:
		# Target escaped — pursue
		_enter_state(AIState.APPROACH)
		return

	var toward := signf(target.global_position.x - _parent.global_position.x)

	# If there's a gap between us and the target (we're at a platform edge),
	# don't attack into the void — back off and find a path around.
	if not _has_ground_ahead(toward, 50.0) and dist > RANGED_MIN_RANGE:
		_enter_state(AIState.APPROACH)
		return

	# Keep tracking/closing on target — don't freeze in place
	if dist > attack_range * 0.5:
		_parent.cpu_move_x = toward   # close the last gap
	else:
		_parent.cpu_move_x = 0.0      # point-blank, hold position

	# While animation is playing, just track and wait
	if _parent._is_locked():
		return

	# Combat mobility jump — conservative chance, only from floor
	if _jump_timer <= 0.0 and _parent.is_on_floor():
		var jump_chance := 0.15 if _jump_count <= 2 else 0.45
		if randf() < jump_chance:
			_parent.cpu_wants_jump = true
		_jump_timer = randf_range(JUMP_INTERVAL_MIN, JUMP_INTERVAL_MAX) * _jump_freq_mult

	# Execute attack — minimum 0.25s between executions prevents spam loops
	if _state_timer <= 0.0:
		_parent.cpu_move_x = toward
		_execute_attack(dist)
		_state_timer = maxf(_idle_duration(), 0.25)

# ── Tick: RETREAT ─────────────────────────────────────────────────────────────
func _tick_retreat(_delta: float) -> void:
	var target := _nearest_enemy()
	if target != null:
		var away := -signf(target.global_position.x - _parent.global_position.x)
		if _parent.is_on_floor() and not _has_ground_ahead(away, 120.0):
			_parent.cpu_move_x = 0.0
			if _parent._jumps_remaining > 0:
				_parent.cpu_wants_jump = true
		else:
			_parent.cpu_move_x = away
	if _state_timer <= 0.0:
		_parent.cpu_move_x = 0.0
		# Small random jitter: prevents two CPUs re-synchronising after simultaneous hits
		_enter_state(AIState.IDLE, _idle_duration() + randf_range(0.0, 0.15))

# ── Tick: RECOVER ─────────────────────────────────────────────────────────────
func _tick_recover(_delta: float) -> void:
	var dir := signf(_stage_center_x - _parent.global_position.x)
	_parent.cpu_move_x = dir
	# Use every available jump while airborne — high-jump chars recover more easily
	if not _parent.is_on_floor() and _parent._jumps_remaining > 0:
		_parent.cpu_wants_jump = true
	if _parent.is_on_floor():
		_enter_state(AIState.APPROACH)

# ── Attack execution ──────────────────────────────────────────────────────────
func _execute_attack(dist: float) -> void:
	match _archetype:
		"ranged":
			if dist > RANGED_MIN_RANGE:
				_parent.special_attack()
			else:
				if randi() % 100 < 60:
					_parent.attack_light()
				else:
					_parent.attack_heavy()

		"healer":
			if dist > RANGED_MIN_RANGE:
				_parent.special_attack()
			else:
				var r := randi() % 100
				if r < 55: _parent.attack_light()
				elif r < 80: _parent.attack_heavy()
				else: _parent.special_attack()

		"blocker":
			var r := randi() % 100
			var bias := [50, 30, 20] if cpu_difficulty <= 2 else [35, 30, 35]
			if r < bias[0]: _parent.attack_light()
			elif r < bias[0] + bias[1]: _parent.attack_heavy()
			else: _parent.special_attack()

		"dasher":
			var r := randi() % 100
			var bias := [30, 25, 45] if cpu_difficulty <= 2 else [20, 20, 60]
			if r < bias[0]: _parent.attack_light()
			elif r < bias[0] + bias[1]: _parent.attack_heavy()
			else: _parent.special_attack()

		_:   # "melee" — default
			var weights := _melee_weights()
			var r := randi() % 100
			if r < weights[0]: _parent.attack_light()
			elif r < weights[0] + weights[1]: _parent.attack_heavy()
			elif r < weights[0] + weights[1] + weights[2]: _parent.special_attack()
			else: _parent.special2_attack()

func _melee_weights() -> Array:
	match cpu_difficulty:
		1: return [85, 10,  5,  0]
		3: return [30, 30, 25, 15]
		_: return [50, 25, 15, 10]

# ── Attack range by archetype ─────────────────────────────────────────────────
func _attack_range() -> float:
	match _archetype:
		"ranged", "healer": return RANGED_PREFER_RANGE
		_: return MELEE_ATTACK_RANGE

# ── Helpers ───────────────────────────────────────────────────────────────────
func _nearest_enemy() -> Character:
	var best: Character = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("characters"):
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

func _has_ground_ahead(direction: float, look_dist: float = 60.0) -> bool:
	if not _parent.is_inside_tree():
		return true
	var space := _parent.get_world_2d().direct_space_state
	var origin := _parent.global_position + Vector2(direction * look_dist, -5.0)
	var target  := origin + Vector2(0.0, 260.0)
	var query   := PhysicsRayQueryParameters2D.create(origin, target)
	query.collision_mask = 1   # layer 1 = StaticBody2D platforms
	query.exclude = [_parent.get_rid()]
	return not space.intersect_ray(query).is_empty()

func _should_recover() -> bool:
	if _parent.is_on_floor():
		return false
	if _parent.velocity.y > 150.0 and _parent.global_position.y > 500.0:
		return true
	if _parent._jumps_remaining == 0 and not _has_ground_ahead(0.0, 0.0):
		return true
	return false
