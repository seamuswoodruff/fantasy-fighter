# Credits.gd
extends Node2D

const SCROLL_SPEED := 35.0   # pixels per second

const PAUSE_DURATION := 1.0  # seconds to hold at top and bottom

enum ScrollState { PAUSE_TOP, SCROLLING, PAUSE_BOTTOM }

var _scroll_container: ScrollContainer
var _scroll_accum: float = 0.0
var _pause_timer: float = PAUSE_DURATION
var _scroll_state: ScrollState = ScrollState.PAUSE_TOP

func _ready() -> void:
	_build_ui()
	AudioManager.play_music("res://the waters by faespencer.ogg")
	print("[Credits] Ready")

func _build_ui() -> void:
	var font_big := load("res://assets/ui/fonts/alagard.ttf") as FontFile
	var font_sm  := load("res://assets/ui/fonts/Planes_ValMore.ttf") as FontFile

	# Animated GIF background (Credits.gif → sprite sheet, 71 frames, 8 cols × 9 rows, 10 fps)
	const SHEET_PATH := "res://assets/ui/backgrounds/credits_bg_sheet.png"
	const FRAME_W := 640
	const FRAME_H := 480
	const FRAME_COUNT := 71
	const COLS := 8
	const BG_FPS := 10.0

	var bg_img := Image.new()
	bg_img.load(ProjectSettings.globalize_path(SHEET_PATH))
	var bg_tex := ImageTexture.create_from_image(bg_img)

	var sf := SpriteFrames.new()
	sf.add_animation("bg")
	sf.set_animation_loop("bg", true)
	sf.set_animation_speed("bg", BG_FPS)
	for i in FRAME_COUNT:
		var at := AtlasTexture.new()
		at.atlas  = bg_tex
		at.region = Rect2((i % COLS) * FRAME_W, int(i / float(COLS)) * FRAME_H, FRAME_W, FRAME_H)
		sf.add_frame("bg", at)

	var bg_anim := AnimatedSprite2D.new()
	bg_anim.sprite_frames = sf
	bg_anim.animation = "bg"
	bg_anim.play("bg")
	var bg_scale := maxf(1280.0 / FRAME_W, 720.0 / FRAME_H)
	bg_anim.scale   = Vector2(bg_scale, bg_scale)
	bg_anim.position = Vector2(640.0, 360.0)
	bg_anim.z_index = -1
	add_child(bg_anim)

	# Dark overlay so text stays readable over the animation
	var overlay := ColorRect.new()
	overlay.color    = Color(0.0, 0.0, 0.0, 0.55)
	overlay.position = Vector2.ZERO
	overlay.size     = Vector2(1280.0, 720.0)
	add_child(overlay)

	# Back button (top-left, matching other screens)
	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.position = Vector2(30.0, 20.0)
	back_btn.size = Vector2(160.0, 44.0)
	back_btn.add_theme_font_override("font", font_big)
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)

	# "CREDITS" title
	var title := Label.new()
	title.text = "CREDITS"
	title.position = Vector2(0.0, 24.0)
	title.size = Vector2(1280.0, 60.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font_big)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(title)

	# Scroll container (below title, above bottom edge)
	_scroll_container = ScrollContainer.new()
	_scroll_container.position = Vector2(240.0, 100.0)
	_scroll_container.size = Vector2(800.0, 590.0)
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll_container)

	# RichTextLabel inside container
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.custom_minimum_size = Vector2(780.0, 0.0)
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.add_theme_font_override("normal_font", font_sm)
	rtl.add_theme_font_size_override("normal_font_size", 16)
	rtl.add_theme_font_override("bold_font", font_big)
	rtl.add_theme_font_size_override("bold_font_size", 22)
	rtl.add_theme_color_override("default_color", Color(0.85, 0.85, 1.0))
	_scroll_container.add_child(rtl)
	rtl.text = _credits_text()  # set after add_child so BBCode processes on live node


