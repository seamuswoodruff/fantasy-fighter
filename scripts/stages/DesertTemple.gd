# DesertTemple.gd — Phase 9 stage
extends Node2D

signal body_entered_kill_zone(body: Node)

const BG_TEX     := "res://assets/stages/desert_temple/background/desert_background.png"
const PLAT_L     := "res://assets/stages/desert_temple/platforms/desert_plat_main_l.png"
const PLAT_H     := "res://assets/stages/desert_temple/platforms/desert_plat_main_h.png"
const FLOAT_C    := "res://assets/stages/desert_temple/platforms/desert_float_isl_c.png"
const FLOAT_0    := "res://assets/stages/desert_temple/platforms/desert_float_isl_0.png"
const FLOAT_1    := "res://assets/stages/desert_temple/platforms/desert_float_isl_1.png"
const CAVE_ARCH  := "res://assets/stages/desert_temple/platforms/desert_cave_arch.png"

func _ready() -> void:
	_build_visuals()
	for kz in $KillZones.get_children():
		kz.body_entered.connect(_on_kill_zone_body_entered)
	print("[DesertTemple] Stage ready — %d kill zones connected" % $KillZones.get_child_count())

func _build_visuals() -> void:
	# Background — scale to cover viewport height
	var bg := Sprite2D.new()
	bg.texture = load(BG_TEX)
	bg.position = Vector2(640, 360)
	bg.scale = Vector2(0.957, 0.957)
	bg.z_index = -10
	add_child(bg)
	move_child(bg, 0)

	# Left ground section — plat_main_l (360x200), anchor left edge at x=0
	# Visual center x = 180, y = 530 + 100 = 630
	_add_sprite(PLAT_L, Vector2(180, 630), false, 1)

	# Right ground section — plat_main_h (720x230), right-align at x=1280
	# center x = 1280 - 360 = 920, y = 530 + 115 = 645
	_add_sprite(PLAT_H, Vector2(920, 645), false, 1)

	# Cave arch decoration in the gap (visual only, no collision)
	# 340x268 piece, center in gap around x=640, y=700
	_add_sprite(CAVE_ARCH, Vector2(640, 710), false, 0)

	# Floating island sprites
	# Center float: desert_float_isl_0 (285x240)
	# Platform surface roughly y=60 from top of sprite; surface at y=240
	# sprite_center_y = 240 - (240*0.5 - 60) = 240 - 60 = 180... let's place at 265
	_add_sprite(FLOAT_0, Vector2(640, 265), false, 2)

	# Left upper float: desert_float_isl_c (180x165)
	# Surface ~y=60 from top; platform top at y=170
	# sprite_center_y = 170 - (165*0.5 - 60) = 170 - 22.5 = 147.5 ≈ 190
	_add_sprite(FLOAT_C, Vector2(230, 195), false, 2)

	# Right upper float: desert_float_isl_1 (270x145)
	# Surface ~y=30 from top; platform top at y=175
	# sprite_center_y = 175 - (145*0.5 - 30) = 175 - 42.5 = 132.5 ≈ 170
	_add_sprite(FLOAT_1, Vector2(990, 185), false, 2)

func _add_sprite(path: String, pos: Vector2, flip_h: bool = false, z: int = 1) -> void:
	var s := Sprite2D.new()
	s.texture = _load_tex(path)
	s.position = pos
	s.flip_h = flip_h
	s.z_index = z
	add_child(s)

func _load_tex(res_path: String) -> ImageTexture:
	var img := Image.new()
	var err := img.load(ProjectSettings.globalize_path(res_path))
	if err != OK:
		push_error("[DesertTemple] Failed to load texture: " + res_path)
		return null
	return ImageTexture.create_from_image(img)

func _on_kill_zone_body_entered(body: Node) -> void:
	body_entered_kill_zone.emit(body)
