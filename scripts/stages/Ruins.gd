# Ruins.gd — Phase 9 stage
extends Node2D

signal body_entered_kill_zone(body: Node)

const BG_TEX   := "res://assets/stages/ruins/background/ruins_background.png"
const ARCH_ISL := "res://assets/stages/ruins/platforms/ruins_arch_island.png"
const PLAIN_ISL:= "res://assets/stages/ruins/platforms/ruins_plain_island.png"
const SURF_TILE:= "res://assets/stages/ruins/platforms/ruins_surface_tile.png"
const BODY_TILE:= "res://assets/stages/ruins/platforms/ruins_body_tile.png"

func _ready() -> void:
	_build_visuals()
	for kz in $KillZones.get_children():
		kz.body_entered.connect(_on_kill_zone_body_entered)
	print("[Ruins] Stage ready — %d kill zones connected" % $KillZones.get_child_count())

func _build_visuals() -> void:
	# Background — scale to cover viewport height, slight crop at sides is fine
	var bg := Sprite2D.new()
	bg.texture = load(BG_TEX)
	bg.position = Vector2(640, 360)
	bg.scale = Vector2(0.957, 0.957)
	bg.z_index = -10
	add_child(bg)
	move_child(bg, 0)

	# Ground surface tiles along top of each ground section
	var surf_tex: ImageTexture = _load_tex(SURF_TILE)
	var body_tex: ImageTexture = _load_tex(BODY_TILE)
	if surf_tex == null or body_tex == null:
		return
	var sw := surf_tex.get_width()   # 80
	var sh := surf_tex.get_height()  # 52
	var bw := body_tex.get_width()   # 80
	var bh := body_tex.get_height()  # 60

	for start_x in [0, 830]:
		var x: int = start_x
		while x < start_x + 460:
			var s := Sprite2D.new()
			s.texture = surf_tex
			s.position = Vector2(x + sw * 0.5, 540 + sh * 0.5)
			s.z_index = 1
			add_child(s)
			x += sw
		# Body fill below surface
		var y_body := 540.0 + sh
		while y_body < 720:
			var xi: int = start_x
			while xi < start_x + 460:
				var b := Sprite2D.new()
				b.texture = body_tex
				b.position = Vector2(xi + bw * 0.5, y_body + bh * 0.5)
				b.z_index = 1
				add_child(b)
				xi += bw
			y_body += bh

	# Floating island sprites
	# Center float: arch island — sprite bottom-of-island ≈ 80% down the 231px sprite
	# Platform surface at y=285; sprite center = 285 - (231*0.5 - 80) = 285 - 35.5 ≈ 280
	_add_sprite(ARCH_ISL,  Vector2(550,  310), false, 2)
	# Upper-right float: plain island — surface near top of 90px sprite (~y=20)
	# Platform surface at y=165; sprite center = 165 - (90*0.5 - 20) = 165 - 25 = 140
	_add_sprite(PLAIN_ISL, Vector2(960,  155), false, 2)
	# Small center-right float: same plain island
	_add_sprite(PLAIN_ISL, Vector2(770,  378), false, 2)

func _add_sprite(path: String, pos: Vector2, flip_h: bool = false, z: int = 1) -> void:
	var s := Sprite2D.new()
	s.texture = _load_tex(path)
	s.position = pos
	s.flip_h = flip_h
	s.z_index = z
	add_child(s)

func _load_tex(res_path: String) -> ImageTexture:
	# Use Image.load for PNGs that may lack .import sidecars
	var img := Image.new()
	var err := img.load(ProjectSettings.globalize_path(res_path))
	if err != OK:
		push_error("[Ruins] Failed to load texture: " + res_path)
		return null
	return ImageTexture.create_from_image(img)

func _on_kill_zone_body_entered(body: Node) -> void:
	body_entered_kill_zone.emit(body)
