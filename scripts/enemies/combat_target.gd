class_name CombatTarget
extends Node3D
## Base class for everything the player can shoot: test dummies now, enemies
## and enemy projectiles from M2 on.
##
## Holds the health state ([TargetStats]) and applies hits through
## [DamageCalc]. Weapons find targets through `CombatTarget.registry`.

signal damaged(result: DamageResult)
signal died()

const GROUP: StringName = &"combat_targets"

## Every target in the scene tree, alive or not (check `is_alive()`). Hot loops
## (proximity fuses, splash, lock-on) read this instead of asking the scene
## tree for the group, which builds a new array on every call.
static var registry: Array[CombatTarget] = []

var stats: TargetStats = TargetStats.new()
## Current velocity in m/s, used by homing weapons and lead indicators.
var velocity: Vector3 = Vector3.ZERO
## Rough size, used for proximity fuses, splash damage and HUD brackets.
var target_radius_m: float = 1.0


func _enter_tree() -> void:
	add_to_group(GROUP)
	registry.append(self)


func _exit_tree() -> void:
	registry.erase(self)


func _process(delta_s: float) -> void:
	stats.tick(delta_s)


func is_alive() -> bool:
	return not stats.is_dead() and is_inside_tree()


## Radius within which a shot counts as a hit right now. Subclasses with a
## distance-assisted hurtbox return its current radius.
func get_hit_radius() -> float:
	return target_radius_m


## The point weapons should aim at.
func get_aim_point() -> Vector3:
	return global_position


## Applies one hit. Returns what happened, or null if the target was already dead.
func apply_damage(info: DamageInfo) -> DamageResult:
	if not is_alive():
		return null
	var result: DamageResult = DamageCalc.apply(info.amount, info.damage_type, info.armour_pierce, stats, GameData.loader.get_config("combat"), info.armour_factor)
	damaged.emit(result)
	EventBus.target_hit.emit(info.source_slot, result.killed)
	if result.killed:
		_on_killed()
		died.emit()
	return result


## Override for death behaviour (effects, removal, respawn).
func _on_killed() -> void:
	pass
