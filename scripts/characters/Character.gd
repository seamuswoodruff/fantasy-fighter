# Character.gd — Base character class
# Phase 3: full combat — attacks, hitboxes, take_damage, die, respawn, blocking
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
var respawn_position: Vector2 = Vector2(640.0, 300.0)

# ── Physics constants ─────────────────────────────────────────────────────────
const GRAVITY: float = 800.0
const MAX_FALL_SPEED: float = 1000.0
const ACCELERATION: float = 1800.0
const FRICTION: float = 1200.0
const AIR_FRICTION: float = 150.0
const JUMP_COUNT: int = 2
const COYOTE_TIME: float = 6.0 / 60.0

# ── Jump tracking ─────────────────────────────────────────────────────────────
var _jumps_remaining: int = JUMP_COUNT
var _coyote_timer: float = 0.0
var _coyote_expired_this_fall: bool = false

# ── Combat timers ─────────────────────────────────────────────────────────────
var _hitstun_timer: float = 0.0
var _invincibility_timer: float = 0.0

# ── State machine ─────────────────────────────────────────────────────────────
enum State {
	IDLE, RUN, JUMP, FALL,
	ATTACK_LIGHT, ATTACK_HEAVY, SPECIAL,
	HURT, DEAD, BLOCKING, DASHING, WALL_SLIDE
}
var state: State = State.IDLE

# Returns true for states that block normal movement / input transitions
func _is_locked() -> bool:
	return state == State.ATTACK_LIGHT or state == State.ATTACK_HEAVY \
		or state == State.HURT or state == State.DEAD or state == State.SPECIAL

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

	# Connect hitbox signals for dealing damage to enemies
	hitbox_light.area_entered.connect(_on_hitbox_light_area_entered)
	hitbox_heavy.area_entered.connect(_on_hitbox_heavy_area_entered)

	# Connect sprite signals for frame-accurate hitbox activation
	if sprite:
		sprite.frame_changed.connect(_on_sprite_frame_changed)
		sprite.animation_finished.connect(_on_sprite_animation_finished)

	print("[Character] P%d '%s' ready — HP: %.0f  Speed: %.0f" % [
		player_id, character_name, max_hp, move_speed
	])

func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_apply_gravity(delta)
	_update_coyote(delta)
	if _hitstun_timer <= 0.0 and state != State.DEAD:
		handle_input()
	_apply_movement(delta)
	_update_facing()
	move_and_slide()
	_update_state()

# ── Timer ticks ───────────────────────────────────────────────────────────────
func _tick_timers(delta: float) -> void:
	if _hitstun_timer > 0.0:
		_hitstun_timer -= delta
		if _hitstun_timer <= 0.0 and state == State.HURT:
			change_state(State.IDLE)

	if _invincibility_timer > 0.0:
		_invincibility_timer -= delta
		if _invincibility_timer <= 0.0:
			is_invincible = false

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
			if _coyote_timer <= 0.0 and not _coyote_expired_this_fall:
				_coyote_expired_this_fall = true
				_jumps_remaining = mini(_jumps_remaining, JUMP_COUNT - 1)

# ── Input handling ────────────────────────────────────────────────────────────
func handle_input() -> void:
	# Block input is read every frame when not in a locked combat state
	if not _is_locked():
		is_blocking = InputManager.is_block_held(player_id)

	# No attacks/jumps during locked states
	if _is_locked():
		return

	# Jump (allowed even while blocking)
	if InputManager.is_jump_pressed(player_id):
		_try_jump()

	# No attacks/special while blocking
	if is_blocking:
		return

	# Combat inputs (ground or air)
	if InputManager.is_light_attack_pressed(player_id):
		attack_light()
	elif InputManager.is_heavy_attack_pressed(player_id):
		attack_heavy()
	elif InputManager.is_special_pressed(player_id):
		special_attack()

