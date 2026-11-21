extends EnemyBehaviour
## Module "approach_kamikaze": fly at the turret while weaving, then ram it.
## Parameters: weave_amplitude_m, weave_period_s, weave_fade_distance_m,
## impact_distance_m.

var _phase: float = 0.0
var _time_s: float = 0.0


func _on_setup() -> void:
	_phase = randf() * TAU
	_time_s = 0.0


func tick(delta_s: float) -> void:
	_time_s += delta_s
	var to_turret: Vector3 = enemy.get_turret_point() - enemy.global_position
	var distance: float = to_turret.length()
	if distance <= _param("impact_distance_m", 7.0):
		enemy.try_attack("collision")
		enemy.self_destruct()
		return

	var forward: Vector3 = to_turret / distance
	var side: Vector3 = forward.cross(Vector3.UP)
	side = side.normalized() if side.length_squared() > 0.0001 else Vector3.RIGHT
	var lift: Vector3 = side.cross(forward)
	# The weave shrinks close to the turret so the drone still arrives.
	var fade: float = clampf(distance / _param("weave_fade_distance_m", 220.0), 0.0, 1.0)
	var rate: float = TAU / maxf(_param("weave_period_s", 2.4), 0.1)
	var swing: float = _param("weave_amplitude_m", 14.0) * rate * fade
	var angle: float = _time_s * rate + _phase
	enemy.velocity = forward * enemy.speed_mps + side * cos(angle) * swing + lift * sin(angle * 0.7) * swing * 0.5
