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
var spawn_facing_right: bool = true  # restored on every respawn
var is_invincible: bool = false
var is_cpu: bool = false
# CPU virtual input (set by CPUController each frame when is_cpu = true)
var cpu_move_x: float = 0.0
var cpu_wants_jump: bool = false
var respawn_position: Vector2 = Vector2(640.0, 300.0)
var _fast_falling: bool = false
var _short_hop_timer: float = 0.0
var _light_hit_connected: bool = false
var _heavy_hit_connected: bool = false
var _attack_recovery_timer: float = 0.0

# ── Physics constants ─────────────────────────────────────────────────────────
const GRAVITY: float = 800.0
const MAX_FALL_SPEED: float = 1000.0
const ACCELERATION: float = 1800.0
const FRICTION: float = 1200.0
const AIR_FRICTION: float = 150.0
const JUMP_COUNT: int = 2
const COYOTE_TIME: float = 6.0 / 60.0
const SHORT_HOP_WINDOW: float = 5.0 / 60.0
const SHORT_HOP_MULTIPLIER: float = 0.55
const FOOTSTEP_BASE_INTERVAL: float = 0.32
const COMBO_RESET_TIME: float = 1.5   # seconds without being hit before combo count resets
const LIGHT_ATTACK_RECOVERY: float = 0.10   # 6 frames post-attack lockout
const HEAVY_ATTACK_RECOVERY: float = 0.20   # 12 frames post-attack lockout
const SPECIAL_ATTACK_RECOVERY: float = 0.15 # used by subclasses

# ── Jump tracking ─────────────────────────────────────────────────────────────
var _jumps_remaining: int = JUMP_COUNT
var _coyote_timer: float = 0.0
var _coyote_expired_this_fall: bool = false

# ── Combat timers ─────────────────────────────────────────────────────────────
var _hitstun_timer: float = 0.0
var _invincibility_timer: float = 0.0
var _kill_zone_grace: float = 0.0   # brief window after respawn to prevent physics-refire
var _shadow_floor_y: float = 0.0
var _shield_damage: float = 0.0     # cumulative raw damage absorbed in current block session
var _combo_hit_count: int = 0
var _combo_reset_timer: float = 0.0

# ── State machine ─────────────────────────────────────────────────────────────
enum State {
	IDLE, RUN, JUMP, FALL,
	ATTACK_LIGHT, ATTACK_HEAVY, SPECIAL,
	HURT, DEAD, BLOCKING, DASHING, WALL_SLIDE
}
var state: State = State.IDLE

enum BufferedInput { NONE, LIGHT, HEAVY, SPECIAL, SPECIAL2 }
const INPUT_BUFFER_WINDOW: float = 10.0 / 60.0

var _buffered_input: BufferedInput = BufferedInput.NONE
var _buffer_timer: float = 0.0
var _footstep_timer: float = 0.0

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
@onready var _shadow: Sprite2D = $Shadow

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("characters")
	current_hp = max_hp
	hitbox_light.monitoring = false
	hitbox_heavy.monitoring = false

	# ── Slope behaviour ───────────────────────────────────────────────────────
	# Snap length keeps the character glued to the floor when stepping from a
	# flat surface onto a downward slope (prevents the brief airborne gap).
	floor_snap_length = 12.0
	# Don't treat the bottom edge of a slope as a wall — removes the invisible
	# barrier that stalls horizontal movement when walking onto a slope.
	floor_block_on_wall = false
	# Let the engine prevent gravity-driven sliding on slopes; we reinforce
	# this in _apply_movement() with an explicit zero-clamp.
	floor_stop_on_slope = true
	# Raise the floor angle threshold to 50° so the Desert Temple slopes
	# (~46°) are recognised as walkable floors, not walls.
	floor_max_angle = deg_to_rad(50.0)

	# Connect hitbox signals for dealing damage to enemies
	hitbox_light.area_entered.connect(_on_hitbox_light_area_entered)
	hitbox_heavy.area_entered.connect(_on_hitbox_heavy_area_entered)

	# Connect sprite signals for frame-accurate hitbox activation
	if sprite:
		sprite.frame_changed.connect(_on_sprite_frame_changed)
		sprite.animation_finished.connect(_on_sprite_animation_finished)

	_setup_blob_shadow()

	print("[Character] P%d '%s' ready — HP: %.0f  Speed: %.0f" % [
		player_id, character_name, max_hp, move_speed
	])

