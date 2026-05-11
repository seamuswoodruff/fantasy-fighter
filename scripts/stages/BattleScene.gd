# BattleScene.gd — Phase 9: dynamic stage + character loading
extends Node2D

# ── Stage configuration ────────────────────────────────────────────────────────
# Phase 10 will use GameManager.selected_stage; for now Windrise is the default.
const DEFAULT_STAGE := "Windrise"

const STAGE_SCENES := {
	"Windrise":     "res://scenes/stages/Windrise.tscn",
	"Ruins":        "res://scenes/stages/Ruins.tscn",
	"DesertTemple": "res://scenes/stages/DesertTemple.tscn",
}

const STAGE_MUSIC := {
	"Windrise": [
		"res://assets/music/PerituneMaterial_Prairie3_loop.ogg",
		"res://assets/music/PerituneMaterial_Prairie4_loop.ogg",
		"res://assets/music/PerituneMaterial_Prairie5_loop.ogg",
		"res://assets/music/PerituneMaterial_BattleField_loop.ogg",
		"res://assets/music/PerituneMaterial_BattleField2_loop.ogg",
		"res://assets/music/PerituneMaterial_BattleField3_loop.ogg",
		"res://assets/music/PerituneMaterial_BattleField4_loop.ogg",
		"res://assets/music/PerituneMaterial_BattleField5_loop.ogg",
		"res://assets/music/PerituneMaterial_EpicBattle_loop.ogg",
	],
	"Ruins": [
		"res://assets/music/PerituneMaterial_Gothic_Dark_loop.ogg",
		"res://assets/music/PerituneMaterial_Demise_loop.ogg",
		"res://assets/music/PerituneMaterial_Havoc_loop.ogg",
		"res://assets/music/PerituneMaterial_Fight_loop.ogg",
		"res://assets/music/PerituneMaterial_Fight2_loop.ogg",
		"res://assets/music/PerituneMaterial_Fight3_loop.ogg",
		"res://assets/music/PerituneMaterial_Crisis_loop.ogg",
	],
	"DesertTemple": [
		"res://assets/music/PerituneMaterial_Raid_Ethnic_loop.ogg",
		"res://assets/music/PerituneMaterial_Raid_FolkMetal_loop.ogg",
		"res://assets/music/PerituneMaterial_Raid_FolkMetal2_loop.ogg",
		"res://assets/music/PerituneMaterial_Raid_loop.ogg",
		"res://assets/music/PerituneMaterial_Raid2_loop.ogg",
		"res://assets/music/PerituneMaterial_Raid3_loop.ogg",
		"res://assets/music/PerituneMaterial_Flap_loop.ogg",
		"res://assets/music/PerituneMaterial_Flap2_loop.ogg",
	],
}

const STAGE_AMBIENCE := {
	"Windrise":     "res://assets/sfx/ambience/Forest Day.ogg",
	"Ruins":        "res://assets/sfx/ambience/Cave.ogg",
	"DesertTemple": "res://assets/sfx/ambience/Forest Night.ogg",
}

# ── Character scenes ───────────────────────────────────────────────────────────
const CHARACTER_SCENES := {
	"knight_1":           "res://scenes/characters/Knight1.tscn",
	"knight_2":           "res://scenes/characters/Knight2.tscn",
	"knight_3":           "res://scenes/characters/Knight3.tscn",
	"samurai":            "res://scenes/characters/Samurai.tscn",
	"samurai_commander":  "res://scenes/characters/SamuraiCommander.tscn",
	"samurai_archer":     "res://scenes/characters/SamuraiArcher.tscn",
	"fire_wizard":        "res://scenes/characters/FireWizard.tscn",
	"lightning_mage":     "res://scenes/characters/LightningMage.tscn",
	"wanderer_magician":  "res://scenes/characters/WandererMagician.tscn",
}

@onready var players_node: Node2D = $Players
@onready var hud = $HUD

var stage: Node2D
var players: Array[Character] = []
var _pause_menu: CanvasLayer
@warning_ignore("unused_private_class_variable")
var _pause_first_focus: Control = null

