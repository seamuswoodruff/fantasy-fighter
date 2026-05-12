# Samurai.gd — Samurai archetype (samurai, samurai_commander)
# Stats: HP 120, Speed 260, Jump -580, Light 10, Heavy 18
# Special: Attack_3 — dash 80px forward, up to 3 hits for 6 damage each
# Block: Protection.png (samurai) or Protect.png (samurai_commander), auto-detected
class_name Samurai
extends "res://scripts/characters/Character.gd"

@export var sprites_path: String = "res://assets/characters/samurai/samurai/sprites/"

const SPECIAL_DAMAGE: float = 8.0
const SPECIAL_MAX_HITS: int = 3
const SPECIAL_DASH_SPEED: float = 300.0
const SPECIAL_DURATION: float = 0.30
const LIGHT_RECOVERY: float = 0.10
const SPECIAL_RECOVERY: float = 0.12

var _special_timer: float = 0.0
var _special_hits: int = 0
var _is_special_active: bool = false
var _dash_dir: float = 1.0
var _recovery_timer: float = 0.0
var _block_frame_locked: bool = false  # true while frozen on frame 1 mid-block
var _block_exit_pending: bool = false  # true for one frame after block released

func _ready() -> void:
	max_hp = 130.0
	move_speed = 240.0
	jump_force = -500.0
	attack_damage_light = 10.0
	attack_damage_heavy = 18.0
	knockback_multiplier = 1.0
	jump_count = 3
	sprite.sprite_frames = _build_sprite_frames()
	sprite.position = Vector2(0, -26)
	super._ready()

func _build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	var p := sprites_path
	var block_file := "Protect.png" if FileAccess.file_exists(p + "Protect.png") else "Protection.png"
	var jump_total := _frames(p + "Jump.png", 128)
	var jump_half := int(jump_total / float(2))

	_add_anim(sf, "idle",         load(p + "Idle.png"),      128, 128, 0,         _frames(p + "Idle.png", 128), 8.0,  true)
	_add_anim(sf, "run",          load(p + "Run.png"),       128, 128, 0,         _frames(p + "Run.png", 128),  12.0, true)
	_add_anim(sf, "jump",         load(p + "Jump.png"),      128, 128, 0,         jump_half,                    10.0, false)
	_add_anim(sf, "fall",         load(p + "Jump.png"),      128, 128, jump_half, jump_total - jump_half,       10.0, false)
	_add_anim(sf, "attack_light", load(p + "Attack_1.png"),  128, 128, 0, 4, 16.0, false)
	_add_anim(sf, "attack_heavy", load(p + "Attack_2.png"),  128, 128, 0, 5, 16.0, false)
	_add_anim(sf, "special",      load(p + "Attack_3.png"),  128, 128, 0, 4, 16.0, false)
	_add_anim(sf, "block",        load(p + block_file),      128, 128, 0, 2, 8.0, false)
	_add_anim(sf, "hurt",         load(p + "Hurt.png"),      128, 128, 0, _frames(p + "Hurt.png", 128), 10.0, false)
	_add_anim(sf, "dead",         load(p + "Dead.png"),      128, 128, 0, 6, 8.0,  false)
	return sf

func _is_locked() -> bool:
	return super._is_locked() or _recovery_timer > 0.0

func _play_animation_for_state() -> void:
	if state == State.BLOCKING:
		if not _block_frame_locked:
			_try_play("block")
		# else: stay frozen on frame 1 — don't touch the sprite
	else:
		super._play_animation_for_state()

func change_state(new_state: State) -> void:
	if state == State.BLOCKING and new_state != State.BLOCKING:
		_block_frame_locked = false
		_block_exit_pending = false
		state = new_state
		sprite.stop()
		sprite.frame = 0
		_block_exit_pending = true  # play correct anim next frame so frame 0 renders first
		return
	if new_state == State.BLOCKING:
		_block_frame_locked = false  # reset so entry animation plays fresh
		_block_exit_pending = false
	super.change_state(new_state)

func _physics_process(delta: float) -> void:
	if _block_exit_pending:
		_block_exit_pending = false
		_play_animation_for_state()
	if _recovery_timer > 0.0:
		_recovery_timer -= delta
	if _is_special_active:
		_special_timer -= delta
		velocity.x = _dash_dir * SPECIAL_DASH_SPEED
		if _special_timer <= 0.0:
			_is_special_active = false
	super._physics_process(delta)

func special_attack() -> void:
	if _is_locked():
		return
	_special_hits = 0
	_is_special_active = true
	_special_timer = SPECIAL_DURATION
	_dash_dir = 1.0 if facing_right else -1.0
	is_attacking = true
	hitbox_light.monitoring = false
	change_state(State.SPECIAL)
	AudioManager.play_sfx("Sword Attack")

func _on_sprite_frame_changed() -> void:
	if state == State.SPECIAL:
		# Attack_3: 4 frames, active on 1-3
		hitbox_light.monitoring = (sprite.frame >= 1 and sprite.frame <= 3)
	else:
		super._on_sprite_frame_changed()

func _on_sprite_animation_finished() -> void:
	match state:
		State.BLOCKING:
			# Entry animation (frames 0→1) finished — freeze on frame 1 while held
			sprite.stop()
			sprite.frame = 1
			_block_frame_locked = true
		State.SPECIAL:
			hitbox_light.monitoring = false
			_is_special_active = false
			is_attacking = false
			_recovery_timer = SPECIAL_RECOVERY
			change_state(State.IDLE)
			_attack_recovery_timer = SPECIAL_ATTACK_RECOVERY
		State.ATTACK_LIGHT:
			hitbox_light.monitoring = false
			is_attacking = false
			_recovery_timer = LIGHT_RECOVERY
			change_state(State.IDLE)
			_attack_recovery_timer = LIGHT_ATTACK_RECOVERY
		_:
			super._on_sprite_animation_finished()

func _read_block_input() -> bool:
	return InputManager.is_special2_held(player_id)

func _on_hitbox_light_area_entered(area: Area2D) -> void:
	if state == State.SPECIAL:
		if _special_hits >= SPECIAL_MAX_HITS:
			return
		var target = area.get_parent()
		if not (target is Character) or target == self:
			return
		_special_hits += 1
		var actual := SPECIAL_DAMAGE * 0.2 if target.is_blocking else SPECIAL_DAMAGE
		target.take_damage(SPECIAL_DAMAGE, global_position, false)
		_spawn_damage_number(area.global_position, actual)
		AudioManager.play_sfx("Sword Impact Hit")
	else:
		super._on_hitbox_light_area_entered(area)