func _setup_blob_shadow() -> void:
	if _shadow == null:
		return
	var w := 64
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx := w / 2.0
	var cy := h / 2.0
	for y in h:
		for x in w:
			var dx := (x - cx) / (w / 2.0)
			var dy := (y - cy) / (h / 2.0)
			var dist := sqrt(dx * dx + dy * dy)
			var alpha: float = clamp(1.0 - dist, 0.0, 1.0)
			alpha = alpha * alpha  # softer falloff
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha))
	_shadow.texture = ImageTexture.create_from_image(img)

func _get_floor_y_below() -> float:
	# Raycast straight down from feet to find the highest ground directly below.
	# Uses layer 1 (World / StaticBody2D platforms) only.
	var space := get_world_2d().direct_space_state
	var feet  := global_position + Vector2(0.0, 32.0)
	var query := PhysicsRayQueryParameters2D.create(feet, feet + Vector2(0.0, 2000.0), 1)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit:
		return (hit["position"] as Vector2).y
	return -1.0  # no ground below (fell off stage)

func _update_shadow() -> void:
	if _shadow == null:
		return
	var floor_y := _get_floor_y_below()
	if floor_y < 0.0:
		# Nothing below — hide shadow (character is off the stage)
		_shadow.visible = false
		return
	_shadow.visible = (state != State.DEAD)
	_shadow_floor_y = floor_y
	_shadow.global_position = Vector2(global_position.x, floor_y)
	# Scale down as character rises above the floor
	var height_above: float = maxf(0.0, floor_y - (global_position.y + 32.0))
	var s: float = clampf(1.0 - height_above / 220.0, 0.25, 1.0)
	_shadow.scale = Vector2(s, 0.4 * s)

func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_apply_gravity(delta)
	_update_coyote(delta)
	if state != State.DEAD:
		handle_input()
	_apply_movement(delta)
	_update_facing()
	_tick_footsteps(delta)
	move_and_slide()
	_update_shadow()
	# Only fire dust when transitioning from an actual airborne state — guards against
	# floor-detection flickering on TileMap tile edges triggering dust every frame.
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

	if _kill_zone_grace > 0.0:
		_kill_zone_grace -= delta

	# Short hop — cap upward velocity if jump is released early
	if _short_hop_timer > 0.0:
		_short_hop_timer -= delta
		if not InputManager.is_jump_held(player_id) and velocity.y < 0.0:
			velocity.y = maxf(velocity.y, jump_force * SHORT_HOP_MULTIPLIER)
			_short_hop_timer = 0.0

	# Input buffer — expire after window
	if _buffer_timer > 0.0:
		_buffer_timer -= delta
		if _buffer_timer <= 0.0:
			_buffered_input = BufferedInput.NONE

	# Combo DR reset timer
	if _combo_reset_timer > 0.0:
		_combo_reset_timer -= delta
		if _combo_reset_timer <= 0.0:
			_combo_hit_count = 0

	# Attack recovery timer — just blocks new attacks until it expires
	if _attack_recovery_timer > 0.0:
		_attack_recovery_timer -= delta

	# I-frame flicker — 6 blinks per second while invincible
	if is_invincible and _invincibility_timer > 0.0:
		sprite.visible = (int(_invincibility_timer * 12.0) % 2 == 0)
	elif sprite and not sprite.visible:
		sprite.visible = true

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
		_fast_falling = false
		_combo_hit_count = 0
		_combo_reset_timer = 0.0
	else:
		if _coyote_timer > 0.0:
			_coyote_timer -= delta
			if _coyote_timer <= 0.0 and not _coyote_expired_this_fall:
				_coyote_expired_this_fall = true
				_jumps_remaining = mini(_jumps_remaining, JUMP_COUNT - 1)

