# WandererMagician.gd — Wanderer Magician (wanderer_magician only)
# Stats: HP 105, Speed 225, Jump -595, Light 9, Heavy 15
# Special: press and release to fire:
#   < 0.6s hold → Charge_1 (0.2s) → Magic_arrow (550px/s, 10 dmg, low cooldown)
#   ≥ 0.6s hold → Charge_2 → Magic_sphere (250px/s, 22 dmg, piercing)
class_name WandererMagician
extends "res://scripts/characters/Character.gd"

@export var sprites_path: String = "res://assets/characters/wizards/wanderer_magician/sprites/"

const ARROW_SPEED: float = 550.0
const ARROW_DAMAGE: float = 10.0
const SPHERE_SPEED: float = 250.0
const SPHERE_DAMAGE: float = 22.0
const PROJ_RANGE: float = 1200.0
const HOLD_THRESHOLD: float = 0.6
const CHARGE1_DURATION: float = 0.2
const CHARGE2_DURATION: float = 0.4
const COOLDOWN: float = 0.25

var _special_held: bool = false
var _hold_timer: float = 0.0
var _is_charging: bool = false
var _charge_timer: float = 0.0
var _is_sphere: bool = false
var _switched_to_charge2: bool = false
var _cooldown_timer: float = 0.0
var _projectile_scene: PackedScene

func _ready() -> void:
	max_hp = 105.0
	move_speed = 225.0
	jump_force = -595.0
	attack_damage_light = 9.0
	attack_damage_heavy = 15.0
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

	_add_anim(sf, "idle",         load(p + "Idle.png"),         128, 128, 0,         _frames(p + "Idle.png", 128),          8.0,  true)
	_add_anim(sf, "run",          load(p + "Run.png"),          128, 128, 0,         _frames(p + "Run.png", 128),           12.0, true)
	_add_anim(sf, "jump",         load(p + "Jump.png"),         128, 128, 0,         jump_half,                             10.0, false)
	_add_anim(sf, "fall",         load(p + "Jump.png"),         128, 128, jump_half, jump_total - jump_half,                10.0, false)
	_add_anim(sf, "attack_light", load(p + "Attack_1.png"),     128, 128, 0, _frames(p + "Attack_1.png", 128),             16.0, false)
	_add_anim(sf, "attack_heavy", load(p + "Attack_2.png"),     128, 128, 0, _frames(p + "Attack_2.png", 128),             16.0, false)
	_add_anim(sf, "charge_1",     load(p + "Charge_1.png"),     128, 128, 0, _frames(p + "Charge_1.png", 128),             16.0, false)
	_add_anim(sf, "charge_2",     load(p + "Charge_2.png"),     128, 128, 0, _frames(p + "Charge_2.png", 128),             12.0, false)
	_add_anim(sf, "special",      load(p + "Magic_arrow.png"),  128, 128, 0, _frames(p + "Magic_arrow.png", 128),          12.0, false)
	_add_anim(sf, "special_hold", load(p + "Magic_sphere.png"), 128, 128, 0, _frames(p + "Magic_sphere.png", 128),         10.0, false)
	_add_anim(sf, "hurt",         load(p + "Hurt.png"),         128, 128, 0, _frames(p + "Hurt.png", 128),                 10.0, false)
	_add_anim(sf, "dead",         load(p + "Dead.png"),         128, 128, 0, _frames(p + "Dead.png", 128),                 8.0,  false)
	return sf

func handle_input() -> void:
	super.handle_input()
	var is_held: bool = InputManager.is_special_held(player_id)
	if is_held:
		if not _special_held and not _is_locked() and _cooldown_timer <= 0.0:
			_special_held = true
			_hold_timer = 0.0
			_switched_to_charge2 = false
			_is_sphere = false
		elif _special_held:
			_hold_timer += get_physics_process_delta_time()
			if not _switched_to_charge2 and _hold_timer >= HOLD_THRESHOLD:
				_switched_to_charge2 = true
				_is_sphere = true
				_try_play("charge_2")
	elif _special_held:
		_special_held = false
		_begin_cast()

func _physics_process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
	if _is_charging:
		_charge_timer -= delta
		if _charge_timer <= 0.0:
			_is_charging = false
			_fire_projectile()
	super._physics_process(delta)

func _begin_cast() -> void:
	if _is_locked():
		return
	_is_charging = true
	is_attacking = true
	if _is_sphere:
		_charge_timer = CHARGE2_DURATION
		change_state(State.SPECIAL)
		_try_play("charge_2")
	else:
		_charge_timer = CHARGE1_DURATION
		change_state(State.SPECIAL)
		_try_play("charge_1")
	AudioManager.play_sfx("Sword Attack")

func _fire_projectile() -> void:
	var proj := _projectile_scene.instantiate()

	var proj_sprite: Sprite2D = proj.get_node("Sprite2D")
	if _is_sphere:
		proj_sprite.texture = load(sprites_path + "Magic_sphere.png")
		proj_sprite.hframes = _frames(sprites_path + "Magic_sphere.png", 128)
	else:
		proj_sprite.texture = load(sprites_path + "Magic_arrow.png")
		proj_sprite.hframes = _frames(sprites_path + "Magic_arrow.png", 128)
	proj_sprite.flip_h = not facing_right

	var shape_node: CollisionShape2D = proj.get_node("CollisionShape2D")
	if _is_sphere:
		var circle := CircleShape2D.new()
		circle.radius = 28.0
		shape_node.shape = circle
	else:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(36.0, 18.0)
		shape_node.shape = rect

	proj.direction = 1.0 if facing_right else -1.0
	proj.speed = SPHERE_SPEED if _is_sphere else ARROW_SPEED
	proj.damage = SPHERE_DAMAGE if _is_sphere else ARROW_DAMAGE
	proj.max_distance = PROJ_RANGE
	proj.owner_id = player_id
	proj.is_piercing = _is_sphere

	get_parent().add_child(proj)
	proj.global_position = global_position + Vector2(50.0 * proj.direction, -30.0)
	# verify: pin magic anim_idx for projectile VFX after visual test
	VFXManager.play("ko", proj.global_position, 0.5, -1)

	_cooldown_timer = COOLDOWN
	is_attacking = false
	change_state(State.IDLE)

func special_attack() -> void:
	pass  # Handled entirely in handle_input

func _on_sprite_animation_finished() -> void:
	match state:
		State.SPECIAL:
			if not _is_charging:
				is_attacking = false
				change_state(State.IDLE)
		_:
			super._on_sprite_animation_finished()
