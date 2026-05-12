# Kunoichi.gd — fast melee + shuriken throw + healing eat
# Stats: HP 90, Speed 300, Jump -615
# Special 1 (C): throw shuriken projectile
# Special 2 (V): eating animation — heals 5 HP on finish. 4-second cooldown.
class_name Kunoichi
extends "res://scripts/characters/Character.gd"

const SPRITES         := "res://assets/characters/ninjas/kunoichi/sprites/"
const SHURIKEN_SPEED  := 600.0
const SHURIKEN_DAMAGE := 12.0
const SHURIKEN_RANGE  := 950.0
const HEAL_AMOUNT     := 5.0
const HEAL_COOLDOWN   := 4.0

var _healing: bool = false
var _heal_cooldown_timer: float = 0.0
var _shuriken_tex: Texture2D

func _ready() -> void:
	max_hp               = 90.0
	move_speed           = 300.0
	jump_force           = -615.0
	attack_damage_light  = 9.0
	attack_damage_heavy  = 16.0
	character_name       = "Kunoichi"
	sprite.sprite_frames = _build_sprite_frames()
	sprite.position      = Vector2(0, -26)
	_shuriken_tex        = _load_raw_texture(SPRITES + "special_projectile.png")
	super._ready()

func _build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	var p := SPRITES
	var fs := 128
	_add_anim(sf, "idle",         _load_raw_texture(p + "Idle.png"),         fs, fs, 0, _frames_raw(p + "Idle.png", fs),         8.0,  true)
	_add_anim(sf, "run",          _load_raw_texture(p + "Run.png"),          fs, fs, 0, _frames_raw(p + "Run.png", fs),          12.0, true)
	_add_anim(sf, "jump",         _load_raw_texture(p + "Jump.png"),         fs, fs, 0, _frames_raw(p + "Jump.png", fs),         10.0, false)
	_add_anim(sf, "fall",         _load_raw_texture(p + "Jump.png"),         fs, fs, 5, _frames_raw(p + "Jump.png", fs) - 5,     10.0, false)
	_add_anim(sf, "attack_light", _load_raw_texture(p + "light attack.png"), fs, fs, 0, _frames_raw(p + "light attack.png", fs), 16.0, false)
	_add_anim(sf, "attack_heavy", _load_raw_texture(p + "heavy attack.png"), fs, fs, 0, _frames_raw(p + "heavy attack.png", fs), 14.0, false)
	_add_anim(sf, "special",      _load_raw_texture(p + "special.png"),      fs, fs, 0, _frames_raw(p + "special.png", fs),      14.0, false)
	_add_anim(sf, "special2",     _load_raw_texture(p + "special 2.png"),    fs, fs, 0, _frames_raw(p + "special 2.png", fs),    10.0, false)
	_add_anim(sf, "hurt",         _load_raw_texture(p + "Hurt.png"),         fs, fs, 0, _frames_raw(p + "Hurt.png", fs),         10.0, false)
	_add_anim(sf, "dead",         _load_raw_texture(p + "Dead.png"),         fs, fs, 0, _frames_raw(p + "Dead.png", fs),         8.0,  false)
	return sf

func _physics_process(delta: float) -> void:
	if _heal_cooldown_timer > 0.0:
		_heal_cooldown_timer -= delta
	super._physics_process(delta)

# Override so State.SPECIAL plays "special2" anim during heal
func _play_animation_for_state() -> void:
	if state == State.SPECIAL and _healing:
		_try_play("special2")
	else:
		super._play_animation_for_state()

# Special 1 — shuriken throw
func special_attack() -> void:
	if _is_locked() or _healing:
		return
	change_state(State.SPECIAL)
	AudioManager.play_sfx("Sword Attack")

# Special 2 — eating heal (4s cooldown, restores 5 HP on finish)
func special2_attack() -> void:
	if _is_locked() or _healing or _heal_cooldown_timer > 0.0:
		return
	_healing = true
	change_state(State.SPECIAL)
	# No SFX — silence while eating

func _on_sprite_frame_changed() -> void:
	var f := sprite.frame
	match state:
		State.ATTACK_LIGHT:
			# 6 frames: 0=startup, 1-3=active, 4-5=recovery
			hitbox_light.monitoring = (f >= 1 and f <= 3) and not _light_hit_connected
		State.ATTACK_HEAVY:
			# 8 frames: 0-1=startup, 2-5=active, 6-7=recovery
			hitbox_heavy.monitoring = (f >= 2 and f <= 5) and not _heavy_hit_connected
		State.SPECIAL:
			hitbox_light.monitoring = false
			hitbox_heavy.monitoring = false

func _on_sprite_animation_finished() -> void:
	match state:
		State.SPECIAL:
			hitbox_light.monitoring = false
			hitbox_heavy.monitoring = false
			if _healing:
				current_hp = minf(current_hp + HEAL_AMOUNT, max_hp)
				_heal_cooldown_timer = HEAL_COOLDOWN
				print("[Kunoichi] P%d healed %.0f HP — now %.0f/%.0f" % [player_id, HEAL_AMOUNT, current_hp, max_hp])
			else:
				_spawn_shuriken()
			_healing     = false
			is_attacking = false
			change_state(State.IDLE)
			_attack_recovery_timer = SPECIAL_ATTACK_RECOVERY
		_:
			super._on_sprite_animation_finished()

func _spawn_shuriken() -> void:
	if _shuriken_tex == null:
		return
	var proj := preload("res://scenes/characters/Projectile.tscn").instantiate()
	var spr: Sprite2D = proj.get_node("Sprite2D")
	spr.texture  = _shuriken_tex
	spr.hframes  = 1
	spr.frame    = 0
	spr.scale    = Vector2(3.0, 3.0)
	spr.flip_h   = not facing_right
	var shape_node: CollisionShape2D = proj.get_node("CollisionShape2D")
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28.0, 16.0)
	shape_node.shape = rect
	proj.direction    = 1.0 if facing_right else -1.0
	proj.speed        = SHURIKEN_SPEED
	proj.damage       = SHURIKEN_DAMAGE
	proj.max_distance = SHURIKEN_RANGE
	proj.owner_id     = player_id
	get_parent().add_child(proj)
	proj.global_position = global_position + Vector2(30.0 * proj.direction, -20.0)
	AudioManager.play_sfx("Sword Attack")
