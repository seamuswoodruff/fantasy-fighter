# FireWizard.gd — Fire Wizard
# Stats: HP 100, Speed 220, Jump -600, Light 8, Heavy 14
# Attacks:
#   Z/,   → Attack_1 (light melee)
#   X/.   → Attack_2 (heavy melee)
#   C/'   → Fireball: plays Fireball cast anim, fires Fireball_projectile (450px/s, 18 dmg)
#   V/;   → Flame_jet: sustained AOE in front (1s, 8 dmg per 0.2s tick)
class_name FireWizard
extends "res://scripts/characters/Character.gd"

@export var sprites_path: String = "res://assets/characters/wizards/fire_wizard/sprites/"

const FIREBALL_SPEED: float = 450.0
const FIREBALL_DAMAGE: float = 18.0
const FIREBALL_RANGE: float = 900.0
const FLAMEJET_TICK_DAMAGE: float = 8.0
const FLAMEJET_TICK_INTERVAL: float = 0.2
const FLAMEJET_DURATION: float = 1.0

var _flamejet_active: bool = false
var _flamejet_timer: float = 0.0
var _flamejet_tick_timer: float = 0.0
var _firing_fireball: bool = false
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

	_add_anim(sf, "idle",         load(p + "Idle.png"),              128, 128, 0,         _frames(p + "Idle.png", 128),         8.0,  true)
	_add_anim(sf, "run",          load(p + "Run.png"),               128, 128, 0,         _frames(p + "Run.png", 128),          12.0, true)
	_add_anim(sf, "jump",         load(p + "Jump.png"),              128, 128, 0,         jump_half,                            10.0, false)
	_add_anim(sf, "fall",         load(p + "Jump.png"),              128, 128, jump_half, jump_total - jump_half,               10.0, false)
	_add_anim(sf, "attack_light", load(p + "Attack_1.png"),          128, 128, 0, _frames(p + "Attack_1.png", 128),            16.0, false)
	_add_anim(sf, "attack_heavy", load(p + "Attack_2.png"),          128, 128, 0, _frames(p + "Attack_2.png", 128),            16.0, false)
	_add_anim(sf, "special",      load(p + "Fireball.png"),          128, 128, 0, _frames(p + "Fireball.png", 128),            12.0, false)
	_add_anim(sf, "special_hold", load(p + "Flame_jet.png"),         128, 128, 0, _frames(p + "Flame_jet.png", 128),           12.0, true)
	_add_anim(sf, "hurt",         load(p + "Hurt.png"),              128, 128, 0, _frames(p + "Hurt.png", 128),                10.0, false)
	_add_anim(sf, "dead",         load(p + "Dead.png"),              128, 128, 0, _frames(p + "Dead.png", 128),                8.0,  false)
	return sf

func special_attack() -> void:
	if _is_locked():
		return
	_firing_fireball = true
	is_attacking = true
	change_state(State.SPECIAL)
	AudioManager.play_sfx("Sword Attack")

func special2_attack() -> void:
	if _is_locked() or _flamejet_active:
		return
	_begin_flamejet()

func _begin_flamejet() -> void:
	_flamejet_active = true
	_firing_fireball = false
	_flamejet_timer = FLAMEJET_DURATION
	_flamejet_tick_timer = FLAMEJET_TICK_INTERVAL
	is_attacking = true
	hitbox_light.monitoring = true
	change_state(State.SPECIAL)
	_try_play("special_hold")
	AudioManager.play_sfx("Sword Attack")

func _launch_fireball() -> void:
	var proj := _projectile_scene.instantiate()
	var fire_sprite: Sprite2D = proj.get_node("Sprite2D")
	var proj_tex := _load_raw_texture(sprites_path + "Fireball_projectile.png")
	fire_sprite.texture = proj_tex
	fire_sprite.hframes = int(proj_tex.get_width() / 64.0)
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
	proj.global_position = global_position + Vector2(50.0 * proj.direction, -15.0)
	VFXManager.play("ko", proj.global_position, 0.5, -1)

	_firing_fireball = false
	is_attacking = false
	change_state(State.IDLE)

func _physics_process(delta: float) -> void:
	if _flamejet_active:
		_flamejet_timer -= delta
		_flamejet_tick_timer -= delta
		if _flamejet_tick_timer <= 0.0:
			_flamejet_tick_timer = FLAMEJET_TICK_INTERVAL
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

func _on_sprite_animation_finished() -> void:
	match state:
		State.SPECIAL:
			if _firing_fireball:
				_launch_fireball()
			elif not _flamejet_active:
				is_attacking = false
				change_state(State.IDLE)
		_:
			super._on_sprite_animation_finished()