# ── Input handling ────────────────────────────────────────────────────────────
func handle_input() -> void:
	if is_cpu:
		# CPUController sets velocity and calls attack methods directly —
		# we only need to handle the virtual jump here
		if cpu_wants_jump:
			_try_jump()
			cpu_wants_jump = false
		# Apply cpu_move_x to horizontal velocity
		if cpu_move_x != 0.0:
			velocity.x = move_toward(velocity.x, cpu_move_x * move_speed, ACCELERATION * get_process_delta_time())
		else:
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * get_process_delta_time())
		return   # skip all real input handling

	# Mash escape — any attack or jump press during hitstun cuts ~2 frames off the timer.
	# Intentionally before all guards so it fires during HURT state.
	if _hitstun_timer > 0.0:
		if InputManager.is_light_attack_pressed(player_id) \
		or InputManager.is_heavy_attack_pressed(player_id) \
		or InputManager.is_jump_pressed(player_id):
			_hitstun_timer = maxf(0.0, _hitstun_timer - 0.033)

	# Capture bufferable inputs regardless of lock state
	if InputManager.is_light_attack_pressed(player_id):
		_buffered_input = BufferedInput.LIGHT
		_buffer_timer = INPUT_BUFFER_WINDOW
	elif InputManager.is_heavy_attack_pressed(player_id):
		_buffered_input = BufferedInput.HEAVY
		_buffer_timer = INPUT_BUFFER_WINDOW
	elif InputManager.is_special_pressed(player_id):
		_buffered_input = BufferedInput.SPECIAL
		_buffer_timer = INPUT_BUFFER_WINDOW
	elif InputManager.is_special2_pressed(player_id):
		_buffered_input = BufferedInput.SPECIAL2
		_buffer_timer = INPUT_BUFFER_WINDOW

	# Block input is read every frame when not in a locked combat state
	if not _is_locked():
		var was_blocking := is_blocking
		is_blocking = _read_block_input()
		# Voluntary block release resets the shield damage counter
		if was_blocking and not is_blocking:
			_shield_damage = 0.0

	# No attacks/jumps during locked states
	if _is_locked():
		return

	# Jump (allowed even while blocking)
	if InputManager.is_jump_pressed(player_id):
		_try_jump()

	# No attacks/special while blocking
	if is_blocking:
		return

	# Recovery lockout — blocks new attacks but allows movement and jumping above
	if _attack_recovery_timer > 0.0:
		return

	# Combat inputs (ground or air)
	if InputManager.is_light_attack_pressed(player_id):
		attack_light()
	elif InputManager.is_heavy_attack_pressed(player_id):
		attack_heavy()
	elif InputManager.is_special_pressed(player_id):
		special_attack()
	elif InputManager.is_special2_pressed(player_id):
		special2_attack()

	# Fast fall — only triggers once per airborne phase, only on the way down
	if not is_on_floor() and not _fast_falling and velocity.y > 0.0:
		if InputManager.is_moving_down(player_id):
			_fast_falling = true
			velocity.y = MAX_FALL_SPEED * 0.8

# ── Jump ──────────────────────────────────────────────────────────────────────
func _try_jump() -> void:
	if is_on_floor():
		velocity.y = jump_force
		_jumps_remaining = JUMP_COUNT - 1
		_coyote_timer = 0.0
		_short_hop_timer = SHORT_HOP_WINDOW
	elif _coyote_timer > 0.0:
		velocity.y = jump_force
		_jumps_remaining = JUMP_COUNT - 1
		_coyote_timer = 0.0
		_coyote_expired_this_fall = true
		_short_hop_timer = SHORT_HOP_WINDOW
	elif _jumps_remaining > 0:
		velocity.y = jump_force * 0.85
		_jumps_remaining -= 1
		_short_hop_timer = SHORT_HOP_WINDOW

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
		# Hard-clamp to zero when nearly stopped on the floor so slope gravity
		# can't accumulate into a visible slide.
		if is_on_floor() and absf(velocity.x) < 8.0:
			velocity.x = 0.0

