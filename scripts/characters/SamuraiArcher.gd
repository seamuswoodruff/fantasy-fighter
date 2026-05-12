# SamuraiArcher.gd — Samurai Archer (samurai_archer only)
# Stats: HP 110, Speed 280, Jump -600, Light 9, Heavy 16, Arrow 16
# Special: Shot animation → spawns Arrow projectile at 600px/s
# No block — most mobile character
class_name SamuraiArcher
extends "res://scripts/characters/Character.gd"

@export var sprites_path: String = "res://assets/characters/samurai/samurai_archer/sprites/"

const ARROW_SPEED: float = 600.0
const ARROW_DAMAGE: float = 25.0
const ARROW_MAX_DIST: float = 1000.0

var _arrow_texture: Texture2D
var _projectile_scene: PackedScene

func _ready() -> void:
	max_hp = 140.0
	move_speed = 200.0
	jump_force = -550.0
	attack_damage_light = 9.0
	attack_damage_heavy = 16.0
	knockback_multiplier = 1.0
	sprite.sprite_frames = _build_sprite_frames()
	sprite.position = Vector2(0, -26)
	_arrow_texture = load(sprites_path + "Arrow.png")
	_projectile_scene = load("res://scenes/characters/Projectile.tscn")
	super._ready()

func _build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	var p := sprites_path
	var jump_total := _frames(p + "Jump.png", 128)
	var jump_half := int(jump_total / float(2))

	_add_anim(sf, "idle",         load(p + "Idle.png"),     128, 128, 0,         _frames(p + "Idle.png", 128),   8.0,  true)
	_add_anim(sf, "run",          load(p + "Run.png"),      128, 128, 0,         _frames(p + "Run.png", 128),    12.0, true)
	_add_anim(sf, "jump",         load(p + "Jump.png"),     128, 128, 0,         jump_half,                      10.0, false)
	_add_anim(sf, "fall",         load(p + "Jump.png"),     128, 128, jump_half, jump_total - jump_half,          10.0, false)
	_add_anim(sf, "attack_light", load(p + "Attack_1.png"), 128, 128, 0, _frames(p + "Attack_1.png", 128),       16.0, false)
	_add_anim(sf, "attack_heavy", load(p + "Attack_2.png"), 128, 128, 0, _frames(p + "Attack_2.png", 128),       16.0, false)
	_add_anim(sf, "special",      load(p + "Shot.png"),     128, 128, 0, _frames(p + "Shot.png", 128),           12.0, false)
	_add_anim(sf, "special2",     load(p + "Attack_3.png"), 128, 128, 0, _frames(p + "Attack_3.png", 128),       16.0, false)
	_add_anim(sf, "hurt",         load(p + "Hurt.png"),     128, 128, 0, _frames(p + "Hurt.png", 128),           10.0, false)
	_add_anim(sf, "dead",         load(p + "Dead.png"),     128, 128, 0, _frames(p + "Dead.png", 128),           8.0,  false)
	return sf

func special_attack() -> void:
	if _is_locked():
		return
	is_attacking = true
	change_state(State.SPECIAL)
	AudioManager.play_sfx("Sword Attack")

func special2_attack() -> void:
	if _is_locked():
		return
	_heavy_hit_connected = false
	is_attacking = true
	hitbox_heavy.monitoring = false
	change_state(State.SPECIAL)
	_try_play("special2")
	AudioManager.play_sfx("Sword Attack")

func _on_sprite_frame_changed() -> void:
	if sprite.animation == "special2":
		var f := sprite.frame
		var total := sprite.sprite_frames.get_frame_count("special2")
		hitbox_heavy.monitoring = (f >= 1 and f <= total - 2) and not _heavy_hit_connected
	else:
		super._on_sprite_frame_changed()

func _on_sprite_animation_finished() -> void:
	match state:
		State.SPECIAL:
			if sprite.animation == "special2":
				hitbox_heavy.monitoring = false
				is_attacking = false
				_heavy_hit_connected = false
				change_state(State.IDLE)
				_attack_recovery_timer = HEAVY_ATTACK_RECOVERY
			else:
				_spawn_arrow()
				is_attacking = false
				change_state(State.IDLE)
				_attack_recovery_timer = SPECIAL_ATTACK_RECOVERY
		_:
			super._on_sprite_animation_finished()

func _spawn_arrow() -> void:
	var proj := _projectile_scene.instantiate()

	var arrow_sprite: Sprite2D = proj.get_node("Sprite2D")
	arrow_sprite.texture = _arrow_texture
	arrow_sprite.flip_h = not facing_right

	var shape_node: CollisionShape2D = proj.get_node("CollisionShape2D")
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40.0, 8.0)
	shape_node.shape = rect

	proj.direction = 1.0 if facing_right else -1.0
	proj.speed = ARROW_SPEED
	proj.damage = ARROW_DAMAGE
	proj.max_distance = ARROW_MAX_DIST
	proj.owner_id = player_id

	get_parent().add_child(proj)
	proj.global_position = global_position + Vector2(45.0 * proj.direction, -20.0)
	# verify: pin magic anim_idx for arrow spawn VFX after visual test
