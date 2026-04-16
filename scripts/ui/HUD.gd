# HUD.gd — Phase 6 Heads-Up Display
# All visual nodes live in HUD.tscn and are fully editable in the Godot editor.
# This script handles only runtime logic: HP polling and stock-loss greying.
extends CanvasLayer

@onready var _p1_bar: TextureProgressBar = $P1Bar
@onready var _p2_bar: TextureProgressBar = $P2Bar

# Hearts are TextureRect nodes in the scene; sorted left→right in _ready()
var _p1_hearts: Array = []
var _p2_hearts: Array = []
var _p1_char: Character = null
var _p2_char: Character = null
var _tex_green: Texture2D = null
var _tex_red:   Texture2D = null

const LOW_HP_RATIO := 0.25

func _ready() -> void:
	_tex_green = load("res://assets/ui/hud/greenbar_1.png")
	_tex_red   = load("res://assets/ui/hud/redblue_1.png")

	# Generate the 7×7 pixel-art heart texture and apply to all scene hearts
	var heart_tex := _create_heart_texture()
	var p1_rects: Array = [$P1Heart0, $P1Heart1, $P1Heart2]
	var p2_rects: Array = [$P2Heart0, $P2Heart1, $P2Heart2]

	# Sort by screen-x so index 0 is always leftmost (safe even if editor order changes)
	p1_rects.sort_custom(func(a, b) -> bool: return (a as Control).position.x < (b as Control).position.x)
	p2_rects.sort_custom(func(a, b) -> bool: return (a as Control).position.x < (b as Control).position.x)

	for rect in p1_rects + p2_rects:
		(rect as TextureRect).texture = heart_tex

	_p1_hearts = p1_rects
	_p2_hearts = p2_rects

	GameManager.stock_lost.connect(_on_stock_lost)

# ── Pixel-art heart texture (7×7, 3× scale via TEXTURE_FILTER_NEAREST) ────────
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

	var img := Image.create(7, 7, false, Image.FORMAT_RGBA8)
	for y in 7:
		for x in 7:
			if pattern[y][x] == 0:
				img.set_pixel(x, y, none)
			elif x == 6 or y == 6:
				img.set_pixel(x, y, dark)
			else:
				img.set_pixel(x, y, red)

	return ImageTexture.create_from_image(img)

# ── Public API ────────────────────────────────────────────────────────────────
func set_characters(p1: Character, p2: Character) -> void:
	_p1_char = p1
	_p2_char = p2

func _process(_delta: float) -> void:
	_refresh(_p1_bar, _p1_char)
	_refresh(_p2_bar, _p2_char)

func _refresh(bar: TextureProgressBar, ch: Character) -> void:
	if bar == null or ch == null:
		return
	var ratio: float = ch.current_hp / ch.max_hp
	bar.value = ratio * 100.0
	if ratio < LOW_HP_RATIO:
		if bar.texture_progress != _tex_red:
			bar.texture_progress = _tex_red
	else:
		if bar.texture_progress != _tex_green:
			bar.texture_progress = _tex_green

func _on_stock_lost(player_id: int) -> void:
	var hearts: Array  = _p1_hearts if player_id == 1 else _p2_hearts
	var remaining: int = GameManager.p1_stocks if player_id == 1 else GameManager.p2_stocks
	var grey_idx: int  = 2 - remaining  # left→right depletion for both players
	if grey_idx >= 0 and grey_idx < hearts.size():
		(hearts[grey_idx] as TextureRect).modulate = Color(0.3, 0.3, 0.3, 0.6)
