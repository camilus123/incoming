extends EnemyBehaviour
## Module "orbit_drop": falls straight at the turret from high altitude with a
## glowing re-entry trail and strikes it with the enemy's "collision" attack.
## Parameters: impact_distance_m, trail_length_s, trail_color [r, g, b].


func tick(_delta_s: float) -> void:
	var to_turret: Vector3 = enemy.get_turret_point() - enemy.global_position
	var distance: float = to_turret.length()
	if distance <= _param("impact_distance_m", 8.0):
		enemy.try_attack("collision")
		enemy.self_destruct()
		return
	enemy.velocity = to_turret / distance * enemy.speed_mps
	var fx: CombatFx = enemy.get_manager().get_fx()
	if fx != null:
		var color: Array = params.get("trail_color", [1.0, 0.55, 0.2])
		var tail: Vector3 = enemy.global_position - enemy.velocity * _param("trail_length_s", 0.35)
		fx.tracer(enemy.global_position, tail, Color(color[0], color[1], color[2]), enemy.target_radius_m * 0.5, 0.06, 4.0)
