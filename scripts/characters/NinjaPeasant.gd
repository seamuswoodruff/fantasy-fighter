# NinjaPeasant.gd — scrappy fastest ninja + stone throw + blade slash
# Stats: HP 85, Speed 295, Jump -610
# Special 1 (C): throw stone projectile
# Special 2 (V): blade slash — melee heavy hit using special 2.png,
#   hitbox_heavy active on frames 2–6 of 9.
class_name NinjaPeasant
extends "res://scripts/characters/Character.gd"

const SPRITES         := "res://assets/characters/ninjas/ninja_peasant/sprites/"
const FRAME_SIZE      := 96
const STONE_SPEED     := 520.0
const STONE_DAMAGE    := 11.0
const STONE_RANGE     := 800.0
const SPECIAL2_DAMAGE := 18.0   # blade slash — heavier than normal heavy attack

var _special2_active: bool = false
var _stone_tex: Texture2D

func _ready() -> void:
	max_hp               = 85.0
	move_speed           = 295.0
	jump_force           = -610.0
	attack_damage_light  = 8.0
	attack_damage_heavy  = 15.0
	character_name       = "Ninja Peasant"
	sprite.sprite_frames = _build_sprite_frames()
	sprite.position      = Vector2(0, -20)
	_stone_tex           = _load_raw_texture(SPRITES + "special1_projectile.png")
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
	_add_anim(sf, "attack_heavy", _load_raw_texture(p + "heavy attack.png"), fs, fs, 0, _frames_raw(p + "heavy attack.png", fs), 13.0, false)
	_add_anim(sf, "special",      _load_raw_texture(p + "special 1.png"),    fs, fs, 0, _frames_raw(p + "special 1.png", fs),    14.0, false)
	_add_anim(sf, "special2",     _load_raw_texture(p + "special 2.png"),    fs, fs, 0, _frames_raw(p + "special 2.png", fs),    14.0, false)
	_add_anim(sf, "hurt",         _load_raw_texture(p + "Hurt.png"),         fs, fs, 0, _frames_raw(p + "Hurt.png", fs),         10.0, false)
	_add_anim(sf, "dead",         _load_raw_texture(p + "Dead.png"),         fs, fs, 0, _frames_raw(p + "Dead.png", fs),         8.0,  false)
	return sf

# Override to play "special2" anim when blade slash is active
func _play_animation_for_state() -> void:
	if state == State.SPECIAL and _special2_active:
		_try_play("special2")
	else:
		super._play_animation_for_state()

# Special 1 — stone throw
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
			# 4 frames: 0=startup, 1-2=active, 3=recovery
			hitbox_light.monitoring = (f >= 1 and f <= 2) and not _light_hit_connected
		State.ATTACK_HEAVY:
			# 6 frames: 0-1=startup, 2-4=active, 5=recovery
			hitbox_heavy.monitoring = (f >= 2 and f <= 4) and not _heavy_hit_connected
		State.SPECIAL:
			if _special2_active:
				# 9-frame blade slash: 0-1=startup, 2-6=active, 7-8=recovery
				hitbox_heavy.monitoring = (f >= 2 and f <= 6) and not _heavy_hit_connected
			else:
				# Stone throw — no hitbox during cast
				hitbox_light.monitoring = false
				hitbox_heavy.monitoring = false

# Override to use SPECIAL2_DAMAGE when blade slash connects
func _on_hitbox_heavy_area_entered(area: Area2D) -> void:
	if state == State.SPECIAL and _special2_active:
		var target = area.get_parent()
		if not (target is Character) or target == self:
			return
		target.take_damage(SPECIAL2_DAMAGE, global_position, true)
		_heavy_hit_connected = true
		hitbox_heavy.set_deferred("monitoring", false)
		VFXManager.play_single("hit_sparks", area.global_position, 2.0, 0.12, 618)
		AudioManager.play_sfx("Sword Impact Hit")
	else:
		super._on_hitbox_heavy_area_entered(area)

func _on_sprite_animation_finished() -> void:
	match state:
		State.SPECIAL:
			hitbox_light.monitoring = false
			hitbox_heavy.monitoring = false
			if not _special2_active:
				_spawn_stone()
			_special2_active = false
			is_attacking     = false
			change_state(State.IDLE)
			_attack_recovery_timer = SPECIAL_ATTACK_RECOVERY
		_:
			super._on_sprite_animation_finished()

func _spawn_stone() -> void:
	if _stone_tex == null:
		return
	var proj := preload("res://scenes/characters/Projectile.tscn").instantiate()
	var spr: Sprite2D = proj.get_node("Sprite2D")
	spr.texture = _stone_tex
	spr.hframes = 1
	spr.frame   = 0
	spr.scale   = Vector2(4.0, 4.0)   # 6×6 → 24×24 display
	proj.speed        = STONE_SPEED * (1.0 if facing_right else -1.0)
	proj.damage       = STONE_DAMAGE
	proj.max_distance = STONE_RANGE
	proj.owner_id     = player_id
	proj.global_position = global_position + Vector2(24.0 * (1.0 if facing_right else -1.0), -18.0)
	get_tree().root.add_child(proj)
	AudioManager.play_sfx("Sword Attack")
