# HUD.gd — dynamic N-player version (Change 6 — 4-player brief)
extends CanvasLayer

const LOW_HP_RATIO  := 0.25
const PANEL_HEIGHT  := 80.0
const PANEL_GAP     := 8.0

var _chars: Array[Character] = []
var _bars: Array[TextureProgressBar] = []
var _heart_groups: Array = []   # Array of Arrays of TextureRect
var _stock_count: int = 3

var _tex_green: Texture2D = null
var _tex_red:   Texture2D = null
var _heart_tex: ImageTexture = null

func _ready() -> void:
	_tex_green = load("res://assets/ui/hud/greenbar_1.png")
	_tex_red   = load("res://assets/ui/hud/redblue_1.png")
	_heart_tex = _create_heart_texture()
	GameManager.stock_lost.connect(_on_stock_lost)

# ── Public API ─────────────────────────────────────────────────────────────────
func set_players(p_array: Array) -> void:
	for c in p_array:
		_chars.append(c as Character)
	_stock_count = GameManager.stock_count
	_build_panels()

# Legacy shim so any code still calling set_characters() doesn't crash
func set_characters(p1: Character, p2: Character) -> void:
	set_players([p1, p2])

# ── Build ──────────────────────────────────────────────────────────────────────
func _build_panels() -> void:
	var n := _chars.size()
	var screen_w := 1280.0
	var panel_w := (screen_w - float(n + 1) * PANEL_GAP) / float(n)
	var font_sm := load("res://assets/ui/fonts/Planes_ValMore.ttf") as FontFile

	for i in n:
		var px := PANEL_GAP + float(i) * (panel_w + PANEL_GAP)
		var py := 720.0 - PANEL_HEIGHT - 8.0

		# Dark panel background
		var bg := ColorRect.new()
		bg.color = Color(0.05, 0.04, 0.10, 0.85)
		bg.position = Vector2(px, py)
		bg.size     = Vector2(panel_w, PANEL_HEIGHT)
		add_child(bg)

		# Health bar (TextureProgressBar)
		var bar := TextureProgressBar.new()
		bar.texture_under    = load("res://assets/ui/hud/HealthBar DARK.png")
		bar.texture_progress = _tex_green
		bar.nine_patch_stretch = true
		bar.min_value = 0.0
		bar.max_value = _chars[i].max_hp if _chars[i] != null else 100.0
		bar.value     = bar.max_value
		bar.position  = Vector2(px + 4.0, py + 4.0)
		bar.size      = Vector2(panel_w - 8.0, 26.0)
		add_child(bar)
		_bars.append(bar)

		# Hearts — show only _stock_count hearts
		var hearts: Array = []
		var heart_w    := 22.0
		var hearts_total_w := float(_stock_count) * heart_w
		var hearts_x   := px + (panel_w - hearts_total_w) / 2.0
		for j in _stock_count:
			var rect := TextureRect.new()
			rect.texture       = _heart_tex
			rect.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			rect.position      = Vector2(hearts_x + float(j) * heart_w, py + 36.0)
			rect.size          = Vector2(20.0, 20.0)
			add_child(rect)
			hearts.append(rect)
		_heart_groups.append(hearts)

		# Player label (P1 / P2 / CPU etc.)
		var lbl := Label.new()
		lbl.text = "CPU" if GameManager.player_is_cpu[i] else "P%d" % (i + 1)
		lbl.position = Vector2(px + 4.0, py + 58.0)
		lbl.size     = Vector2(panel_w - 8.0, 18.0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", font_sm)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
		add_child(lbl)

# ── Per-frame update ───────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	for i in _chars.size():
		if i >= _bars.size() or _chars[i] == null:
			continue
		var ch := _chars[i]
		var bar := _bars[i]
		bar.value = ch.current_hp
		var ratio := ch.current_hp / ch.max_hp
		if ratio < LOW_HP_RATIO:
			if bar.texture_progress != _tex_red:
				bar.texture_progress = _tex_red
		else:
			if bar.texture_progress != _tex_green:
				bar.texture_progress = _tex_green

# ── Stock-loss callback ────────────────────────────────────────────────────────
func _on_stock_lost(player_id: int) -> void:
	var idx := player_id - 1
	if idx < 0 or idx >= _heart_groups.size():
		return
	var remaining: int = GameManager.player_stocks[idx]
	var hearts: Array = _heart_groups[idx]
	for j in hearts.size():
		if j >= remaining:
			(hearts[j] as TextureRect).modulate = Color(0.3, 0.3, 0.3, 0.6)

# ── Pixel-art heart texture ────────────────────────────────────────────────────
func _create_heart_texture() -> ImageTexture:
	var pattern: Array = [
		[0, 1, 1, 0, 1, 1, 0],
		[1, 1, 1, 1, 1, 1, 1],
		[1, 1, 1, 1, 1, 1, 1],
		[1, 1, 1, 1, 1, 1, 1],
		[0, 1, 1, 1, 1, 1, 0],
		[0, 0, 1, 1, 1, 0, 0],
		[0, 0, 0, 1, 0, 0, 0],
	]
	var red  := Color(0.92, 0.10, 0.15, 1.0)
	var dark := Color(0.50, 0.04, 0.07, 1.0)
	var none := Color(0.0,  0.0,  0.0,  0.0)
	var img  := Image.create(7, 7, false, Image.FORMAT_RGBA8)
	for y in 7:
		for x in 7:
			if pattern[y][x] == 0:
				img.set_pixel(x, y, none)
			elif x == 6 or y == 6:
				img.set_pixel(x, y, dark)
			else:
				img.set_pixel(x, y, red)
	return ImageTexture.create_from_image(img)
