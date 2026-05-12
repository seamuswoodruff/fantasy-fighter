# NinjaPeasant.gd — scrappy fastest ninja + stone throw + block/defend
# Stats: HP 85, Speed 295, Jump -610
# Special 1 (C): throw stone projectile
# Special 2 (V, hold): block — 60% damage reduction while held.
#   Uses special 2.png as the block animation.
#   Identical to Knight/Samurai block system, triggered by special2 input.
class_name NinjaPeasant
extends "res://scripts/characters/Character.gd"

const SPRITES     := "res://assets/characters/ninjas/ninja_peasant/sprites/"
const FRAME_SIZE  := 96
const STONE_SPEED  := 520.0
const STONE_DAMAGE := 11.0
const STONE_RANGE  := 800.0

var _stone_tex: Texture2D
var _block_frame_locked: bool = false  # true when frozen on frame 4 mid-block
var _block_exit_active: bool = false   # true while release animation plays

func _ready() -> void:
	max_hp               = 100.0
	move_speed           = 300.0
	jump_force           = -450.0
	attack_damage_light  = 9.0
	attack_damage_heavy  = 16.0
	character_name       = "Ninja Peasant"
	jump_count           = 4
	sprite.sprite_frames = _build_sprite_frames()
	# 96px frames but art fills ~68px (vs 64px art in 128px frames) — scale to match
	sprite.scale    = Vector2(0.94, 0.94)
	sprite.position = Vector2(0, -7)
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
	# special: sp2[0,1,2] → sp1[1,2,3,4] → sp2[6,7,8]
	var sp1_tex := _load_raw_texture(p + "special 1.png")
	var sp2_tex := _load_raw_texture(p + "special 2.png")
	sf.add_animation("special")
	sf.set_animation_speed("special", 14.0)
	sf.set_animation_loop("special", false)
	for i in [0, 1, 2]:
		var at := AtlasTexture.new(); at.atlas = sp2_tex; at.region = Rect2(i * fs, 0, fs, fs)
		sf.add_frame("special", at)
	for i in [1, 2, 3, 4]:
		var at := AtlasTexture.new(); at.atlas = sp1_tex; at.region = Rect2(i * fs, 0, fs, fs)
		sf.add_frame("special", at)
	for i in [6, 7, 8]:
		var at := AtlasTexture.new(); at.atlas = sp2_tex; at.region = Rect2(i * fs, 0, fs, fs)
		sf.add_frame("special", at)
	# block entry: frames 0-4 (raise shield), non-loop
	_add_anim(sf, "block",      sp2_tex, fs, fs, 0, 5, 14.0, false)
	# block exit: frames 5-8 (lower shield), non-loop
	_add_anim(sf, "block_exit", sp2_tex, fs, fs, 5, 4, 14.0, false)
	_add_anim(sf, "hurt",         _load_raw_texture(p + "Hurt.png"),         fs, fs, 0, _frames_raw(p + "Hurt.png", fs),         10.0, false)
	_add_anim(sf, "dead",         _load_raw_texture(p + "Dead.png"),         fs, fs, 0, _frames_raw(p + "Dead.png", fs),         8.0,  false)
	return sf

func _on_special_interrupted() -> void:
	_block_frame_locked = false
	_block_exit_active = false

func _play_animation_for_state() -> void:
	if state == State.BLOCKING:
		if not _block_exit_active and not _block_frame_locked:
			_try_play("block")
		# else: exit anim already playing, or frozen on frame 4 — don't interrupt
	else:
		super._play_animation_for_state()

func change_state(new_state: State) -> void:
	# Re-pressing block during exit cancels the exit and restarts entry
	if new_state == State.BLOCKING and _block_exit_active:
		_block_exit_active = false
		_block_frame_locked = false
		super.change_state(State.BLOCKING)
		return
	if state == State.BLOCKING and new_state != State.BLOCKING:
		if not _block_exit_active:
			# Interrupting hits skip the exit animation
			if new_state == State.HURT or new_state == State.DEAD:
				super.change_state(new_state)
				return
			if _block_frame_locked:
				# Fully raised — play the exit animation before leaving
				_block_exit_active = true
				_block_frame_locked = false
				_try_play("block_exit")
			else:
				# Released before fully raised — exit immediately
				super.change_state(new_state)
				return
		return  # stay in BLOCKING while exit anim plays
	super.change_state(new_state)

# Override handle_input so holding Special 2 activates the block state.
# The base class handles all block logic — we just map the input.
func handle_input() -> void:
	super.handle_input()
	if not _is_locked() and not is_cpu:
		if Input.is_action_pressed("p%d_special2" % player_id):
			is_blocking = true

# Special 1 — stone throw
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
			# 4 frames: 0=startup, 1-2=active, 3=recovery
			hitbox_light.monitoring = (f >= 1 and f <= 2) and not _light_hit_connected
		State.ATTACK_HEAVY:
			# 6 frames: 0-1=startup, 2-4=active, 5=recovery
			hitbox_heavy.monitoring = (f >= 2 and f <= 4) and not _heavy_hit_connected
		State.SPECIAL:
			hitbox_light.monitoring = false
			hitbox_heavy.monitoring = false
			if f == 5:
				_spawn_stone()

func _on_sprite_animation_finished() -> void:
	match state:
		State.BLOCKING:
			if _block_exit_active:
				# Exit animation done — leave blocking state
				_block_exit_active = false
				_block_frame_locked = false
				super.change_state(State.IDLE)
			else:
				# Entry animation done — freeze on frame 4
				sprite.stop()
				sprite.frame = 4
				_block_frame_locked = true
		State.SPECIAL:
			hitbox_light.monitoring = false
			hitbox_heavy.monitoring = false
			is_attacking = false
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
	spr.scale   = Vector2(2.0, 2.0)
	spr.flip_h  = not facing_right
	var shape_node: CollisionShape2D = proj.get_node("CollisionShape2D")
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10.0, 10.0)
	shape_node.shape = rect
	proj.direction    = 1.0 if facing_right else -1.0
	proj.speed        = STONE_SPEED
	proj.damage       = STONE_DAMAGE
	proj.max_distance = STONE_RANGE
	proj.owner_id     = player_id
	get_parent().add_child(proj)
	proj.global_position = global_position + Vector2(24.0 * proj.direction, 12.0)
	AudioManager.play_sfx("Sword Attack")
