class_name EnemyBehaviour
extends RefCounted
## Base class of behaviour modules. An enemy type lists one or more behaviours
## (data/behaviours/*.json); each names a module and its parameters.
## Every frame each module's `tick()` runs in order. Movement modules set
## `enemy.velocity`; the enemy then moves and turns to face its velocity.

var enemy: Enemy
var params: Dictionary = {}


func setup(owner_enemy: Enemy, behaviour_params: Dictionary) -> void:
	enemy = owner_enemy
	params = behaviour_params
	_on_setup()


## Called again when the enemy is placed at a new position (spawn, new pass).
func reset() -> void:
	_on_setup()


func tick(_delta_s: float) -> void:
	pass


func _on_setup() -> void:
	pass


func _param(key: String, fallback: float) -> float:
	return float(params.get(key, fallback))


## A random value from a [min, max] parameter.
func _param_in_range(key: String, fallback_min: float, fallback_max: float) -> float:
	var pair: Variant = params.get(key)
	if pair is Array and (pair as Array).size() >= 2:
		return randf_range(float(pair[0]), float(pair[1]))
	return randf_range(fallback_min, fallback_max)
