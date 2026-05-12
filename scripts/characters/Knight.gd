# Knight.gd — Knight archetype (knight_1, knight_2, knight_3)
# Stats: HP 150, Speed 200, Jump -550, Light 12, Heavy 22
# Mechanics: Run+Attack, Attack 3 combo chain, Defend/Protect block states
class_name Knight
extends "res://scripts/characters/Character.gd"

@export var sprites_path: String = "res://assets/characters/warriors/knight_1/sprites/"

var _is_run_attacking: bool = false
var _is_attack_3: bool = false
var _protect_timer: float = 0.0
var _is_slash_char: bool = false
var _slash_cooldown: float = 0.0

func _ready() -> void:
	if sprites_path.contains("knight_2"):
		max_hp = 140.0
		move_speed = 150.0
		jump_force = -550.0
		attack_damage_light = 14.0
		attack_damage_heavy = 24.0
	else:
		max_hp = 140.0
		move_speed = 175.0
		jump_force = -550.0
		attack_damage_light = 10.0
		attack_damage_heavy = 18.0
	knockback_multiplier = 1.0
	_is_slash_char = sprites_path.contains("knight_1") or sprites_path.contains("knight_3")
	sprite.sprite_frames = _build_sprite_frames()
	sprite.position = Vector2(16, -26)
	super._ready()

func _build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	var p := sprites_path
	_add_anim(sf, "idle",         load(p + "Idle.png"),       128, 128, 0, 4, 8.0,  true)
	_add_anim(sf, "run",          load(p + "Run.png"),        128, 128, 0, 7, 12.0, true)
	_add_anim(sf, "jump",         load(p + "Jump.png"),       128, 128, 0, 3, 10.0, false)
	_add_anim(sf, "fall",         load(p + "Jump.png"),       128, 128, 3, 3, 10.0, false)
	var swap := sprites_path.contains("knight_1") or sprites_path.contains("knight_3")
	_add_anim(sf, "attack_light", load(p + ("Attack 3.png" if swap else "Attack 1.png")), 128, 128, 0, (4 if swap else 5), 16.0, false)
	_add_anim(sf, "attack_heavy", load(p + "Attack 2.png"),   128, 128, 0, 4, 10.0, false)
	if swap:
		_add_anim_cleaned_last(sf, "attack_3", load(p + "Attack 1.png"), 128, 128, 0, 5, 15.0, false)
	else:
		_add_anim(sf, "attack_3", load(p + "Attack 3.png"), 128, 128, 0, 4, 16.0, false)
	_add_anim(sf, "run_attack",   load(p + "Run+Attack.png"), 128, 128, 0, 6, 16.0, false)
	_add_anim(sf, "protect",      load(p + "Protect.png"),    128, 128, 0, 1, 8.0,  false)
	_add_anim(sf, "block",        load(p + "Defend.png"),     128, 128, 0, 5, 8.0,  true)
	_add_anim(sf, "hurt",         load(p + "Hurt.png"),       128, 128, 0, 2, 10.0, false)
	_add_anim(sf, "dead",         load(p + "Dead.png"),       128, 128, 0, 6, 8.0,  false)
	return sf

func _add_anim_cleaned_last(sf: SpriteFrames, anim_name: String, tex: Texture2D,
		frame_w: int, frame_h: int, start: int, count: int,
		fps: float, loop: bool) -> void:
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, loop)
	for i in range(start, start + count - 1):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		sf.add_frame(anim_name, at)
	# Last frame — erase the 3 slash arc marks (x >= 70, y 54-108)
	var img := tex.get_image()
	var last_x := (start + count - 1) * frame_w
	for y in range(54, 109):
		for x in range(last_x + 70, last_x + frame_w):
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	var clean_tex := ImageTexture.create_from_image(img)
	var last_at := AtlasTexture.new()
	last_at.atlas = clean_tex
	last_at.region = Rect2(last_x, 0, frame_w, frame_h)
	sf.add_frame(anim_name, last_at)