# ── Jump ──────────────────────────────────────────────────────────────────────
func _try_jump() -> void:
	if is_on_floor():
		velocity.y = jump_force
		_jumps_remaining = JUMP_COUNT - 1
		_coyote_timer = 0.0
	elif _coyote_timer > 0.0:
		velocity.y = jump_force
		_jumps_remaining = JUMP_COUNT - 1
		_coyote_timer = 0.0
		_coyote_expired_this_fall = true
	elif _jumps_remaining > 0:
		velocity.y = jump_force * 0.85
		_jumps_remaining -= 1

# ── Horizontal movement ───────────────────────────────────────────────────────
func _apply_movement(delta: float) -> void:
	# Dead characters decelerate only
	if state == State.DEAD:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		return

	# Blocking characters stop in place
	if is_blocking:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		return

	var input_x: float = InputManager.get_move_vector(player_id).x
	if input_x != 0.0:
		velocity.x = move_toward(velocity.x, input_x * move_speed, ACCELERATION * delta)
	else:
		var decel := FRICTION if is_on_floor() else AIR_FRICTION
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)

# ── Facing direction ──────────────────────────────────────────────────────────
func _update_facing() -> void:
	if _is_locked():
		return
	if velocity.x > 10.0:
		_set_facing(true)
	elif velocity.x < -10.0:
		_set_facing(false)

func _set_facing(right: bool) -> void:
	if facing_right == right:
		return
	facing_right = right
	sprite.flip_h = not facing_right
	# Mirror sprite x offset so it stays centred regardless of direction
	var sign_x := 1.0 if facing_right else -1.0
	sprite.position.x = absf(sprite.position.x) * sign_x
	# Mirror hitbox x-positions so attacks always land in front of the character
	var hl := $HitboxLight/HitboxLightShape as CollisionShape2D
	var hh := $HitboxHeavy/HitboxHeavyShape as CollisionShape2D
	hl.position.x = absf(hl.position.x) * sign_x
	hh.position.x = absf(hh.position.x) * sign_x

# ── State machine ─────────────────────────────────────────────────────────────
func _update_state() -> void:
	# These states manage their own transitions
	if _is_locked():
		return

	var new_state: State
	if is_blocking:
		new_state = State.BLOCKING
	elif is_on_floor():
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
		State.IDLE:         _try_play("idle")
		State.RUN:          _try_play("run")
		State.JUMP:         _try_play("jump")
		State.FALL:         _try_play("fall")
		State.ATTACK_LIGHT: _try_play("attack_light")
		State.ATTACK_HEAVY: _try_play("attack_heavy")
		State.SPECIAL:      _try_play("special")
		State.BLOCKING:     _try_play("block")
		State.HURT:         _try_play("hurt")
		State.DEAD:         _try_play("dead")

func _try_play(anim_name: String) -> void:
	if not sprite.sprite_frames:
		return
	if sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)
	else:
		# Fall back to idle if animation missing (shouldn't happen with knight_1)
		if sprite.sprite_frames.has_animation("idle") and sprite.animation != "idle":
			sprite.play("idle")

# ── Sprite signal handlers ────────────────────────────────────────────────────
func _on_sprite_frame_changed() -> void:
	var f: int = sprite.frame
	match state:
		State.ATTACK_LIGHT:
			# Active frames: 1–3 of 5 total (0=startup, 4=recovery)
			hitbox_light.monitoring = (f >= 1 and f <= 3)
		State.ATTACK_HEAVY:
			# Active frames: 1–2 of 4 total (0=startup, 3=recovery)
			hitbox_heavy.monitoring = (f >= 1 and f <= 2)

func _on_sprite_animation_finished() -> void:
	match state:
		State.ATTACK_LIGHT:
			hitbox_light.monitoring = false
			is_attacking = false
			change_state(State.IDLE)
		State.ATTACK_HEAVY:
			hitbox_heavy.monitoring = false
			is_attacking = false
			change_state(State.IDLE)
		State.HURT:
			if _hitstun_timer <= 0.0:
				change_state(State.IDLE)
		State.DEAD:
			pass  # respawn timer handles this

# ── Hitbox → Hurtbox collision ────────────────────────────────────────────────
func _on_hitbox_light_area_entered(area: Area2D) -> void:
	_apply_hit(area, attack_damage_light, false)

