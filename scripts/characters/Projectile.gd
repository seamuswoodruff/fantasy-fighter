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
var _distance_traveled: float = 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	var move := speed * direction * delta
	position.x += move
	_distance_traveled += absf(move)
	if _distance_traveled >= max_distance:
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
