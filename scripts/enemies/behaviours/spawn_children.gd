extends EnemyBehaviour
## Module "spawn_children": launches other enemies at intervals (carrier,
## boss). It stops while the owner's `spawn_enabled` is false, which is how
## destroyed hangars and boss phases switch it.
## Parameters:
##   enemy          id of the enemy type to launch
##   count          how many per launch
##   interval_s     time between launches
##   first_delay_s  time before the first launch
##   max_alive      no launch while this many of its children are still alive
##   spread_m       how far from the owner they appear

var _timer_s: float = 0.0
var _children: Array[Enemy] = []
## Life id of each child when it was launched (pooled enemies are reused).
var _child_lives: PackedInt32Array = []


func _on_setup() -> void:
	_timer_s = _param("first_delay_s", 5.0)


func tick(delta_s: float) -> void:
	if not enemy.spawn_enabled:
		return
	_timer_s -= delta_s
	if _timer_s > 0.0:
		return
	_timer_s = _param("interval_s", 12.0)
	for index: int in range(_children.size() - 1, -1, -1):
		if not is_instance_valid(_children[index]) or _children[index].stats.is_dead() or _children[index].life_id != _child_lives[index]:
			_children.remove_at(index)
			_child_lives.remove_at(index)
	var count: int = mini(int(_param("count", 4.0)), int(_param("max_alive", 16.0)) - _children.size())
	var spread_m: float = _param("spread_m", 40.0)
	for index: int in count:
		var offset: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(-0.6, 0.2), randf_range(-1.0, 1.0)) * spread_m
		var child: Enemy = enemy.get_manager().spawn_enemy(str(params.get("enemy", "")), enemy.global_position + offset, enemy.wave_index)
		if child != null:
			_children.append(child)
			_child_lives.append(child.life_id)
