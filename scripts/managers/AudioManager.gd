# AudioManager.gd
# Autoload singleton — manages all game audio with bus routing and SFX grouping.
extends Node

const SFX_BASE := "res://assets/sfx/"
const SFX_DIRS := ["attacks", "footsteps", "impacts", "ui"]
const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"
const AMBIENCE_BUS := "Ambience"

# SFX preloaded by stripped prefix: {"Sword Attack": [stream, stream, ...], ...}
var _sfx_groups: Dictionary = {}

# Two music players for crossfading
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _use_a: bool = true  # which player fills next play_music call

var _ambience_player: AudioStreamPlayer

func _ready() -> void:
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = MUSIC_BUS
	add_child(_music_a)

	_music_b = AudioStreamPlayer.new()
	_music_b.bus = MUSIC_BUS
	_music_b.volume_db = -80.0
	add_child(_music_b)

	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.bus = AMBIENCE_BUS
	_ambience_player.volume_db = -12.0
	add_child(_ambience_player)

	_preload_sfx()
	print("[AudioManager] Ready — %d SFX groups preloaded" % _sfx_groups.size())

func _preload_sfx() -> void:
	for subdir: String in SFX_DIRS:
		var dir_path := SFX_BASE + subdir + "/"
		var dir := DirAccess.open(dir_path)
		if dir == null:
			push_warning("[AudioManager] SFX folder not found: " + dir_path)
			continue
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if fname.ends_with(".wav"):
				var stream = load(dir_path + fname)
				if stream:
					var prefix := _strip_number_suffix(fname.get_basename())
					if not _sfx_groups.has(prefix):
						_sfx_groups[prefix] = []
					_sfx_groups[prefix].append(stream)
			fname = dir.get_next()
		dir.list_dir_end()

func _strip_number_suffix(s: String) -> String:
	# "Sword Attack 1" → "Sword Attack", "Dirt Land" → "Dirt Land"
	var parts := s.split(" ")
	if parts.size() > 1 and parts[-1].is_valid_int():
		parts.remove_at(parts.size() - 1)
	return " ".join(parts)

# Play a one-shot SFX by group name. Picks randomly if multiple files share the prefix.
func play_sfx(sfx_name: String) -> void:
	var group: Array = []
	for key: String in _sfx_groups:
		if key.to_lower() == sfx_name.to_lower():
			group = _sfx_groups[key]
			break
	if group.is_empty():
		push_warning("[AudioManager] No SFX found for: " + sfx_name)
		return
	var player := AudioStreamPlayer.new()
	player.stream = group[randi() % group.size()]
	player.bus = SFX_BUS
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

# Crossfade to a new music track (full res:// path).
func play_music(track_path: String) -> void:
	var stream = load(track_path)
	if stream == null:
		push_warning("[AudioManager] Music not found: " + track_path)
		return

	var next: AudioStreamPlayer
	var prev: AudioStreamPlayer
	if _use_a:
		next = _music_a
		prev = _music_b
	else:
		next = _music_b
		prev = _music_a
	_use_a = not _use_a

	next.stream = stream
	next.volume_db = -80.0
	next.play()

	# Fade in next player
	var tween_in := create_tween()
	tween_in.tween_property(next, "volume_db", 0.0, 1.0)

	# Fade out and stop previous player if it was playing
	if prev.playing:
		var tween_out := create_tween()
		tween_out.tween_property(prev, "volume_db", -80.0, 1.0)
		tween_out.tween_callback(prev.stop)

	print("[AudioManager] Playing music: " + track_path.get_file())

# Loop an ambience track (full res:// path) on the Ambience bus at -12db.
func play_ambience(amb_path: String) -> void:
	if _ambience_player.playing:
		_ambience_player.stop()
	var stream = load(amb_path)
	if stream == null:
		push_warning("[AudioManager] Ambience not found: " + amb_path)
		return
	_ambience_player.stream = stream
	_ambience_player.play()
	print("[AudioManager] Playing ambience: " + amb_path.get_file())

# Fade out and stop all music over 1 second.
func stop_music() -> void:
	for player: AudioStreamPlayer in [_music_a, _music_b]:
		if player.playing:
			var tween := create_tween()
			tween.tween_property(player, "volume_db", -80.0, 1.0)
			tween.tween_callback(player.stop)

func stop_ambience() -> void:
	_ambience_player.stop()

func set_volume(category: String, db: float) -> void:
	var bus_idx := AudioServer.get_bus_index(category)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, db)
	else:
		push_warning("[AudioManager] Unknown bus: " + category)