# ── Facing direction ──────────────────────────────────────────────────────────
func _update_facing() -> void:
	if _is_locked() or is_blocking:
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
			# Active frames: 1–3 of 5 total — blocked after first hit connects
			hitbox_light.monitoring = (f >= 1 and f <= 3) and not _light_hit_connected
		State.ATTACK_HEAVY:
			# Active frames: 1–2 of 4 total — blocked after first hit connects
			hitbox_heavy.monitoring = (f >= 1 and f <= 2) and not _heavy_hit_connected

func _on_sprite_animation_finished() -> void:
	match state:
		State.ATTACK_LIGHT:
			hitbox_light.monitoring = false
			is_attacking = false
			_light_hit_connected = false
			change_state(State.IDLE)
			_attack_recovery_timer = LIGHT_ATTACK_RECOVERY
		State.ATTACK_HEAVY:
			hitbox_heavy.monitoring = false
			is_attacking = false
			_heavy_hit_connected = false
			change_state(State.IDLE)
			_attack_recovery_timer = HEAVY_ATTACK_RECOVERY
		State.HURT:
			if _hitstun_timer <= 0.0:
				change_state(State.IDLE)
				_flush_input_buffer()
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
	var actual := damage * 0.2 if target.is_blocking else damage
	target.take_damage(damage, global_position, is_heavy)

	# Mark this swing as having connected — prevents re-hit via _on_sprite_frame_changed
	if is_heavy:
		_heavy_hit_connected = true
		hitbox_heavy.set_deferred("monitoring", false)
		_trigger_screen_freeze(0.1)
	else:
		_light_hit_connected = true
		hitbox_light.set_deferred("monitoring", false)

	# Subtle recoil — nudges attacker back slightly so they must re-approach.
	var recoil_dir := signf(global_position.x - target.global_position.x)
	velocity.x += recoil_dir * (28.0 if is_heavy else 16.0)

	_spawn_damage_number(area.global_position, actual)
	VFXManager.play_single("hit_sparks", area.global_position, 2.0, 0.12, 618)
	AudioManager.play_sfx("Sword Impact Hit")

# ── Combat ────────────────────────────────────────────────────────────────────
func attack_light() -> void:
	if _is_locked():
		return
	_light_hit_connected = false
	is_attacking = true
	hitbox_light.monitoring = false  # will activate on frame 1 via frame_changed
	change_state(State.ATTACK_LIGHT)
	AudioManager.play_sfx("Sword Attack")

func attack_heavy() -> void:
	if _is_locked():
		return
	_heavy_hit_connected = false
	is_attacking = true
	hitbox_heavy.monitoring = false
	change_state(State.ATTACK_HEAVY)
	AudioManager.play_sfx("Sword Attack")

func special_attack() -> void:
	pass  # Override in subclasses

func special2_attack() -> void:
	pass  # Override in subclasses that have two specials

# Override in subclasses to change which input triggers blocking
func _read_block_input() -> bool:
	return InputManager.is_block_held(player_id)