func _on_hitbox_heavy_area_entered(area: Area2D) -> void:
	_apply_hit(area, attack_damage_heavy, true)

func _apply_hit(area: Area2D, damage: float, is_heavy: bool) -> void:
	var target = area.get_parent()
	if not (target is Character) or target == self:
		return
	target.take_damage(damage, global_position, is_heavy)
	# Disable hitbox after landing a hit — use set_deferred because we're inside a signal callback
	if is_heavy:
		hitbox_heavy.set_deferred("monitoring", false)
		_trigger_screen_freeze(0.1)
	else:
		hitbox_light.set_deferred("monitoring", false)

# ── Combat ────────────────────────────────────────────────────────────────────
func attack_light() -> void:
	if _is_locked():
		return
	is_attacking = true
	hitbox_light.monitoring = false  # will activate on frame 1 via frame_changed
	change_state(State.ATTACK_LIGHT)

func attack_heavy() -> void:
	if _is_locked():
		return
	is_attacking = true
	hitbox_heavy.monitoring = false
	change_state(State.ATTACK_HEAVY)

func special_attack() -> void:
	pass  # Override in Warrior / Wizard / Samurai

func take_damage(amount: float, attacker_pos: Vector2, is_heavy: bool) -> void:
	if is_invincible or state == State.DEAD:
		return

	# Blocking reduces damage by 60%
	var actual_damage := amount * 0.4 if is_blocking else amount
	current_hp -= actual_damage
	current_hp = maxf(current_hp, 0.0)

	# Apply knockback impulse — fixed values per spec (not Smash-style scaling)
	var direction: float = signf(global_position.x - attacker_pos.x)
	if direction == 0.0:
		direction = 1.0  # default push right if perfectly aligned
	var kb_velocity := Vector2(direction * 350.0, -200.0) if is_heavy \
		else Vector2(direction * 200.0, -120.0)
	velocity = kb_velocity * knockback_multiplier

	print("[Character] P%d took %.0f dmg (%.0f HP left)%s" % [
		player_id, actual_damage, current_hp,
		" [BLOCKED]" if is_blocking else ""
	])

	if current_hp <= 0.0:
		die()
	else:
		# Enter hitstun — timer-driven exit (not animation_finished) to avoid freeze bug
		var hitstun := 1.2 if is_heavy else 0.5
		_hitstun_timer = hitstun
		hitbox_light.monitoring = false
		hitbox_heavy.monitoring = false
		is_attacking = false
		is_blocking = false
		change_state(State.HURT)

func die() -> void:
	if state == State.DEAD:
		return
	hitbox_light.monitoring = false
	hitbox_heavy.monitoring = false
	is_attacking = false
	is_blocking = false
	velocity = Vector2.ZERO
	stocks -= 1
	print("[Character] P%d died — %d stocks remaining" % [player_id, stocks])
	change_state(State.DEAD)
	is_invincible = true
	GameManager.on_player_death(player_id)

	if stocks > 0:
		# Disable physics + hide while waiting to respawn
		process_mode = Node.PROCESS_MODE_DISABLED
		hide()
		get_tree().create_timer(1.5, true).timeout.connect(respawn)

func respawn() -> void:
	if stocks <= 0:
		return
	# Re-enable before moving so the character appears at the correct spawn point
	process_mode = Node.PROCESS_MODE_INHERIT
	show()
	global_position = respawn_position
	current_hp = max_hp
	velocity = Vector2.ZERO
	_invincibility_timer = 2.0
	is_invincible = true
	change_state(State.IDLE)
	print("[Character] P%d respawned at %v — %.0f HP, 2s i-frames" % [
		player_id, respawn_position, max_hp
	])

# ── Screen freeze ─────────────────────────────────────────────────────────────
func _trigger_screen_freeze(duration: float) -> void:
	Engine.time_scale = 0.0
	# ignore_time_scale=true so the timer fires even while time is frozen
	get_tree().create_timer(duration, true, false, true).timeout.connect(
		func() -> void: Engine.time_scale = 1.0
	)
