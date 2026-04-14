# VFXManager.gd
# Autoload singleton — spawns one-shot VFX AnimatedSprite2D nodes.
extends Node

var _vfx_frames: Dictionary = {}

const VFX_BASE := "res://assets/vfx/"
const VFX_TYPES := ["hit_sparks", "magic", "ko", "dust"]

func _ready() -> void:
	_preload_vfx()
	print("[VFXManager] Ready — preloaded %d VFX types" % _vfx_frames.size())

func _preload_vfx() -> void:
	for vfx_type: String in VFX_TYPES:
		var dir_path: String = VFX_BASE + vfx_type + "/"
		var dir: DirAccess = DirAccess.open(dir_path)
		if dir == null:
			push_warning("[VFXManager] VFX folder not found: " + dir_path)
			continue

		var frames: Array = []
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".png"):
				var full_res := dir_path + file_name
				if ResourceLoader.exists(full_res):
					var tex: Texture2D = load(full_res)
					if tex:
						frames.append(tex)
			file_name = dir.get_next()
		dir.list_dir_end()

		frames.sort_custom(func(a: Texture2D, b: Texture2D) -> bool: return a.resource_path < b.resource_path)
		_vfx_frames[vfx_type] = frames

func play(vfx_type: String, position: Vector2, scale_factor: float = 1.0) -> void:
	if not _vfx_frames.has(vfx_type):
		push_warning("[VFXManager] Unknown VFX type: " + vfx_type)
		return

	var frames: Array = _vfx_frames[vfx_type]
	if frames.is_empty():
		return

	var sprite := AnimatedSprite2D.new()
	var sprite_frames := SpriteFrames.new()
	sprite_frames.add_animation("play")
	sprite_frames.set_animation_loop("play", false)
	sprite_frames.set_animation_speed("play", 24.0)
	for tex in frames:
		sprite_frames.add_frame("play", tex)

	sprite.sprite_frames = sprite_frames
	sprite.position = position
	sprite.scale = Vector2(scale_factor, scale_factor)
	get_tree().current_scene.add_child(sprite)
	sprite.play("play")
	sprite.animation_finished.connect(sprite.queue_free)
