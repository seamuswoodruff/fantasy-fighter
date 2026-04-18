# Projectile.gd — Base projectile for arrows, fireballs, magic missiles, etc.
# Despawns after max_distance traveled or on hitting a hurtbox.
# Set is_piercing=true for sphere that doesn't stop on first hit.
class_name Projectile
extends Area2D

@export var speed: float = 400.0
@export var damage: float = 14.0
@export var max_distance: float = 1000.0
@export var is_piercing: bool = false
@export var extra_hitstun: float = 0.0  # LightningMage charged ball applies 1s bonus

var direction: float = 1.0
var owner_id: int = 1
var anim_fps: float = 12.0
var _distance_traveled: float = 0.0
var _anim_timer: float = 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 3  # layer 1 (platforms/world) + layer 2 (hurtboxes)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	# Advance sprite animation manually (Sprite2D doesn't animate on its own)
	var spr := get_node("Sprite2D") as Sprite2D
	if spr and spr.hframes > 1:
		_anim_timer += delta
		var frame_dur := 1.0 / anim_fps
		if _anim_timer >= frame_dur:
			_anim_timer -= frame_dur
			spr.frame = (spr.frame + 1) % spr.hframes

	var move := speed * direction * delta
	position.x += move
	_distance_traveled += absf(move)
	if _distance_traveled >= max_distance:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body is StaticBody2D:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	var target = area.get_parent()
	if not (target is Character):
		return
	if target.player_id == owner_id:
		return
	target.take_damage(damage, global_position, false)
	if extra_hitstun > 0.0 and target.has_method("_apply_extra_hitstun"):
		target._apply_extra_hitstun(extra_hitstun)
	VFXManager.play_single("hit_sparks", global_position, 1.5, 0.12, 618)
	AudioManager.play_sfx("Sword Impact Hit")
	if not is_piercing:
		queue_free()
