# Samurai.gd — Samurai archetype (samurai, samurai_commander)
# Stats: HP 120, Speed 260, Jump -580, Light 10, Heavy 18
# Special: Attack_3 — dash 80px forward, up to 3 hits for 6 damage each
# Block: Protection.png (samurai) or Protect.png (samurai_commander), auto-detected
class_name Samurai
extends "res://scripts/characters/Character.gd"

@export var sprites_path: String = "res://assets/characters/samurai/samurai/sprites/"

const SPECIAL_DAMAGE: float = 6.0
const SPECIAL_MAX_HITS: int = 3
const SPECIAL_DASH_SPEED: float = 300.0
const SPECIAL_DURATION: float = 0.30

var _special_timer: float = 0.0
var _special_hits: int = 0
var _is_special_active: bool = false
var _dash_dir: float = 1.0

func _ready() -> void:
	max_hp = 120.0
	move_speed = 260.0
	jump_force = -580.0
	attack_damage_light = 10.0
	attack_damage_heavy = 18.0
	knockback_multiplier = 1.0
	sprite.sprite_frames = _build_sprite_frames()
	sprite.position = Vector2(0, -26)
	super._ready()

func _build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	var p := sprites_path
	var block_file := "Protect.png" if FileAccess.file_exists(p + "Protect.png") else "Protection.png"
	var jump_total := _frames(p + "Jump.png", 128)
	var jump_half := int(jump_total / float(2))

	_add_anim(sf, "idle",         load(p + "Idle.png"),      128, 128, 0,         _frames(p + "Idle.png", 128), 8.0,  true)
	_add_anim(sf, "run",          load(p + "Run.png"),       128, 128, 0,         _frames(p + "Run.png", 128),  12.0, true)
	_add_anim(sf, "jump",         load(p + "Jump.png"),      128, 128, 0,         jump_half,                    10.0, false)
	_add_anim(sf, "fall",         load(p + "Jump.png"),      128, 128, jump_half, jump_total - jump_half,       10.0, false)
	_add_anim(sf, "attack_light", load(p + "Attack_1.png"),  128, 128, 0, 4, 16.0, false)
	_add_anim(sf, "attack_heavy", load(p + "Attack_2.png"),  128, 128, 0, 5, 16.0, false)
	_add_anim(sf, "special",      load(p + "Attack_3.png"),  128, 128, 0, 4, 16.0, false)
	_add_anim(sf, "block",        load(p + block_file),      128, 128, 0, _frames(p + block_file, 128), 8.0, true)
	_add_anim(sf, "hurt",         load(p + "Hurt.png"),      128, 128, 0, _frames(p + "Hurt.png", 128), 10.0, false)
	_add_anim(sf, "dead",         load(p + "Dead.png"),      128, 128, 0, 6, 8.0,  false)
	return sf

func _physics_process(delta: float) -> void:
	if _is_special_active:
		_special_timer -= delta
		velocity.x = _dash_dir * SPECIAL_DASH_SPEED
		if _special_timer <= 0.0:
			_is_special_active = false
	super._physics_process(delta)

func special_attack() -> void:
	if _is_locked():
		return
	_special_hits = 0
	_is_special_active = true
	_special_timer = SPECIAL_DURATION
	_dash_dir = 1.0 if facing_right else -1.0
	is_attacking = true
	hitbox_light.monitoring = false
	change_state(State.SPECIAL)
	AudioManager.play_sfx("Sword Attack")

func _on_sprite_frame_changed() -> void:
	if state == State.SPECIAL:
		# Attack_3: 4 frames, active on 1-3
		hitbox_light.monitoring = (sprite.frame >= 1 and sprite.frame <= 3)
	else:
		super._on_sprite_frame_changed()

func _on_sprite_animation_finished() -> void:
	match state:
		State.SPECIAL:
			hitbox_light.monitoring = false
			_is_special_active = false
			is_attacking = false
			change_state(State.IDLE)
		_:
			super._on_sprite_animation_finished()

func _on_hitbox_light_area_entered(area: Area2D) -> void:
	if state == State.SPECIAL:
		if _special_hits >= SPECIAL_MAX_HITS:
			return
		var target = area.get_parent()
		if not (target is Character) or target == self:
			return
		_special_hits += 1
		target.take_damage(SPECIAL_DAMAGE, global_position, false)
		VFXManager.play_single("hit_sparks", area.global_position, 2.0, 0.12, 618)
		AudioManager.play_sfx("Sword Impact Hit")
	else:
		super._on_hitbox_light_area_entered(area)
