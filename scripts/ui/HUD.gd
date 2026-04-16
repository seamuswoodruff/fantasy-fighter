# HUD.gd — Phase 6 Heads-Up Display
# CanvasLayer rendered above the game world (layer = 10).
# Builds both player panels programmatically in _ready().
#
# Usage from BattleScene:  hud.set_characters(player1, player2)
extends CanvasLayer

# Health bar fill widgets (polled every frame)
var _p1_bar: TextureProgressBar = null
var _p2_bar: TextureProgressBar = null

# Stock icon TextureRect arrays (3 per player)
var _p1_icons: Array = []
var _p2_icons: Array = []

# Character references — set by BattleScene after spawning
var _p1_char: Character = null
var _p2_char: Character = null

# Textures
var _tex_green: Texture2D = null
var _tex_red:   Texture2D = null
var _tex_frame: Texture2D = null   # HealthBar DARK.png — used as overlay TextureRect
var _tex_stock: Texture2D = null
var _tex_panel: Texture2D = null

const LOW_HP_RATIO := 0.25

# Panel geometry — both panels are 300 × 100 px
const PANEL_W   := 300.0
const PANEL_H   := 100.0
const PANEL_Y   := 578.0   # top of panel; bottom = 578+110 = 688 (32px margin on 720 screen)
const PANEL_P1X := 10.0
const PANEL_P2X := 970.0   # 970 + 300 = 1270 (10px margin on 1280 screen)

func _ready() -> void:
	_tex_green  = load("res://assets/ui/hud/greenbar_1.png")
	_tex_red    = load("res://assets/ui/hud/redblue_1.png")
	_tex_frame  = load("res://assets/ui/hud/HealthBar DARK.png")
	_tex_stock  = load("res://assets/ui/hud/rpg_1.png")
	_tex_panel  = load("res://assets/ui/hud/Darkupdate.png")

	_build_panel(1)
	_build_panel(2)

	GameManager.stock_lost.connect(_on_stock_lost)
	print("[HUD] Ready — panels built, stock_lost connected")

# ── Panel construction ────────────────────────────────────────────────────────
func _build_panel(pid: int) -> void:
	var px := PANEL_P1X if pid == 1 else PANEL_P2X

	# Root control — no background colour; we draw the panel texture inside
	var root := Control.new()
	root.name = "P%dPanel" % pid
	root.position = Vector2(px, PANEL_Y)
	root.size = Vector2(PANEL_W, PANEL_H)
	add_child(root)

	# ── Background panel texture ──────────────────────────────────────────────
	var bg := TextureRect.new()
	bg.texture = _tex_panel
	bg.size = Vector2(PANEL_W, PANEL_H)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(bg)

	# ── Player label ──────────────────────────────────────────────────────────
	var lbl := Label.new()
	lbl.text = "P%d" % pid
	lbl.position = Vector2(8.0, 6.0)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_font_size_override("font_size", 14)
	root.add_child(lbl)

	# ── Health bar ────────────────────────────────────────────────────────────
	# texture_under = dark trough (HealthBar DARK.png) — visible on depleted side
	# texture_progress = green fill — shrinks left-to-right as HP drops
	var bar := TextureProgressBar.new()
	bar.position = Vector2(34.0, 10.0)
	bar.size = Vector2(258.0, 32.0)
	bar.texture_under = _tex_frame
	bar.texture_progress = _tex_green
	bar.max_value = 100.0
	bar.value = 100.0
	bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	root.add_child(bar)

	if pid == 1:
		_p1_bar = bar
	else:
		_p2_bar = bar

	# ── Stock icons ───────────────────────────────────────────────────────────
	var icons: Array = []
	var icon_y := 52.0
	var icon_x_start := 36.0
	for i in range(3):
		var icon := TextureRect.new()
		icon.texture = _tex_stock
		icon.position = Vector2(icon_x_start + i * 38.0, icon_y)
		icon.size = Vector2(34.0, 34.0)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		root.add_child(icon)
		icons.append(icon)

	if pid == 1:
		_p1_icons = icons
	else:
		_p2_icons = icons

# ── Public API ────────────────────────────────────────────────────────────────
func set_characters(p1: Character, p2: Character) -> void:
	_p1_char = p1
	_p2_char = p2
	print("[HUD] Characters linked — P1: %s  P2: %s" % [p1.character_name, p2.character_name])

# ── Per-frame HP polling ──────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	_refresh_bar(_p1_bar, _p1_char)
	_refresh_bar(_p2_bar, _p2_char)

func _refresh_bar(bar: TextureProgressBar, ch: Character) -> void:
	if bar == null or ch == null:
		return
	var ratio: float = ch.current_hp / ch.max_hp
	bar.value = ratio * 100.0

	# Swap fill texture at low HP
	if ratio < LOW_HP_RATIO:
		if bar.texture_progress != _tex_red:
			bar.texture_progress = _tex_red
	else:
		if bar.texture_progress != _tex_green:
			bar.texture_progress = _tex_green

# ── Stock icon greying ────────────────────────────────────────────────────────
func _on_stock_lost(player_id: int) -> void:
	var icons: Array  = _p1_icons if player_id == 1 else _p2_icons
	var remaining: int = GameManager.p1_stocks if player_id == 1 else GameManager.p2_stocks

	# P1: grey from rightmost → index = remaining (2→grey[2], 1→grey[1], 0→grey[0])
	# P2: grey from leftmost  → index = 2 - remaining
	var grey_idx: int
	if player_id == 1:
		grey_idx = remaining
	else:
		grey_idx = 2 - remaining

	if grey_idx >= 0 and grey_idx < icons.size():
		(icons[grey_idx] as TextureRect).modulate = Color(0.3, 0.3, 0.3)
		print("[HUD] P%d stock lost — greyed icon[%d], %d remaining" % [player_id, grey_idx, remaining])
