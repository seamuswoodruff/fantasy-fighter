# WandererMagician.gd — Wanderer Magician
# Stats: HP 105, Speed 225, Jump -595, Light 9, Heavy 15
# Attacks:
#   Z/,   → Attack_1 (light melee)
#   X/.   → Attack_2 (heavy melee)
#   C/'   → Magic_arrow: plays cast anim, fires Magic_arrow_projectile (550px/s, 10 dmg, low cooldown)
#   V/;   → Magic_sphere: plays cast anim, fires Magic_sphere_projectile (250px/s, 22 dmg, piercing)
class_name WandererMagician
extends "res://scripts/characters/Character.gd"

@export var sprites_path: String = "res://assets/characters/wizards/wanderer_magician/sprites/"

const ARROW_SPEED: float = 550.0
const ARROW_DAMAGE: float = 10.0
const SPHERE_SPEED: float = 325.0
const SPHERE_DAMAGE: float = 18.0
const PROJ_RANGE: float = 1200.0
const COOLDOWN: float = 0.25

var _is_sphere: bool = false
var _cooldown_timer: float = 0.0
var _projectile_scene: PackedScene

func _ready() -> void:
	max_hp = 120.0
	move_speed = 225.0
	jump_force = -500.0
	attack_damage_light = 9.0
	attack_damage_heavy = 15.0
	knockback_multiplier = 1.0
	jump_count = 3
	cpu_archetype = "ranged"
	sprite.sprite_frames = _build_sprite_frames()
	sprite.position = Vector2(0, -26)
	_projectile_scene = load("res://scenes/characters/Projectile.tscn")
	super._ready()

func _build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	var p := sprites_path
	var jump_total := _frames(p + "Jump.png", 128)
	var jump_half := int(jump_total / float(2))

	_add_anim(sf, "idle",         load(p + "Idle.png"),         128, 128, 0,         _frames(p + "Idle.png", 128),         8.0,  true)
	_add_anim(sf, "run",          load(p + "Run.png"),          128, 128, 0,         _frames(p + "Run.png", 128),          12.0, true)
	_add_anim(sf, "jump",         load(p + "Jump.png"),         128, 128, 0,         jump_half,                            10.0, false)
	_add_anim(sf, "fall",         load(p + "Jump.png"),         128, 128, jump_half, jump_total - jump_half,               10.0, false)
	_add_anim(sf, "attack_light", load(p + "Attack_1.png"),     128, 128, 0, _frames(p + "Attack_1.png", 128),            16.0, false)
	_add_anim(sf, "attack_heavy", load(p + "Attack_2.png"),     128, 128, 0, _frames(p + "Attack_2.png", 128),            16.0, false)
	_add_anim(sf, "special",      load(p + "Magic_arrow.png"),  128, 128, 0, _frames(p + "Magic_arrow.png", 128),         12.0, false)
	_add_anim(sf, "special_hold", load(p + "Magic_sphere.png"), 128, 128, 0, _frames(p + "Magic_sphere.png", 128),        10.0, false)
	_add_anim(sf, "hurt",         load(p + "Hurt.png"),         128, 128, 0, _frames(p + "Hurt.png", 128),                10.0, false)
	_add_anim(sf, "dead",         load(p + "Dead.png"),         128, 128, 0, _frames(p + "Dead.png", 128),                8.0,  false)
	return sf

func special_attack() -> void:
	if _is_locked() or _cooldown_timer > 0.0:
		return
	_is_sphere = false
	is_attacking = true
	change_state(State.SPECIAL)
	AudioManager.play_sfx("Sword Attack")

func special2_attack() -> void:
	if _is_locked():
		return
	_is_sphere = true
	is_attacking = true
	change_state(State.SPECIAL)
	_try_play("special_hold")
	AudioManager.play_sfx("Sword Attack")

func _physics_process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
	super._physics_process(delta)

func _fire_projectile() -> void:
	var proj := _projectile_scene.instantiate()

	var proj_sprite: Sprite2D = proj.get_node("Sprite2D")
	if _is_sphere:
		var sphere_tex := _load_raw_texture(sprites_path + "Magic_sphere_projectile.png")
		proj_sprite.texture = sphere_tex
		proj_sprite.hframes = int(sphere_tex.get_width() / 64.0)
	else:
		var arrow_tex := _load_raw_texture(sprites_path + "Magic_arrow_projectile.png")
		proj_sprite.texture = arrow_tex
		proj_sprite.hframes = int(arrow_tex.get_width() / 64.0)
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
	if _is_sphere:
		# Loop frames 0–4 three times, then play die-out frames 5–8 and despawn
		proj.loop_end_frame = 4
		proj.loop_count = 3
		proj.tail_start_frame = 5

	get_parent().add_child(proj)
	proj.global_position = global_position + Vector2(50.0 * proj.direction, -15.0)

	if not _is_sphere:
		_cooldown_timer = COOLDOWN
	is_attacking = false
	change_state(State.IDLE)
	_attack_recovery_timer = SPECIAL_ATTACK_RECOVERY

func _on_sprite_animation_finished() -> void:
	match state:
		State.SPECIAL:
			_fire_projectile()
		_:
			super._on_sprite_animation_finished()