func _credits_text() -> String:
	return """
[center][color=#ffd966][b]OF SHADOWS AND STEEL[/b][/color][/center]
[center]A 2D Local Multiplayer Platform Fighter[/center]
[center]DCS 247 — AI in the World  ·  Bowdoin College  ·  2026[/center]

[center]────────────────────────────[/center]

[center][color=#ffd966][b]DEVELOPMENT[/b][/color][/center]
[center]Seamus Woodruff — Developer[/center]
[center]Claude Code (Anthropic) — AI Coding Assistant[/center]

[center]────────────────────────────[/center]

[center][color=#ffd966][b]ENGINE[/b][/color][/center]
[center]Godot 4.6.2[/center]
[center]godotengine.org[/center]

[center]────────────────────────────[/center]

[center][color=#ffd966][b]MUSIC[/b][/color][/center]
[center][b]Battle Music[/b][/center]
[center]PeriTune — "Battle Tracks" JRPG Battle Music Pack[/center]
[center]peritune.com[/center]
[center]Free for commercial use[/center]
[center][b]Menu & Ambient Music[/b][/center]
[center]alkakrab — alkakrab.itch.io[/center]
[center]HitsLab — "Japan Japanese Music"[/center]

[center]────────────────────────────[/center]

[center][color=#ffd966][b]SOUND EFFECTS[/b][/color][/center]
[center][b]UI Sounds[/b][/center]
[center]leohpaz — "10 Retro RPG Menu Sounds"[/center]
[center]opengameart.org  ·  CC-BY 3.0 / CC-BY 4.0[/center]
[center]Lokif — "GUI Sound Effects"[/center]
[center]opengameart.org  ·  CC0 Public Domain[/center]
[center][b]Fantasy SFX Pack[/b][/center]
[center]TomMusic — tommusic.itch.io[/center]

[center]────────────────────────────[/center]

[center][color=#ffd966][b]VISUAL ASSETS[/b][/color][/center]
[center][b]Character Sprites[/b][/center]
[center]Craftpix.net — Medieval Sprite Packs[/center]
[center]craftpix.net[/center]
[center][b]Stage Backgrounds — Windrise[/b][/center]
[center]The Flavare — "Mondstadt" Pixel Art Asset Pack[/center]
[center][b]Stage Backgrounds — Ruins & Desert Temple[/b][/center]
[center]Generated with Gemini[/center]
[center][b]Stage Platform Assets[/b][/center]
[center]Penzilla — "Floating Islands"[/center]
[center]itch.io/penzilla[/center]
[center][b]VFX — Hit Sparks, KO, Magic[/b][/center]
[center]Craftpix.net — craftpix.net[/center]
[center][b]Homescreen Animation[/b][/center]
[center]Sandy Gordon — patreon.com/sandygordon[/center]
[center][b]Character Select Background[/b][/center]
[center]Lennart Butz — "View over Japanese Temple in River Valley"[/center]
[center]artstation.com[/center]
[center][b]Options Screen Background[/b][/center]
[center]vertibirdo — deviantart.com/vertibirdo[/center]
[center][b]Win Screens[/b][/center]
[center]Generated with Gemini[/center]

[center]────────────────────────────[/center]

[center][color=#ffd966][b]FONTS[/b][/color][/center]
[center]Alagard — Hewett Tsoi[/center]
[center]dafont.com/alagard.font  ·  Free[/center]
[center]Planes ValMore[/center]

[center]────────────────────────────[/center]

[center][color=#ffd966][b]SPECIAL THANKS[/b][/color][/center]
[center]My lovely roommates for playtesting[/center]

[center]────────────────────────────[/center]

[center][color=#888888]Built with Claude Code for DCS 247 — AI in the World[/color][/center]
[center]Bowdoin College  ·  2026[/center]
[center] [/center]
[center] [/center]
"""

func _process(delta: float) -> void:
	match _scroll_state:
		ScrollState.PAUSE_TOP:
			_pause_timer -= delta
			if _pause_timer <= 0.0:
				_scroll_state = ScrollState.SCROLLING
		ScrollState.SCROLLING:
			_scroll_accum += SCROLL_SPEED * delta
			_scroll_container.scroll_vertical = int(_scroll_accum)
			var max_scroll := _scroll_container.get_v_scroll_bar().max_value - _scroll_container.size.y
			if _scroll_accum >= max_scroll:
				_scroll_state = ScrollState.PAUSE_BOTTOM
				_pause_timer = PAUSE_DURATION
		ScrollState.PAUSE_BOTTOM:
			_pause_timer -= delta
			if _pause_timer <= 0.0:
				_scroll_accum = 0.0
				_scroll_container.scroll_vertical = 0
				_scroll_state = ScrollState.PAUSE_TOP
				_pause_timer = PAUSE_DURATION

	if Input.is_action_just_pressed("ui_cancel"):
		_on_back_pressed()

func _on_back_pressed() -> void:
	AudioManager.play_sfx("click")
	GameManager.go_to_main_menu()
