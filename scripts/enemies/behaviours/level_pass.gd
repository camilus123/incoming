extends EnemyBehaviour
## Module "level_pass": fly level over the turret and release the enemy's
## "guided_bomb" attack once in range. After passing overhead the enemy
## circles round out of sight and starts a new pass from the front.
## Parameters: exit_distance_m, repass_delay_s.

var _heading: Vector3 = Vector3.FORWARD
var _released: bool = false
var _away_left_s: float = 0.0


func _on_setup() -> void:
	_released = false
	_away_left_s = 0.0
	var to_turret: Vector3 = enemy.get_turret_point() - enemy.global_position
	to_turret.y = 0.0
	_heading = to_turret.normalized() if to_turret.length_squared() > 1.0 else Vector3.BACK
	enemy.velocity = _heading * enemy.speed_mps


func tick(delta_s: float) -> void:
	if enemy.away:
		enemy.velocity = Vector3.ZERO
		_away_left_s -= delta_s
		if _away_left_s <= 0.0:
			enemy.return_for_new_pass()
		return

	enemy.velocity = _heading * enemy.speed_mps
	var to_turret: Vector3 = enemy.get_turret_point() - enemy.global_position
	to_turret.y = 0.0
	var approaching: bool = to_turret.dot(_heading) > 0.0
	if approaching and not _released and to_turret.length() <= enemy.get_attack_range("guided_bomb"):
		_released = enemy.try_attack("guided_bomb")
	if not approaching and to_turret.length() >= _param("exit_distance_m", 500.0) and not enemy.is_attacking():
		_away_left_s = _param("repass_delay_s", 6.0)
		enemy.set_away(true)