func _ready() -> void:
	_validate_all_characters()

	# Load stage — use GameManager selection if set, else default
	var stage_key := GameManager.selected_stage if GameManager.selected_stage != "" else DEFAULT_STAGE
	if not STAGE_SCENES.has(stage_key):
		push_error("[BattleScene] Unknown stage '%s', falling back to Windrise" % stage_key)
		stage_key = DEFAULT_STAGE
	GameManager.selected_stage = stage_key

	var stage_scene: PackedScene = load(STAGE_SCENES[stage_key])
	stage = stage_scene.instantiate() as Node2D
	stage.name = "Stage"
	add_child(stage)
	move_child(stage, 0)

	var fallbacks := ["knight_1", "lightning_mage", "samurai", "fire_wizard"]
	for i in GameManager.active_player_count:
		var key: String = GameManager.player_characters[i]
		if key == "":
			key = fallbacks[i % fallbacks.size()]
		var char_node := _spawn_character(key, i + 1)
		char_node.stocks = GameManager.stock_count   # sync with selected stock count
		var sp_node := stage.get_node_or_null("SpawnPoints/SpawnP%d" % (i + 1))
		if sp_node == null:
			push_error("[BattleScene] Missing SpawnP%d — using default position" % (i + 1))
			char_node.global_position = Vector2(320.0 + i * 320.0, 400.0)
			char_node.respawn_position = char_node.global_position
		else:
			var sp := sp_node as Marker2D
			char_node.global_position = sp.global_position
			char_node.respawn_position = sp.global_position
		if i > 0:
			char_node.spawn_facing_right = false
			char_node._set_facing(false)
		if GameManager.player_is_cpu[i]:
			char_node.is_cpu = true
			_add_cpu_controller(char_node)
		players.append(char_node)

	stage.body_entered_kill_zone.connect(_on_kill_zone_entered)

	hud.set_players(players)
	_play_stage_audio(stage_key)

	_setup_pause_menu()

	var keys_str := "  vs  ".join(players.map(func(c: Character) -> String: return c.character_name))
	print("[BattleScene] %s on %s" % [keys_str, stage_key])

	# Freeze players during countdown, then start match after FIGHT!
	for p in players:
		p.process_mode = Node.PROCESS_MODE_DISABLED
	await _run_countdown()
	for p in players:
		p.process_mode = Node.PROCESS_MODE_INHERIT
	GameManager.start_match()

func _play_stage_audio(stage_key: String) -> void:
	var music_list: Array = STAGE_MUSIC.get(stage_key, STAGE_MUSIC["Windrise"])
	# Filter to existing files so a missing OGG doesn't crash
	var available: Array = music_list.filter(func(p): return ResourceLoader.exists(p))
	if available.is_empty():
		available = STAGE_MUSIC["Windrise"].filter(func(p): return ResourceLoader.exists(p))
	if not available.is_empty():
		AudioManager.play_music(available[randi() % available.size()])

	var amb_path: String = STAGE_AMBIENCE.get(stage_key, "")
	if amb_path != "" and ResourceLoader.exists(amb_path):
		AudioManager.play_ambience(amb_path)

func _validate_all_characters() -> void:
	print("[BattleScene] Validating all 9 character scenes...")
	for key in CHARACTER_SCENES.keys():
		var node := _spawn_character(key, 99)
		if node == null:
			push_error("[BattleScene] FAILED to load: " + key)
		else:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			print("[BattleScene] OK: %s — HP:%.0f Spd:%.0f" % [key, node.max_hp, node.move_speed])
			node.queue_free()
	print("[BattleScene] All character validation complete.")

func _spawn_character(key: String, pid: int) -> Character:
	var scene_path: String = CHARACTER_SCENES.get(key, CHARACTER_SCENES["knight_1"])
	var scene: PackedScene = load(scene_path)
	var char_node := scene.instantiate() as Character
	if char_node == null:
		push_error("[BattleScene] Failed to load character: " + key)
		return null
	char_node.player_id = pid
	char_node.name = "Player%d" % pid
	players_node.add_child(char_node)
	return char_node

func _add_cpu_controller(char_node: Character) -> void:
	var cpu := preload("res://scripts/characters/CPUController.gd").new()
	cpu.name = "CPUController"
	char_node.add_child(cpu)

