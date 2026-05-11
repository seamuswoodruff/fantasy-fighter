# NinjaMonk.gd — balanced staff fighter + staff throw + block/defend
# Stats: HP 105, Speed 275, Jump -595
# Special 1 (C): throw staff projectile
# Special 2 (V, hold): block — 60% damage reduction while held.
#   Uses special 2.png as the block animation.
#   Identical to Knight/Samurai block system, triggered by special2 input.
class_name NinjaMonk
extends "res://scripts/characters/Character.gd"

const SPRITES      := "res://assets/characters/ninjas/ninja_monk/sprites/"
const FRAME_SIZE   := 96
const STAFF_SPEED  := 480.0
const STAFF_DAMAGE := 14.0
const STAFF_RANGE  := 950.0

var _staff_tex: Texture2D

func _ready() -> void:
	max_hp               = 105.0
	move_speed           = 275.0
	jump_force           = -595.0
	attack_damage_light  = 10.0
	attack_damage_heavy  = 18.0
	character_name       = "Ninja Monk"
	sprite.sprite_frames = _build_sprite_frames()
	sprite.position      = Vector2(0, -20)
	_staff_tex           = _load_raw_texture(SPRITES + "special1_projectile.png")
	super._ready()

func _build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	var p  := SPRITES
	var fs := FRAME_SIZE
	_add_anim(sf, "idle",         _load_raw_texture(p + "Idle.png"),         fs, fs, 0, _frames_raw(p + "Idle.png", fs),         8.0,  true)
	_add_anim(sf, "run",          _load_raw_texture(p + "Run.png"),          fs, fs, 0, _frames_raw(p + "Run.png", fs),          12.0, true)
	_add_anim(sf, "jump",         _load_raw_texture(p + "Jump.png"),         fs, fs, 0, _frames_raw(p + "Jump.png", fs),         10.0, false)
	_add_anim(sf, "fall",         _load_raw_texture(p + "Jump.png"),         fs, fs, 4, _frames_raw(p + "Jump.png", fs) - 4,     10.0, false)
	_add_anim(sf, "attack_light", _load_raw_texture(p + "light attack.png"), fs, fs, 0, _frames_raw(p + "light attack.png", fs), 16.0, false)
	_add_anim(sf, "attack_heavy", _load_raw_texture(p + "heavy attack.png"), fs, fs, 0, _frames_raw(p + "heavy attack.png", fs), 12.0, false)
	_add_anim(sf, "special",      _load_raw_texture(p + "special 1.png"),    fs, fs, 0, _frames_raw(p + "special 1.png", fs),    14.0, false)
	# "block" anim uses special 2.png — base class plays this for State.BLOCKING
	_add_anim(sf, "block",        _load_raw_texture(p + "special 2.png"),    fs, fs, 0, _frames_raw(p + "special 2.png", fs),    8.0,  true)
	_add_anim(sf, "hurt",         _load_raw_texture(p + "Hurt.png"),         fs, fs, 0, _frames_raw(p + "Hurt.png", fs),         10.0, false)
	_add_anim(sf, "dead",         _load_raw_texture(p + "Dead.png"),         fs, fs, 0, _frames_raw(p + "Dead.png", fs),         8.0,  false)
	return sf

# Override handle_input so holding Special 2 activates the block state.
# The base class already handles all block logic (damage reduction, state
# machine, animation) — we just need to set is_blocking from the right input.
func handle_input() -> void:
	super.handle_input()
	if not _is_locked() and not is_cpu:
		if Input.is_action_pressed("p%d_special2" % player_id):
			is_blocking = true

# Special 1 — staff throw
func special_attack() -> void:
	if _is_locked() or is_blocking:
		return
	change_state(State.SPECIAL)
	AudioManager.play_sfx("Sword Attack")

# Special 2 is the block button — no separate attack action
func special2_attack() -> void:
	pass

func _on_sprite_frame_changed() -> void:
	var f := sprite.frame
	match state:
		State.ATTACK_LIGHT:
			# 5 frames: 0=startup, 1-3=active, 4=recovery
			hitbox_light.monitoring = (f >= 1 and f <= 3) and not _light_hit_connected
		State.ATTACK_HEAVY:
			# 5 frames: 0=startup, 1-3=active, 4=recovery
			hitbox_heavy.monitoring = (f >= 1 and f <= 3) and not _heavy_hit_connected
		State.SPECIAL:
			hitbox_light.monitoring = false
			hitbox_heavy.monitoring = false

func _on_sprite_animation_finished() -> void:
	match state:
		State.SPECIAL:
			hitbox_light.monitoring = false
			hitbox_heavy.monitoring = false
			_spawn_staff_projectile()
			is_attacking = false
			change_state(State.IDLE)
			_attack_recovery_timer = SPECIAL_ATTACK_RECOVERY
		_:
			super._on_sprite_animation_finished()

func _spawn_staff_projectile() -> void:
	if _staff_tex == null:
		return
	var proj := preload("res://scenes/characters/Projectile.tscn").instantiate()
	var spr: Sprite2D = proj.get_node("Sprite2D")
	spr.texture = _staff_tex
	# 48×16 sheet: width/height = 3 frames — correct for this projectile
	spr.hframes = int(_staff_tex.get_width() / float(_staff_tex.get_height()))
	spr.frame   = 0
	spr.scale   = Vector2(2.0, 2.0)
	proj.speed        = STAFF_SPEED * (1.0 if facing_right else -1.0)
	proj.damage       = STAFF_DAMAGE
	proj.max_distance = STAFF_RANGE
	proj.owner_id     = player_id
	proj.global_position = global_position + Vector2(28.0 * (1.0 if facing_right else -1.0), -18.0)
	get_tree().root.add_child(proj)
	AudioManager.play_sfx("Sword Attack")
