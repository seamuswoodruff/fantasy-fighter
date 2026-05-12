# NinjaMonk.gd — balanced staff fighter + staff throw + blade slash
# Stats: HP 105, Speed 275, Jump -595
# Special 1 (C): throw staff projectile
# Special 2 (V): blade slash — melee heavy hit using special 2.png,
#   hitbox_heavy active on frames 2–6 of 9. Deals SPECIAL2_DAMAGE.
class_name NinjaMonk
extends "res://scripts/characters/Character.gd"

const SPRITES        := "res://assets/characters/ninjas/ninja_monk/sprites/"
const FRAME_SIZE     := 96
const STAFF_SPEED    := 480.0
const STAFF_DAMAGE   := 14.0
const STAFF_RANGE    := 950.0
const SPECIAL2_DAMAGE := 18.0

var _special2_active: bool = false
var _staff_tex: Texture2D

func _ready() -> void:
	max_hp               = 110.0
	move_speed           = 290.0
	jump_force           = -450.0
	attack_damage_light  = 10.0
	attack_damage_heavy  = 18.0
	character_name       = "Ninja Monk"
	jump_count           = 4
	sprite.sprite_frames = _build_sprite_frames()
	# 96px frames but art fills ~71px (vs 64px art in 128px frames) — scale to match
	sprite.scale    = Vector2(0.90, 0.90)
	sprite.position = Vector2(0, -5)
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
	# "special2" anim uses special 2.png — played during the blade slash
	_add_anim(sf, "special2",     _load_raw_texture(p + "special 2.png"),    fs, fs, 0, _frames_raw(p + "special 2.png", fs),    14.0, false)
	_add_anim(sf, "hurt",         _load_raw_texture(p + "Hurt.png"),         fs, fs, 0, _frames_raw(p + "Hurt.png", fs),         10.0, false)
	_add_anim(sf, "dead",         _load_raw_texture(p + "Dead.png"),         fs, fs, 0, _frames_raw(p + "Dead.png", fs),         8.0,  false)
	return sf

func _on_special_interrupted() -> void:
	_special2_active = false

# Override to play "special2" anim when blade slash is active
func _play_animation_for_state() -> void:
	if state == State.SPECIAL and _special2_active:
		_try_play("special2")
	else:
		super._play_animation_for_state()

# Special 1 — staff throw
func special_attack() -> void:
	if _is_locked() or _special2_active:
		return
	change_state(State.SPECIAL)
	AudioManager.play_sfx("Sword Attack")

# Special 2 — blade slash (melee, uses hitbox_heavy with SPECIAL2_DAMAGE)
func special2_attack() -> void:
	if _is_locked() or _special2_active:
		return
	_special2_active     = true
	_heavy_hit_connected = false
	change_state(State.SPECIAL)
	AudioManager.play_sfx("Sword Attack")

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
			if _special2_active:
				# Blade slash: 0-1=startup, 2-6=active, 7-8=recovery
				hitbox_heavy.monitoring = (f >= 2 and f <= 6) and not _heavy_hit_connected
			else:
				# Staff throw cast — no hitbox
				hitbox_light.monitoring = false
				hitbox_heavy.monitoring = false

# Override to apply SPECIAL2_DAMAGE when blade slash connects.
# Routes through _apply_hit so damage numbers, screen freeze, and recoil all fire.
func _on_hitbox_heavy_area_entered(area: Area2D) -> void:
	if state == State.SPECIAL and _special2_active:
		_apply_hit(area, SPECIAL2_DAMAGE, true)
	else:
		super._on_hitbox_heavy_area_entered(area)

func _on_sprite_animation_finished() -> void:
	match state:
		State.SPECIAL:
			hitbox_light.monitoring = false
			hitbox_heavy.monitoring = false
			if not _special2_active:
				_spawn_staff_projectile()
			_special2_active = false
			is_attacking     = false
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
	# 48×16 sheet — use height as frame size
	spr.hframes = int(_staff_tex.get_width() / float(_staff_tex.get_height()))
	spr.frame   = 0
	spr.scale   = Vector2(2.0, 2.0)
	spr.flip_h  = not facing_right
	var shape_node: CollisionShape2D = proj.get_node("CollisionShape2D")
	var rect := RectangleShape2D.new()
	rect.size = Vector2(36.0, 14.0)
	shape_node.shape = rect
	proj.direction    = 1.0 if facing_right else -1.0
	proj.speed        = STAFF_SPEED
	proj.damage       = STAFF_DAMAGE
	proj.max_distance = STAFF_RANGE
	proj.owner_id     = player_id
	get_parent().add_child(proj)
	proj.global_position = global_position + Vector2(28.0 * proj.direction, -18.0)
	AudioManager.play_sfx("Sword Attack")