func _run_countdown() -> void:
	# Build a full-screen CanvasLayer for the overlay
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)

	var font: Font = load("res://assets/ui/fonts/alagard.ttf")

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(0.0, 0.0)
	label.size     = Vector2(1280.0, 720.0)
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 128)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 4)
	label.add_theme_constant_override("shadow_offset_y", 4)
	canvas.add_child(label)

	# Each beat: pop in, hold, fade out
	var beats: Array = ["3", "2", "1", "FIGHT!"]
	for i in beats.size():
		var beat: String = beats[i]
		var is_fight: bool = (beat == "FIGHT!")

		label.text    = beat
		label.scale   = Vector2(0.3, 0.3)
		label.modulate = Color(1.0, 1.0, 1.0, 1.0) if not is_fight \
						else Color(1.0, 0.85, 0.2, 1.0)

		# Pop-in scale
		var pop := create_tween()
		pop.tween_property(label, "scale", Vector2(1.15, 1.15), 0.12)
		pop.tween_property(label, "scale", Vector2(1.0,  1.0),  0.08)
		AudioManager.play_sfx("confirm_1")
		await pop.finished

		# Hold
		await get_tree().create_timer(0.5 if not is_fight else 0.65).timeout

		# Fade out (skip fade on last beat — let it linger as game starts)
		if not is_fight:
			var fade := create_tween()
			fade.tween_property(label, "modulate:a", 0.0, 0.15)
			await fade.finished

	canvas.queue_free()