func take_damage(amount: float, attacker_pos: Vector2, is_heavy: bool) -> void:
	if is_invincible or state == State.DEAD:
		return

	# Blocking reduces damage by 80%; knockback is also cut to 25%
	var blocked := is_blocking
	var actual_damage := amount * 0.2 if blocked else amount
	current_hp -= actual_damage
	# Snap sub-1 HP to exactly 0 so the bar fully empties on the killing hit
	if current_hp < 1.0:
		current_hp = 0.0

	# Apply knockback impulse — fixed values per spec (not Smash-style scaling)
	var direction: float = signf(global_position.x - attacker_pos.x)
	if direction == 0.0:
		direction = 1.0  # default push right if perfectly aligned
	var kb_velocity := Vector2(direction * 350.0, -200.0) if is_heavy \
		else Vector2(direction * 200.0, -120.0)

	# Directional Influence — rotate knockback up to 15° based on held direction
	var di_input := InputManager.get_move_vector(player_id)
	if di_input.length() > 0.3:
		var kb_norm := kb_velocity.normalized()
		var perp := Vector2(-kb_norm.y, kb_norm.x)
		var perp_dot := di_input.normalized().dot(perp) * di_input.length()
		var rotation_rad := perp_dot * deg_to_rad(15.0)
		kb_velocity = kb_velocity.rotated(rotation_rad)

	var kb_scale := 0.25 if blocked else 1.0
	velocity = kb_velocity * knockback_multiplier * kb_scale

	print("[Character] P%d took %.0f dmg (%.0f HP left)%s" % [
		player_id, actual_damage, current_hp,
		" [BLOCKED]" if blocked else ""
	])

	if current_hp <= 0.0:
		die()
	elif blocked:
		_shield_damage += amount  # accumulate raw damage for this block session
		if _shield_damage >= 100.0:
			# Shield break — too much damage absorbed, knocked out into brief hitstun
			var total := _shield_damage
			_shield_damage = 0.0
			is_blocking = false
			_hitstun_timer = 0.3
			hitbox_light.monitoring = false
			hitbox_heavy.monitoring = false
			is_attacking = false
			change_state(State.HURT)
			print("[Character] P%d shield broken! (%.0f cumulative raw dmg)" % [player_id, total])
		else:
			# Normal block — short stagger, no hitstun, stay in BLOCKING
			AudioManager.play_sfx("Sword Impact Hit")
			velocity.y = minf(velocity.y, 0.0)  # no upward pop on block
	else:
		# Enter hitstun — timer-driven exit (not animation_finished) to avoid freeze bug
		_combo_hit_count += 1
		_combo_reset_timer = COMBO_RESET_TIME
		# Diminishing returns: each successive hit reduces stun by 18%, floored at 35% of base.
		# Hit 1=100%, hit 2=82%, hit 3=64%, hit 4=46%, hit 5+=35%.
		var dr_scale := maxf(0.35, 1.0 - float(_combo_hit_count - 1) * 0.18)
		var hitstun := (0.35 if is_heavy else 0.18) * dr_scale
		_hitstun_timer = maxf(_hitstun_timer, hitstun)
		hitbox_light.monitoring = false
		hitbox_heavy.monitoring = false
		is_attacking = false
		is_blocking = false
		_light_hit_connected = false
		_heavy_hit_connected = false
		change_state(State.HURT)

func die() -> void:
	if state == State.DEAD:
		return
	# Set DEAD immediately — prevents a second kill-zone body_entered (fired in the
	# same physics frame before either callback runs) from also calling die().
	change_state(State.DEAD)
	hitbox_light.monitoring = false
	hitbox_heavy.monitoring = false
	is_attacking = false
	is_blocking = false
	velocity = Vector2.ZERO
	stocks -= 1
	print("[Character] P%d died — %d stocks remaining" % [player_id, stocks])
	is_invincible = true
	GameManager.on_player_death(player_id)
	VFXManager.play("ko", global_position, 2.0, 19)

	if stocks > 0:
		# Let the death animation play (~0.7s), then move to respawn position
		# before disabling physics — this prevents the body from sitting inside
		# a kill zone while frozen, which would re-fire body_entered on re-enable.
		get_tree().create_timer(0.7, true).timeout.connect(func() -> void:
			if state == State.DEAD:
				global_position = respawn_position
				process_mode = Node.PROCESS_MODE_DISABLED
				hide()
		)
		get_tree().create_timer(1.5, true).timeout.connect(respawn)
	else:
		# Eliminated — hide and permanently disable after death animation
		get_tree().create_timer(0.7, true).timeout.connect(func() -> void:
			hide()
			process_mode = Node.PROCESS_MODE_DISABLED
		)

