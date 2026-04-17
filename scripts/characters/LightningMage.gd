# LightningMage.gd — Lightning Mage (lightning_mage only)
# Stats: HP 100, Speed 215, Jump -600, Light 8, Heavy 14
# Special: press to Charge, release to fire:
#   < 0.8s hold → small Light_ball (500px/s, 12 dmg)
#   ≥ 0.8s hold → large Light_ball (300px/s, 28 dmg + 1s extra hitstun)
#   At 0.8s hold, charge animation switches to Light_charge visually
class_name LightningMage
extends "res://scripts/characters/Character.gd"

@export var sprites_path: String = "res://assets/characters/wizards/lightning_mage/sprites/"

const HOLD_THRESHOLD: float = 0.8
const BALL_SPEED_TAP: float = 500.0
const BALL_SPEED_HOLD: float = 300.0
const BALL_DAMAGE_TAP: float = 12.0
const BALL_DAMAGE_HOLD: float = 28.0
const BALL_RANGE: float = 1200.0
const EXTRA_HITSTUN: float = 1.0

var _special_held: bool = false
var _hold_timer: float = 0.0
var _switched_to_lightcharge: bool = false
var _projectile_scene: PackedScene

func _ready() -> void:
	max_hp = 100.0
	move_speed = 215.0
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

	_add_anim(sf, "idle",         load(p + "Idle.png"),        128, 128, 0,         _frames(p + "Idle.png", 128),         8.0,  true)
	_add_anim(sf, "run",          load(p + "Run.png"),         128, 128, 0,         _frames(p + "Run.png", 128),          12.0, true)
	_add_anim(sf, "jump",         load(p + "Jump.png"),        128, 128, 0,         jump_half,                            10.0, false)
	_add_anim(sf, "fall",         load(p + "Jump.png"),        128, 128, jump_half, jump_total - jump_half,               10.0, false)
	_add_anim(sf, "attack_light", load(p + "Attack_1.png"),    128, 128, 0, _frames(p + "Attack_1.png", 128),            16.0, false)
	_add_anim(sf, "attack_heavy", load(p + "Attack_2.png"),    128, 128, 0, _frames(p + "Attack_2.png", 128),            16.0, false)
	# Charge.png is 64x64 frames (sheet is 64px tall)
	_add_anim(sf, "charge",       load(p + "Charge.png"),      64,  64,  0, _frames(p + "Charge.png", 64),              16.0, true)
	_add_anim(sf, "light_charge", load(p + "Light_charge.png"),128, 128, 0, _frames(p + "Light_charge.png", 128),       12.0, true)
	_add_anim(sf, "special",      load(p + "Light_ball.png"),  128, 128, 0, _frames(p + "Light_ball.png", 128),         12.0, false)
	_add_anim(sf, "hurt",         load(p + "Hurt.png"),        128, 128, 0, _frames(p + "Hurt.png", 128),               10.0, false)
	_add_anim(sf, "dead",         load(p + "Dead.png"),        128, 128, 0, _frames(p + "Dead.png", 128),               8.0,  false)
	return sf

func handle_input() -> void:
	super.handle_input()
	var is_held: bool = InputManager.is_special_held(player_id)
	if is_held:
		if not _special_held and not _is_locked():
			_special_held = true
			_hold_timer = 0.0
			_switched_to_lightcharge = false
			_start_charge()
		elif _special_held:
			_hold_timer += get_physics_process_delta_time()
			if not _switched_to_lightcharge and _hold_timer >= HOLD_THRESHOLD:
				_switched_to_lightcharge = true
				_try_play("light_charge")
	elif _special_held:
		_special_held = false
		_fire_ball(_hold_timer >= HOLD_THRESHOLD)

func _start_charge() -> void:
	is_attacking = true
	change_state(State.SPECIAL)
	_try_play("charge")
	AudioManager.play_sfx("Sword Attack")

func _fire_ball(is_held: bool) -> void:
	if state != State.SPECIAL:
		return
	var proj := _projectile_scene.instantiate()

	var ball_sprite: Sprite2D = proj.get_node("Sprite2D")
	ball_sprite.texture = load(sprites_path + "Light_ball.png")
	ball_sprite.hframes = _frames(sprites_path + "Light_ball.png", 128)
	ball_sprite.flip_h = not facing_right

	var shape_node: CollisionShape2D = proj.get_node("CollisionShape2D")
	var circle := CircleShape2D.new()
	circle.radius = 30.0 if is_held else 18.0
	shape_node.shape = circle

	proj.direction = 1.0 if facing_right else -1.0
	proj.speed = BALL_SPEED_HOLD if is_held else BALL_SPEED_TAP
	proj.damage = BALL_DAMAGE_HOLD if is_held else BALL_DAMAGE_TAP
	proj.max_distance = BALL_RANGE
	proj.owner_id = player_id
	proj.extra_hitstun = EXTRA_HITSTUN if is_held else 0.0

	get_parent().add_child(proj)
	proj.global_position = global_position + Vector2(50.0 * proj.direction, -30.0)
	# verify: pin magic anim_idx for light ball VFX after visual test
	VFXManager.play("ko", proj.global_position, 0.5, -1)

	is_attacking = false
	change_state(State.IDLE)

func special_attack() -> void:
	pass  # Handled entirely in handle_input

func _on_sprite_animation_finished() -> void:
	match state:
		State.SPECIAL:
			is_attacking = false
			change_state(State.IDLE)
		_:
			super._on_sprite_animation_finished()
