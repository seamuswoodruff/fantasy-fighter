# Warrior.gd — Warrior archetype (knight_1, knight_2, knight_3)
# Stats: HP 150, Speed 200, Jump -550
# Special: Shield — brief invincibility that absorbs the next hit
class_name Warrior
extends "res://scripts/characters/Character.gd"

# How long the shield special lasts
const SHIELD_DURATION: float = 0.5

var _shield_timer: float = 0.0

func _ready() -> void:
	# Warrior stats
	max_hp = 150.0
	move_speed = 200.0
	jump_force = -550.0
	attack_damage_light = 12.0
	attack_damage_heavy = 22.0
	knockback_multiplier = 1.0
	super._ready()

func _physics_process(delta: float) -> void:
	# Tick the shield timer
	if _shield_timer > 0.0:
		_shield_timer -= delta
		if _shield_timer <= 0.0:
			is_invincible = false
			if state == State.SPECIAL:
				change_state(State.IDLE)
	super._physics_process(delta)

func special_attack() -> void:
	if _is_locked():
		return
	# Activate shield: brief invincibility + Defend animation
	_shield_timer = SHIELD_DURATION
	is_invincible = true
	change_state(State.SPECIAL)
	print("[Warrior] P%d shield activated (%.1fs)" % [player_id, SHIELD_DURATION])
