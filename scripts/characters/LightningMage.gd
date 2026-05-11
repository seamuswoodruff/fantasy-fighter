# LightningMage.gd — Lightning Mage
# Stats: HP 100, Speed 215, Jump -600, Light 8, Heavy 14
# Attacks:
#   Z/,   → Attack_1 (light melee, 8 dmg)
#   X/.   → Attack_2 (heavy melee, 14 dmg)
#   C/'   → Light_ball: cast anim → fires Light_ball_projectile (325px/s, 12 dmg)
#   V/;   → Light_charge: animation-range burst (no projectile), 28 dmg + 1s hitstun, hitbox_heavy
class_name LightningMage
extends "res://scripts/characters/Character.gd"

@export var sprites_path: String = "res://assets/characters/wizards/lightning_mage/sprites/"

const BALL_SPEED: float = 325.0
const BALL_DAMAGE: float = 18.0
const BALL_RANGE: float = 1200.0
const CHARGE_DAMAGE: float = 28.0
const EXTRA_HITSTUN: float = 0.25
const CHARGE_COOLDOWN: float = 0.3

var _is_charged: bool = false
var _charge_cooldown_timer: float = 0.0
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

	_add_anim(sf, "idle",         load(p + "Idle.png"),         128, 128, 0,         _frames(p + "Idle.png", 128),         8.0,  true)
	_add_anim(sf, "run",          load(p + "Run.png"),          128, 128, 0,         _frames(p + "Run.png", 128),          12.0, true)
	_add_anim(sf, "jump",         load(p + "Jump.png"),         128, 128, 0,         jump_half,                            10.0, false)
	_add_anim(sf, "fall",         load(p + "Jump.png"),         128, 128, jump_half, jump_total - jump_half,               10.0, false)
	_add_anim(sf, "attack_light", load(p + "Attack_1.png"),     128, 128, 0, _frames(p + "Attack_1.png", 128),            16.0, false)
	_add_anim(sf, "attack_heavy", load(p + "Attack_2.png"),     128, 128, 0, _frames(p + "Attack_2.png", 128),            16.0, false)
	_add_anim(sf, "special",      load(p + "Light_ball.png"),   128, 128, 0, _frames(p + "Light_ball.png", 128),          14.0, false)
	_add_anim(sf, "special_hold", load(p + "Light_charge.png"), 128, 128, 0, _frames(p + "Light_charge.png", 128),        10.0, false)
	_add_anim(sf, "hurt",         load(p + "Hurt.png"),         128, 128, 0, _frames(p + "Hurt.png", 128),                10.0, false)
	_add_anim(sf, "dead",         load(p + "Dead.png"),         128, 128, 0, _frames(p + "Dead.png", 128),                8.0,  false)
	return sf

# C/' — Light_ball: plays cast animation, fires projectile on animation finish
func special_attack() -> void:
	if _is_locked():
		return
	_is_charged = false
	is_attacking = true
	change_state(State.SPECIAL)
	AudioManager.play_sfx("Sword Attack")

# V/; — Light_charge: plays charge animation, hitbox activates during active frames
func special2_attack() -> void:
	if _is_locked() or _charge_cooldown_timer > 0.0:
		return
	_heavy_hit_connected = false
	_is_charged = true
	is_attacking = true
	hitbox_heavy.monitoring = false
	change_state(State.SPECIAL)
	_try_play("special_hold")
	AudioManager.play_sfx("Sword Attack")

func _apply_movement(delta: float) -> void:
	if _is_charged and state == State.SPECIAL:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		return
	super._apply_movement(delta)

func _physics_process(delta: float) -> void:
	if _charge_cooldown_timer > 0.0:
		_charge_cooldown_timer -= delta
	super._physics_process(delta)

func _fire_ball() -> void:
	var proj := _projectile_scene.instantiate()

	var proj_tex := _load_raw_texture(sprites_path + "Light_ball_projectile.png")
	var ball_sprite: Sprite2D = proj.get_node("Sprite2D")
	ball_sprite.texture = proj_tex
	ball_sprite.hframes = int(proj_tex.get_width() / 64.0) if proj_tex else 1
	ball_sprite.flip_h = not facing_right

	var shape_node: CollisionShape2D = proj.get_node("CollisionShape2D")
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	shape_node.shape = circle

	proj.direction = 1.0 if facing_right else -1.0
	proj.speed = BALL_SPEED
	proj.damage = BALL_DAMAGE
	proj.max_distance = BALL_RANGE
	proj.owner_id = player_id
	# Loop frames 0–4 three times, then play die-out frames 5–8 and despawn
	proj.loop_end_frame = 4
	proj.loop_count = 3
	proj.tail_start_frame = 5

	get_parent().add_child(proj)
	proj.global_position = global_position + Vector2(50.0 * proj.direction, -15.0)
	VFXManager.play("ko", proj.global_position, 0.5, -1)

	is_attacking = false
	change_state(State.IDLE)
	_attack_recovery_timer = SPECIAL_ATTACK_RECOVERY

# Activate hitbox_heavy during the active window of Light_charge animation
func _on_sprite_frame_changed() -> void:
	if state == State.SPECIAL and _is_charged:
		var f: int = sprite.frame
		hitbox_heavy.monitoring = (f >= 5 and f <= 12) and not _heavy_hit_connected
	else:
		super._on_sprite_frame_changed()

# Override for Light_charge special damage + extra hitstun
func _on_hitbox_heavy_area_entered(area: Area2D) -> void:
	if state == State.SPECIAL and _is_charged:
		var target = area.get_parent()
		if not (target is Character) or target == self:
			return
		var actual := CHARGE_DAMAGE * 0.2 if target.is_blocking else CHARGE_DAMAGE
		_heavy_hit_connected = true
		target.take_damage(CHARGE_DAMAGE, global_position, true)
		target._apply_extra_hitstun(EXTRA_HITSTUN)
		_spawn_damage_number(area.global_position, actual)
		hitbox_heavy.set_deferred("monitoring", false)
		_trigger_screen_freeze(0.1)
		VFXManager.play_single("hit_sparks", area.global_position, 2.0, 0.12, 618)
		AudioManager.play_sfx("Sword Impact Hit")
	else:
		super._on_hitbox_heavy_area_entered(area)

func _on_sprite_animation_finished() -> void:
	match state:
		State.SPECIAL:
			if not _is_charged:
				_fire_ball()
			else:
				hitbox_heavy.monitoring = false
				is_attacking = false
				_heavy_hit_connected = false
				change_state(State.IDLE)
				_attack_recovery_timer = SPECIAL_ATTACK_RECOVERY
				_charge_cooldown_timer = CHARGE_COOLDOWN
		_:
			super._on_sprite_animation_finished()