func respawn() -> void:
	if stocks <= 0:
		return
	# Set position BEFORE re-enabling physics so body_entered doesn't refire
	# for whatever kill zone the body was parked inside while disabled.
	global_position = respawn_position + Vector2(0.0, -80.0)
	modulate.a = 0.0
	show()
	process_mode = Node.PROCESS_MODE_INHERIT
	current_hp = max_hp
	velocity = Vector2.ZERO
	_invincibility_timer = 2.0
	is_invincible = true
	_kill_zone_grace = 0.15
	_set_facing(spawn_facing_right)
	change_state(State.IDLE)
	# Drop in and fade in simultaneously
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", respawn_position, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "modulate:a", 1.0, 0.6)
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

# ── Sprite frame builder (shared by all character subclasses) ─────────────────
func _add_anim(sf: SpriteFrames, anim_name: String, tex: Texture2D,
		frame_w: int, frame_h: int, start: int, count: int,
		fps: float, loop: bool) -> void:
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, loop)
	for i in range(start, start + count):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		sf.add_frame(anim_name, at)

func _frames(path: String, frame_size: int) -> int:
	return int(load(path).get_width() / float(frame_size))

# For PNGs without .import sidecars — used by ninja characters
func _frames_raw(path: String, frame_size: int) -> int:
	var tex := _load_raw_texture(path)
	if tex == null:
		return 1
	return int(tex.get_width() / float(frame_size))

# Loads a PNG that has no .import file (bypasses Godot's importer).
# Calculates hframes for a projectile texture.
# Tries the sheet height as the frame size (square frames).
# If the width isn't evenly divisible by height, falls back to 64px frames.
func _calc_hframes(tex: Texture2D) -> int:
	var w := tex.get_width()
	var h := tex.get_height()
	if w % h == 0:
		return int(w / float(h))
	return int(w / float(64))

func _load_raw_texture(res_path: String) -> ImageTexture:
	var img := Image.new()
	var err := img.load(ProjectSettings.globalize_path(res_path))
	if err != OK:
		push_error("[Character] _load_raw_texture failed for: " + res_path + " (err %d)" % err)
		return null
	return ImageTexture.create_from_image(img)

func _flush_input_buffer() -> void:
	if _buffered_input == BufferedInput.NONE or _buffer_timer <= 0.0:
		_buffered_input = BufferedInput.NONE
		return
	var inp := _buffered_input
	_buffered_input = BufferedInput.NONE
	_buffer_timer = 0.0
	match inp:
		BufferedInput.LIGHT:    attack_light()
		BufferedInput.HEAVY:    attack_heavy()
		BufferedInput.SPECIAL:  special_attack()
		BufferedInput.SPECIAL2: special2_attack()

func _spawn_damage_number(pos: Vector2, amount: float) -> void:
	var label := Label.new()
	label.text = "-%d" % int(amount)
	var font: Font = load("res://assets/ui/fonts/alagard.ttf")
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 3)
	label.z_index = 10
	get_tree().root.add_child(label)
	label.global_position = pos + Vector2(randf_range(-15.0, 15.0), -50.0)
	var tween := label.create_tween()
	tween.tween_property(label, "global_position",
		label.global_position + Vector2(randf_range(-10.0, 10.0), -55.0), 0.75)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.75)
	tween.tween_callback(label.queue_free)

func _tick_footsteps(delta: float) -> void:
	if state != State.RUN or not is_on_floor():
		_footstep_timer = 0.0
		return
	_footstep_timer -= delta
	if _footstep_timer <= 0.0:
		var speed_ratio := move_speed / 200.0
		_footstep_timer = FOOTSTEP_BASE_INTERVAL / speed_ratio
		AudioManager.play_sfx("Stone Run")

func _apply_extra_hitstun(extra: float) -> void:
	_hitstun_timer = maxf(_hitstun_timer, extra)
