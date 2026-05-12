class_name KnightSlash
extends Area2D

var direction: float = 1.0
var vfx_row: int = 2
var owner_id: int = 0
var speed: float = 280.0
var damage: float = 18.0
var max_distance: float = 220.0

const SEQUENCE: Array = [2, 0, 0, 1, 1, 2, 2, 2, 2, 2, 1, 0, 10, 11]
const FPS: float = 16.0

var _distance: float = 0.0
var _hit_connected: bool = false
var _anim_timer: float = 0.0
var _seq_idx: int = 0
var _spr: Sprite2D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 3
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	_spr = Sprite2D.new()
	_spr.texture = load("res://assets/vfx/hit_sparks/946.png")
	_spr.region_enabled = true
	_spr.region_rect = Rect2(SEQUENCE[0] * 64, vfx_row * 64, 64, 64)
	_spr.scale = Vector2(1.5 * direction, 1.5)
	add_child(_spr)

	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(44, 44)
	shape_node.shape = rect
	add_child(shape_node)

func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	_distance += speed * delta

	_anim_timer += delta
	while _anim_timer >= 1.0 / FPS:
		_anim_timer -= 1.0 / FPS
		_seq_idx += 1
		if _seq_idx >= SEQUENCE.size():
			queue_free()
			return
		_spr.region_rect = Rect2(SEQUENCE[_seq_idx] * 64, vfx_row * 64, 64, 64)

	if _distance >= max_distance:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if _hit_connected:
		return
	var target := area.get_parent()
	if not target.has_method("take_damage"):
		return
	if target.get("player_id") == owner_id:
		return
	_hit_connected = true
	var actual := damage * 0.2 if target.get("is_blocking") else damage
	target.take_damage(damage, global_position, true)
	target._spawn_damage_number(global_position, actual)
	VFXManager.play_single("hit_sparks", global_position, 2.0, 0.12, 618)
	AudioManager.play_sfx("Sword Impact Hit")
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is StaticBody2D:
		queue_free()
