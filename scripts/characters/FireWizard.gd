# FireWizard.gd — Fire Wizard (fire_wizard only)
# Stats: HP 100, Speed 220, Jump -600, Light 8, Heavy 14
# Special: press to start Charge, release to fire:
#   < 0.5s hold → Fireball projectile (450px/s, 18 dmg, 900px range)
#   ≥ 0.5s hold → Flame_jet sustained AOE (1s, 8 dmg per 0.2s tick)
class_name FireWizard
extends "res://scripts/characters/Character.gd"

@export var sprites_path: String = "res://assets/characters/wizards/fire_wizard/sprites/"

const FIREBALL_SPEED: float = 450.0
const FIREBALL_DAMAGE: float = 18.0
const FIREBALL_RANGE: float = 900.0
const FLAMEJET_TICK_DAMAGE: float = 8.0
const FLAMEJET_TICK_INTERVAL: float = 0.2
const FLAMEJET_DURATION: float = 1.0
const HOLD_THRESHOLD: float = 0.5

var _special_held: bool = false
var _hold_timer: float = 0.0
var _flamejet_active: bool = false
var _flamejet_timer: float = 0.0
var _flamejet_tick_timer: float = 0.0
var _projectile_scene: PackedScene

func _ready() -> void:
	max_hp = 100.0
	move_speed = 220.0
	jump_force = -600.0
	attack_damage_light = 8.0
	attack_damage_heavy = 14.0
	knockback_multiplier = 1.0
	sprite.sprite_frames = _build_sprite_frames()
	sprite.position = Vector2(0, -26)
	_projectile_scene = load("res://scenes/characters/Projectile.tscn")
	super._ready()

func _build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	var p := sprites_path
	var jump_total := _frames(p + "Jump.png", 128)
	var jump_half := int(jump_total / float(2))

	_add_anim(sf, "idle",         load(p + "Idle.png"),     128, 128, 0,         _frames(p + "Idle.png", 128),   8.0,  true)
	_add_anim(sf, "run",          load(p + "Run.png"),       128, 128, 0,        _frames(p + "Run.png", 128),    12.0, true)
	_add_anim(sf, "jump",         load(p + "Jump.png"),      128, 128, 0,        jump_half,                      10.0, false)
	_add_anim(sf, "fall",         load(p + "Jump.png"),      128, 128, jump_half, jump_total - jump_half,         10.0, false)
	_add_anim(sf, "attack_light", load(p + "Attack_1.png"),  128, 128, 0, _frames(p + "Attack_1.png", 128),      16.0, false)
	_add_anim(sf, "attack_heavy", load(p + "Attack_2.png"),  128, 128, 0, _frames(p + "Attack_2.png", 128),      16.0, false)
	# Charge.png is 64x64 frames (sheet is 64px tall)
	_add_anim(sf, "charge",       load(p + "Charge.png"),    64,  64,  0, _frames(p + "Charge.png", 64),         16.0, true)
	_add_anim(sf, "special",      load(p + "Fireball.png"),  128, 128, 0, _frames(p + "Fireball.png", 128),      12.0, false)
	_add_anim(sf, "special_hold", load(p + "Flame_jet.png"), 128, 128, 0, _frames(p + "Flame_jet.png", 128),     12.0, true)
	_add_anim(sf, "hurt",         load(p + "Hurt.png"),      128, 128, 0, _frames(p + "Hurt.png", 128),          10.0, false)
	_add_anim(sf, "dead",         load(p + "Dead.png"),      128, 128, 0, _frames(p + "Dead.png", 128),          8.0,  false)
	return sf

func handle_input() -> void:
	super.handle_input()
	# is_special_held = action_pressed (continuous); detect first frame with is_special_pressed
	var is_held: bool = InputManager.is_special_held(player_id)
	if is_held:
		if not _special_held and not _is_locked():
			_special_held = true
			_hold_timer = 0.0
			_start_charge()
		elif _special_held:
			_hold_timer += get_physics_process_delta_time()
	elif _special_held:
		_special_held = false
		_on_special_released()

func _start_charge() -> void:
	is_attacking = true
	change_state(State.SPECIAL)
	_try_play("charge")
	AudioManager.play_sfx("Sword Attack")

func _on_special_released() -> void:
	if state != State.SPECIAL or _flamejet_active:
		return
	if _hold_timer >= HOLD_THRESHOLD:
		_begin_flamejet()
	else:
		_launch_fireball()

func _launch_fireball() -> void:
	var proj := _projectile_scene.instantiate()
	var fire_sprite: Sprite2D = proj.get_node("Sprite2D")
	fire_sprite.texture = load(sprites_path + "Fireball.png")
	fire_sprite.hframes = _frames(sprites_path + "Fireball.png", 128)
	fire_sprite.flip_h = not facing_right

	var shape_node: CollisionShape2D = proj.get_node("CollisionShape2D")
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	shape_node.shape = circle

	proj.direction = 1.0 if facing_right else -1.0
	proj.speed = FIREBALL_SPEED
	proj.damage = FIREBALL_DAMAGE
	proj.max_distance = FIREBALL_RANGE
	proj.owner_id = player_id

	get_parent().add_child(proj)
	proj.global_position = global_position + Vector2(50.0 * proj.direction, -30.0)
	# verify: pin magic anim_idx for fireball VFX after visual test
	VFXManager.play("ko", proj.global_position, 0.5, -1)

	is_attacking = false
	change_state(State.IDLE)

func _begin_flamejet() -> void:
	_flamejet_active = true
	_flamejet_timer = FLAMEJET_DURATION
	_flamejet_tick_timer = FLAMEJET_TICK_INTERVAL
	hitbox_light.monitoring = true
	_try_play("special_hold")

func _physics_process(delta: float) -> void:
	if _flamejet_active:
		_flamejet_timer -= delta
		_flamejet_tick_timer -= delta
		if _flamejet_tick_timer <= 0.0:
			_flamejet_tick_timer = FLAMEJET_TICK_INTERVAL
			var flame_pos := global_position + Vector2(60.0 * (1.0 if facing_right else -1.0), -30.0)
			# verify: pin magic anim_idx for flame VFX after visual test
			VFXManager.play_single("hit_sparks", flame_pos, 1.0, 0.15, -1)
		if _flamejet_timer <= 0.0:
			_end_flamejet()
	super._physics_process(delta)

func _end_flamejet() -> void:
	_flamejet_active = false
	hitbox_light.monitoring = false
	is_attacking = false
	change_state(State.IDLE)

func _on_hitbox_light_area_entered(area: Area2D) -> void:
	if _flamejet_active:
		var target = area.get_parent()
		if not (target is Character) or target == self:
			return
		target.take_damage(FLAMEJET_TICK_DAMAGE, global_position, false)
		AudioManager.play_sfx("Sword Impact Hit")
	else:
		super._on_hitbox_light_area_entered(area)

func special_attack() -> void:
	pass  # Handled entirely in handle_input

func _on_sprite_animation_finished() -> void:
	match state:
		State.SPECIAL:
			if not _flamejet_active:
				is_attacking = false
				change_state(State.IDLE)
		_:
			super._on_sprite_animation_finished()
