# VFXManager.gd
# Autoload singleton — slices sprite-sheet VFX into per-row animations and spawns them.
#
# Sheet format: each PNG is a grid of frames. Each ROW is one complete animation.
# Frame size is detected from sheet height:
#   576px tall → 64×64 frames, 9 rows, variable columns
#    72px tall → 72×72 frames, 1 row,  variable columns
extends Node

# _vfx_anims[type] = Array of Array[AtlasTexture]
# Each inner array is one animation (all frames in one row of one sheet).
var _vfx_anims: Dictionary = {}

const VFX_BASE := "res://assets/vfx/"
const VFX_TYPES := ["hit_sparks", "magic", "ko", "dust"]

func _ready() -> void:
	_preload_vfx()
	var total := 0
	for k: String in _vfx_anims:
		total += (_vfx_anims[k] as Array).size()
	print("[VFXManager] Ready — %d VFX types, %d total animations" % [_vfx_anims.size(), total])

func _preload_vfx() -> void:
	for vfx_type: String in VFX_TYPES:
		var dir_path := VFX_BASE + vfx_type + "/"
		var dir := DirAccess.open(dir_path)
		if dir == null:
			push_warning("[VFXManager] Folder not found: " + dir_path)
			continue

		var files: Array = []
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if fname.ends_with(".png"):
				files.append(fname)
			fname = dir.get_next()
		dir.list_dir_end()
		files.sort()

		var all_anims: Array = []
		for file: String in files:
			var tex: Texture2D = load(dir_path + file)
			if tex == null:
				continue
			var w := tex.get_width()
			var h := tex.get_height()
			var frame_size := _frame_size_for_height(h)
			var cols := int(w / float(frame_size))
			var rows := int(h / float(frame_size))

			for row in rows:
				var frames: Array = []
				for col in cols:
					var atlas := AtlasTexture.new()
					atlas.atlas = tex
					atlas.region = Rect2(col * frame_size, row * frame_size, frame_size, frame_size)
					frames.append(atlas)
				all_anims.append(frames)

		_vfx_anims[vfx_type] = all_anims

func _frame_size_for_height(h: int) -> int:
	if h == 576:
		return 64   # 9 rows of 64px
	if h == 72:
		return 72   # 1 row of 72px (magic horizontal strips)
	return h        # fallback: treat as single-row

# Play a full frame-sequence animation. Picks one random row from the pool.
func play(vfx_type: String, position: Vector2, scale_factor: float = 2.0) -> void:
	if not _vfx_anims.has(vfx_type):
		push_warning("[VFXManager] Unknown VFX type: " + vfx_type)
		return
	var all_anims: Array = _vfx_anims[vfx_type]
	if all_anims.is_empty():
		return

	var frames: Array = all_anims[randi() % all_anims.size()]
	var sprite := AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.add_animation("play")
	sf.set_animation_loop("play", false)
	sf.set_animation_speed("play", 24.0)
	for tex in frames:
		sf.add_frame("play", tex)
	sprite.sprite_frames = sf
	sprite.position = position
	sprite.scale = Vector2(scale_factor, scale_factor)
	get_tree().current_scene.add_child(sprite)
	sprite.play("play")
	sprite.animation_finished.connect(sprite.queue_free)

# Show a single random frame briefly — for hit sparks and instant flashes.
func play_single(vfx_type: String, position: Vector2, scale_factor: float = 2.0, duration: float = 0.12) -> void:
	if not _vfx_anims.has(vfx_type):
		push_warning("[VFXManager] Unknown VFX type: " + vfx_type)
		return
	var all_anims: Array = _vfx_anims[vfx_type]
	if all_anims.is_empty():
		return

	var frames: Array = all_anims[randi() % all_anims.size()]
	var sprite := Sprite2D.new()
	sprite.texture = frames[randi() % frames.size()]
	sprite.position = position
	sprite.scale = Vector2(scale_factor, scale_factor)
	get_tree().current_scene.add_child(sprite)
	get_tree().create_timer(duration, true).timeout.connect(sprite.queue_free)
