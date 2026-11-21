extends EnemyBehaviour
## Module "strafe": attack runs. Dive at the turret firing the enemy's
## "hitscan_burst" attack, bank away to a point in the forward arc, come back.
## Parameters: break_distance_m, retreat_yaw_deg, retreat_pitch_deg,
## retreat_distance_m, retreat_reached_m, retreat_timeout_s.

enum Phase { ATTACK, RETREAT }

var _phase: Phase = Phase.ATTACK
var _retreat_point: Vector3
var _retreat_time_s: float = 0.0


func _on_setup() -> void:
	_phase = Phase.ATTACK
	var to_turret: Vector3 = enemy.get_turret_point() - enemy.global_position
	enemy.velocity = to_turret.normalized() * enemy.speed_mps


func tick(delta_s: float) -> void:
	var turret_point: Vector3 = enemy.get_turret_point()
	if _phase == Phase.ATTACK:
		enemy.steer_towards(turret_point, delta_s)
		var distance: float = enemy.global_position.distance_to(turret_point)
		# Only fire inside the weapon's range and while actually pointing at the turret.
		if distance <= enemy.get_attack_range("hitscan_burst") and enemy.velocity.normalized().dot((turret_point - enemy.global_position).normalized()) > 0.97:
			enemy.try_attack("hitscan_burst")
		if distance <= _param("break_distance_m", 230.0):
			_start_retreat()
	else:
		_retreat_time_s += delta_s
		enemy.steer_towards(_retreat_point, delta_s)
		if enemy.global_position.distance_to(_retreat_point) <= _param("retreat_reached_m", 120.0) or _retreat_time_s >= _param("retreat_timeout_s", 12.0):
			_phase = Phase.ATTACK


func _start_retreat() -> void:
	_phase = Phase.RETREAT
	_retreat_time_s = 0.0
	var direction: Vector3 = TurretAim.direction_from(
		_param_in_range("retreat_yaw_deg", -65.0, 65.0),
		_param_in_range("retreat_pitch_deg", 15.0, 45.0))
	_retreat_point = enemy.get_turret_point() + enemy.get_turret_basis() * direction * _param_in_range("retreat_distance_m", 900.0, 1400.0)