func _physics_process(delta: float) -> void:
	if _protect_timer > 0.0:
		_protect_timer -= delta
		if _protect_timer <= 0.0 and state == State.BLOCKING:
			_try_play("block")
	if _slash_cooldown > 0.0:
		_slash_cooldown -= delta
	super._physics_process(delta)

func attack_light() -> void:
	if _is_locked():
		return
	_light_hit_connected = false
	is_attacking = true
	hitbox_light.monitoring = false
	_is_run_attacking = (state == State.RUN)
	change_state(State.ATTACK_LIGHT)
	if _is_run_attacking:
		_try_play("run_attack")
	AudioManager.play_sfx("Sword Attack")

func attack_heavy() -> void:
	if _is_locked():
		return
	_heavy_hit_connected = false
	is_attacking = true
	hitbox_heavy.monitoring = false
	_is_attack_3 = false
	change_state(State.ATTACK_HEAVY)
	AudioManager.play_sfx("Sword Attack")

func special_attack() -> void:
	if _is_locked() or _slash_cooldown > 0.0:
		return
	_heavy_hit_connected = false
	_is_attack_3 = true
	is_attacking = true
	hitbox_heavy.monitoring = false
	change_state(State.ATTACK_HEAVY)
	_try_play("attack_3")
	AudioManager.play_sfx("Sword Attack")
	if _is_slash_char:
		_slash_cooldown = 1.2
		_spawn_slash_projectile()

func _spawn_slash_projectile() -> void:
	var dir := 1.0 if facing_right else -1.0
	var row := 2 if sprites_path.contains("knight_1") else 7
	var slash: Area2D = (load("res://scripts/characters/KnightSlash.gd") as GDScript).new()
	slash.set("direction", dir)
	slash.set("vfx_row", row)
	slash.set("owner_id", player_id)
	get_tree().current_scene.add_child(slash)
	slash.global_position = global_position + Vector2(dir * 4.0, 8.0)

func _read_block_input() -> bool:
	return InputManager.is_special2_held(player_id)

func change_state(new_state: State) -> void:
	if new_state == State.BLOCKING and state != State.BLOCKING:
		state = State.BLOCKING
		_protect_timer = 0.12
		_try_play("protect")
	else:
		super.change_state(new_state)

func _on_sprite_frame_changed() -> void:
	var f: int = sprite.frame
	match state:
		State.ATTACK_LIGHT:
			if _is_run_attacking:
				hitbox_light.monitoring = (f >= 1 and f <= 4) and not _light_hit_connected
			else:
				hitbox_light.monitoring = (f >= 1 and f <= 3) and not _light_hit_connected
		State.ATTACK_HEAVY:
			if _is_attack_3 and _is_slash_char:
				hitbox_heavy.monitoring = false
			else:
				hitbox_heavy.monitoring = (f >= 1 and f <= 2) and not _heavy_hit_connected
		_:
			super._on_sprite_frame_changed()

func _on_sprite_animation_finished() -> void:
	match state:
		State.ATTACK_HEAVY:
			hitbox_heavy.monitoring = false
			# Chain into Attack 3 if a heavy was buffered during this swing and
			# we haven't already fired Attack 3 this combo.
			if _buffered_input == BufferedInput.HEAVY and not _is_attack_3:
				_is_attack_3 = true
				_buffered_input = BufferedInput.NONE   # consume the buffer
				_buffer_timer = 0.0
				is_attacking = true
				_heavy_hit_connected = false           # fresh swing, fresh hit window
				_try_play("attack_3")
				AudioManager.play_sfx("Sword Attack")
			else:
				_is_attack_3 = false
				is_attacking = false
				_is_run_attacking = false
				_heavy_hit_connected = false
				change_state(State.IDLE)
				_attack_recovery_timer = HEAVY_ATTACK_RECOVERY
		State.ATTACK_LIGHT:
			hitbox_light.monitoring = false
			is_attacking = false
			_is_run_attacking = false
			change_state(State.IDLE)
			_attack_recovery_timer = LIGHT_ATTACK_RECOVERY
		_:
			super._on_sprite_animation_finished()
