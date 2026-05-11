# HUD.gd — fixed-width top health bars + inline name/stocks (N-player)
extends CanvasLayer

const LOW_HP_RATIO  := 0.25
const BAR_W         := 260.0
const BAR_H         := 28.0
const BAR_GAP       := 12.0
const INFO_H        := 20.0   # height of name+stocks row below bar
const INFO_GAP      := 4.0    # gap between bar bottom and info row

const COL_GREEN  := Color(0.18, 0.78, 0.22, 1.0)
const COL_RED    := Color(0.85, 0.14, 0.18, 1.0)
const COL_TROUGH := Color(0.22, 0.04, 0.08, 1.0)
const COL_BORDER := Color(0.55, 0.08, 0.14, 1.0)

var _chars: Array[Character] = []
var _fills: Array[ColorRect] = []
var _fill_max_w: Array[float] = []
var _heart_groups: Array = []
var _stock_count: int = 3
var _heart_tex: ImageTexture = null

func _ready() -> void:
	_heart_tex = _create_heart_texture()
	GameManager.stock_lost.connect(_on_stock_lost)

# ── Public API ─────────────────────────────────────────────────────────────────
func set_players(p_array: Array) -> void:
	for c in p_array:
		_chars.append(c as Character)
	_stock_count = GameManager.stock_count
	_build_hud()

func set_characters(p1: Character, p2: Character) -> void:
	set_players([p1, p2])

# ── Build ──────────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	var n        := _chars.size()
	var screen_w := 1280.0
	var bar_w    := BAR_W
	var total_w  := float(n) * bar_w + float(n - 1) * BAR_GAP
	if total_w > screen_w - 16.0:
		bar_w = (screen_w - 16.0 - float(n - 1) * BAR_GAP) / float(n)
	var start_x := (screen_w - (float(n) * bar_w + float(n - 1) * BAR_GAP)) / 2.0
	var font_sm := load("res://assets/ui/fonts/Planes_ValMore.ttf") as FontFile

	for i in n:
		var bx  := start_x + float(i) * (bar_w + BAR_GAP)
		var by  := BAR_GAP
		var pad := 3.0

		# ── Health bar ───────────────────────────────────────────────────────

		# Outer border
		var border := ColorRect.new()
		border.color    = COL_BORDER
		border.position = Vector2(bx - 2.0, by - 2.0)
		border.size     = Vector2(bar_w + 4.0, BAR_H + 4.0)
		add_child(border)

		# Dark trough
		var trough := ColorRect.new()
		trough.color    = COL_TROUGH
		trough.position = Vector2(bx, by)
		trough.size     = Vector2(bar_w, BAR_H)
		add_child(trough)

		# Green fill
		var fill_w := bar_w - pad * 2.0
		var fill := ColorRect.new()
		fill.color    = COL_GREEN
		fill.position = Vector2(bx + pad, by + pad)
		fill.size     = Vector2(fill_w, BAR_H - pad * 2.0)
		add_child(fill)
		_fills.append(fill)
		_fill_max_w.append(fill_w)

		# "+" label
		var plus := Label.new()
		plus.text     = "+"
		plus.position = Vector2(bx + 3.0, by - 1.0)
		plus.size     = Vector2(22.0, BAR_H)
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus.add_theme_font_override("font", font_sm)
		plus.add_theme_font_size_override("font_size", 22)
		plus.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		add_child(plus)

		# ── Info row (name + stocks) directly below bar ──────────────────────
		var iy := by + BAR_H + INFO_GAP

		# Player name — left-aligned with bar
		var lbl := Label.new()
		lbl.text = "CPU" if GameManager.player_is_cpu[i] else "P%d" % (i + 1)
		lbl.position = Vector2(bx, iy)
		lbl.size     = Vector2(60.0, INFO_H)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", font_sm)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
		add_child(lbl)

		# Hearts — centered under the bar, same y as name
		var hearts: Array = []
		var heart_w        := 20.0
		var hearts_total_w := float(_stock_count) * heart_w
		var hearts_x       := bx + (bar_w - hearts_total_w) / 2.0
		for j in _stock_count:
			var rect := TextureRect.new()
			rect.texture        = _heart_tex
			rect.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			rect.position       = Vector2(hearts_x + float(j) * heart_w, iy)
			rect.size           = Vector2(18.0, INFO_H)
			add_child(rect)
			hearts.append(rect)
		_heart_groups.append(hearts)

# ── Per-frame update ───────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	for i in _chars.size():
		if i >= _fills.size() or _chars[i] == null:
			continue
		var ch    := _chars[i]
		var fill  := _fills[i]
		var ratio := ch.current_hp / ch.max_hp
		fill.size.x = _fill_max_w[i] * ratio
		fill.color  = COL_RED if ratio < LOW_HP_RATIO else COL_GREEN

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
