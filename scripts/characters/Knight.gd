# Knight.gd — Knight archetype (knight_1, knight_2, knight_3)
# Stats: HP 150, Speed 200, Jump -550, Light 12, Heavy 22
# Mechanics: Run+Attack, Attack 3 combo chain, Defend/Protect block states
class_name Knight
extends "res://scripts/characters/Character.gd"

@export var sprites_path: String = "res://assets/characters/warriors/knight_1/sprites/"

var _combo_buffered: bool = false
var _is_run_attacking: bool = false
var _is_attack_3: bool = false
var _protect_timer: float = 0.0

func _ready() -> void:
	max_hp = 150.0
	move_speed = 200.0
	jump_force = -550.0
	attack_damage_light = 12.0
	attack_damage_heavy = 22.0
	knockback_multiplier = 1.0
	sprite.sprite_frames = _build_sprite_frames()
	sprite.position = Vector2(16, -26)
	super._ready()

func _build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	var p := sprites_path
	_add_anim(sf, "idle",         load(p + "Idle.png"),       128, 128, 0, 4, 8.0,  true)
	_add_anim(sf, "run",          load(p + "Run.png"),        128, 128, 0, 7, 12.0, true)
	_add_anim(sf, "jump",         load(p + "Jump.png"),       128, 128, 0, 3, 10.0, false)
	_add_anim(sf, "fall",         load(p + "Jump.png"),       128, 128, 3, 3, 10.0, false)
	_add_anim(sf, "attack_light", load(p + "Attack 1.png"),   128, 128, 0, 5, 16.0, false)
	_add_anim(sf, "attack_heavy", load(p + "Attack 2.png"),   128, 128, 0, 4, 16.0, false)
	_add_anim(sf, "attack_3",     load(p + "Attack 3.png"),   128, 128, 0, 4, 16.0, false)
	_add_anim(sf, "run_attack",   load(p + "Run+Attack.png"), 128, 128, 0, 6, 16.0, false)
	_add_anim(sf, "protect",      load(p + "Protect.png"),    128, 128, 0, 1, 8.0,  false)
	_add_anim(sf, "block",        load(p + "Defend.png"),     128, 128, 0, 5, 8.0,  true)
	_add_anim(sf, "hurt",         load(p + "Hurt.png"),       128, 128, 0, 2, 10.0, false)
	_add_anim(sf, "dead",         load(p + "Dead.png"),       128, 128, 0, 6, 8.0,  false)
	return sf

func _physics_process(delta: float) -> void:
	if _protect_timer > 0.0:
		_protect_timer -= delta
		if _protect_timer <= 0.0 and state == State.BLOCKING:
			_try_play("block")
	# Buffer Attack 3 during active heavy animation
	if state == State.ATTACK_HEAVY and not _is_attack_3:
		if InputManager.is_heavy_attack_pressed(player_id):
			_combo_buffered = true
	super._physics_process(delta)

func attack_light() -> void:
	if _is_locked():
		return
	is_attacking = true
	hitbox_light.monitoring = false
	_is_run_attacking = (state == State.RUN)
	_combo_buffered = false
	change_state(State.ATTACK_LIGHT)
	if _is_run_attacking:
		_try_play("run_attack")
	AudioManager.play_sfx("Sword Attack")

func attack_heavy() -> void:
	if _is_locked():
		return
	is_attacking = true
	hitbox_heavy.monitoring = false
	_is_attack_3 = false
	_combo_buffered = false
	change_state(State.ATTACK_HEAVY)
	AudioManager.play_sfx("Sword Attack")

func special_attack() -> void:
	pass  # Knights are pure melee — no special

func change_state(new_state: State) -> void:
	if new_state == State.BLOCKING and state != State.BLOCKING:
		state = State.BLOCKING
		_protect_timer = 0.12
		_try_play("protect")
	else:
		super.change_state(new_state)

func _on_sprite_frame_changed() -> void:
	var f: int = sprite.frame
	match state:
		State.ATTACK_LIGHT:
			if _is_run_attacking:
				hitbox_light.monitoring = (f >= 1 and f <= 4)
			else:
				hitbox_light.monitoring = (f >= 1 and f <= 3)
		State.ATTACK_HEAVY:
			if _is_attack_3:
				hitbox_heavy.monitoring = (f >= 0 and f <= 2)
			else:
				hitbox_heavy.monitoring = (f >= 1 and f <= 2)
		_:
			super._on_sprite_frame_changed()

func _on_sprite_animation_finished() -> void:
	match state:
		State.ATTACK_HEAVY:
			hitbox_heavy.monitoring = false
			if _combo_buffered and not _is_attack_3:
				_is_attack_3 = true
				_combo_buffered = false
				is_attacking = true
				_try_play("attack_3")
				AudioManager.play_sfx("Sword Attack")
			else:
				_is_attack_3 = false
				is_attacking = false
				_is_run_attacking = false
				change_state(State.IDLE)
		State.ATTACK_LIGHT:
			hitbox_light.monitoring = false
			is_attacking = false
			_is_run_attacking = false
			change_state(State.IDLE)
		_:
			super._on_sprite_animation_finished()
