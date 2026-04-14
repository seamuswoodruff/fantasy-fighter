# AudioManager.gd
# Autoload singleton — manages all game audio with bus routing.
extends Node

var _sfx_cache: Dictionary = {}
var _music_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer

const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"
const AMBIENCE_BUS := "Ambience"

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)

	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.bus = AMBIENCE_BUS
	_ambience_player.volume_db = -6.0
	add_child(_ambience_player)

	print("[AudioManager] Ready — buses: Music, SFX, Ambience")

func play_sfx(sfx_path: String) -> void:
	if not _sfx_cache.has(sfx_path):
		var stream = load(sfx_path)
		if stream == null:
			push_warning("[AudioManager] SFX not found: " + sfx_path)
			return
		_sfx_cache[sfx_path] = stream

	var player := AudioStreamPlayer.new()
	player.stream = _sfx_cache[sfx_path]
	player.bus = SFX_BUS
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func play_music(track_path: String) -> void:
	if _music_player.playing:
		_music_player.stop()
	var stream = load(track_path)
	if stream == null:
		push_warning("[AudioManager] Music not found: " + track_path)
		return
	_music_player.stream = stream
	_music_player.play()
	print("[AudioManager] Playing music: " + track_path)

func play_ambience(amb_path: String) -> void:
	if _ambience_player.playing:
		_ambience_player.stop()
	var stream = load(amb_path)
	if stream == null:
		push_warning("[AudioManager] Ambience not found: " + amb_path)
		return
	_ambience_player.stream = stream
	_ambience_player.play()

func stop_music() -> void:
	_music_player.stop()

func stop_ambience() -> void:
	_ambience_player.stop()

func set_volume(category: String, db: float) -> void:
	var bus_idx := AudioServer.get_bus_index(category)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, db)
	else:
		push_warning("[AudioManager] Unknown bus: " + category)
