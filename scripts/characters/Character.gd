# Character.gd — Base character class
# Phase 2: movement, gravity, coyote time, double jump, state machine (IDLE/RUN/JUMP/FALL)
# Phase 3+: combat methods are stubs, filled in by subclasses.
class_name Character
extends CharacterBody2D

# ── Exported stats (override per archetype subclass) ──────────────────────────
@export var player_id: int = 1
@export var character_name: String = "Character"
@export var max_hp: float = 120.0
@export var move_speed: float = 220.0
@export var jump_force: float = -550.0
@export var attack_damage_light: float = 10.0
@export var attack_damage_heavy: float = 18.0
@export var knockback_multiplier: float = 1.0

# ── Runtime state ─────────────────────────────────────────────────────────────
var current_hp: float
var stocks: int = 3
var is_blocking: bool = false
var is_attacking: bool = false
var facing_right: bool = true
var is_invincible: bool = false

# ── Physics constants ─────────────────────────────────────────────────────────
const GRAVITY: float = 800.0          # px/s²
const MAX_FALL_SPEED: float = 1000.0  # terminal velocity px/s
const ACCELERATION: float = 1800.0   # px/s² when input held
const FRICTION: float = 1200.0       # px/s² on ground with no input
const AIR_FRICTION: float = 150.0    # px/s² in air with no input
const JUMP_COUNT: int = 2            # 1 normal + 1 double jump
const COYOTE_TIME: float = 6.0 / 60.0  # 6 frames at 60 fps

# ── Jump tracking ─────────────────────────────────────────────────────────────
var _jumps_remaining: int = JUMP_COUNT
var _coyote_timer: float = 0.0
var _coyote_expired_this_fall: bool = false

# ── State machine ─────────────────────────────────────────────────────────────
enum State {
	IDLE, RUN, JUMP, FALL,
	ATTACK_LIGHT, ATTACK_HEAVY, SPECIAL,
	HURT, DEAD, BLOCKING, DASHING, WALL_SLIDE
}
var state: State = State.IDLE

# ── Node references ───────────────────────────────────────────────────────────
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox_light: Area2D = $HitboxLight
@onready var hitbox_heavy: Area2D = $HitboxHeavy
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	current_hp = max_hp
	hitbox_light.monitoring = false
	hitbox_heavy.monitoring = false
	print("[Character] P%d '%s' ready — HP: %.0f  Speed: %.0f  Jump: %.0f" % [
		player_id, character_name, max_hp, move_speed, jump_force
	])

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_update_coyote(delta)
	handle_input()
	_apply_movement(delta)
	_update_facing()
	move_and_slide()
	_update_state()

# ── Gravity ───────────────────────────────────────────────────────────────────
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)

# ── Coyote time & jump-count reset ────────────────────────────────────────────
func _update_coyote(delta: float) -> void:
	if is_on_floor():
		_jumps_remaining = JUMP_COUNT
		_coyote_timer = COYOTE_TIME
		_coyote_expired_this_fall = false
	else:
		if _coyote_timer > 0.0:
			_coyote_timer -= delta
			# Coyote window just closed — burn the floor-jump slot so
			# the player can't land and get 2 air jumps.
			if _coyote_timer <= 0.0 and not _coyote_expired_this_fall:
				_coyote_expired_this_fall = true
				_jumps_remaining = mini(_jumps_remaining, JUMP_COUNT - 1)

# ── Input (override or extend in subclasses for combat) ───────────────────────
func handle_input() -> void:
	if InputManager.is_jump_pressed(player_id):
		_try_jump()

# ── Jump ──────────────────────────────────────────────────────────────────────
func _try_jump() -> void:
	if is_on_floor():
		# Normal floor jump
		velocity.y = jump_force
		_jumps_remaining = JUMP_COUNT - 1
		_coyote_timer = 0.0
	elif _coyote_timer > 0.0:
		# Coyote jump — player just walked off the edge, still allowed
		velocity.y = jump_force
		_jumps_remaining = JUMP_COUNT - 1
		_coyote_timer = 0.0
		_coyote_expired_this_fall = true
	elif _jumps_remaining > 0:
		# Double jump (or any remaining air jump)
		velocity.y = jump_force * 0.85
		_jumps_remaining -= 1

# ── Horizontal movement ───────────────────────────────────────────────────────
func _apply_movement(delta: float) -> void:
	var input_x: float = InputManager.get_move_vector(player_id).x
	if input_x != 0.0:
		velocity.x = move_toward(velocity.x, input_x * move_speed, ACCELERATION * delta)
	else:
		var decel := FRICTION if is_on_floor() else AIR_FRICTION
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)

# ── Facing direction ──────────────────────────────────────────────────────────
func _update_facing() -> void:
	if velocity.x > 10.0:
		facing_right = true
		scale.x = absf(scale.x)
	elif velocity.x < -10.0:
		facing_right = false
		scale.x = -absf(scale.x)

# ── State machine ─────────────────────────────────────────────────────────────
func _update_state() -> void:
	var new_state: State
	if is_on_floor():
		new_state = State.RUN if absf(velocity.x) > 10.0 else State.IDLE
	else:
		new_state = State.JUMP if velocity.y < 0.0 else State.FALL

	if new_state != state:
		change_state(new_state)

func change_state(new_state: State) -> void:
	state = new_state
	_play_animation_for_state()

func _play_animation_for_state() -> void:
	if not sprite or not sprite.sprite_frames:
		return
	match state:
		State.IDLE: _try_play("idle")
		State.RUN:  _try_play("run")
		State.JUMP: _try_play("jump")
		State.FALL: _try_play("fall")

func _try_play(anim_name: String) -> void:
	if sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)

# ── Combat stubs — implemented by Warrior / Wizard / Samurai in Phase 3+ ──────
func take_damage(_amount: float, _knockback_dir: Vector2, _is_heavy: bool) -> void:
	pass

func die() -> void:
	pass

func respawn() -> void:
	pass

func attack_light() -> void:
	pass

func attack_heavy() -> void:
	pass

func special_attack() -> void:
	pass
