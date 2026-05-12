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

# Optional loop-then-tail animation pattern.
# Set loop_end_frame + loop_count + tail_start_frame to enable.
# Leave at defaults (-1 / 0) for normal infinite looping behaviour.
var loop_end_frame: int = -1    # inclusive last frame of the loop section
var loop_count: int = 0         # 0 = loop forever; >0 = loop N times then play tail
var tail_start_frame: int = -1  # first frame of the die-out section
var _loops_completed: int = 0
var _in_tail: bool = false

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
			_advance_frame(spr)

	var move := speed * direction * delta
	position.x += move
	_distance_traveled += absf(move)
	# Once the tail is playing we let it finish regardless of distance
	if not _in_tail and _distance_traveled >= max_distance:
		_start_tail_or_free(spr)

func _advance_frame(spr: Sprite2D) -> void:
	if _in_tail:
		# Play tail frames to the end then despawn
		var next := spr.frame + 1
		if next >= spr.hframes:
			queue_free()
		else:
			spr.frame = next
	elif loop_end_frame >= 0 and loop_count > 0:
		# Looping section — track completions and switch to tail when done
		var next := spr.frame + 1
		if next > loop_end_frame:
			_loops_completed += 1
			if _loops_completed >= loop_count:
				_start_tail_or_free(spr)
			else:
				spr.frame = 0
		else:
			spr.frame = next
	else:
		# Default: loop all frames forever
		spr.frame = (spr.frame + 1) % spr.hframes

func _start_tail_or_free(spr: Sprite2D) -> void:
	if tail_start_frame >= 0 and spr != null:
		_in_tail = true
		spr.frame = tail_start_frame
	else:
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
	var actual := damage * 0.2 if target.is_blocking else damage
	target.take_damage(damage, global_position, false)
	if extra_hitstun > 0.0 and target.has_method("_apply_extra_hitstun"):
		target._apply_extra_hitstun(extra_hitstun)
	target._spawn_damage_number(global_position, actual)
	AudioManager.play_sfx("Sword Impact Hit")
	if not is_piercing:
		queue_free()