func _setup_pause_menu() -> void:
	_pause_menu = CanvasLayer.new()
	_pause_menu.layer = 30
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_menu)
	_pause_menu.hide()

	var font_big: Font = load("res://assets/ui/fonts/alagard.ttf")
	var font_sm:  Font = load("res://assets/ui/fonts/Planes_ValMore.ttf")

	# Full-screen dim
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.position = Vector2.ZERO
	dim.size = Vector2(1280.0, 720.0)
	_pause_menu.add_child(dim)

	# Centered panel — 440 × 500
	const PW := 440.0
	const PH := 500.0
	var panel := Panel.new()
	panel.position = Vector2((1280.0 - PW) / 2.0, (720.0 - PH) / 2.0)
	panel.size = Vector2(PW, PH)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.05, 0.14, 0.92)
	panel_style.border_width_left   = 2
	panel_style.border_width_right  = 2
	panel_style.border_width_top    = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(1.0, 0.85, 0.3, 0.7)
	panel_style.corner_radius_top_left     = 8
	panel_style.corner_radius_top_right    = 8
	panel_style.corner_radius_bottom_left  = 8
	panel_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	_pause_menu.add_child(panel)

	# "PAUSED" title
	var title := Label.new()
	title.text = "PAUSED"
	title.position = Vector2(0.0, 22.0)
	title.size = Vector2(PW, 60.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font_big)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	panel.add_child(title)

	# Divider
	var div := ColorRect.new()
	div.color = Color(1.0, 0.85, 0.3, 0.35)
	div.position = Vector2(24.0, 88.0)
	div.size = Vector2(PW - 48.0, 2.0)
	panel.add_child(div)

	# Collect all focusable widgets in top-to-bottom order for nav wiring
	var focusables: Array = []

	# Volume sliders
	var slider_defs := [
		["Music",    "Music"],
		["SFX",      "SFX"],
		["Ambience", "Ambience"],
	]
	var sy := 106.0
	for entry in slider_defs:
		var label_text: String = entry[0]
		var bus_name:   String = entry[1]

		var lbl := Label.new()
		lbl.text = label_text
		lbl.position = Vector2(28.0, sy)
		lbl.size = Vector2(120.0, 30.0)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", font_sm)
		lbl.add_theme_font_size_override("font_size", 17)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0))
		panel.add_child(lbl)

		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 5.0   # coarser step — easier to adjust with D-pad
		var bus_idx := AudioServer.get_bus_index(bus_name)
		var cur_db := AudioServer.get_bus_volume_db(bus_idx) if bus_idx >= 0 else 0.0
		slider.value = clampf((cur_db + 80.0) / 80.0 * 100.0, 0.0, 100.0)
		slider.position = Vector2(155.0, sy + 4.0)
		slider.size = Vector2(PW - 183.0, 22.0)
		slider.focus_mode = Control.FOCUS_ALL
		panel.add_child(slider)
		focusables.append(slider)

		var captured_bus := bus_name
		slider.value_changed.connect(func(val: float) -> void:
			var db := (val / 100.0) * 80.0 - 80.0
			AudioManager.set_volume(captured_bus, db)
		)

		sy += 46.0

	# Divider 2
	var div2 := ColorRect.new()
	div2.color = Color(1.0, 0.85, 0.3, 0.35)
	div2.position = Vector2(24.0, sy + 4.0)
	div2.size = Vector2(PW - 48.0, 2.0)
	panel.add_child(div2)
	sy += 22.0

	# Shared button styleboxes
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.15, 0.1, 0.28, 1.0)
	btn_normal.set_border_width_all(2)
	btn_normal.border_color = Color(1.0, 0.85, 0.3, 0.5)
	btn_normal.set_corner_radius_all(6)

	var btn_hover := btn_normal.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.25, 0.18, 0.45, 1.0)
	btn_hover.border_color = Color(1.0, 0.85, 0.3, 1.0)

	var btn_focus := btn_normal.duplicate() as StyleBoxFlat
	btn_focus.bg_color = Color(0.22, 0.15, 0.42, 1.0)
	btn_focus.border_color = Color(1.0, 0.85, 0.3, 1.0)
	btn_focus.set_border_width_all(3)

	var btn_data := [
		["Resume",       _on_pause_resume],
		["Quit to Menu", _on_pause_quit],
	]
	for entry in btn_data:
		var btn_label: String = entry[0]
		var btn_cb = entry[1]

		var btn := Button.new()
		btn.text = btn_label
		btn.position = Vector2((PW - 320.0) / 2.0, sy)
		btn.size = Vector2(320.0, 52.0)
		btn.focus_mode = Control.FOCUS_ALL
		btn.add_theme_font_override("font", font_big)
		btn.add_theme_font_size_override("font_size", 24)
		btn.add_theme_stylebox_override("normal",   btn_normal)
		btn.add_theme_stylebox_override("hover",    btn_hover)
		btn.add_theme_stylebox_override("focus",    btn_focus)
		btn.add_theme_stylebox_override("pressed",  btn_focus)
		btn.pressed.connect(btn_cb)
		panel.add_child(btn)
		focusables.append(btn)
		sy += 62.0

	# Wire up/down focus neighbors in a wrapping loop
	# Order: Music → SFX → Ambience → Resume → Quit → (wraps back to Music)
	var n := focusables.size()
	for i in n:
		var cur: Control  = focusables[i]
		var prv: Control  = focusables[(i - 1 + n) % n]
		var nxt: Control  = focusables[(i + 1) % n]
		cur.focus_neighbor_top    = cur.get_path_to(prv)
		cur.focus_neighbor_bottom = cur.get_path_to(nxt)
		# Sliders: left/right should change value, not move focus
		if cur is HSlider:
			cur.focus_neighbor_left  = cur.get_path_to(cur)
			cur.focus_neighbor_right = cur.get_path_to(cur)

	# Auto-focus Resume button when menu opens
	_pause_first_focus = focusables[-2] as Control  # Resume is second-to-last

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and GameManager.match_active:
		_toggle_pause()

func _toggle_pause() -> void:
	var pausing := not get_tree().paused
	get_tree().paused = pausing
	if pausing:
		_pause_menu.show()
		if _pause_first_focus:
			_pause_first_focus.grab_focus()
	else:
		_pause_menu.hide()

func _on_pause_resume() -> void:
	_toggle_pause()

func _on_pause_quit() -> void:
	get_tree().paused = false
	AudioManager.stop_music()
	GameManager.go_to_main_menu()

func _on_kill_zone_entered(body: Node) -> void:
	if not (body is Character):
		return
	var character := body as Character
	# DEAD guard: prevents double-kill when two kill zones overlap and fire in the
	# same physics frame.
	# _kill_zone_grace guard: 0.15s window after respawn prevents the physics
	# server from re-firing body_entered before the body has fully re-inserted
	# at the safe spawn position. This is NOT the 2s combat i-frame window —
	# players can still die from kill zones after 0.15s post-respawn.
	if character.state == Character.State.DEAD or character._kill_zone_grace > 0.0:
		return
	print("[BattleScene] P%d entered kill zone — triggering die()" % character.player_id)
	character.die()
