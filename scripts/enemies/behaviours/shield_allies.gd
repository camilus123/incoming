extends EnemyBehaviour
## Module "shield_allies": covers nearby allies with a shield (Shield
## Frigate). The cover ends shortly after the projector is destroyed or its
## "disable_spawn"-style switch is thrown via `spawn_enabled`.
## Parameters: radius_m, ally_shield, regen_per_s.

const REFRESH_S: float = 0.5

var _timer_s: float = 0.0


func tick(delta_s: float) -> void:
	_timer_s -= delta_s
	if _timer_s > 0.0 or not enemy.spawn_enabled:
		return
	_timer_s = REFRESH_S
	var radius_m: float = _param("radius_m", 300.0)
	for ally: Enemy in enemy.get_manager().get_enemies():
		# Projectors do not cover each other, or the fight would never end.
		if ally == enemy or not ally.is_alive() or ally.enemy_id == enemy.enemy_id:
			continue
		if ally.global_position.distance_to(enemy.global_position) <= radius_m:
			ally.grant_shield(_param("ally_shield", 60.0), _param("regen_per_s", 10.0), REFRESH_S * 2.5)
